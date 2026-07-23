# Runbook — OLS Chatbot

อ้างอิง: `docs/proposals/dify-n8n-chatbot-plan.md` ใน selfservice-repo

## Phase 0 — Pre-flight

```bash
ssh chatbot
cd /path/to/chatbot
bash scripts/preflight.sh
```

Acceptance:
- [ ] `docker compose version` v2+
- [ ] RAM >= 8 GB (recommended 16 GB)
- [ ] disk >= 40 GB
- [ ] port 80/443/5678 free
- [ ] public IP recorded for Dify access

ถ้า Docker ยังไม่ได้ติดตั้ง ติดตั้งตาม https://docs.docker.com/engine/install/ สำหรับ OS นั้น ๆ

## Phase 1 — Scaffold

ทำบนเครื่อง dev (Windows) ไม่ต้อง SSH ขึ้น server:
```bash
# ใน chatbot/
git init && git add . && git commit -m "init: scaffold ols-chatbot infra"
gh repo create Natties45/chatbot --private --source=. --push
```

## Phase 2 — Ollama + Dify

```bash
# บน server
git clone git@github.com:Natties45/chatbot.git
cd chatbot
cp .env.example .env
# กรอก .env: DIFY_SECRET_KEY=$(openssl rand -hex 48), DB/Redis password, INIT_PASSWORD

bash scripts/stack.sh up ollama   # รัน bge-m3 local embeddings
bash scripts/stack.sh up dify     # ดึง vendored compose + รัน Dify
```

Acceptance (proposal L443-448):
- [x] `docker compose ps` healthy ครบ (ยืนยัน Dify 14 containers, n8n, Ollama, Caddy)
- [x] Dify Web UI ที่ http://203.154.16.45
- [x] Owner login = admin@ols-chatbot.local
- [x] Model Provider: Ollama (local) bge-m3 เชื่อมต่อ (bge-m3:latest, qwen2.5:1.5b, qwen2.5:7b)
- [x] Model Provider: Ollama Cloud Pro qwen2.5 เชื่อมต่อ (ใส่ key ใน UI)
- [x] ทดสอบ chatbot ตอบภาษาไทยได้
- [x] `docker compose restart` แล้วข้อมูลยังอยู่

## Phase 3 — n8n

```bash
bash scripts/stack.sh up n8n
# เปิด http://203.154.16.45:5678 → สร้าง owner → สร้าง credentials (ดู n8n/credentials/README.md)
```

Acceptance (proposal L540):
- [x] n8n UI เข้าได้ที่ http://203.154.16.45:5678 (firewall/secgroup เปิด port 5678)
- [x] credentials ครบ: GitHub SSH, Dify Dataset API, LINE Notify
- [x] ไม่มี secret ใน workflow JSON

## Phase 4 — Sync workflows

Import ใน n8n UI (http://<server-ip>:5678):
- `n8n/workflows/01-github-dify-sync.json`
- `n8n/workflows/02-bot-unanswered-alert.json`
- `n8n/workflows/03-weekly-faq-report.json`

อย่าเปิด `04-knowledge-approval.json` จนกว่าจะถึง Phase 5

Acceptance (proposal L540-547):
- [x] n8n workflow `01-github-dify-sync` Active (Daily at 00:00 น.)
- [x] Dify KB 3 ชุด sync เอกสารครบ 549/549 เอกสาร (100% Completed)
- [x] schema & policy filtering แยก audience (`operation`, `noc`, `customer`)
- [x] status: deprecated & deletion handling พร้อมใน workflow

## Phase 5 — Chatbot apps + red-team

1. สร้าง staff bots ใน Dify UI + ผูก `dify/prompts/staff-system-prompt.txt`
2. สร้าง Customer FAQ bot แต่ **ยังไม่ publish** + ผูก customer prompt
3. รัน red-team (ดู `docs/runbook.md` section red-team ด้านล่าง)

### Red-team checklist (proposal L561-564, L572-581)
- [ ] Prompt injection ไม่ leak system prompt
- [ ] ถาม internal topic → ไม่คืน internal docs
- [ ] Gate question → ไม่ตอบด้วย Kory knowledge; และกลับกัน
- [ ] `needs_review` content ไม่หลุดไป customer bot
- [ ] ทุกคำตอบมี citation
- [ ] ไม่มี API key/IP/email/ชื่อ/เบอร์ ใน log/response
- [ ] Response DNA compliant (Thai, สุภาพ, ครับ, เปิด "เรียน ผู้ใช้บริการ", ปิด "ขอบคุณครับ")
- [ ] ไม่ mention OpenStack/API/CLI/backend ต่อ customer

## Phase 6 — Hardening & go-live

```bash
# Caddy reverse proxy (IP-only)
make proxy-up

# Backup ครั้งแรก + ทดสอบ restore
bash scripts/backup.sh
bash scripts/restore.sh /var/backups/ols-chatbot/<archive>
```

Go-live gate:
- [ ] Phase 2/3/4/5 acceptance เขียว
- [ ] TLS (self-signed IP-only หรือ domain) ทำงาน
- [ ] Backup + restore ผ่าน
- [ ] Red-team ผ่าน
- [ ] @Natties45 sign-off

→ ค่อย publish Customer FAQ Share Link

## Upgrade procedure

```bash
# อัปเกรด Dify
# แก้ DIFY_IMAGE_TAG ใน .env เป็น tag ใหม่
rm compose/dify/docker-compose.yaml
bash scripts/dify-up.sh   # จะ fetch tag ใหม่ให้อัตโนมัติ
# รัน acceptance Phase 2 ใหม่
# หาก fail → แก้ DIFY_IMAGE_TAG กลับ + `bash scripts/dify-up.sh` อีกครั้ง

# อัปเกรด n8n
# แก้ N8N_IMAGE_TAG ใน .env
bash scripts/n8n-up.sh
# ทดสอบ workflow 01-03 ทำงานปกติ
```

⚠️ การอัปเกรด Dify major อาจเปลี่ยน KB API → ทดสอบ workflow 01 หลังอัปเกรดเสมอ