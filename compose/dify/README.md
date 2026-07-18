# Dify compose

`docker-compose.yaml` ในโฟลเดอร์นี้ **ไม่ได้ commit ไว้ใน repo** — ดาวน์โหลดจาก
upstream ก่อนรันครั้งแรก เพื่อให้สามารถ pin ตาม release tag ของ Dify ได้

## วิธีดาวน์โหลด (Phase 2)

```bash
# อ่าน tag จาก .env แล้ว clone Dify ที่ tag นั้น
git clone --depth 1 --branch $(grep DIFY_IMAGE_TAG .env | cut -d= -f2) \
  https://github.com/langgenius/dify.git /tmp/dify-src

cp /tmp/dify-src/docker/docker-compose.yaml compose/dify/docker-compose.yaml
cp /tmp/dify-src/docker/.env.example .env.example.dify
rm -rf /tmp/dify-src
```

หรือรันผ่าน Make:

```bash
make dify-fetch
```

## หลังดาวน์โหลด

- กรอก `.env` (gitignored) โดยอ้างอิง `.env.example.dify` รวมกับ `.env.example` ที่ root
- ปรับ `docker-compose.yaml` ให้ใช้ network `ols-chatbot` และ volume `dify-data` จาก
  `compose/docker-compose.yml` (base)
- ทุก image ต้องมี tag ห้าม `latest` (proposal L434)

## ห้าม

- อย่า commit `compose/dify/docker-compose.yaml` ที่ดาวน์โหลดแล้วกลับเข้า repo
  (เป็น vendored artifact ติดตาม release ของ upstream ดีกว่า)
- อย่า commit `.env` จริง