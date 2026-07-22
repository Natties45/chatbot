# Chatbot Activation Plan — LLM + Knowledge Base + Apps

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.

**Goal:** Configure LLM + embedding in Dify, create 3 Knowledge Bases, create 3 Chatbot Apps, test chatbot end-to-end.

**Architecture:** Dify Web UI (`http://203.154.16.159:80`) is already deployed and loginable. We need to: (1) add Ollama Cloud Pro as LLM provider (cheapest model), (2) add local Ollama as embedding provider (bge-m3), (3) create 3 empty Knowledge Bases, (4) create 3 Chatbot Apps with system prompts, (5) test via Dify preview.

**Tech Stack:** Dify 1.16.0, Ollama Cloud Pro API, bge-m3 (local), pgvector

**Key constraint:** User wants cheapest LLM model. Use `qwen2.5:7b` (or smaller if available). Do NOT use expensive models like qwen2.5:72b or llama3.1:70b.

---

## Current State

- ✅ Dify Web UI running at `http://203.154.16.159:80` (login: `admin@ols-chatbot.local` / `F9NNjqvyRakN6m1X`)
- ✅ Dify API healthy (`localhost:5001/health` → 200)
- ✅ pgvector running (vector store)
- ✅ Local Ollama running with `bge-m3` model (`ollama:11434`)
- ✅ n8n running at `http://203.154.16.159:5678`
- ✅ `OLLAMA_CLOUD_API_KEY` in `secrets/.env`
- ❌ No LLM provider configured in Dify
- ❌ No embedding provider configured in Dify
- ❌ No Knowledge Bases created
- ❌ No Chatbot Apps created
- ⚠️ Prompt files have encoding bugs (garbled Thai characters)

---

## Task 1: Fix garbled characters in prompt files

**Objective:** Clean up encoding artifacts in system prompt files before using them in Dify.

**Files:**
- Modify: `dify/prompts/noc-system-prompt.txt` — fix `-้ Be concise` → `- Be concise`, `##ไ language` → `## Language`
- Modify: `dify/prompts/operation-system-prompt.txt` — fix `Trou้Cleshooting` → `Troubleshooting`

**Step 1: Fix NOC prompt**

Invoke through the `patch` tool on `dify/prompts/noc-system-prompt.txt`:
- Replace `-้ Be concise` with `- Be concise`
- Replace `##ไ language` with `## Language`

**Step 2: Fix Operation prompt**

Invoke through the `patch` tool on `dify/prompts/operation-system-prompt.txt`:
- Replace `Trou้Cleshooting` with `Troubleshooting`

**Step 3: Verify**

Invoke through the `terminal` tool:
```bash
cd /c/Users/natti/OneDrive/Documents/natties45/chatbot
grep -n '้' dify/prompts/*.txt
# Expected: no matches (all garbled chars removed)
```

**Step 4: Commit**

```bash
git add dify/prompts/noc-system-prompt.txt dify/prompts/operation-system-prompt.txt
git commit -m "fix: garbled characters in system prompts"
```

---

## Task 2: Configure Ollama Cloud Pro as LLM provider in Dify

**Objective:** Add Ollama Cloud Pro API as LLM provider in Dify, using the cheapest available model.

**Files:** None (Dify UI only — all actions via `browser_navigate` + `browser_click` + `browser_type`)

**Step 1: Navigate to Dify Model Provider settings**

Invoke through `browser_navigate`:
- URL: `http://203.154.16.159:80/`
- Login if needed: `admin@ols-chatbot.local` / `F9NNjqvyRakN6m1X`
- Navigate to: Settings → Model Providers (or `http://203.154.16.159:80/settings?category=model`)

**Step 2: Find Ollama provider**

- Look for "Ollama" in the provider list
- Click "Add Model" or "Configure"

**Step 3: Configure LLM model**

Fill in:
- **Model Type:** LLM
- **Model Name:** `qwen2.5:7b` (cheapest with Thai support — ~$0.001/1K tokens on Cloud Pro)
- **Provider:** Ollama
- **API Key:** value from `secrets/.env` → `OLLAMA_CLOUD_API_KEY`
- **Base URL:** `https://cloud.ollama.ai` (or the endpoint shown in Ollama Cloud dashboard)
- **Context Size:** 4096 (default)
- **Max Tokens:** 2048

**Step 4: Test model**

- Click "Test" or "Save" — Dify will send a test request
- Expected: model returns a response, status shows "Available" or green checkmark

**Step 5: Set as system default model**

- Go to Settings → System Model Settings
- Set default LLM to `qwen2.5:7b`

**Verification:**

Invoke through `browser_navigate`:
- Go to `http://203.154.16.159:80/settings?category=model`
- Expected: Ollama provider shows as "Configured" with `qwen2.5:7b` listed

---

## Task 3: Configure local Ollama as embedding provider in Dify

**Objective:** Add local Ollama (bge-m3) as embedding provider for Knowledge Bases.

**Files:** None (Dify UI only)

**Step 1: Navigate to Model Provider settings**

- Same as Task 2 Step 1

**Step 2: Configure embedding model**

In the Ollama provider configuration:
- **Model Type:** Embedding (Text Embedding)
- **Model Name:** `bge-m3`
- **Base URL:** `http://ollama:11434` (internal Docker network name)
- **API Key:** (leave empty — local Ollama doesn't require auth)
- **No API key needed** — local Ollama is open

**Step 3: Test embedding model**

- Click "Test" — Dify will send a test embedding request
- Expected: model returns a vector, status shows "Available"

**Verification:**

Invoke through `browser_navigate`:
- Go to `http://203.154.16.159:80/settings?category=model`
- Expected: Ollama provider shows both `qwen2.5:7b` (LLM) and `bge-m3` (Embedding)

---

## Task 4: Create Knowledge Base — kb-operation

**Objective:** Create the first Knowledge Base for Operation role.

**Files:** None (Dify UI only)

**Step 1: Navigate to Knowledge**

Invoke through `browser_navigate`:
- URL: `http://203.154.16.159:80/knowledge`

**Step 2: Create Knowledge Base**

- Click "Create Knowledge" → "Create an Empty Knowledge Base"
- **Name:** `kb-operation`
- **Description:** `Operation team KB — runbooks, incident response, architecture docs`
- Click "Next"

**Step 3: Configure embedding**

- **Embedding Model:** `bge-m3` (from Ollama provider configured in Task 3)
- **Index Method:** High Quality (uses vector + keyword)
- **Permission:** Only Me
- Click "Save"

**Step 4: Get Dataset ID + API Key**

- After creation, go to Knowledge → click `kb-operation` → Settings (gear icon)
- Find **Dataset ID** (UUID format) — copy it
- Find **API Key** — click "API" button → copy the API key
- Save both values (will be added to `secrets/.env` in Task 7)

**Verification:**

- Knowledge list should show `kb-operation` with 0 documents
- Status: "Ready" or "Active"

---

## Task 5: Create Knowledge Base — kb-noc

**Objective:** Create the second Knowledge Base for NOC role.

**Files:** None (Dify UI only)

**Step 1: Create Knowledge Base**

Same as Task 4 but:
- **Name:** `kb-noc`
- **Description:** `NOC team KB — monitoring procedures, escalation policies, internal runbooks (filtered)`
- **Embedding Model:** `bge-m3`
- **Index Method:** High Quality
- **Permission:** Only Me

**Step 2: Get Dataset ID + API Key**

- Copy Dataset ID and API Key for `kb-noc`

---

## Task 6: Create Knowledge Base — kb-customer-faq

**Objective:** Create the third Knowledge Base for Customer role.

**Files:** None (Dify UI only)

**Step 1: Create Knowledge Base**

Same as Task 4 but:
- **Name:** `kb-customer-faq`
- **Description:** `Customer FAQ KB — service descriptions, pricing, common issues, contact info`
- **Embedding Model:** `bge-m3`
- **Index Method:** High Quality
- **Permission:** Only Me

**Step 2: Get Dataset ID + API Key**

- Copy Dataset ID and API Key for `kb-customer-faq`

---

## Task 7: Update secrets/.env with Dataset IDs + API Keys

**Objective:** Record the Dataset IDs and API keys from Tasks 4-6 into `secrets/.env`.

**Files:**
- Modify: `secrets/.env` (gitignored)

**Step 1: Append to secrets/.env**

Invoke through the `terminal` tool (or `patch` tool):

```bash
# Append to secrets/.env (values from Dify UI)
cat >> /c/Users/natti/OneDrive/Documents/natties45/chatbot/secrets/.env << 'EOF'

# ─── Dify Dataset IDs + API Keys (from Dify UI) ───
DIFY_OPERATION_DATASET_ID=<uuid-from-task-4>
DIFY_OPERATION_API_KEY=<api-key-from-task-4>
DIFY_NOC_DATASET_ID=<uuid-from-task-5>
DIFY_NOC_API_KEY=<api-key-from-task-5>
DIFY_CUSTOMER_DATASET_ID=<uuid-from-task-6>
DIFY_CUSTOMER_API_KEY=<api-key-from-task-6>
EOF
```

Replace the `<...>` placeholders with actual values from Dify UI.

**Step 2: Verify**

```bash
grep -c 'DATASET_ID' /c/Users/natti/OneDrive/Documents/natties45/chatbot/secrets/.env
# Expected: 3
```

---

## Task 8: Create Chatbot App — Operation Assistant

**Objective:** Create the first chatbot app in Dify with the Operation system prompt.

**Files:** None (Dify UI only)

**Step 1: Create new app**

Invoke through `browser_navigate`:
- Go to `http://203.154.16.159:80/apps`
- Click "Create Blank App" → "Chatbot"

**Step 2: Configure app**

- **Name:** `Operation Assistant`
- **Description:** `OLS Operation chatbot — runbooks, incident response, architecture docs`
- Click "Create"

**Step 3: Set system prompt**

- Go to app → "Prompt Settings" or "Orchestration"
- Paste content from `dify/prompts/operation-system-prompt.txt`
- Set **LLM:** `qwen2.5:7b`
- Set **Temperature:** 0.3 (precise, factual)
- Set **Max Tokens:** 2048

**Step 4: Attach Knowledge Base**

- In the "Context" section, click "Add"
- Select `kb-operation`
- Save

**Step 5: Test in preview**

- Click "Preview" (top right)
- Type: "สวัสดี คุณคือใคร?"
- Expected: model responds in Thai, identifying as OLS Operation Assistant
- Type: "มี runbook อะไรบ้าง?"
- Expected: model searches KB (will say no docs found since KB is empty)

**Step 6: Export app config (optional)**

- Go to app → Settings → Export
- Save as `dify/apps/operation-app.json`

---

## Task 9: Create Chatbot App — NOC Assistant

**Objective:** Create the second chatbot app with NOC system prompt.

**Files:** None (Dify UI only)

**Step 1-5:** Same as Task 8 but:
- **Name:** `NOC Assistant`
- **Description:** `OLS NOC chatbot — monitoring procedures, escalation, restricted categories`
- **System prompt:** paste from `dify/prompts/noc-system-prompt.txt`
- **Knowledge Base:** `kb-noc`
- **Temperature:** 0.2 (more precise, policy-driven)

**Step 6: Test NOC policy filter**

- Type: "เงินเดือนของพนักงานเท่าไหร่?"
- Expected: "ขออภัย หัวข้อนี้ไม่อยู่ในขอบเขตที่ฉันสามารถตอบได้ กรุณาติดต่อแผนกที่เกี่ยวข้อง"

---

## Task 10: Create Chatbot App — Customer Assistant

**Objective:** Create the third chatbot app with Customer system prompt.

**Files:** None (Dify UI only)

**Step 1-5:** Same as Task 8 but:
- **Name:** `Customer Assistant`
- **Description:** `OLS Customer chatbot — FAQs, services, pricing`
- **System prompt:** paste from `dify/prompts/customer-system-prompt.txt`
- **Knowledge Base:** `kb-customer-faq`
- **Temperature:** 0.5 (friendlier, more natural)

**Step 6: Test customer tone**

- Type: "บริการมีอะไรบ้าง?"
- Expected: friendly response, may say KB is empty

---

## Task 11: End-to-end verification

**Objective:** Verify all 3 apps work correctly.

**Files:** None (Dify UI only)

**Step 1: Verify Operation app**

- Open `Operation Assistant` app → Preview
- Test: "คุณใช้ model อะไร?" → should respond
- Test: "หาไม่เจอใน KB" → should suggest contacting NOC

**Step 2: Verify NOC app**

- Open `NOC Assistant` app → Preview
- Test: restricted category question → should refuse
- Test: normal question → should respond or say KB is empty

**Step 3: Verify Customer app**

- Open `Customer Assistant` app → Preview
- Test: "ราคาเท่าไหร่?" → should say KB is empty / suggest contacting support
- Test: greeting → should be friendly

**Step 4: Commit app configs**

If app JSON was exported:
```bash
cd /c/Users/natti/OneDrive/Documents/natties45/chatbot
git add dify/apps/
git commit -m "feat: export 3 chatbot app configs from Dify"
```

---

## Risks & Open Questions

- **Ollama Cloud Pro Base URL:** The exact endpoint URL for Ollama Cloud Pro API is unknown. Check `https://cloud.ollama.ai` or the Ollama Cloud dashboard for the correct API endpoint. If the URL is different, adjust Task 2 Step 3.
- **Model availability:** `qwen2.5:7b` may not be available on Ollama Cloud Pro. Check available models first. Alternatives (cheapest first): `qwen2.5:3b`, `llama3.2:3b`, `phi-3.5:mini`.
- **Dify GitHub Plugin:** If the user wants to import data into KBs without n8n, they can install the GitHub plugin from Dify Marketplace. This is fine for initial testing but won't support 3-branch routing or NOC policy filtering.
- **n8n deferred:** Per user decision, n8n workflow import is deferred. Data will be manually uploaded to KBs for now.
- **selfservice-repo:** No data exists yet in the GitHub repo. KBs will be empty until data is added. This is expected — we're testing the pipeline, not the content.
- **Plugin daemon error:** The "Failed to request plugin daemon" toast may still appear. It's cosmetic and doesn't affect KB/app functionality.
