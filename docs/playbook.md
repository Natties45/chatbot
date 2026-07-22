# Playbook — OLS Chatbot Implementation Guide

> เอกสารขั้นตอนการติดตั้งและตั้งค่าระบบ OLS Chatbot (อัปเดตสถานะการดำเนินงานปัจจุบัน)

---

## 📍 สถานะการติดตั้งปัจจุบัน (Current Progress)

- ✅ **Server IP:** `203.154.16.45` (Hostname: `chatbot`)
- ✅ **Dify Stack (Port 80):** ติดตั้งและรันสำเร็จ พร้อมลงทะเบียน Admin Account
- ✅ **n8n Stack (Port 5678):** ติดตั้งและรันสำเร็จ พร้อมลงทะเบียน Owner Account + เชื่อม Network เดียวกับ Dify
- ⏳ **Ollama Stack:** (รอการติดตั้งในเฟสถัดไป)
- ⏳ **Dify Knowledge Base & Prompts:** (รอการตั้งค่าในเฟสถัดไป)

---

## 🔑 ข้อมูลเข้าใช้งานระบบ (Credentials & Endpoints)

| บริการ | URL / Endpoint | บัญชีผู้ใช้งาน / Email | Password |
|---|---|---|---|
| **Dify Web UI** | http://203.154.16.45 | `admin@ols-chatbot.local` | `u29Q958AHuGo9lkR` |
| **n8n Automation** | http://203.154.16.45:5678 | `admin@ols-chatbot.local` | `ojvuzVsQ6iNPKJvb` |

*ข้อมูลรหัสผ่านฉบับสมบูรณ์จัดเก็บไว้อย่างปลอดภัยที่ `secrets/credentials.txt` และ `secrets/.env` (Gitignored)*

---

## 🛠️ ขั้นตอนการรันและควบคุมบริการ (Operations Guide)

### 1. การตรวจสอบสถานะระบบ
```bash
ssh chatbot
docker ps
```

### 2. การเปิดบริการ Dify (Port 80)
```bash
ssh chatbot
cd /root/chatbot/compose/dify
docker compose up -d
```

### 3. การเปิดบริการ n8n (Port 5678)
```bash
ssh chatbot
cd /root/chatbot
docker compose --env-file /root/chatbot/.env -f compose/n8n/docker-compose.n8n.yml up -d
```

---

## 🌐 เครือข่ายและการเชื่อมต่อภายใน (Docker Networking)

- **Network หลัก:** `dify_default` (Bridge Network)
- **n8n ➔ Dify Internal Communication:** 
  - n8n สามารถส่ง API ไปหา Dify ภายในวงเสมือนได้โดยตรงที่: `http://dify-nginx-1/v1/...`
- **Public Port:**
  - `80` (Dify Web Nginx Proxy)
  - `5678` (n8n Web UI)
- **Private Port (Internal only):**
  - PostgreSQL (`5432`), Redis (`6379`), Weaviate (`8080`), Dify Internal Web (`3000`), Dify API (`5001`)

---

## 📝 แผนการดำเนินงานในเฟสถัดไป (Next Steps)

1. **ติดตั้งและรัน Ollama Stack:**
   - รัน Ollama Container (`ollama/ollama:0.32.1`)
   - Pull Model สำหรับทำ Embedding (`bge-m3`)
2. **ตั้งค่า Model Provider ใน Dify UI:**
   - เชื่อมต่อ Ollama Local (Embedding: `bge-m3`)
   - เชื่อมต่อ Ollama Cloud Pro (LLM: `qwen2.5:7b`)
3. **สร้าง Knowledge Base (KB) 3 ชุดใน Dify:**
   - `kb-operation`
   - `kb-noc`
   - `kb-customer-faq`
4. **สร้างและตั้งค่า Chatbot Apps 3 ชุด:**
   - Operation Assistant
   - NOC Assistant
   - Customer Assistant
