# n8n credentials

Credentials สำหรับ n8n workflows เก็บใน **n8n credential store (UI)** เท่านั้น
ห้าม commit credential JSON จริงเข้า repo นี้

## รายการที่ต้องสร้างใน n8n UI

| Credential name | Type | Purpose |
|---|---|---|
| GitHub SSH | SSH | n8n git pull `git@github.com:Natties45/selfservice-repo.git` |
| Dify Dataset API (kb-operation) | Header Auth | Upsert documents into kb-operation dataset |
| Dify Dataset API (kb-noc) | Header Auth | Upsert documents into kb-noc dataset |
| Dify Dataset API (kb-customer) | Header Auth | Upsert documents into kb-customer dataset |
| LINE Notify | Header Auth | ส่ง notification ไป @Natties45 (Authorization: Bearer <token>) |
| SMTP (optional) | SMTP | สำรองการแจ้งเตือนทาง email |

## วิธีสร้าง

1. เข้า n8n UI ผ่าน SSH tunnel: `ssh -L 5678:127.0.0.1:5678 chatbot`
2. Credentials → New
3. เลือก type ตามตาราง ตั้งชื่อตรงตามนั้น (workflows อ้างอิงด้วยชื่อ)
4. ใส่ค่าจริง บันทึก

## ห้าม

- ห้าม export credential JSON แล้ว commit ที่นี่
- ห้ามวาง secret ใน `n8n/workflows/*.json` ให้ใช้ credential reference by name เท่านั้น