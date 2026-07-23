# Playbook — OLS Chatbot Implementation Guide

> เอกสารขั้นตอนการติดตั้งและบันทึกสถานะระบบ OLS Chatbot (อัปเดตล่าสุด 2026-07-23 ICT)

---

## 📍 สถานะการติดตั้งปัจจุบัน (Current Progress)

- ✅ **Server IP:** `203.154.16.45` (Hostname: `chatbot`)
- ✅ **Dify Stack (Port 80):** ติดตั้งและรันสำเร็จ (14 Containers Healthy) พร้อมลงทะเบียน Admin Account
- ✅ **n8n Stack (Port 5678):** ติดตั้งและรันสำเร็จ พร้อมลงทะเบียน Owner Account + เชื่อม Network เดียวกับ Dify
- ✅ **Ollama Stack:** Deployed `ollama/ollama:0.32.1` บน `dify_default` network, `bge-m3:latest` pulled สำหรับ local embeddings (ลบ local LLM models ที่ไม่ใช้ออก คืนดิสก์ > 5.7 GB)
- ✅ **Dify Model Provider:** เชื่อมต่อ Ollama Local (`bge-m3`) และ Ollama Cloud Pro (LLM API) เรียบร้อย
- ✅ **Knowledge Base 3 ชุด:** สร้างและ Sync ข้อมูลสำเร็จ 549/549 เอกสาร (100% Completed) ครบทั้ง `kb-operation`, `kb-noc`, `kb-customer-faq`
- ✅ **n8n Workflows:** Workflow `01-github-dify-sync` Active เรียบร้อย (ปรับรอบการ sync เป็น Daily at 00:00 น.)
- ✅ **Chatbot Apps & Prompts:** สร้างสำเร็จ 3 Apps (`Operation Bot`, `NOC Bot`, `Customer FAQ Bot`) พร้อมผูก System Prompts ตาม Response DNA

---

## 🔑 ข้อมูลเข้าใช้งานระบบ (Credentials & Endpoints)

| บริการ | URL / Endpoint | บัญชีผู้ใช้งาน / Email | Password / Description |
|---|---|---|---|
| **Dify Web UI** | http://203.154.16.45 | `admin@ols-chatbot.local` | Console Admin Account |
| **n8n Automation** | http://203.154.16.45:5678 | `admin@ols-chatbot.local` | Workflow Owner Account |
| **Ollama (internal)** | http://ollama:11434 | (internal network) | `bge-m3:latest` Local Embedding |

---

## ⚠️ สรุปประเด็นที่แก้ไขเสร็จสิ้นแล้ว (Resolved Issues)

1. ✅ **ล้าง raw SQL entries** ใน Dify DB และสร้าง Knowledge Base + Apps ผ่าน Dify service layer สำเร็จ
2. ✅ **ตั้งค่า Model Provider** ใน Dify UI สมบูรณ์ (Embedding: `bge-m3:latest`, LLM: Ollama Cloud Pro)
3. ✅ **ลบ Unused Ollama Local Models** (`qwen2.5:1.5b` และ `qwen2.5:7b`) คืนพื้นที่ดิสก์รวม > 5.7 GB
4. ✅ **ปรับลดความถี่ n8n Schedule** จากทุก 2 นาที เป็นทุกเที่ยงคืน (00:00 น.) เพื่อประหยัดทรัพยากร
5. ✅ **Git sync** — สภาพแวดล้อมระหว่าง Dev machine และ Live Server สอดคล้องกันเรียบร้อย

---

## 📝 แผนการดำเนินงานในเฟสถัดไป (Next Steps — Phase 6 Go-Live)

1. **Red-team Security & DNA Testing**:
   - ทดสอบ Prompt Injection, Privacy compliance, Customer wording rules
2. **Reverse Proxy & TLS Hardening**:
   - เปิด Caddy Reverse Proxy (`make proxy-up`) สำหรับ IP-only SSL/TLS หรือ Domain mapping
3. **Automated Backup & Restore Verification**:
   - ทดสอบรัน `bash scripts/backup.sh` และยืนยันการ Restore จาก Backup Archive
4. **Final Sign-off & Publish Customer FAQ Share Link**:
   - รับอนุมัติ Go-live และเผยแพร่ Customer Bot Share Link

