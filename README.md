# OLS Chatbot Infrastructure Template

Infra-as-Code สำหรับติดตั้งและดูแลระบบ **OLS Chatbot** โดยใช้ **Dify + n8n + Ollama + Caddy** บน Linux Server (Ubuntu/Debian)

---

## 🌟 จุดเด่นของสถาปัตยกรรม (Architecture Highlights)

* **Multi-Role AI Chatbot:** รองรับ 3 บทบาทหลักแยกสิทธิ์และคู่มือการตอบ (Operation, NOC, Customer)
* **Hybrid Model Inference:** ใช้ **Ollama Local (`bge-m3`)** สำหรับ Vector Embeddings และ **Ollama Cloud Pro** สำหรับ LLM Inference (ประหยัดทรัพยากรเครื่อง)
* **Automated Knowledge Sync:** ดึงข้อมูลองค์ความรู้จาก `selfservice-repo` มาแปลงลง Dify Datasets โดยอัตโนมัติผ่าน n8n Workflow (ตั้งเวลาทำงานทุกเที่ยงคืน 00:00 น.)
* **Unified 2-Step Deployment:** สคริปต์ติดตั้งใหม่สั่งงานรวดเร็ว ตรวจสอบความพร้อมและเช็คการเชื่อมต่อให้อัตโนมัติ

---

## 🚀 Quick Start (การติดตั้งระบบใหม่ 2 ขั้นตอน)

### 1️⃣ ขั้นตอนที่ 1: ติดตั้ง Core Services ทั้งหมด
```bash
# 1. คัดลอก template .env และสร้างสุ่มคีย์ลับความปลอดภัย
cp .env.example .env
sed -i "s/N8N_ENCRYPTION_KEY=/N8N_ENCRYPTION_KEY=$(openssl rand -hex 32)/" .env
sed -i "s/DIFY_SECRET_KEY=/DIFY_SECRET_KEY=$(openssl rand -hex 48)/" .env

# 2. สั่งรันสคริปต์ติดตั้ง Core Services (Ollama, Dify, n8n, Caddy)
make install
```

### 2️⃣ ขั้นตอนที่ 2: ตั้งค่า Admin UI & กรอก API Keys
1. เปิด Web Browser เข้าไปที่ `http://<SERVER_IP>` เพื่อตั้งค่า Admin Account ของ Dify
2. สร้าง Datasets 3 ตัว (`kb-operation`, `kb-noc`, `kb-customer-faq`) แล้วกดคัดลอก **Dataset IDs** และ **API Keys**
3. แก้ไขไฟล์ `.env` บน Server เพื่อวางค่า Keys ที่ได้มา

### 3️⃣ ขั้นตอนที่ 3: สั่งรันซิงค์ Workspace & Workflows
```bash
make setup-workspace
```
*(ระบบจะทำการนำเข้า n8n Workflows และซิงค์เอกสารองค์ความรู้ทั้งหมดเข้า Dify พร้อมใช้งาน 100%)*

📖 **อ่านคู่มือการติดตั้งและวิธีเอาค่าใน `.env` อย่างละเอียดยิบได้ที่:** [scripts/README.md](file:///c:/Users/natti/OneDrive/Documents/natties45/chatbot/scripts/README.md)

---

## 📁 โครงสร้างโปรเจกต์ (Project Structure)

```text
chatbot/
├── compose/              # Docker compose configs (dify, n8n, ollama, caddy)
├── dify/                 # System Prompts & App DSL templates
├── n8n/                  # n8n Workflow JSON templates (01-github-dify-sync.json)
├── docs/                 # Runbook & Recovery documentation
├── scripts/              # ศูนย์รวมสคริปต์ติดตั้งและซิงค์ระบบ (ดูรายละเอียดใน scripts/README.md)
│   ├── install.sh        # [Step 1] ติดตั้งแพ็กเกจ Host, Pull Images, ขึ้น Stack & Verify
│   ├── setup_workspace.sh# [Step 2] นำเข้า n8n Workflows & Sync Dify KB
│   └── README.md         # คู่มือสคริปต์และคำสั่งทีละขั้นตอนอย่างละเอียด
├── Makefile              # คำสั่งหลักทั้งหมดสำหรับผู้ดูแลระบบ
├── .env.example          # Template ค่าแวดล้อมระบบ
└── AGENTS.md             # กฎการทำงานและ DNA ตอบลูกค้าภาษาไทย
```

---

## 🛠️ คำสั่งหลักในการดูแลรักษาระบบ (Makefile Commands)

| คำสั่ง | การทำงาน |
|---|---|
| `make install` | รัน Preflight, ติดตั้งแพ็กเกจระบบ, Pull Images และขึ้น Core Services ทั้งหมด |
| `make setup-workspace` | นำเข้า n8n Workflows และซิงค์ Knowledge Base เข้า Dify Datasets |
| `make status` | ตรวจสอบสถานะและ Healthcheck ของ Docker Containers ทั้งหมด |
| `make logs` | ดู Logs รวมของทั้ง Stack แบบ Real-time |
| `make logs-dify` | ดู Logs เฉพาะของ Dify Services |
| `make logs-n8n` | ดู Logs เฉพาะของ n8n Services |
| `make logs-ollama` | ดู Logs เฉพาะของ Ollama |
| `make backup` | สำรองข้อมูลฐานข้อมูล Postgres (Dify, n8n) และ Volume ทั้งหมด |
| `make restore ARCHIVE=<path>` | กู้คืนระบบจากไฟล์ Backup Archive |

---

## 🔒 กฎความปลอดภัยและการปฏิบัติตามมาตรฐาน (Security & DNA Rules)

1. **No Secrets in Git:** ห้าม commit ไฟล์ `.env`, API Keys, Passwords หรือ Secrets ใดๆ ขึ้น Git เด็ดขาด
2. **Version Pinning:** ทุก Docker Image ใน `.env` ต้องระบุเวอร์ชันชัดเจน (ห้ามใช้ `:latest`)
3. **Response DNA (Thai สุภาพ):**
   - **Operation:** "เรียน ทีม Operation ครับ" ... "ขอบคุณครับ"
   - **NOC:** "เรียน ทีม NOC ครับ" ... "ขอบคุณครับ"
   - **Customer:** "เรียน ผู้ใช้บริการ" ... "ขอบคุณครับ" (ใช้ approved wording เท่านั้น)
4. **Customer Bot Gate:** ปิดการใช้งาน Customer bot สำหรับภายนอกจนกว่าจะผ่าน Red-team review

---
*ดูรายละเอียดเพิ่มเติมที่ [docs/runbook.md](file:///c:/Users/natti/OneDrive/Documents/natties45/chatbot/docs/runbook.md) และ [scripts/README.md](file:///c:/Users/natti/OneDrive/Documents/natties45/chatbot/scripts/README.md)*
