#!/usr/bin/env bash
# Bring up n8n + its postgres (Phase 3).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "Starting n8n ..."
docker compose --project-directory "${ROOT}" -f compose/docker-compose.yml -f compose/n8n/docker-compose.n8n.yml --env-file .env up -d
docker compose --project-directory "${ROOT}" -f compose/docker-compose.yml -f compose/n8n/docker-compose.n8n.yml ps

echo
echo "n8n is running — access at:"
echo "  http://<server-ip>:5678"
echo "  (ensure firewall/secgroup allows port 5678)"