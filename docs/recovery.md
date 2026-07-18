# Recovery — OLS Chatbot

## กรณี 1: Dify KB ผิด/เสียหาย — rebuild จาก canonical

KB เป็น derived store สร้างใหม่ได้จาก selfservice-repo เสมอ (proposal L147, L290)

1. ใน n8n UI เปิด workflow `01-github-dify-sync`
2. Manual trigger → ตรวจสอบว่า git pull สำเร็จ
3. หากต้องการ full rebuild:
   - ลบ documents ทั้งหมดใน dataset ผ่าน Dify UI หรือ API
   - manual trigger workflow 01 (จะ upsert ใหม่ทั้งหมด)
4. ตรวจ document count + metadata ใน Dify Knowledge UI

## กรณี 2: Restore จาก backup

```bash
bash scripts/restore.sh /var/backups/ols-chatbot/<timestamp>.age.tar.gz
# หรือถ้า unencrypted:
bash scripts/restore.sh /var/backups/ols-chatbot/<timestamp>/
```

restore.sh จะ:
1. หยุด n8n + Dify
2. restore Dify postgres + n8n postgres + volumes
3. รัน ollama + dify + n8n ใหม่

⚠️ ทดสอบ restore ใน staging ก่อนใช้บน production

## กรณี 3: เปลี่ยน LLM provider

LLM provider ผูกกับ Dify Model Provider UI ไม่ใช่ไฟล์ใน repo

1. Dify UI → Settings → Model Provider → เพิ่ม provider ใหม่
2. ในแต่ละ chatbot app → Model → เลือก model ใหม่
3. ทดสอบคำตอบภาษาไทย
4. ปิด provider เก่าถ้าไม่ใช้แล้ว

## กรณี 4: เปลี่ยน embeddings model

⚠️ เปลี่ยนแล้วต้อง reindex KB ทั้งหมด

1. แก้ `OLLAMA_EMBED_MODEL` ใน `.env`
2. `bash scripts/ollama-up.sh` (จะ pull model ใหม่)
3. Dify UI → Settings → Model Provider → Ollama local → เปลี่ยน model
4. ในแต่ละ dataset → Settings → Retrain (หรือ reindex)
5. ตรวจสอบ embedding dimensions ตรงกับที่ Dify คาดการณ์

## กรณี 5: n8n workflow sync ล้มเหลว

1. ดู execution log ใน n8n UI → workflow `01-github-dify-sync`
2. ถ้า schema validation fail → แก้ YAML ใน selfservice-repo (ไม่ใช่ repo นี้)
3. ถ้า Dify API fail → ตรวจ Dify Dataset API key ใน n8n credential store
4. ถ้า git pull fail → ตรวจ GitHub SSH credential + network ออก internet
5. หลังแก้ → manual trigger workflow เพื่อทดสอบ

## กรณี 6: Ollama local ล่ม

```bash
docker logs ollama --tail 100
docker restart ollama
# ถ้า model หาย
docker exec ollama ollama pull bge-m3
# ทดสอบ
docker exec ollama curl -s http://127.0.0.1:11434/api/embeddings \
  -d '{"model":"bge-m3","prompt":"ทดสอบ"}'
```

## กรณี 7: เปลี่ยน server

1. ทำ backup บนเครื่องเก่า
2. clone chatbot repo บนเครื่องใหม่
3. คัดลอก `.env` (ด้วยมือ ผ่าน password manager — ห้าม commit)
4. รัน Phase 0 → Phase 3 ตาม runbook
5. restore backup
6. ทดสอบ red-team อีกครั้ง