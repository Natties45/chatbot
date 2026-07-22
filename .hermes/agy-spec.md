# Phase 0 — Pre-flight & Server Setup

## Objective
SSH into `chatbot` (root@chatbot1) and prepare the server for OLS Chatbot deployment.

## Steps

### 1. SSH and verify Docker images
```bash
ssh chatbot 'docker image list'
```
Expected: 8 images already pulled (caddy, dify-api, dify-web, n8n, ollama, postgres:15, postgres:16, redis)

### 2. Clone the chatbot repo
```bash
ssh chatbot 'cd /opt && git clone git@github.com:Natties45/chatbot.git ols-chatbot && cd ols-chatbot && ls -la'
```

### 3. Copy .env.example → .env
```bash
ssh chatbot 'cd /opt/ols-chatbot && cp .env.example .env'
```

### 4. Generate secrets and fill .env
Run on server:
```bash
ssh chatbot 'cd /opt/ols-chatbot && \
  N8N_ENCRYPTION_KEY=$(openssl rand -hex 32) && \
  DIFY_SECRET_KEY=$(openssl rand -hex 48) && \
  N8N_DB_PASSWORD=$(openssl rand -hex 16) && \
  DIFY_INIT_PASSWORD=$(openssl rand -hex 12) && \
  N8N_BASIC_AUTH_PASSWORD=$(openssl rand -hex 12) && \
  SERVER_IP=$(curl -s ifconfig.me) && \
  sed -i "s|N8N_HOST=<server-ip-or-domain>|N8N_HOST=$SERVER_IP|" .env && \
  sed -i "s|WEBHOOK_URL=http://<server-ip-or-domain>:5678/|WEBHOOK_URL=http://$SERVER_IP:5678/|" .env && \
  sed -i "s|N8N_ENCRYPTION_KEY=  #|N8N_ENCRYPTION_KEY=$N8N_ENCRYPTION_KEY|" .env && \
  sed -i "s|N8N_BASIC_AUTH_PASSWORD=  #|N8N_BASIC_AUTH_PASSWORD=$N8N_BASIC_AUTH_PASSWORD|" .env && \
  sed -i "s|N8N_DB_PASSWORD=  #|N8N_DB_PASSWORD=$N8N_DB_PASSWORD|" .env && \
  sed -i "s|DIFY_SECRET_KEY=  #|DIFY_SECRET_KEY=$DIFY_SECRET_KEY|" .env && \
  sed -i "s|DIFY_INIT_PASSWORD=  #|DIFY_INIT_PASSWORD=$DIFY_INIT_PASSWORD|" .env && \
  echo "Server IP: $SERVER_IP" && \
  echo "Dify admin password: $DIFY_INIT_PASSWORD" && \
  echo "n8n basic auth password: $N8N_BASIC_AUTH_PASSWORD"'
```

### 5. Run preflight
```bash
ssh chatbot 'cd /opt/ols-chatbot && bash scripts/preflight.sh'
```
Expected: All checks PASS

### 6. Start Ollama (Phase 1)
```bash
ssh chatbot 'cd /opt/ols-chatbot && bash scripts/stack.sh up ollama'
```
Expected: Ollama container running, bge-m3 model pulled, embeddings test returns JSON

### 7. Start Dify (Phase 2)
```bash
ssh chatbot 'cd /opt/ols-chatbot && bash scripts/stack.sh up dify'
```
Expected: Dify containers running, compose fetched from GitHub

### 8. Start n8n (Phase 3)
```bash
ssh chatbot 'cd /opt/ols-chatbot && bash scripts/stack.sh up n8n'
```
Expected: n8n + n8n-postgres running

### 9. Start Caddy (Phase 3)
```bash
ssh chatbot 'cd /opt/ols-chatbot && bash scripts/stack.sh up caddy'
```
Expected: Caddy running on port 80/443/5678

### 10. Final status check
```bash
ssh chatbot 'cd /opt/ols-chatbot && bash scripts/stack.sh status'
```

## Constraints
- Do NOT commit anything
- Do NOT modify files outside /opt/ols-chatbot/
- If any step fails, STOP and report the error
- Report the Server IP and all generated passwords at the end
