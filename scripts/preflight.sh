#!/usr/bin/env bash
# Pre-flight checks for OLS chatbot server (run on server via `bash scripts/preflight.sh`)
set -u

PASS=0
FAIL=0
warn() { echo "  [WARN] $1"; }
ok()   { echo "  [OK]   $1"; PASS=$((PASS+1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL+1)); }

echo "=== OLS chatbot pre-flight ==="
echo

echo "OS:"
if [[ -f /etc/os-release ]]; then
  . /etc/os-release
  ok "OS: ${PRETTY_NAME:-unknown}"
else
  warn "/etc/os-release not found"
fi
echo

echo "Docker Engine:"
if command -v docker >/dev/null 2>&1; then
  ok "docker found: $(docker --version)"
else
  fail "docker not installed — install from https://docs.docker.com/engine/install/"
fi
echo

echo "Docker Compose v2:"
if docker compose version >/dev/null 2>&1; then
  ok "compose v2: $(docker compose version --short)"
else
  fail "docker compose v2 missing — install compose plugin"
fi
echo

echo "Memory:"
MEM_MB=$(free -m | awk '/^Mem:/ {print $2}')
AVAIL_MB=$(free -m | awk '/^Mem:/ {print $7}')
ok "total RAM: ${MEM_MB} MB; available: ${AVAIL_MB} MB"
if (( AVAIL_MB < 8000 )); then
  fail "available RAM < 8 GB (proposal requires 8-24 GB; recommended 16 GB)"
fi
echo

echo "Disk (root):"
DISK_AVAIL_KB=$(df -k / | awk 'NR==2 {print $4}')
DISK_AVAIL_GB=$((DISK_AVAIL_KB / 1024 / 1024))
ok "free on /: ${DISK_AVAIL_GB} GB"
if (( DISK_AVAIL_GB < 40 )); then
  fail "free disk < 40 GB"
fi
echo

echo "Ports (80, 443, 5678 must be free):"
for p in 80 443 5678; do
  if command -v ss >/dev/null 2>&1; then
    if ss -tlnp 2>/dev/null | awk '{print $4}' | grep -q ":${p}$"; then
      fail "port ${p} already in use"
    else
      ok "port ${p} free"
    fi
  elif command -v netstat >/dev/null 2>&1; then
    if netstat -tlnp 2>/dev/null | awk '{print $4}' | grep -q ":${p}$"; then
      fail "port ${p} already in use"
    else
      ok "port ${p} free"
    fi
  else
    warn "cannot check port ${p} (ss/netstat not found)"
  fi
done
echo

echo "Public IP:"
PUB_IP=$(curl -s --max-time 5 ifconfig.me || true)
if [[ -n "$PUB_IP" ]]; then
  ok "public IP: ${PUB_IP} (IP-only mode — domain added later)"
else
  warn "could not determine public IP (offline or no curl)"
fi
echo

echo "Ollama image tag:"
if grep -q '^OLLAMA_IMAGE_TAG=' .env 2>/dev/null; then
  ok "OLLAMA_IMAGE_TAG set in .env"
else
  warn "OLLAMA_IMAGE_TAG not set in .env (default 0.3.6 will be used)"
fi
echo

echo "=== Summary: ${PASS} OK, ${FAIL} FAIL ==="
if (( FAIL > 0 )); then
  echo "Fix FAIL items before proceeding to Phase 2."
  exit 1
fi
exit 0