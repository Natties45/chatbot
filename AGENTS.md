# AGENTS.md — chatbot/ workspace

## Constraints

1. **Version pinning**: ทุก Docker image ต้องระบุ tag ชัดเจน ห้ามใช้ `latest`.
2. **No secrets in Git**: ห้าม commit `.env`, credentials, API keys, passwords, private keys, หรือ logs ที่มีข้อมูล sensitive.
3. **selfservice-repo is canonical**: อ่านได้อย่างเดียว ห้ามแก้ไขไฟล์ใด ๆ ใน selfservice-repo.
4. **Customer wording rules**:
   - ห้าม mention `OpenStack`, `API`, `CLI`, `backend`, `Dante`, internal path ต่อลูกค้า
   - อนุญาตให้กล่าวถึง: `Instance`, `SSH`, `RDP`, `DNS`, `SSL`, `Snapshot`, `Security Group`, `Bucket`
5. **Response DNA (Thai สุภาพ)**:
   - เปิดด้วย "เรียน ผู้ใช้บริการ"
   - ปิดด้วย "ขอบคุณครับ"
   - ใช้ "ครับ" ในประโยค
6. **Customer bot gate**: ปิดการใช้งาน customer bot จนกว่าผ่าน red-team review.
7. **Cite proposal**: อ้างอิง `docs/proposals/dify-n8n-chatbot-plan.md` line refs เมื่อตอบคำถามเกี่ยวกับแผน.

## Approved terminology

| หัวข้อ | คำที่ใช้กับลูกค้า |
|---|---|
| Server | Instance |
| Remote access | SSH / RDP |
| Domain/DNS | DNS / SSL |
| Backup | Snapshot |
| Firewall | Security Group |
| Object storage | Bucket |

## File ownership

- `selfservice-repo`: canonical (read-only)
- `chatbot/`: infra implementation (writeable)
