# OLS Chatbot — Deployment Plan (Server ใหม่)

> **For Hermes:** Execute one phase at a time, stop after each phase, report results to user for review before proceeding.

**Goal:** Deploy OLS Chatbot stack (Dify + n8n + Ollama + Caddy) บน Linux server ใหม่ แบบ clean slate

**Architecture:** 4 services บน shared `ols-chatbot` bridge network — Caddy reverse proxy เป็น single entry point (port 80/443/5678), Ollama internal-only, n8n proxied through Caddy, Dify vendored compose with OLS override

**Tech Stack:** Docker Compose v2.20+, Caddy 2.8.4, Dify 1.16.0, n8n 2.31.3, Ollama 0.32.1, PostgreSQL 16

**Server Requirements:** Linux (Ubuntu 22.04+), 8+ GB RAM, 40+ GB disk, public IP

---

## Phase 0 — Pre-flight & Server Setup

**Objective:** ตรวจสอบ server พร้อม + ติดตั้ง dependencies

### Task 0.1: SSH เข้า server + บันทึก IP

```bash
ssh root@<server-ip>
# บันทึก public IP ไว้ใช้ใน .env
curl -s ifconfig.me
```

### Task 0.2: ติดตั้ง Docker + Docker Compose v2

```bash
# Ubuntu/Debian
curl -fsSL https://get.docker.com | sh
usermod -aG docker $USER
# logout/login ใหม่

# ตรวจสอบ version (ต้อง v2.20+ สำหรับ compose include)
docker --version
docker compose version
```

**Expected:** `docker compose version` ≥ v2.20.0

### Task 0.3: Clone repo + setup .env

```bash
git clone git@github.com:Natties45/chatbot.git /opt/ols-chatbot
cd /opt/ols-chatbot

# Copy .env.example → .env แล้วกรอกค่าจริง
cp .env.example .env
```

**กรอกค่าใน `.env` (ใช้ `vim .env`):**

| Variable | Value | วิธีสร้าง |
|----------|-------|-----------|
| `N8N_HOST` | `<server-public-ip>` | จาก Task 0.1 |
| `WEBHOOK_URL` | `http://<server-public-ip>:5678/` | ใช้ IP เดียวกัน |
| `N8N_ENCRYPTION_KEY` | `<random>` | `openssl rand -hex 32` |
| `N8N_BASIC_AUTH_PASSWORD` | `<password>` | ตั้งเอง |
| `N8N_DB_PASSWORD` | `<password>` | ตั้งเอง |
| `DIFY_SECRET_KEY` | `<random>` | `openssl rand -hex 48` |
| `DIFY_INIT_PASSWORD` | `<password>` | ตั้งเอง |
| `OLLAMA_CLOUD_API_KEY` | `<key>` | จาก cloud.ollama.ai |

### Task 0.4: Run preflight

```bash
bash scripts/preflight.sh
```

**Expected:** All checks PASS — Docker, RAM ≥ 8 GB, disk ≥ 40 GB, ports 80/443 free, env vars validated

**Stop here — รายงานผลให้ user ตรวจสอบก่อนไป Phase 1**

---

## Phase 1 — Ollama (Embeddings)

**Objective:** รัน Ollama container + pull bge-m3 embedding model

### Task 1.1: Start Ollama

```bash
bash scripts/stack.sh up ollama
```

**Expected:**
- Container `ollama` running
- `bge-m3` model pulled
- Embeddings test returns JSON

### Task 1.2: Verify

```bash
docker ps --filter name=ollama
docker exec ollama ollama list
# ต้องเห็น bge-m3 ใน list
```

**Stop here — รายงานผลให้ user ตรวจสอบก่อนไป Phase 2**

---

## Phase 2 — Dify (Chatbot Platform)

**Objective:** Fetch Dify vendored compose + deploy with OLS overrides

### Task 2.1: Fetch Dify compose

```bash
bash scripts/stack.sh up dify
# stack.sh จะ auto-fetch compose จาก GitHub ถ้ายังไม่มี
```

**Expected:**
- `compose/dify/docker-compose.yaml` ถูกสร้าง
- `.env.example.dify` ถูกสร้าง
- OLS override (`compose/dify/docker-compose.override.yml`) applied
- Dify containers ทั้งหมด running

### Task 2.2: Verify Dify Web UI

```bash
# ตรวจสอบ containers
docker ps --filter network=ols-chatbot

# เปิด browser: http://<server-ip>:80
# ต้องเห็น Dify setup page (สร้าง admin account)
```

### Task 2.3: Setup Dify admin + Model Providers

ผ่าน Dify Web UI (`http://<server-ip>:80`):

1. สร้าง admin account ด้วย email `admin@ols-chatbot.local` + password จาก `DIFY_INIT_PASSWORD`
2. Settings → Model Provider → Ollama:
   - **Ollama (local):** URL `http://ollama:11434`, Model `bge-m3` → ใช้สำหรับ embeddings
   - **Ollama (Cloud Pro):** API Key จาก `OLLAMA_CLOUD_API_KEY`, Model `qwen2.5:7b` → ใช้สำหรับ LLM
3. ทดสอบ connection ทั้งสอง provider

### Task 2.4: Create Knowledge Base Datasets

ผ่าน Dify Web UI → Knowledge → Create Dataset:

| Dataset Name | Dataset ID (บันทึกใส่ .env) | API Key (บันทึกใส่ .env) |
|---|---|---|
| kb-operation | `DIFY_OPERATION_DATASET_ID` | `DIFY_OPERATION_API_KEY` |
| kb-noc | `DIFY_NOC_DATASET_ID` | `DIFY_NOC_API_KEY` |
| kb-customer-faq | `DIFY_CUSTOMER_DATASET_ID` | `DIFY_CUSTOMER_API_KEY` |
| kb-staff | `DIFY_STAFF_DATASET_ID` | `DIFY_STAFF_API_KEY` |

หลังสร้างแต่ละ dataset → Settings → API → สร้าง API key → บันทึกใส่ `.env`

### Task 2.5: Create Chatbot Apps

ผ่าน Dify Web UI → Studio → Create App (เลือก Chatbot):

| App | System Prompt | Knowledge Base | Model |
|-----|---------------|----------------|-------|
| OLS Operation Bot | `dify/prompts/operation-system-prompt.txt` | kb-operation | qwen2.5:7b |
| OLS NOC Bot | `dify/prompts/noc-system-prompt.txt` | kb-noc | qwen2.5:7b |
| OLS Customer FAQ Bot | `dify/prompts/customer-system-prompt.txt` | kb-customer-faq | qwen2.5:7b |

**⚠️ Customer bot: ตั้งเป็น Draft — ห้าม Publish จนกว่าผ่าน red-team (Phase 5)**

### Task 2.6: Test chatbot ตอบภาษาไทย

ผ่าน Dify Web UI → แต่ละ app → Preview → ทดสอบถามคำถามง่ายๆ:
- "สวัสดีครับ" → ต้องตอบภาษาไทย
- "ช่วยแนะนำ Instance คืออะไร" → ต้องตอบจาก KB (ถ้ามีข้อมูล)

**Stop here — รายงานผลให้ user ตรวจสอบก่อนไป Phase 3**

---

## Phase 3 — n8n (Workflow Automation)

**Objective:** รัน n8n + Postgres + import workflows

### Task 3.1: Start n8n

```bash
bash scripts/stack.sh up n8n
```

**Expected:**
- Container `n8n` + `n8n-postgres` running
- n8n accessible via Caddy ที่ `http://<server-ip>:5678`

### Task 3.2: Setup n8n owner account

เปิด `http://<server-ip>:5678` → สร้าง owner account

### Task 3.3: Create credentials ใน n8n

ผ่าน n8n UI → Credentials → New (ตาม `n8n/credentials/README.md`):

| Credential Name | Type | Value |
|---|---|---|
| GitHub SSH | SSH Key | Private key สำหรับ `git@github.com:Natties45/selfservice-repo.git` |
| Dify Dataset API (kb-operation) | Header Auth | `Authorization: Bearer <DIFY_OPERATION_API_KEY>` |
| Dify Dataset API (kb-noc) | Header Auth | `Authorization: Bearer <DIFY_NOC_API_KEY>` |
| Dify Dataset API (kb-customer) | Header Auth | `Authorization: Bearer <DIFY_CUSTOMER_API_KEY>` |
| Dify Dataset API (kb-staff) | Header Auth | `Authorization: Bearer <DIFY_STAFF_API_KEY>` |
| LINE Notify | Header Auth | `Authorization: Bearer <LINE_NOTIFY_TOKEN>` |

### Task 3.4: Import workflows

ผ่าน n8n UI → Import from file:

1. `n8n/workflows/01-github-dify-sync.json` → **อย่าเพิ่ง activate**
2. `n8n/workflows/02-bot-unanswered-alert.json` → **อย่าเพิ่ง activate**
3. `n8n/workflows/03-weekly-faq-report.json` → **อย่าเพิ่ง activate**
4. `n8n/workflows/04-knowledge-approval.json` → **อย่า import** (Phase 5)

### Task 3.5: Verify workflow structure

- ตรวจสอบว่าแต่ละ workflow ใช้ credential ถูกต้อง (ไม่มี error icon)
- ตรวจสอบว่า env vars (`{{$env.DIFY_STAFF_DATASET_ID}}` ฯลฯ) resolve ได้

**Stop here — รายงานผลให้ user ตรวจสอบก่อนไป Phase 4**

---

## Phase 4 — Knowledge Sync + Test

**Objective:** Sync knowledge จาก selfservice-repo → Dify KB + ทดสอบ end-to-end

### Task 4.1: Manual trigger sync workflow

ผ่าน n8n UI → workflow `01-github-dify-sync` → Execute Workflow (manual)

**Expected:**
- Git pull จาก `Natties45/selfservice-repo` สำเร็จ
- Documents ถูก upsert เข้า Dify datasets
- ตรวจสอบใน Dify UI → Knowledge → แต่ละ dataset → ต้องมี documents

### Task 4.2: Activate schedule workflows

ผ่าน n8n UI:
1. `01-github-dify-sync` → Activate (every 2 min)
2. `02-bot-unanswered-alert` → Activate (every hour)
3. `03-weekly-faq-report` → Activate (Monday 09:00)

### Task 4.3: End-to-end test

1. แก้ไขไฟล์ YAML ใน `selfservice-repo` → push main
2. รอ 2 นาที → ตรวจสอบ Dify KB ว่ามี document ใหม่
3. ทดสอบถาม Operation bot → ต้องตอบด้วยข้อมูลใหม่
4. ทดสอบถาม NOC bot → ต้องตอบจาก kb-noc เท่านั้น
5. ทดสอบถาม Customer bot → ต้องตอบจาก kb-customer-faq + ใช้ customer wording

**Stop here — รายงานผลให้ user ตรวจสอบก่อนไป Phase 5**

---

## Phase 5 — Red-Team + Go-Live

**Objective:** Security review + hardening + เปิด customer bot

### Task 5.1: Red-team checklist

ทดสอบทีละข้อ (ดู `docs/runbook.md` Phase 5):

- [ ] Prompt injection — ไม่ leak system prompt
- [ ] Internal topic — ไม่คืน internal docs
- [ ] Gate question — ไม่ตอบด้วย Kory knowledge (และกลับกัน)
- [ ] `needs_review` content — ไม่หลุดไป customer bot
- [ ] Citation — ทุกคำตอบมี citation
- [ ] PII — ไม่มี API key/IP/email/ชื่อ/เบอร์ ใน log/response
- [ ] Response DNA — Thai, สุภาพ, ครับ, เปิด/ปิดถูกต้อง
- [ ] Customer wording — ไม่ mention OpenStack/API/CLI/backend

### Task 5.2: Fix red-team findings

แก้ไข system prompts / workflow filters ตาม findings จาก Task 5.1

### Task 5.3: Backup

```bash
bash scripts/backup.sh
```

**Expected:** Backup สำเร็จที่ `/var/backups/ols-chatbot/<timestamp>/`

### Task 5.4: Test restore

```bash
# ทดสอบ restore บน staging หรือ server เดิม
bash scripts/restore.sh /var/backups/ols-chatbot/<timestamp>
```

### Task 5.5: Publish Customer bot

เมื่อ red-team ผ่านทั้งหมด:
- Dify UI → Customer FAQ Bot → Publish
- แชร์ link ให้ลูกค้า

### Task 5.6: Import approval workflow

ผ่าน n8n UI → Import `n8n/workflows/04-knowledge-approval.json` → Activate

**Stop here — รายงานผลให้ user ตรวจสอบ (final sign-off)**

---

## Quick Reference — คำสั่งหลัก

| คำสั่ง | การทำงาน |
|---|---|
| `bash scripts/stack.sh up ollama` | เริ่ม Ollama + pull bge-m3 |
| `bash scripts/stack.sh up dify` | Fetch + deploy Dify |
| `bash scripts/stack.sh up n8n` | เริ่ม n8n + postgres |
| `bash scripts/stack.sh up caddy` | เริ่ม Caddy reverse proxy |
| `bash scripts/stack.sh status` | ดูสถานะ containers |
| `bash scripts/stack.sh logs <service>` | ดู logs |
| `bash scripts/backup.sh` | Backup DB + volumes |
| `bash scripts/restore.sh <archive>` | Restore จาก backup |

## Server URLs (หลัง deploy)

| Service | URL | Auth |
|---------|-----|------|
| Dify Web UI | `http://<server-ip>:80` | admin@ols-chatbot.local / `DIFY_INIT_PASSWORD` |
| n8n UI | `http://<server-ip>:5678` | owner account (สร้างตอน setup) |
| Ollama | internal only (`ollama:11434`) | ไม่มี (internal Docker network) |

## Risks & Notes

- **Dify compose fetch:** ต้องออก internet ได้ (git clone จาก GitHub)
- **Ollama Cloud Pro:** ต้องมี API key + internet
- **n8n GitHub SSH:** ต้อง setup SSH key บน server + add to GitHub deploy keys
- **LINE Notify:** ต้องมี token สำหรับแจ้งเตือน
- **Caddy TLS:** IP-only mode → browser จะเตือน self-signed cert (รับได้ชั่วคราว)
- **n8n version:** `.env.example` ยังเป็น `2.31.3` — แนะนำ bump เป็น `2.31.4` ก่อน deploy
