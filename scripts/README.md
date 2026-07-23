# คู่มือการติดตั้งและใช้งาน Scripts ระบบ OLS Chatbot (scripts/README.md)

ยินดีต้อนรับสู่คู่มือการใช้งานและการติดตั้งระบบ **OLS Chatbot** (Dify + n8n + Ollama + Caddy) แบบละเอียดยิบ พร้อมคำสั่งทุกขั้นตอนสำหรับคัดลอกไปใช้งานได้ทันที

---

## 📌 ภาพรวมสคริปต์หลัก (Core Scripts)

| สคริปต์ | หน้าที่หลัก | คำสั่งทางเลือก (Makefile) |
|---|---|---|
| **`install.sh`** | **[ขั้นตอนที่ 1]** ตรวจสภาพเครื่อง, ติดตั้งแพ็กเกจที่จำเป็นบน Host, ดึง Docker Images, รัน Core Services ทั้งหมด และเช็คความเชื่อมต่อระหว่างคอนเทนเนอร์ | `make install` |
| **`setup_workspace.sh`** | **[ขั้นตอนที่ 2]** นำเข้า n8n Workflows และซิงค์ Knowledge Base จาก selfservice-repo เข้า Dify | `make setup-workspace` |
| `preflight.sh` | ตรวจสอบระบบปฏิบัติการ, RAM, Disk, Port และ `.env` ก่อนติดตั้ง | `make preflight` |
| `stack.sh` | ตัวจัดการ Container Stack (เปิด/ปิด/ดูสถานะ/ดู logs รายบริการ) | `make <service>-up` / `make status` |
| `backup.sh` | สำรองข้อมูลฐานข้อมูล Postgres (Dify, n8n) และ Volume ทั้งหมด | `make backup` |
| `restore.sh` | กู้คืนระบบจากไฟล์ Backup Archive | `make restore ARCHIVE=...` |

---

## 📖 คู่มือการติดตั้งระบบทีละขั้นตอน (Step-by-Step Complete Guide)

### 🔹 ขั้นตอนที่ 1: การเตรียมไฟล์ `.env` และสุ่มสร้างคีย์ (Environment Setup)

เปิด Terminal บน Server แล้วรันชุดคำสั่งด้านล่างนี้ตามลำดับ:

1. **สลับไปที่ไดเรกทอรีโปรเจกต์:**
   ```bash
   cd /root/chatbot
   ```

2. **คัดลอกไฟล์ Template เป็น `.env`:**
   ```bash
   cp .env.example .env
   ```

3. **สุ่มสร้างคีย์เข้ารหัสลับความปลอดภัยอัตโนมัติลงใน `.env` (รันคำสั่ง 1-Click นี้ได้เลย):**
   ```bash
   sed -i "s/N8N_ENCRYPTION_KEY=/N8N_ENCRYPTION_KEY=$(openssl rand -hex 32)/" .env
   sed -i "s/DIFY_SECRET_KEY=/DIFY_SECRET_KEY=$(openssl rand -hex 48)/" .env
   ```

4. **ตรวจหา IP ของ Server และใส่ใน `.env` อัตโนมัติ:**
   ```bash
   MY_IP=$(curl -s ifconfig.me)
   sed -i "s/N8N_HOST=<server-ip-or-domain>/N8N_HOST=${MY_IP}/" .env
   sed -i "s|WEBHOOK_URL=http://<server-ip-or-domain>:5678/|WEBHOOK_URL=http://${MY_IP}:5678/|" .env
   ```

5. **เปิดแก้ไขไฟล์ `.env` เพื่อตั้งรหัสผ่านของคุณ:**
   ```bash
   nano .env
   ```
   - เลื่อนลงไปกำหนดรหัสผ่านที่คุณต้องการ:
     - `N8N_BASIC_AUTH_PASSWORD=ตั้งรหัสผ่านของคุณ`
     - `N8N_DB_PASSWORD=ตั้งรหัสผ่านพาสเกรสของคุณ`
     - `DIFY_INIT_PASSWORD=ตั้งรหัสผ่านแอดมินดิฟายของคุณ`
   - *วิธีบันทึกไฟล์ในโปรแกรม nano:* กด `Ctrl + O` แล้วกด `Enter` เพื่อบันทึก จากนั้นกด `Ctrl + X` เพื่อออกจากโปรแกรม

---

### 🔹 ขั้นตอนที่ 2: การสั่งรันสคริปต์ติดตั้ง Core Services

เมื่อเตรียมไฟล์ `.env` เรียบร้อย ให้สั่งรันสคริปต์ติดตั้ง:

```bash
make install
# หรือรันคำสั่ง: bash scripts/install.sh
```

**ผลลัพธ์ที่สคริปต์จะทำให้อัตโนมัติ:**
1. ตรวจสอบสเปคเครื่อง (RAM >= 8GB, Disk >= 40GB)
2. อัปเดตแพ็กเกจระบบปฏิบัติการและติดตั้ง `curl`, `git`, `python3`, `jq`
3. สร้าง Docker Network `ols-chatbot`
4. Pull และรัน Docker Containers ทั้งหมด (Dify 14 ตัว, n8n, Ollama, Caddy)
5. สั่ง Pull โมเดล `bge-m3` เข้า Ollama
6. ยิงทดสอบการสื่อสารข้ามคอนเทนเนอร์ (Dify -> Ollama, n8n -> Ollama, n8n -> Dify) และขึ้นข้อความ `[OK]`

---

### 🔹 ขั้นตอนที่ 3: การตั้งค่า Admin บน Dify Web UI และการเอา API Keys

เมื่อสคริปต์ในขั้นตอนที่ 2 รันเสร็จสิ้นแล้ว ให้ทำตามขั้นตอนการเข้าหน้าเว็บดังนี้:

1. **เข้าหน้าเว็บ Dify:**
   เปิด Web Browser บนคอมพิวเตอร์ของคุณ แล้วพิมพ์ URL:
   `http://<SERVER_IP>`

2. **สมัคร Admin Account ครั้งแรก:**
   - กรอก Email, Username และ Password สำหรับเป็นเจ้าของระบบ Dify แล้วกด **Set up**

3. **สร้าง Knowledge Base Datasets และดึงคีย์มาใช้งาน (3 Datasets):**

   * ** Dataset 1: `kb-operation` **
     - ที่แถบเมนูด้านบน คลิก **"Knowledge"** (องค์ความรู้)
     - คลิกปุ่ม **"Create Knowledge"** -> เลือก **"Create from blank"**
     - ช่องชื่อพิมพ์: `kb-operation` แล้วกด **"Save"**
     - **วิธีเอา Dataset ID:** มองที่ช่องแถบ URL ของ Web Browser จะเห็น URL เช่น:
       `http://<SERVER_IP>/datasets/<DATASET_ID>/documents`
       ให้คัดลอกข้อความรหัสในตำแหน่ง `<DATASET_ID>`
     - **วิธีเอา API Key:** ที่เมนูด้านซ้ายในหน้า Dataset คลิก **"API Access"** -> คลิก **"API Key"** -> กด **"Create API Key"** -> กด Copy คีย์ที่ได้ (จะขึ้นต้นด้วย `ds-...`)

   * ** Dataset 2: `kb-noc` **
     - ทำเช่นเดียวกัน: คลิก Knowledge -> Create Knowledge -> Create from blank
     - ตั้งชื่อ: `kb-noc` -> กด Save
     - คัดลอก **Dataset ID** จาก URL
     - เมนูด้านซ้ายไปที่ **API Access** -> กด **Create API Key** แล้ว Copy คีย์

   * ** Dataset 3: `kb-customer-faq` **
     - ทำเช่นเดียวกัน: คลิก Knowledge -> Create Knowledge -> Create from blank
     - ตั้งชื่อ: `kb-customer-faq` -> กด Save
     - คัดลอก **Dataset ID** จาก URL
     - เมนูด้านซ้ายไปที่ **API Access** -> กด **Create API Key** แล้ว Copy คีย์

---

### 🔹 ขั้นตอนที่ 4: นำ Keys กลับมาอัปเดตในไฟล์ `.env`

1. **เปิดไฟล์ `.env` บน Terminal:**
   ```bash
   nano .env
   ```

2. **เลื่อนไปที่หมวด Dify Datasets แล้ววางค่าที่คุณคัดลอกมาจาก Web UI:**
   ```env
   DIFY_OPERATION_DATASET_ID=<วาง Dataset ID ของ kb-operation>
   DIFY_OPERATION_API_KEY=<วาง API Key ของ kb-operation>

   DIFY_NOC_DATASET_ID=<วาง Dataset ID ของ kb-noc>
   DIFY_NOC_API_KEY=<วาง API Key ของ kb-noc>

   DIFY_CUSTOMER_DATASET_ID=<วาง Dataset ID ของ kb-customer-faq>
   DIFY_CUSTOMER_API_KEY=<วาง API Key ของ kb-customer-faq>
   ```

3. **บันทึกและปิดไฟล์:** กด `Ctrl + O` -> กด `Enter` -> กด `Ctrl + X`

---

### 🔹 ขั้นตอนที่ 5: สั่งรันสคริปต์ตั้งค่า Workspace

เมื่อวาง Keys ใน `.env` เรียบร้อยแล้ว ให้รันคำสั่งสุดท้าย:

```bash
make setup-workspace
# หรือรันคำสั่ง: bash scripts/setup_workspace.sh
```

**ผลลัพธ์ที่สคริปต์จะทำให้อัตโนมัติ:**
1. นำเข้า n8n Workflow (`01-github-dify-sync.json`) เข้าฐานข้อมูล n8n และเปิดทำงานอัตโนมัติ
2. อ่านไฟล์ข้อมูล YAML จาก `selfservice-repo` แปลงเป็น Markdown และอัปโหลดเข้า Dify Datasets ทั้ง 3 ตัว
3. สรุปรายการ Workflow และจำนวนเอกสารใน Knowledge Base พร้อมเข้าใช้งาน 100%

---

## 🔍 คำสั่งดูแลรักษาระบบ (Operations & Troubleshooting)

* **ดูสถานะการทำงานของทุกคอนเทนเนอร์:**
  ```bash
  make status
  ```
* **ดู Logs ของ Dify Stack:**
  ```bash
  make logs-dify
  ```
* **ดู Logs ของ n8n Stack:**
  ```bash
  make logs-n8n
  ```
* **ดู Logs ของ Ollama Stack:**
  ```bash
  make logs-ollama
  ```
* **สำรองข้อมูลระบบ (Backup DB & Volumes):**
  ```bash
  make backup
  ```

---
*คู่มือฉบับนี้อัปเดตล่าสุดสอดคล้องตามข้อกำหนดใน `AGENTS.md` และแผนงาน `docs/proposals/dify-n8n-chatbot-plan.md`*
