#!/usr/bin/env bash
# Backup Dify + n8n postgres + volumes. Reads targets from backup-manifest.yml.
# Usage: bash scripts/backup.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BACKUP_DIR=$(grep '^BACKUP_DIR=' .env | cut -d= -f2)
RETENTION=$(grep '^BACKUP_RETENTION_DAYS=' .env | cut -d= -f2)
BACKUP_DIR="${BACKUP_DIR:-/var/backups/ols-chatbot}"
RETENTION="${RETENTION:-14}"

STAMP=$(date -u +%Y%m%dT%H%M%SZ)
DEST="${BACKUP_DIR}/${STAMP}"
mkdir -p "$DEST"

echo "Backing up to ${DEST} ..."

# Read backup-manifest.yml and process each target
# Simple YAML parser — reads targets array
python3 -c "
import yaml, subprocess, sys, os

with open('backup-manifest.yml') as f:
    manifest = yaml.safe_load(f)

for t in manifest['targets']:
    name = t['name']
    typ = t['type']
    dest = '$DEST'
    print(f'  -> {name} ...')

    if typ == 'postgres':
        container = t['container']
        db = t['db']
        user = t['user']
        cmd = f'docker exec {container} pg_dump -U {user} -d {db}'
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        if result.returncode != 0:
            print(f'  [WARN] {name} dump failed: {result.stderr.strip()}')
            continue
        import gzip
        with gzip.open(f'{dest}/{name}.sql.gz', 'wt') as fout:
            fout.write(result.stdout)

    elif typ == 'volume':
        volume = t['volume']
        # Try both naming conventions
        for vol_name in [volume, volume.replace('ols-chatbot_', 'chatbot_')]:
            cmd = f'docker run --rm -v {vol_name}:/data -v {dest}:/backup alpine tar czf /backup/{name}.tar.gz -C /data .'
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
            if result.returncode == 0:
                break
        else:
            print(f'  [WARN] {name} volume not found (tried {volume} and {volume.replace(\"ols-chatbot_\", \"chatbot_\")})')

print('Backup targets processed.')
" 2>&1 || {
  echo "Python/YAML backup failed — falling back to manual backup"
  # Fallback: hardcoded backup for critical targets
  echo "  -> n8n postgres ..."
  docker exec n8n-postgres pg_dump -U n8n -d n8n | gzip > "$DEST/n8n-db.sql.gz"
  echo "  -> n8n-data volume ..."
  docker run --rm -v ols-chatbot_n8n-data:/data -v "$DEST":/backup alpine \
    tar czf /backup/n8n-data.tar.gz -C /data . 2>/dev/null || \
  docker run --rm -v chatbot_n8n-data:/data -v "$DEST":/backup alpine \
    tar czf /backup/n8n-data.tar.gz -C /data . 2>/dev/null || \
  echo "  [WARN] n8n-data volume not found"
}

echo "Encrypting (age) ..."
if command -v age >/dev/null 2>&1 && [[ -n "${AGE_RECIPIENT:-}" ]]; then
  tar czf - -C "$BACKUP_DIR" "$STAMP" | age -r "$AGE_RECIPIENT" > "${DEST}.age.tar.gz"
  rm -rf "$DEST"
  echo "  -> encrypted archive: ${DEST}.age.tar.gz"
else
  echo "  [WARN] age not found or AGE_RECIPIENT unset — leaving unencrypted (set up age for production)"
fi

echo "Rotating (keep ${RETENTION} days) ..."
find "$BACKUP_DIR" -maxdepth 1 -type f -mtime "+${RETENTION}" -delete
find "$BACKUP_DIR" -maxdepth 1 -type d -mtime "+${RETENTION}" -exec rm -rf {} +

echo "Backup done: ${DEST}"
echo "Test restore with: bash scripts/restore.sh <archive>"
