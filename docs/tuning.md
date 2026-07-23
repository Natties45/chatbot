# คู่มือการปรับจูนระบบ OLS Chatbot (Tuning Guide & Reference)

เอกสารนี้ระบุรายละเอียดการปรับแต่ง (Tuning Guide) ทั้งหมดสำหรับระบบ OLS Chatbot ทั้ง 3 บทบาท (Operation, NOC, Customer) รวมถึงคู่มือการใช้งานสคริปต์อัตโนมัติในการปรับจูนระบบ Dify

---

## 1. ภาพรวมโครงสร้างการปรับจูน (Bottom-Up Optimization)

```
[Level 3: Application Layer] ──> Model Temperature (0.1/0.3) + Sensitive Word Moderation + Response DNA
[Level 2: System Prompt Layer] ─> English Prompts + Anti-Thinking (<think>) + Role Restrictions
[Level 1: Knowledge Base Layer] ─> Hybrid Search + Score Threshold (0.55) + Top-K (3) + Custom Delimiter (\n\n# )
```

---

## 2. รายละเอียดสคริปต์อัตโนมัติ (`scripts/tuning/`)

สคริปต์อัตโนมัติถูกจัดเก็บแยกไว้ในไดเรกทอรี `scripts/tuning/` เพื่อไม่ให้กระทบกระบวนการทำงานหลัก:

| ไฟล์สคริปต์ | หน้าที่การทำงาน |
|---|---|
| `scripts/tuning/tune_dify_all.py` | สคริปต์หลักสำหรับรันอัปเดตการปรับจูนทั้งหมดในคำสั่งเดียว |
| `scripts/update_dify_db.py` | อัปเดต RAG Retrieval Model (Hybrid Search, Score Threshold 0.55) |
| `scripts/update_process_rules_db.py` | อัปเดต Custom Segmenting Rules (`\n\n# `, max_tokens 800) |
| `scripts/update_dify_app_prompts.py` | อัปเดต System Prompts และ Moderation Words บน Dify Apps |

---

## 3. วิธีการรันปรับจูนระบบอัตโนมัติ (Execution Command)

ผู้ดูแลระบบสามารถรันปรับจูนค่าทั้งหมดผ่านคำสั่งเดียวดังนี้:

```bash
python scripts/tuning/tune_dify_all.py
```

### การตรวจสอบผลลัพธ์หลังการปรับจูน:
1. เปิด Dify Console UI ที่ `http://203.154.16.45/v1`
2. ไปที่เมนู **Studio** -> เลือก App (`Operation Bot`, `NOC Bot`, `Customer FAQ Bot`)
3. ตรวจสอบว่าช่อง **System Instructions** แสดงผลเป็นโปรมป์ภาษาอังกฤษตัวใหม่เรียบร้อยแล้ว
4. ตรวจสอบ **Moderation Filter** บน Customer App ว่ามีคำต้องห้าม 7 คำ (`OpenStack`, `Dante`, `backend`, `internal tool`, `internal path`, `API`, `CLI`) ถูกตั้งค่าไว้เรียบร้อยแล้ว
