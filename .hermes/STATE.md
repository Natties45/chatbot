# HERMES AGENT STATE

Current Phase: Ollama deployed, Model Provider & KBs require fix (raw SQL approach failed verification)
Server IP: 203.154.16.45
SSH Target: chatbot

## Active Services
- Dify (Port 80): Up (Admin: admin@ols-chatbot.local)
- n8n (Port 5678): Up
- Ollama (Port 11434 internal): Up on dify_default, bge-m3 pulled

## ✅ Verified
- Ollama container healthy, bge-m3 model pulled
- Cross-container: dify-api-1 → http://ollama:11434/api/embeddings = 1024-dim ✅
- `.env` updated on both local and server (dataset IDs may change after fix)

## ❌ Needs Fix — Created via raw SQL, NOT working
- `provider_credentials.encrypted_config` is plaintext JSON (not encrypted)
- `datasets.index_struct` is NULL (no vector collection initialized)
- `dataset_keyword_tables` missing (hybrid search broken)
- Must recreate through Dify service layer or Console API

## ⚠️ Other Issues
- OLLAMA_CLOUD_API_KEY exposed in chat history — must rotate
- Git push broken (no SSH key on server, local HTTPS times out)
