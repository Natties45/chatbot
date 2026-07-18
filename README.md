# OLS Chatbot Infrastructure

Infra-as-code สำหรับ deploy **OLS chatbot** โดยใช้ **Dify + n8n + Ollama** บน Linux server ผ่าน SSH alias `chatbot`.

- Proposal ต้นฉบับ: `docs/proposals/dify-n8n-chatbot-plan.md` ใน **selfservice-repo** (canonical knowledge — อ่านเท่านั้น ห้ามแก้)
- Canonical repo: `Natties45/selfservice-repo` via SSH `git@github.com:Natties45/selfservice-repo.git`
- ห้าม commit secrets ใน repo นี้ โดยเด็ดขาด

## Quick start

```bash
# 1. Copy .env แล้วกรอกค่า
make preflight

# 2. รันแต่ละ stack
make dify-up
make n8n-up
make ollama-up

# 3. Reverse proxy (IP-only)
make proxy-up
```

## Phase plan

| Phase | งาน | คำสั่งหลัก |
|---|---|---|
| Phase 1 | ติดตั้ง Docker + preflight + reverse proxy | `make preflight` `make proxy-up` |
| Phase 2 | Deploy Dify + ดึง vendor compose | `make dify-fetch` `make dify-up` |
| Phase 3 | Sync knowledge จาก selfservice-repo | manual trigger n8n `01-github-dify-sync` |
| Phase 4 | สร้าง customer/staff bot ใน Dify | Dify UI + import DSL จาก `dify/apps/` |
| Phase 5 | n8n workflows สำหรับ monitoring + approval | `make n8n-up` แล้ว import workflows |
| Phase 6 | Hardening, backup, red-team, go-live | `make backup` |

## ข้อควรระวัง

- ทุก Docker image **ต้อง pin tag** ห้ามใช้ `latest`.
- Secrets เก็บใน `.env` (gitignored) หรือ password manager เท่านั้น.
- ห้ามแก้ไข `selfservice-repo` จาก agent นี้.
- Customer bot เปิดใช้งานได้ **ต่อเมื่อผ่าน red-team** เท่านั้น.
- ดู runbook: `docs/runbook.md` และ `docs/recovery.md`
