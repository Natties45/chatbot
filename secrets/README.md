# Secrets policy — DO NOT commit real secrets to this repository

Real secrets must never live in this folder or anywhere under `chatbot/`.

## Where secrets belong

- **`.env` at repo root** (gitignored) — runtime environment variables
- **n8n credential store** (encrypted in n8n database) — workflow credentials
- **Dify Model Provider UI** — LLM / embeddings API keys
- **Password manager / vault** — long-term storage

## Required credentials

Create these in the n8n credential store (UI) — not as files:

| Credential | Purpose |
|---|---|
| GitHub SSH | n8n git pull `git@github.com:Natties45/selfservice-repo.git` |
| Dify Dataset API | Upsert documents into Dify Knowledge Base |
| LINE Notify (or SMTP) | Alert + report notifications to @Natties45 |

Create these in the Dify Model Provider UI:

| Provider | Model | Key source |
|---|---|---|
| Ollama (Cloud Pro) | qwen2.5 (LLM) | Ollama Cloud Pro API key |
| Ollama (local) | bge-m3 (embeddings) | no key — local Docker |

## Forbidden

- Never commit `.env`, `*.env` (except `*.env.example`), API keys, tokens, passwords,
  private keys, or bcrypt hashes.
- Never paste credentials into workflow JSON exported to this repo.
- Workflow JSON files under `n8n/workflows/` must reference credentials by name only.