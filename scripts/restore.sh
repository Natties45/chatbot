#!/usr/bin/env bash
# Restore from a backup archive. Usage: bash scripts/restore.sh <archive>
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ARCHIVE="${1:-}"
if [[ -z "$ARCHIVE" ]]; then
  echo "Usage: bash scripts/restore.sh <archive>"
  echo "  archive = path to .age.tar.gz (encrypted) or a backup directory"
  exit 1
fi

BACKUP_DIR=$(grep '^BACKUP_DIR=' .env | cut -d= -f2)
BACKUP_DIR="${BACKUP_DIR:-/var/backups/ols-chatbot}"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

if [[ "$ARCHIVE" == *.age.tar.gz ]]; then
  if ! command -v age >/dev/null 2>&1; then
    echo "age is required to decrypt .age.tar.gz"; exit 1
  fi
  age -d "$ARCHIVE" | tar xzf - -C "$WORK"
  STAMP=$(ls "$WORK" | head -1)
  SRC="${WORK}/${STAMP}"
else
  SRC="$ARCHIVE"
fi

echo "Restoring from ${SRC} ..."

echo "Stopping stacks ..."
docker compose -f compose/docker-compose.yml -f compose/n8n/docker-compose.n8n.yml down
docker compose -f compose/docker-compose.yml -f compose/dify/docker-compose.yaml down || true

echo "  -> Dify postgres ..."
DIFY_DB_CONTAINER=$(docker ps --filter name=db_postgres --format '{{.Names}}' | head -1)
if [[ -z "$DIFY_DB_CONTAINER" ]]; then
  echo "  [WARN] Dify postgres container not found — skipping"
else
  gunzip -c "${SRC}/dify-postgres.sql.gz" | docker exec -i "$DIFY_DB_CONTAINER" psql -U postgres
fi

echo "  -> n8n postgres ..."
gunzip -c "${SRC}/n8n-postgres.sql.gz" | docker exec -i n8n-postgres psql -U n8n -d n8n

echo "  -> n8n-data volume ..."
docker run --rm -v ols-chatbot_n8n-data:/data -v "${SRC}":/backup alpine \
  tar xzf /backup/n8n-data.tar.gz -C /data

if [[ -f "${SRC}/weaviate-data.tar.gz" ]]; then
  echo "  -> Weaviate volume ..."
  docker run --rm -v ols-chatbot_weaviate-data:/data -v "${SRC}":/backup alpine \
    tar xzf /backup/weaviate-data.tar.gz -C /data
fi

echo "Bringing stacks back up ..."
bash scripts/ollama-up.sh
bash scripts/dify-up.sh
bash scripts/n8n-up.sh

echo "Restore complete."