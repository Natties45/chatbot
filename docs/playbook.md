# Playbook — OLS Chatbot Implementation Guide

> เอกสารขั้นตอนการติดตั้งและตั้งค่าระบบ OLS Chatbot (อัปเดต 2026-07-22 ~22:30 ICT)

---

## 📍 สถานะการติดตั้งปัจจุบัน (Current Progress)

- ✅ **Server IP:** `203.154.16.45` (Hostname: `chatbot`)
- ✅ **Dify Stack (Port 80):** ติดตั้งและรันสำเร็จ พร้อมลงทะเบียน Admin Account
- ✅ **n8n Stack (Port 5678):** ติดตั้งและรันสำเร็จ พร้อมลงทะเบียน Owner Account + เชื่อม Network เดียวกับ Dify
- ✅ **Ollama Stack:** Deployed `ollama/ollama:0.32.1` บน `dify_default` network, bge-m3 pulled, cross-container embeddings verified (1024-dim)
- ❌ **Dify Model Provider:** Raw SQL approach failed — `encrypted_config` เป็น plaintext, ต้อง recreate ผ่าน Dify Console API หรือ UI
- ❌ **Knowledge Base 3 ชุด:** Raw SQL approach failed — `index_struct` เป็น NULL, ไม่มี keyword tables, ต้อง recreate ผ่าน Dify service layer
- ⏳ **Ollama Cloud Pro LLM:** รอ rotate `OLLAMA_CLOUD_API_KEY` (key เดิมหลุดใน chat history)
- ⏳ **n8n Workflows:** รอ import
- ⏳ **Chatbot Apps & Prompts:** รอสร้าง

---

## 🔑 ข้อมูลเข้าใช้งานระบบ (Credentials & Endpoints)

| บริการ | URL / Endpoint | บัญชีผู้ใช้งาน / Email | Password |
|---|---|---|---|
| **Dify Web UI** | http://203.154.16.45 | `admin@ols-chatbot.local` | `u29Q958AHuGo9lkR` |
| **n8n Automation** | http://203.154.16.45:5678 | `admin@ols-chatbot.local` | `ojvuzVsQ6iNPKJvb` |
| **Ollama (internal)** | http://ollama:11434 | (internal only) | — |

---

## ⚠️ Issues ที่ต้องแก้ก่อนดำเนินการต่อ

1. **ล้าง raw SQL entries** ใน Dify DB (providers, provider_credentials, provider_models, provider_model_settings, datasets, api_tokens, dataset_collection_bindings ที่สร้างผิด)
2. **Rotate `OLLAMA_CLOUD_API_KEY`** ที่ cloud.ollama.ai (key เก่าหลุดใน chat history)
3. **Git push** — มี commits บน server ที่ยังไม่ push + local/server history diverged แล้ว

---

## 📝 แผนการดำเนินงานในเฟสถัดไป (Next Steps)

1. **Rotate OLLAMA_CLOUD_API_KEY** + อัปเดต `.env`
2. **ตั้งค่า Model Provider ใน Dify** ผ่าน Console API หรือ UI:
   - Ollama Local (Embedding: `bge-m3`) → base URL `http://ollama:11434`
   - Ollama Cloud Pro (LLM: `qwen2.5:7b`) → ใช้ key ใหม่
3. **สร้าง Knowledge Base (KB) 3 ชุด** ผ่าน Dify service layer:
   - `kb-operation`, `kb-noc`, `kb-customer-faq`
4. **Import n8n Workflows**
5. **สร้าง Chatbot Apps 3 ชุด**
