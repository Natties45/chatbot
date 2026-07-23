# Master Execution Plan: Dify Chatbot Evolution & KB Enrichment
*(ผ่านกระบวนการ Scrutinize & การปรับโครงสร้างแบบบูรณาการทั้งหมด)*

เอกสารนี้คือ **แผนปฏิบัติการขั้นสูงสุด (Master Execution Plan)** แบบละเอียดมากๆ ที่ครอบคลุมทุกประเด็นที่เราหารือกัน ตั้งแต่การจัดการ Knowledge Base ไปจนถึงสถาปัตยกรรมระดับสูงของ Dify (DSL & Chatflow) โดยเรียงลำดับการทำงานจากต้นน้ำ (ข้อมูล) ไปจนถึงปลายน้ำ (ตัวแชทบอท)

---

## 🎯 Phase 1: Knowledge Base Content Enrichment (การเพิ่มพูนความรู้จาก Blog)
**เป้าหมาย:** ดึงเนื้อหาฉบับเต็มจาก Blog มาจัดเก็บลงใน Git (Local KB) เพื่อให้บอทอ่านเนื้อหาทั้งหมดได้ทันทีและมี Link ไว้อ้างอิง (Citation)

*   **Step 1.1: สร้างที่เก็บข้อมูล Blog ใน Git**
    *   สร้างโครงสร้างไฟล์ เช่น `KB/data/blog-archive/` หรือแทรกในไฟล์เดิมตาม Domain หมวดหมู่
*   **Step 1.2: กระบวนการจัดเก็บข้อมูล (Content Ingestion)**
    *   นำเนื้อหา Text/Markdown ทั้งหมดจาก Blog มาใส่ในไฟล์ YAML
    *   **สำคัญ:** ระบุ URL ต้นทางไว้ในฟิลด์ `refs:` หรือ `url:` ของ YAML เพื่อให้สคริปต์ดึงไปทำเป็น Reference ให้ LLM ได้
*   **Step 1.3: กำหนด Role-Based Access Control (RBAC)**
    *   ใส่ Metadata `audience: [operation, noc, customer]` กำกับแต่ละบล็อกให้ชัดเจนว่าให้ใครอ่านได้บ้าง

---

## ⚙️ Phase 2: Sync Script Enhancement (อัปเกรดท่อส่งข้อมูลเข้า Dify)
**เป้าหมาย:** แก้ไขสคริปต์ `scripts/sync_selfservice_to_dify.py` ให้ฉลาดขึ้นและรองรับกฎเกณฑ์ Metadata ที่ตั้งไว้ใน Taxonomy

*   **Step 2.1: แก้ไขลอจิกการคัดกรอง (Audience Filtering)**
    *   *ปัญหาเดิม:* โค้ดบรรทัดที่ 78 คัดกรองความลับโดยดูแค่ชื่อไฟล์ `noc-scripts` (Hardcoded)
    *   *การแก้ไข:* เขียนโค้ด Python ให้ดึงค่า `audience` จากโครงสร้าง YAML (ตาม `taxonomy-and-roles.md`) เพื่อกรองข้อมูลก่อนส่งไป Dataset ของ Customer
*   **Step 2.2: ตรวจสอบการแปลง Markdown**
    *   ตรวจสอบให้แน่ใจว่าสคริปต์สามารถแปลงเนื้อหาบล็อกยาวๆ (พร้อม Link อ้างอิง) ให้ออกมาเป็นโครงสร้าง `# Heading` ที่ Dify ใช้หั่น (Chunk) ได้อย่างสมบูรณ์

---

## 🧩 Phase 3: Dify Configuration as Code (DSL Migration)
**เป้าหมาย:** เลิกรันสคริปต์แฮ็กฐานข้อมูล `tune_dify_all.py` (เสี่ยงพัง) และเปลี่ยนมาจัดการการตั้งค่าผ่านไฟล์ DSL (YAML) แบบ Best Practice

*   **Step 3.1: เตรียมไฟล์ DSL สำหรับ Basic Bots (NOC & Customer)**
    *   ตั้งค่าบน Dify UI ให้สมบูรณ์:
        *   Model: `qwen3.5:cloud`
        *   Stop Sequence: ลบ `</think>` ทิ้ง
        *   RAG: `Hybrid Search`, `Top-K = 4`, `Score Threshold = 0.50`
        *   Memory: `8 Turns`
    *   Export ไฟล์ DSL นำมาเก็บไว้ใน Git (เช่น `dify/apps/noc-bot.chat.yml`)
*   **Step 3.2: ยกเลิกการใช้สคริปต์เดิม**
    *   ลบไฟล์ หรือติดป้าย [DEPRECATED] ให้กับ `scripts/tuning/tune_dify_all.py` เพื่อป้องกันทีมงานเผลอไปกดรันจนทำ DB ล่ม

---

## 🧠 Phase 4: Operation Bot Chatflow Upgrade (Agentic RAG)
**เป้าหมาย:** อัปเกรด Operation Bot ให้มีความคิดและตรรกะเหมือนมนุษย์ (Workflow-based) เพื่อแก้ปัญหาทางเทคนิคที่ซับซ้อน

*   **Step 4.1: สร้าง App ใหม่เป็น Advanced Chat**
    *   สร้างแอปใหม่บน Dify สเตตัสเป็น `Advanced Chat / Chatflow`
*   **Step 4.2: วางโครงสร้าง Node Workflow**
    1.  **Question Classifier Node**: วิเคราะห์คำถาม (เทคนิค / ทั่วไป / ไม่เกี่ยว)
    2.  **Knowledge Retrieval Nodes**: แยกสายการค้นหา ถ้าเป็นเชิงเทคนิควิ่งไปหา `KB-Operation` ถ้าเป็นเรื่องทั่วไปวิ่งหา `KB-NOC`
    3.  **Context Merge & LLM Node**: นำข้อมูลที่ได้จาก KB มาร้อยเรียง สรุปผล พร้อมแนบ Link อ้างอิงส่งให้ User
*   **Step 4.3: Export Chatflow DSL**
    *   Export งานทั้งหมดเป็นไฟล์ `dify/apps/operation-bot.chatflow.yml` เก็บลง Git

---

## 🔒 บทสรุปการ Scrutinize รอบสุดท้าย (Final Verdict)
แผนการทั้งหมดนี้ถูกจัดเรียงลำดับความสำคัญไว้อย่างถูกต้อง **ลดความเสี่ยงด้าน Infrastructure เป็น 0** และปูทางไปสู่ **Self-Updating RAG** อย่างแท้จริง โดยเริ่มจากการทำให้ข้อมูล (Knowledge) มีคุณภาพสูงสุดก่อน (Phase 1 & 2) แล้วค่อยไปปรับแต่งสมองของบอท (Phase 3 & 4)

---
*สถานะ: แผนงานรอการอนุมัติ (Plan Mode - Pending User Execution)*
