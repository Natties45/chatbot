# Repo Sync + Secrets Restructure Plan

> **For Hermes:** Execute this plan task-by-task. Do NOT implement LLM or chatbot features yet — this is purely structural.

**Goal:** Sync local `chatbot/` repo with server-side changes, organize files cleanly, and move secrets to `secrets/.env`.

**Architecture:** The repo has two layers: (1) source-of-truth files committed to git, (2) deploy-time artifacts (Dify vendored compose, env files) fetched at deploy time. Server-side patches to deploy-time files must be captured as scripts or Makefile targets so they're reproducible, not committed as static files.

**Key constraint:** `compose/dify/` is mostly gitignored (fetched at deploy time). Server-side patches to those files must be preserved as patch scripts, not as committed copies.

---

## Current State

### Local repo (`chatbot/`)
```
chatbot/
├── .env.example          ← template, committed
├── .gitignore            ← ignores .env, compose/dify/docker-compose.yaml, volumes/
├── AGENTS.md             ← committed
├── Makefile              ← committed
├── README.md             ← committed
├── compose/
│   ├── docker-compose.yml
│   ├── caddy/            ← committed (Caddyfile, compose)
│   ├── dify/             ← gitignored (only README.md committed)
│   ├── n8n/              ← committed (compose)
│   └── ollama/           ← committed (compose)
├── dify/prompts/         ← committed
├── docs/                 ← committed
├── n8n/workflows/        ← committed
├── n8n/credentials/       ← committed
├── scripts/              ← committed
└── secrets/              ← committed (README.md + .gitkeep only)
```

### Server-side changes NOT in repo

| File | Change | Source |
|------|--------|--------|
| `compose/dify/docker-compose.yaml` | Patched: profiles removed, volume paths fixed, nginx ports removed, networks fixed | Server runtime |
| `compose/dify/envs/` | Full env files (shared.env, api.env, web.env, etc.) | Server runtime |
| `compose/dify/nginx/` | Copied from Dify upstream | Server runtime |
| `compose/dify/pgvector/` | Copied from Dify upstream | Server runtime |
| `compose/dify/ssrf_proxy/` | Copied from Dify upstream | Server runtime |
| `compose/dify/volumes/` | Copied from Dify upstream | Server runtime |
| `compose/dify/certbot/` | Copied from Dify upstream | Server runtime |
| `compose/n8n/docker-compose.n8n.yml` | Added `N8N_SECURE_COOKIE=false` | Unstaged in local |
| `compose/caddy/Caddyfile` | Changed `reverse_proxy` target | Already committed? |
| `compose/caddy/docker-compose.caddy.yml` | Volume path fix | Already committed? |
| `.env` on server | Real secrets (DIFY_SECRET_KEY, passwords, etc.) | NOT in repo |

---

## Task Breakdown

### Task 1: Pull server-side compose patches into local repo

**Objective:** Capture all server-side Dify compose patches as a reproducible script so `make dify-up` works correctly.

**Files:**
- Create: `scripts/dify-patch-compose.sh`
- Modify: `Makefile` (add `dify-patch` target)

**Step 1: Create patch script**

Create `scripts/dify-patch-compose.sh` that applies all needed patches to the freshly-fetched `compose/dify/docker-compose.yaml`:

```bash
#!/usr/bin/env bash
# Apply OLS-specific patches to Dify vendored compose
# Run after `make dify-fetch`, before `make dify-up`
set -euo pipefail

COMPOSE_FILE="compose/dify/docker-compose.yaml"

# 1. Remove profiles from db_postgres (always needed)
sed -i '/profiles:/d' "$COMPOSE_FILE"

# 2. Fix volume paths: ./xxx/ → ./compose/dify/xxx/
for dir in nginx envs volumes ssrf_proxy certbot elasticsearch startupscripts pgvector; do
  sed -i "s|\\./$dir/|./compose/dify/$dir/|g" "$COMPOSE_FILE"
done

# 3. Fix env_file paths: ./envs/ → ./compose/dify/envs/
sed -i 's|path: \./envs/|path: ./compose/dify/envs/|g' "$COMPOSE_FILE"

# 4. Remove nginx port mapping (Caddy handles port 80)
sed -i '/EXPOSE_NGINX_PORT/d' "$COMPOSE_FILE"

# 5. Remove milvus/opensearch network refs from service network lists
sed -i '/- milvus/d; /- opensearch-net/d' "$COMPOSE_FILE"

# 6. Remove milvus/opensearch network definitions
sed -i '/^  milvus:/,/^[a-z]/d; /^  opensearch-net:/,/^[a-z]/d' "$COMPOSE_FILE"

# 7. Remove dify_es01_data volume
sed -i '/dify_es01_data:/d' "$COMPOSE_FILE"

# 8. Replace 'default' network with 'ols-chatbot'
sed -i 's/network: default/network: ols-chatbot/g; s/    - default/    - ols-chatbot/g' "$COMPOSE_FILE"

# 9. Add dify-data external volume
sed -i '/^volumes:/a\  dify-data:\n    external: true' "$COMPOSE_FILE"

echo "✅ Dify compose patched for OLS deployment"
```

**Step 2: Add Makefile target**

Add to `Makefile`:
```makefile
dify-patch: ## Apply OLS-specific patches to Dify vendored compose
	@scripts/dify-patch-compose.sh
```

**Step 3: Update `dify-up` target to call patch**

Modify the `dify-up` target in Makefile to call `dify-patch` after `dify-fetch`:
```makefile
dify-up: dify-fetch dify-patch ## Fetch + patch + deploy Dify stack
	docker compose -f compose/docker-compose.yml -f compose/dify/docker-compose.yaml \
		--project-directory . --env-file .env \
		--profile postgresql --profile pgvector up -d
```

**Step 4: Verify**

```bash
# Test the script is valid
bash -n scripts/dify-patch-compose.sh
# Expected: no output (syntax OK)

# Test Makefile syntax
make -n dify-patch
# Expected: prints the command without executing
```

**Step 5: Commit**

```bash
git add scripts/dify-patch-compose.sh Makefile
git commit -m "fix: capture Dify compose patches as reproducible script"
```

---

### Task 2: Sync server env files to local `secrets/` directory

**Objective:** Pull the real `.env` from server into `secrets/.env` (gitignored) so local dev can reproduce the server setup.

**Files:**
- Create: `secrets/.env` (gitignored — already covered by `*.env` rule)
- Modify: `.gitignore` (ensure `secrets/.env` is ignored)

**Step 1: Check .gitignore covers secrets/.env**

Current `.gitignore` has `*.env` which already covers `secrets/.env`. Verify:
```bash
grep -q 'secrets/' .gitignore || echo "secrets/.env" >> .gitignore
```

**Step 2: Pull .env from server**

```bash
scp chatbot:/root/chatbot/.env secrets/.env
```

**Step 3: Verify**

```bash
# Check it's gitignored
git check-ignore secrets/.env
# Expected: secrets/.env (path is ignored)

# Check it has real values
grep -c '=' secrets/.env
# Expected: > 0
```

**Step 4: Commit .gitignore change (if any)**

```bash
git add .gitignore
git commit -m "chore: ensure secrets/.env is gitignored"
```

---

### Task 3: Commit unstaged n8n compose change

**Objective:** Commit the `N8N_SECURE_COOKIE=false` change that's currently unstaged.

**Files:**
- Modify: `compose/n8n/docker-compose.n8n.yml` (already modified)

**Step 1: Verify the change**

```bash
git diff compose/n8n/docker-compose.n8n.yml
# Expected: shows N8N_SECURE_COOKIE=false addition
```

**Step 2: Commit**

```bash
git add compose/n8n/docker-compose.n8n.yml
git commit -m "fix: add N8N_SECURE_COOKIE=false for HTTP access"
```

---

### Task 4: Clean up untracked artifacts

**Objective:** Remove or gitignore generated artifacts that don't belong in the repo.

**Files:**
- Remove: `chatbot-architecture.html` (generated artifact, not part of project)

**Step 1: Remove generated HTML**

```bash
rm chatbot-architecture.html
```

**Step 2: Commit**

```bash
git add -A
git commit -m "chore: remove generated architecture diagram"
```

---

### Task 5: Update .env.example with new variables

**Objective:** Ensure `.env.example` documents all variables needed, including the new ones discovered during deployment.

**Files:**
- Modify: `.env.example`

**Step 1: Add missing variables**

Add to `.env.example`:
```ini
# ─── Ollama Cloud Pro (LLM for chatbot) ───
OLLAMA_CLOUD_API_KEY=  # API key from cloud.ollama.ai
OLLAMA_CLOUD_MODEL=qwen2.5:7b  # หรือ model ที่เลือก

# ─── Dify Vector Store ───
VECTOR_STORE=pgvector

# ─── n8n secure cookie (false for HTTP) ───
N8N_SECURE_COOKIE=false
```

**Step 2: Commit**

```bash
git add .env.example
git commit -m "docs: add Ollama Cloud Pro + vector store vars to .env.example"
```

---

### Task 6: Push to remote

**Objective:** Push all 5 commits to GitHub.

**Step 1: Push**

```bash
git push origin main
```

Expected: 5 commits pushed.

---

## Verification

After all tasks:

```bash
# 1. No unstaged changes
git status --short
# Expected: empty

# 2. secrets/.env exists and is gitignored
test -f secrets/.env && git check-ignore secrets/.env
# Expected: secrets/.env (ignored)

# 3. Patch script is valid
bash -n scripts/dify-patch-compose.sh
# Expected: no output

# 4. Makefile has dify-patch target
grep -q 'dify-patch' Makefile
# Expected: exit 0

# 5. .env.example has new vars
grep -q 'OLLAMA_CLOUD_API_KEY' .env.example
grep -q 'N8N_SECURE_COOKIE' .env.example
# Expected: both exit 0
```

## Risks & Open Questions

- **Risk:** `scripts/dify-patch-compose.sh` uses `sed -i` which works on Linux but may behave differently on macOS/BSD. The deploy target is Ubuntu, so this is acceptable.
- **Risk:** If Dify upstream compose changes significantly, the patch script may need updating. The `dify-fetch` target pins a specific version tag, so this is bounded.
- **Open:** Should `compose/dify/envs/` templates be committed? Decision: No — they're generated from `.env.example` at deploy time. The patch script handles env file creation.
- **Open:** Should Caddy be removed from the repo entirely since we're using Dify nginx? Decision: Keep for now — may be needed for TLS/HTTPS in Phase 6.
