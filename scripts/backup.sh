#!/usr/bin/env bash
# Backup Dify + n8n postgres + Weaviate volume. Encrypted with age if available.
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

echo "  -> Dify postgres ..."
docker exec dify-db pg_dumpall -U postgres | gzip > "$DEST/dify-postgres.sql.gz"

echo "  -> n8n postgres ..."
docker exec n8n-postgres pg_dump -U n8n -d n8n | gzip > "$DEST/n8n-postgres.sql.gz"

echo "  -> Weaviate volume ..."
docker run --rm -v ols-chatbot_weaviate-data:/data -v "$DEST":/backup alpine \
  tar czf /backup/weaviate-data.tar.gz -C /data . 2>/dev/null || \
  echo "  [WARN] weaviate-data volume not found (Dify may use built-in vector store)"

echo "  -> n8n-data volume ..."
docker run --rm -v ols-chatbot_n8n-data:/data -v "$DEST":/backup alpine \
  tar czf /backup/n8n-data.tar.gz -C /data .

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