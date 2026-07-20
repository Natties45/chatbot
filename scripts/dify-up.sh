#!/usr/bin/env bash
# Bring up Dify stack (Phase 2). Fetches vendored compose first if missing.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

DIFY_TAG=$(grep '^DIFY_IMAGE_TAG=' .env | cut -d= -f2- | sed 's/[[:space:]]*#.*//' | xargs)
if [[ -z "$DIFY_TAG" ]]; then
  echo "DIFY_IMAGE_TAG not set in .env"; exit 1
fi

if [[ ! -f compose/dify/docker-compose.yaml ]]; then
  echo "Fetching Dify compose @ ${DIFY_TAG} ..."
  git clone --depth 1 --branch "$DIFY_TAG" https://github.com/langgenius/dify.git /tmp/dify-src
  cp /tmp/dify-src/docker/docker-compose.yaml compose/dify/docker-compose.yaml
  cp /tmp/dify-src/docker/.env.example .env.example.dify
  rm -rf /tmp/dify-src
  echo "  -> compose/dify/docker-compose.yaml"
  echo "  -> .env.example.dify (merge relevant vars into .env)"
  echo "  NOTE: edit compose/dify/docker-compose.yaml to use network: ols-chatbot"
fi

echo "Starting Dify ..."
docker compose --project-directory "${ROOT}" -f compose/docker-compose.yml -f compose/dify/docker-compose.yaml --env-file "${ROOT}/.env" up -d
docker compose --project-directory "${ROOT}" -f compose/docker-compose.yml -f compose/dify/docker-compose.yaml ps