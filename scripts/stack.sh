#!/usr/bin/env bash
# Unified stack management — replaces dify-up.sh, n8n-up.sh, ollama-up.sh
# Usage: bash scripts/stack.sh <up|down|status|logs> [dify|n8n|ollama|caddy|all]
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ACTION="${1:-}"
SERVICE="${2:-}"

usage() {
  echo "Usage: bash scripts/stack.sh <up|down|status|logs> [dify|n8n|ollama|caddy|all]"
  echo ""
  echo "Examples:"
  echo "  bash scripts/stack.sh up ollama     # Start Ollama + pull embedding model"
  echo "  bash scripts/stack.sh up dify       # Fetch Dify compose + start"
  echo "  bash scripts/stack.sh up n8n        # Start n8n + postgres"
  echo "  bash scripts/stack.sh up caddy      # Start Caddy reverse proxy"
  echo "  bash scripts/stack.sh status         # Show all container status"
  echo "  bash scripts/stack.sh logs n8n      # Tail n8n logs"
  exit 1
}

[[ -z "$ACTION" ]] && usage

# Compose file lookup
COMPOSE_BASE="compose/docker-compose.yml"
declare -A COMPOSE_FILES
COMPOSE_FILES[dify]="compose/dify/docker-compose.yaml"
COMPOSE_FILES[n8n]="compose/n8n/docker-compose.n8n.yml"
COMPOSE_FILES[ollama]="compose/ollama/docker-compose.ollama.yml"
COMPOSE_FILES[caddy]="compose/caddy/docker-compose.caddy.yml"

compose_cmd() {
  local svc="$1"
  shift
  if [[ "$svc" == "all" ]]; then
    docker compose --project-directory "$ROOT" -f "$COMPOSE_BASE" --env-file "$ROOT/.env" "$@"
  else
    docker compose --project-directory "$ROOT" -f "$COMPOSE_BASE" -f "${COMPOSE_FILES[$svc]}" --env-file "$ROOT/.env" "$@"
  fi
}

case "$ACTION" in
  up)
    [[ -z "$SERVICE" ]] && usage
    if [[ "$SERVICE" == "ollama" ]]; then
      EMBED_MODEL=$(grep '^OLLAMA_EMBED_MODEL=' .env | cut -d= -f2)
      EMBED_MODEL="${EMBED_MODEL:-bge-m3}"
      compose_cmd ollama up -d
      echo "Waiting for Ollama to be ready ..."
      for i in $(seq 1 20); do
        if docker exec ollama ollama list >/dev/null 2>&1; then break; fi
        sleep 2
      done
      echo "Pulling embedding model: ${EMBED_MODEL} ..."
      docker exec ollama ollama pull "$EMBED_MODEL"
      echo "Test embeddings:"
      docker exec ollama curl -s http://127.0.0.1:11434/api/embeddings \
        -d "{\"model\":\"${EMBED_MODEL}\",\"prompt\":\"ทดสอบ\"}" | head -c 200
      echo
    elif [[ "$SERVICE" == "dify" ]]; then
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
        bash scripts/dify-patch-compose.sh
      fi
      compose_cmd dify up -d
    else
      compose_cmd "$SERVICE" up -d
    fi
    compose_cmd "$SERVICE" ps
    ;;
  down)
    [[ -z "$SERVICE" ]] && usage
    compose_cmd "$SERVICE" down
    ;;
  status)
    docker compose ls
    echo ""
    docker ps --filter network=ols-chatbot
    ;;
  logs)
    [[ -z "$SERVICE" ]] && SERVICE="all"
    compose_cmd "$SERVICE" logs -f
    ;;
  *)
    usage
    ;;
esac
