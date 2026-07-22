#!/usr/bin/env bash
# Pre-flight checks for OLS chatbot server (run on server via `bash scripts/preflight.sh`)
# Now validates .env against n8n/env-schema.json
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
  COMPOSE_VER=$(docker compose version --short)
  ok "compose v2: ${COMPOSE_VER}"
  # Check for include support (v2.20+)
  MAJOR=$(echo "$COMPOSE_VER" | cut -d. -f1)
  MINOR=$(echo "$COMPOSE_VER" | cut -d. -f2)
  if [[ "$MAJOR" -ge 2 && "$MINOR" -ge 20 ]]; then
    ok "compose v2.20+ (include directive supported)"
  else
    warn "compose < v2.20 — include directive not supported; upgrade recommended"
  fi
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

echo "Ports (80, 443 must be free; 5678 proxied through Caddy):"
for p in 80 443; do
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

echo "Environment validation (n8n/env-schema.json):"
if [[ -f n8n/env-schema.json ]]; then
  if command -v python3 >/dev/null 2>&1; then
    python3 -c "
import json, os, sys
with open('n8n/env-schema.json') as f:
    schema = json.load(f)
required = schema.get('required', [])
missing = []
for var in required:
    val = os.environ.get(var, '')
    # Also check .env file
    if not val:
        try:
            with open('.env') as ef:
                for line in ef:
                    if line.startswith(var + '='):
                        val = line.split('=', 1)[1].strip()
                        break
        except:
            pass
    if not val:
        missing.append(var)
if missing:
    print(f'  [FAIL] Missing env vars: {\", \".join(missing)}')
    sys.exit(1)
else:
    print(f'  [OK]   All {len(required)} required env vars present')
" 2>&1
    if [[ $? -eq 0 ]]; then
      ok "env schema validation passed"
    else
      fail "env schema validation failed — see above"
    fi
  else
    warn "python3 not found — skipping env schema validation"
  fi
else
  warn "n8n/env-schema.json not found — skipping env validation"
fi
echo

echo "Image tags:"
for tag in DIFY_IMAGE_TAG N8N_IMAGE_TAG OLLAMA_IMAGE_TAG; do
  VAL=$(grep "^${tag}=" .env 2>/dev/null | cut -d= -f2- | sed 's/[[:space:]]*#.*//' | xargs)
  if [[ -n "$VAL" ]]; then
    ok "${tag}=${VAL}"
  else
    warn "${tag} not set in .env"
  fi
done
echo

echo "=== Summary: ${PASS} OK, ${FAIL} FAIL ==="
if (( FAIL > 0 )); then
  echo "Fix FAIL items before proceeding to Phase 2."
  exit 1
fi
exit 0
