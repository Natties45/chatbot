#!/usr/bin/env bash
# Bring up Ollama local (embeddings) and pull bge-m3 (Phase 2).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

EMBED_MODEL=$(grep '^OLLAMA_EMBED_MODEL=' .env | cut -d= -f2)
EMBED_MODEL="${EMBED_MODEL:-bge-m3}"

echo "Starting Ollama ..."
docker compose --project-directory "${ROOT}" -f compose/docker-compose.yml -f compose/ollama/docker-compose.ollama.yml --env-file .env up -d
docker compose --project-directory "${ROOT}" -f compose/docker-compose.yml -f compose/ollama/docker-compose.ollama.yml ps

echo "Waiting for Ollama to be ready ..."
for i in $(seq 1 20); do
  if docker exec ollama ollama list >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

echo "Pulling embedding model: ${EMBED_MODEL} ..."
docker exec ollama ollama pull "$EMBED_MODEL"

echo
echo "Test embeddings:"
docker exec ollama curl -s http://127.0.0.1:11434/api/embeddings \
  -d "{\"model\":\"${EMBED_MODEL}\",\"prompt\":\"ทดสอบ\"}" \
  | head -c 200
echo