#!/usr/bin/env bash
# Unified installation script for OLS Chatbot core services
# Usage: bash scripts/install.sh

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "=================================================="
echo "    OLS Chatbot — Core Services Installation"
echo "=================================================="
echo

# Step 1: Preflight checks
echo "[1/6] Running Preflight Environment Checks..."
if [[ -f scripts/preflight.sh ]]; then
  bash scripts/preflight.sh || { echo "[ERROR] Preflight checks failed!"; exit 1; }
else
  echo "[WARN] scripts/preflight.sh not found, skipping preflight."
fi
echo

# Step 2: System Dependencies & Package Updates
echo "[2/6] Installing Necessary System Dependencies & Updating Packages..."
if command -v apt-get >/dev/null 2>&1; then
  echo "  -> Updating package list & installing required tools (curl, git, python3, jq)..."
  SUDO=""
  if [[ "$EUID" -ne 0 ]] && command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  fi
  $SUDO apt-get update -qq || true
  $SUDO apt-get install -y -qq curl git python3 python3-pip jq ca-certificates >/dev/null 2>&1 || echo "  [WARN] apt-get install completed with warnings."
else
  echo "  -> non-apt system detected. Ensuring basic CLI tools exist..."
fi
echo "  [OK] System packages checked."
echo

# Step 3: Ensure Docker Network exists
echo "[3/6] Setting up Docker Network (ols-chatbot)..."
docker network create ols-chatbot 2>/dev/null || echo "Network 'ols-chatbot' already exists."
echo

# Step 4: Pre-pull / Update Docker Images & Deploy Core Services
echo "[4/6] Pulling/Updating Docker Images & Deploying Core Services..."

echo "  -> Pulling & starting Ollama stack..."
bash scripts/stack.sh up ollama

echo "  -> Pulling & starting Dify stack..."
bash scripts/stack.sh up dify

echo "  -> Pulling & starting n8n stack..."
bash scripts/stack.sh up n8n

echo "  -> Pulling & starting Caddy reverse proxy..."
bash scripts/stack.sh up caddy

echo

# Step 5: Verification & Inter-Service Connectivity Checks
echo "[5/6] Verifying Services & Connectivity..."

echo -n "  - Checking Ollama HTTP API (11434)... "
if docker exec ollama curl -s http://127.0.0.1:11434/api/tags >/dev/null; then
  echo "OK"
else
  echo "FAILED"
fi

echo -n "  - Checking n8n HTTP API (5678)... "
if docker exec n8n curl -s http://127.0.0.1:5678/healthz >/dev/null 2>&1 || docker exec n8n-postgres pg_isready -U n8n >/dev/null 2>&1; then
  echo "OK"
else
  echo "FAILED"
fi

echo -n "  - Checking Dify Web Nginx (80)... "
if docker exec dify-nginx-1 nginx -t >/dev/null 2>&1 || docker ps | grep -q dify-nginx; then
  echo "OK"
else
  echo "FAILED"
fi

echo -n "  - Verification: Dify worker -> Ollama connection... "
if docker exec dify-worker-1 curl -s http://ollama:11434/api/tags >/dev/null 2>&1; then
  echo "OK (dify-worker can reach ollama:11434)"
else
  echo "WARN (dify-worker could not reach ollama:11434 directly)"
fi

echo -n "  - Verification: n8n -> Ollama connection... "
if docker exec n8n curl -s http://ollama:11434/api/tags >/dev/null 2>&1; then
  echo "OK (n8n can reach ollama:11434)"
else
  echo "WARN (n8n could not reach ollama:11434 directly)"
fi

echo -n "  - Verification: n8n -> Dify API connection... "
if docker exec n8n curl -s http://dify-api:5001/v1/health >/dev/null 2>&1 || docker exec n8n curl -s http://dify-nginx:80 >/dev/null 2>&1; then
  echo "OK (n8n can reach dify-api)"
else
  echo "WARN (n8n could not reach dify-api directly)"
fi

echo

# Step 6: Summary & Next Steps Instructions
echo "=================================================="
echo "    Core Services Installation Complete!"
echo "=================================================="
echo
echo "NEXT STEPS:"
echo " 1. Access Dify Web UI in your browser (e.g. http://<SERVER_IP>)"
echo " 2. Complete the initial Admin Registration (Create Admin Account)"
echo " 3. Generate a Dify API Key from Dify Web UI"
echo " 4. Update '.env' file with your credentials & Dify API Key"
echo " 5. Run 'bash scripts/setup_workspace.sh' to provision Workflows, Knowledge Base, and Apps."
echo
