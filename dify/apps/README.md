# Dify app exports (optional)

โฟลเดอร์นี้เก็บ Dify app DSL export (YAML/JSON) สำหรับ re-import เมื่อสร้าง app ใหม่
หรือ migrate server ไม่จำเป็นต้องมี แต่แนะนำให้ export หลังจาก config app เสร็จใน Phase 5

## ชื่อไฟล์ที่แนะนำ

- `staff-general.app.yml` — OLS Staff General bot
- `billing-support.app.yml` — OLS Billing Support bot
- `vm-support.app.yml` — OLS VM Support bot
- `customer-faq.app.yml` — OLS Customer FAQ bot (disabled until red-team passes)

## วิธี export

Dify UI → App → จุดสามจุด → Export → DSL (YAML) → save ที่นี่