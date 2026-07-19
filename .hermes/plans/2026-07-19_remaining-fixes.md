# Remaining Fixes — OLS Chatbot Post-Audit

> **For Hermes:** ใช้ subagent-driven-development skill เพื่อ implement ทีละ task

**Goal:** แก้ส่วนที่เหลือจากการรีวิว — n8n public port, grep parsing, docs alignment

**Architecture:** Security at network edge (firewall/secgroup) → Docker expose ports public ได้

**Tech Stack:** Docker Compose v2, n8n 2.31.3, Caddy 2-alpine

---

## 📋 สรุปว่าเหลืออะไรต้องแก้ (หลัง audit + discussion)

| # | ไฟล์ | ปัญหา | Priority |
|---|---|---|---|
| 1 | `compose/n8n/docker-compose.n8n.yml:7` | `127.0.0.1:5678` → เปลี่ยนเป็น `5678:5678` (public) | 🔴 |
| 2 | `Makefile:dify-fetch` + `seed-ollama` | `grep` ยังใช้ `cut -f2` แบบเก่า — ต้องใช้ `-f2-` + `sed` เหมือน `dify-up.sh` | 🟡 |
| 3 | `.env.example` | `N8N_HOST=localhost` → ควรเป็น IP จริงของ server | 🟡 |
| 4 | `scripts/n8n-up.sh` | ข้อความ SSH tunnel — เปลี่ยนเป็นบอกว่าเข้า public ได้ | 🟢 |
| 5 | `compose/caddy/Caddyfile` | n8n block — เอา `bind 127.0.0.1` ออก + เพิ่ม basic_auth ซ้ำ | 🟢 |

---

### Task 1: เปิด n8n ให้ public

**Objective:** เปลี่ยน n8n port bind จาก localhost → ทุก interface

**Files:**
- Modify: `compose/n8n/docker-compose.n8n.yml:7`

**Step 1: แก้ port mapping**

เปลี่ยน:
```yaml
    ports:
      - "127.0.0.1:5678:5678"
```

เป็น:
```yaml
    ports:
      - "5678:5678"
```

**Step 2: Commit**

```bash
git add compose/n8n/docker-compose.n8n.yml
git commit -m "feat: expose n8n publicly (firewall-managed access)"
```

---

### Task 2: Fix grep ใน Makefile ให้กัน comment

**Objective:** `make dify-fetch` กับ `make seed-ollama` ใช้ `grep` แบบเดียวกับที่แก้ใน `dify-up.sh`

**Files:**
- Modify: `Makefile:10` (dify-fetch)
- Modify: `Makefile:47` (seed-ollama)

**Step 1: dify-fetch**

เปลี่ยน:
```makefile
dify-fetch:
	git clone --depth 1 --branch $$(grep DIFY_IMAGE_TAG $(ROOT)/.env | cut -d= -f2) https://github.com/langgenius/dify.git /tmp/dify-src
```

เป็น:
```makefile
dify-fetch:
	git clone --depth 1 --branch $$(grep DIFY_IMAGE_TAG $(ROOT)/.env | cut -d= -f2- | sed 's/[[:space:]]*#.*//' | xargs) https://github.com/langgenius/dify.git /tmp/dify-src
```

**Step 2: seed-ollama**

เปลี่ยน:
```makefile
seed-ollama:
	docker exec ollama ollama pull $$(grep OLLAMA_EMBED_MODEL $(ROOT)/.env | cut -d= -f2)
```

เป็น:
```makefile
seed-ollama:
	docker exec ollama ollama pull $$(grep OLLAMA_EMBED_MODEL $(ROOT)/.env | cut -d= -f2- | sed 's/[[:space:]]*#.*//' | xargs)
```

**Step 3: Commit**

```bash
git add Makefile
git commit -m "fix: make grep patterns resilient to inline comments"
```

---

### Task 3: แก้ `.env.example` ให้ n8n host ตรงกับ deployment

**Objective:** n8n public แล้ว → `N8N_HOST` ควรเป็น IP server, `N8N_PROTOCOL` เป็น `https` (ถ้าใช้ Caddy)

**Files:**
- Modify: `.env.example:13-16`

**Step 1: แก้ไข**

เปลี่ยน:
```bash
N8N_HOST=localhost
N8N_PORT=5678
N8N_PROTOCOL=http
WEBHOOK_URL=http://localhost:5678/
```

เป็น:
```bash
N8N_HOST=<server-ip-or-domain>
N8N_PORT=5678
N8N_PROTOCOL=http      # เปลี่ยนเป็น https ถ้าผ่าน Caddy
WEBHOOK_URL=http://<server-ip-or-domain>:5678/
```

**Step 2: Commit**

```bash
git add .env.example
git commit -m "fix: n8n env defaults — host to server IP + public webhook"
```

---

### Task 4: อัปเดตข้อความใน `n8n-up.sh`

**Objective:** script นี้บอกให้ SSH tunnel — เปลี่ยนเป็นบอกเข้า public ได้

**Files:**
- Modify: `scripts/n8n-up.sh:12-14`

**Step 1: แก้ output message**

เปลี่ยน:
```bash
echo
echo "Access n8n via SSH tunnel from your workstation:"
echo "  ssh -L 5678:127.0.0.1:5678 chatbot"
echo "  then open http://localhost:5678"
```

เป็น:
```bash
echo
echo "n8n is running — access at:"
echo "  http://<server-ip>:5678"
echo "  (ensure firewall/secgroup allows port 5678)"
```

**Step 2: Commit**

```bash
git add scripts/n8n-up.sh
git commit -m "docs: update n8n-up output for public access"
```

---

### Task 5 (optional): อัปเดต Caddyfile สำหรับ n8n

**Objective:** n8n public แล้ว → เอา `bind 127.0.0.1` ออกจาก n8n block ใน Caddyfile

**Files:**
- Modify: `compose/caddy/Caddyfile:19-29`

**Step 1: แก้ไข**

เปลี่ยน:
```caddy
# n8n admin — localhost bind only, never exposed publicly
:5678 {
	bind 127.0.0.1

	# Generate bcrypt hash for the password, then uncomment:
	# basic_auth {
	#   ${N8N_BASIC_AUTH_USER} <bcrypt-hash-here>
	# }

	reverse_proxy n8n:5678
}
```

เป็น:
```caddy
# n8n admin — public (firewall/secgroup controlled)
# Suggestion: proxy ผ่าน Caddy เพื่อ double-layer basic_auth
# :5678 {
#   reverse_proxy n8n:5678
#   basic_auth {
#     ${N8N_BASIC_AUTH_USER} <bcrypt-hash-here>
#   }
# }
```

**Step 2: Commit**

```bash
git add compose/caddy/Caddyfile
git commit -m "docs: disable Caddy n8n block — n8n exposed directly"
```

---

## ✅ หลังจากนี้ deploy ได้เลย

| สิ่งที่ต้องทำบน server |
|---|
| 1. `git clone` / `git pull` repo นี้ |
| 2. `cp .env.example .env` → กรอกค่าจริง |
| 3. `make preflight` |
| 4. `make ollama-up` → `make dify-up` → `make n8n-up` → `make proxy-up` |
| 5. ตั้ง firewall/secgroup ให้เปิดเฉพาะ port ที่ต้องการ (80/443, 5678) |
