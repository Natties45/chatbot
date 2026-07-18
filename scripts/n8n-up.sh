#!/usr/bin/env bash
# Bring up n8n + its postgres (Phase 3).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "Starting n8n ..."
docker compose -f compose/docker-compose.yml -f compose/n8n/docker-compose.n8n.yml --env-file .env up -d
docker compose -f compose/docker-compose.yml -f compose/n8n/docker-compose.n8n.yml ps

echo
echo "Access n8n via SSH tunnel from your workstation:"
echo "  ssh -L 5678:127.0.0.1:5678 chatbot"
echo "  then open http://localhost:5678"