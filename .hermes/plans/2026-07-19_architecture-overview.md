# OLS Chatbot — Architecture & Workflow Overview

> **For Hermes:** ใช้เป็น reference ก่อนแก้ไขหรือ deploy ระบบ

**Goal:** อธิบายโครงสร้าง การทำงาน การใช้งาน n8n และวิธีอัปเดต repo

**Architecture:** Docker Compose multi-service stack (Dify + n8n + Ollama + Caddy) บน Linux server

**Tech Stack:** Docker Compose v2, Dify 1.16.0, n8n 2.31.3, Ollama 0.32.1, Caddy 2-alpine, PostgreSQL 16-alpine

---
---

## 1. chatbot ทำงานยังไง? (System Architecture Flow)

```
                        Internet
                           │
                    ┌──────┴──────┐
                    │   Caddy     │  ← reverse proxy (port 80/443)
                    │  (IP-only)  │
                    └──────┬──────┘
                           │
              ┌────────────┼────────────┐
              │            │            │
        ┌─────┴─────┐ ┌───┴────┐ ┌────┴─────┐
        │  Dify     │ │ n8n    │ │ Ollama   │
        │  - Web UI │ │ - Sync │ │ - bge-m3 │
        │  - API    │ │ - Alert│ │ (embedd) │
        │  - KB     │ │ - Rpt  │ └──────────┘
        └─────┬─────┘ └────────┘
              │
    ┌─────────┴─────────┐
    │  Database Layer    │
    │  ├─ Dify Postgres  │
    │  ├─ n8n Postgres   │
    │  └─ Vector Store   │
    └───────────────────┘
```

### 1.1 ระบบแบ่งเป็น 4 ส่วนหลัก

| ส่วน | หน้าที่ | เข้าถึง |
|---|---|---|
| **Dify** | แพลตฟอร์ม chatbot — มี Web UI สำหรับสร้าง/จัดการ bot, API สำหรับถามตอบ, Knowledge Base สำหรับเก็บความรู้ | Public ผ่าน Caddy (port 80) |
| **n8n** | workflow automation — เชื่อมต่อระบบต่างๆ โดยอัตโนมัติ | SSH tunnel เท่านั้น (port 5678) |
| **Ollama** | รัน AI model ในเครื่อง本地 — ใช้ `bge-m3` สำหรับแปลงข้อความเป็น embedding (vector) | Internal network (port 11434) |
| **Caddy** | reverse proxy — รับ request จาก internet แล้วส่งไป Dify | Public (port 80/443) |

### 1.2 Knowledge ส่งต่อกันยังไง?

```
selfservice-repo (GitHub)
  └─ YAML knowledge files
       │
       ▼  (n8n workflow 01-github-dify-sync ดึงทุก 2 นาที)
       │
  Dify Knowledge Base (vector store)
       │
       ├──► Customer FAQ bot  ← customer-system-prompt.txt
       └──► Staff Support bot ← staff-system-prompt.txt
```

### 1.3 ผู้ใช้คุยกับ chatbot ได้ยังไง?

```
ลูกค้า/พนักงาน
     │
     ├─ Web browser → เปิด Dify Share Link → คุยกับ bot
     ├─ LINE → (ผ่าน n8n webhook → Dify API)
     └─ API → เรียก Dify API โดยตรง
```

---

## 2. เก็บ repo ไว้ที่ไหน? (Repository Locations)

### 2.1 chatbot repo (โปรเจกต์นี้)

| รายการ | ค่า |
|---|---|
| **Local path** | `C:\Users\natti\OneDrive\Documents\natties45\chatbot\` |
| **GitHub remote** | `git@github.com:Natties45/chatbot.git` |
| **Branch** | `main` |
| **เนื้อหา** | Infra-as-code — compose files, scripts, prompts, workflow JSON |
| **ลง server** | clone + setup `.env` → `make dify-up` `make n8n-up` `make ollama-up` |

### 2.2 selfservice-repo (Canonical Knowledge)

| รายการ | ค่า |
|---|---|
| **GitHub remote** | `git@github.com:Natties45/selfservice-repo.git` |
| **สถานะ** | **อ่านเท่านั้น (read-only)** — ห้ามแก้จาก agent นี้ |
| **เนื้อหา** | YAML knowledge files ต้นฉบับ — เป็น canonical source of truth |
| **เชื่อมกับ chatbot** | n8n workflow `01-github-dify-sync` ดึงทุก 2 นาที → อัปเดต Dify Knowledge Base |

---

## 3. จะอัปเดท repo ยังไง? (How to Update)

### 3.1 อัปเดต chatbot repo

วิธีทั่วไป (push จากเครื่อง dev):

```bash
# 1. แก้ไขไฟล์ใน chatbot/
# 2. commit แล้ว push
cd "C:\Users\natti\OneDrive\Documents\natties45\chatbot"
git add <files>
git commit -m "type: description"
git push
```

จากนั้นบน server:

```bash
cd /path/to/chatbot
git pull origin main
# ถ้ามี compose changes → docker compose up -d
# ถ้ามี script changes → เรียก bash scripts/<name>.sh
```

### 3.2 อัปเดต Dify Version

```bash
# 1. แก้ DIFY_IMAGE_TAG ใน .env
# 2. ลบ compose เก่า
rm compose/dify/docker-compose.yaml
# 3. fetch + deploy ใหม่
make dify-fetch
make dify-up
# 4. ทดสอบ: เปิด Dify Web UI + ตรวจ bot ตอบได้
```

⚠️ Dify major version upgrade → อาจเปลี่ยน KB API → ทดสอบ workflow 01 หลังอัปเกรดเสมอ

### 3.3 อัปเดต n8n Version

```bash
# 1. แก้ N8N_IMAGE_TAG ใน .env
# 2. รันใหม่
make n8n-up
# 3. ทดสอบ workflow 01-03 ทำงานปกติ
```

### 3.4 อัปเดต Knowledge (selfservice-repo)

> ห้ามแก้ selfservice-repo จาก agent นี้

วิธีแก้ knowledge:

1. ไปที่ `Natties45/selfservice-repo` (แยกต่างหาก)
2. แก้ YAML knowledge files
3. push → n8n workflow `01-github-dify-sync` จะ detect ภายใน 2 นาที
4. ถ้าต้องการ rebuild ทั้งหมด: ลบ documents ใน Dify → manual trigger workflow 01

---

## 4. n8n เอาไว้ใช้ทำไร? (n8n Workflow Roles)

n8n คือตัว **automation backbone** — เชื่อมต่อระบบต่างๆ โดยไม่ต้องเขียน code เอง

### 4.1 Workflows ทั้ง 4 ตัว

| Workflow | จังหวะ | หน้าที่ |
|---|---|---|
| **01-github-dify-sync** ⭐ | ทุก 2 นาที | **หัวใจของระบบ** — ดึง knowledge YAML จาก selfservice-repo → แปลง → อัปโหลดเข้า Dify Knowledge Base |
| **02-bot-unanswered-alert** | ทุก 1 ชั่วโมง | สแกน Dify conversations → หาคำถามที่ bot ตอบไม่ได้ → แจ้งเตือนทาง LINE |
| **03-weekly-faq-report** | ทุกวันจันทร์ 09:00 | สรุปรายงาน FAQ รายสัปดาห์ — คำถามยอดนิยม, unanswered rate |
| **04-knowledge-approval** | Manual (Phase 5) | workflow สำหรับขออนุมัติ knowledge ที่มีสถานะ `needs_review` ก่อนเผยแพร่ |

### 4.2 ภาพรวม Data Flow ของ n8n

```
GitHub (selfservice-repo)
   │ git pull (SSH)
   ▼
n8n workflow 01
   │ parse YAML → validate schema
   │ upsert ไป Dify Dataset API
   ▼
Dify Knowledge Base
   │
   ├──► 02-bot-unanswered-alert สแกนหาคำถามที่ตอบไม่ได้
   └──► 03-weekly-faq-report สรุปสถิติรายสัปดาห์
```

### 4.3 การแจ้งเตือนของ n8n

| ช่องทาง | ใช้กับ |
|---|---|
| **LINE Notify** | แจ้ง alert + report ไปหา @Natties45 |
| **SMTP (optional)** | สำรองการแจ้งเตือนทาง email |

### 4.4 ข้อสำคัญเกี่ยวกับ n8n

- **n8n UI** เข้าผ่าน SSH tunnel เท่านั้น: `ssh -L 5678:127.0.0.1:5678 chatbot`
- **Credentials** (GitHub SSH, Dify Dataset API key, LINE Notify token) — ตั้งใน n8n UI ห้ามเก็บในไฟล์
- **Workflow JSON** ใน repo นี้ — ไม่มี secret ฝัง ใช้ credential reference by name เท่านั้น
- **Active/inactive** — workflow ทั้ง 4 ตัว import มาแล้ว **inactive** ต้องเปิดใน n8n UI ถึงจะทำงาน

---

## 5. สรุป Flow ตั้งแต่ต้นจนจบ

```
1. Admin แก้ knowledge YAML → push ไป selfservice-repo (GitHub)
2. n8n workflow 01 detect การเปลี่ยนแปลง (ทุก 2 นาที)
3. n8n pull จาก GitHub → ตรวจ schema → upsert ไป Dify Dataset API
4. Dify Knowledge Base อัปเดต — documents เก่าถูกแทนที่, อันใหมถูกเพิ่ม, อันที่ลบถูกลบ
5. ลูกค้า/พนักงาน เปิด Share Link คุยกับ bot
6. Dify chatbot ตอบโดยค้นจาก Knowledge Base (vector search via Ollama bge-m3 embeddings)
7. n8n workflow 02-03 คอย monitor + report ตลอดเวลา
```

### Key Design Decisions

| Decision | เหตุผล |
|---|---|
| **Dify ไม่ commit compose** | ตาม release tag — ไม่ต้อง maintenance Dify infra code เอง |
| **selfservice-repo แยกจาก chatbot** | ความรู้แยกจาก infrastructure — knowledge team ไม่ต้องแตะ Docker |
| **n8n ไม่ public** | security — เฉพาะ SSH tunnel |
| **Ollama local สำหรับ embedding** | ไม่เสียค่า API, privacy, latency ต่ำ |
| **KB = derived store** | rebuild ได้จาก selfservice-repo เสมอ — ถ้าเสียหายก็ rebuild |

---

*เอกสารนี้อัปเดตล่าสุด: 2026-07-19 หลัง audit fixes*
