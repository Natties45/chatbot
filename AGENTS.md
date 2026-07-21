# AGENTS.md — chatbot/ workspace

ภาษาไทย — อ่านก่อนทำงานทุกครั้ง

## จุดประสงค์ของโปรเจกต์

Infra-as-code สำหรับ deploy **OLS chatbot** โดยใช้ **Dify + n8n + Ollama** บน Linux server
- Proposal ต้นฉบับ: `docs/proposals/dify-n8n-chatbot-plan.md` ใน **selfservice-repo** (canonical — อ่านเท่านั้น)
- Canonical repo: `Natties45/selfservice-repo` via SSH `git@github.com:Natties45/selfservice-repo.git`

## Constraints

1. **Version pinning**: ทุก Docker image ต้องระบุ tag ชัดเจน ห้ามใช้ `latest`.
2. **No secrets in Git**: ห้าม commit `.env`, credentials, API keys, passwords, private keys, หรือ logs ที่มีข้อมูล sensitive.
3. **selfservice-repo is canonical**: อ่านได้อย่างเดียว ห้ามแก้ไขไฟล์ใด ๆ ใน selfservice-repo.
4. **Customer wording rules**:
   - ห้าม mention `OpenStack`, `API`, `CLI`, `backend`, `Dante`, internal path ต่อลูกค้า
   - อนุญาตให้กล่าวถึง: `Instance`, `SSH`, `RDP`, `DNS`, `SSL`, `Snapshot`, `Security Group`, `Bucket`
5. **Response DNA (Thai สุภาพ)**:
   - เปิดด้วย "เรียน ผู้ใช้บริการ"
   - ปิดด้วย "ขอบคุณครับ"
   - ใช้ "ครับ" ในประโยค
6. **Customer bot gate**: ปิดการใช้งาน customer bot จนกว่าผ่าน red-team review.
7. **Cite proposal**: อ้างอิง `docs/proposals/dify-n8n-chatbot-plan.md` line refs เมื่อตอบคำถามเกี่ยวกับแผน.

## Approved terminology

| หัวข้อ | คำที่ใช้กับลูกค้า |
|---|---|
| Server | Instance |
| Remote access | SSH / RDP |
| Domain/DNS | DNS / SSL |
| Backup | Snapshot |
| Firewall | Security Group |
| Object storage | Bucket |

## Role Definitions

ระบบมี 3 roles หลัก — แต่ละ role มี scope, KB access, และ constraints ต่างกัน

| Role | Scope | KB Access | External Search | Constraints |
|------|-------|-----------|-----------------|-------------|
| **Operation** | ถามตอบ + ค้นหาเพิ่มเติมเพื่อแก้ปัญหา | `kb-operation` (full) | ✅ อนุญาต | น้อยที่สุด — troubleshooting, diagnosis |
| **NOC** | ถามตอบใน repo เท่านั้น | `kb-noc` (filtered) | ❌ ห้าม | บางหมวด policy ห้ามตอบ (ดูตารางด้านล่าง) |
| **Customer** | ถามตอบ FAQ สำหรับลูกค้า | `kb-customer` (approved only) | ❌ ห้าม | Customer wording rules + red-team gate |

### NOC Policy — Restricted Categories

หมวดหมู่ที่ NOC bot **ห้ามตอบ** (policy enforcement — sync-level + prompt-level):

| หมวด | เหตุผล | ตัวอย่าง |
|------|--------|---------|
| `internal/debug` | ข้อมูล internal troubleshooting | debug log, stack trace, internal tool |
| `internal/security` | ข้อมูลความปลอดภัยภายใน | firewall rule detail, internal IP range |
| `internal/architecture` | โครงสร้างระบบภายใน | service topology, DB schema |
| `internal/change` | การเปลี่ยนแปลงที่ยังไม่ approved | pending change, rollback plan |
| `internal/audit` | audit log / compliance | internal audit trail |

### Response DNA

| Role | เปิด | ปิด | ภาษา |
|------|-----|-----|------|
| Operation | "เรียน ทีม Operation ครับ" | "ขอบคุณครับ" | Thai สุภาพ + technical |
| NOC | "เรียน ทีม NOC ครับ" | "ขอบคุณครับ" | Thai สุภาพ + policy-aware |
| Customer | "เรียน ผู้ใช้บริการ" | "ขอบคุณครับ" | Thai สุภาพ + customer-safe |

## File ownership

- `selfservice-repo`: canonical (read-only)
- `chatbot/`: infra implementation (writeable)

## โครงสร้าง directory

```
chatbot/
├── compose/              # Docker compose files
│   ├── docker-compose.yml          # base (network + volumes)
│   ├── dify/                       # Dify compose (vendored)
│   ├── n8n/docker-compose.n8n.yml  # n8n compose
│   ├── ollama/docker-compose.ollama.yml  # Ollama compose
│   └── caddy/Caddyfile             # reverse proxy config
├── dify/
│   ├── apps/             # Dify app DSL (import ผ่าน Dify UI)
│   └── prompts/          # system prompts (operation + noc + customer)
├── n8n/
│   ├── workflows/        # n8n workflow JSON (import ผ่าน n8n UI)
│   └── credentials/      # credential setup guide
├── docs/
│   ├── runbook.md        # deployment runbook
│   └── recovery.md       # disaster recovery procedures
├── scripts/
│   ├── backup.sh         # backup Dify + n8n DB + volumes
│   ├── dify-up.sh        # deploy Dify stack
│   ├── n8n-up.sh         # deploy n8n stack
│   ├── ollama-up.sh      # deploy Ollama stack
│   ├── preflight.sh      # environment check
│   └── restore.sh        # restore from backup
├── Makefile              # คำสั่งหลักทั้งหมด
├── .env                  # secrets (gitignored)
└── AGENTS.md             # ไฟล์นี้
```

## คำสั่งหลัก (Makefile)

| คำสั่ง | การทำงาน |
|---|---|
| `make preflight` | ตรวจสอบ environment ก่อน deploy |
| `make dify-up` / `make dify-down` | เปิด/ปิด Dify stack |
| `make n8n-up` / `make n8n-down` | เปิด/ปิด n8n stack |
| `make ollama-up` / `make ollama-down` | เปิด/ปิด Ollama stack |
| `make proxy-up` | เปิด Caddy reverse proxy |
| `make status` | ดูสถานะ Docker containers |
| `make logs` | ดู logs ของทั้ง stack |
| `make backup` | backup DB + volumes |
| `make restore ARCHIVE=<path>` | restore จาก backup |
| `make seed-ollama` | pull embedding model ใน Ollama |
| `make dify-fetch` | ดึง vendor compose ของ Dify |

## Architecture boundaries

- **Dify**: chatbot platform — มี Web UI, API, Knowledge Base (vector store)
- **n8n**: workflow automation — sync knowledge, alert, report, approval
- **Ollama**: local LLM inference — embeddings (bge-m3) + LLM (qwen2.5 via cloud)
- **Caddy**: reverse proxy (IP-only, self-signed TLS)
- **Shared network**: `ols-chatbot` bridge network
- **Secrets**: เก็บใน `.env` (gitignored) หรือ n8n credential store เท่านั้น
- **Knowledge Base (KB)**: derived store จาก selfservice-repo — rebuild ได้เสมอ

## เอกสารที่ควรอ่านก่อนแก้ไข

- `docs/runbook.md` — ขั้นตอน deploy ทั้งหมด
- `docs/recovery.md` — การกู้คืนระบบ
- `dify/prompts/operation-system-prompt.txt` — system prompt ของ Operation bot
- `dify/prompts/noc-system-prompt.txt` — system prompt ของ NOC bot
- `dify/prompts/customer-system-prompt.txt` — system prompt ของ Customer bot
- `n8n/credentials/README.md` — วิธีตั้งค่า credentials ใน n8n

## Known gotchas

- **Dify upgrade**: เปลี่ยน `DIFY_IMAGE_TAG` ใน `.env` → `rm compose/dify/docker-compose.yaml` → `make dify-fetch` → `make dify-up`
- **Embeddings change**: เปลี่ยน model แล้วต้อง reindex KB ทั้งหมด
- **n8n workflow JSON**: ต้องไม่มี secrets ฝังในไฟล์
- **Customer bot**: เปิดใช้งานได้ต่อเมื่อผ่าน red-team review เท่านั้น
- **Backup**: ใช้ `age` encryption ถ้ามี `AGE_RECIPIENT` ใน environment
