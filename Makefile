.PHONY: preflight dify-fetch dify-patch dify-up dify-down n8n-up n8n-down ollama-up ollama-down proxy-up proxy-down backup restore status logs seed-ollama all-up all-down logs-dify logs-n8n logs-ollama

SHELL := /bin/bash
ROOT := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

preflight:
	bash $(ROOT)/scripts/preflight.sh

dify-fetch:
	git clone --depth 1 --branch $$(grep DIFY_IMAGE_TAG $(ROOT)/.env | cut -d= -f2- | sed 's/[[:space:]]*#.*//' | xargs) https://github.com/langgenius/dify.git /tmp/dify-src
	cp /tmp/dify-src/docker/docker-compose.yaml $(ROOT)/compose/dify/docker-compose.yaml
	cp /tmp/dify-src/docker/.env.example $(ROOT)/.env.example.dify
	cp -r /tmp/dify-src/docker/nginx $(ROOT)/compose/dify/nginx
	cp -r /tmp/dify-src/docker/envs $(ROOT)/compose/dify/envs
	cp -r /tmp/dify-src/docker/ssrf_proxy $(ROOT)/compose/dify/ssrf_proxy
	cp -r /tmp/dify-src/docker/pgvector $(ROOT)/compose/dify/pgvector
	cp -r /tmp/dify-src/docker/certbot $(ROOT)/compose/dify/certbot
	cp -r /tmp/dify-src/docker/volumes $(ROOT)/compose/dify/volumes
	cp -r /tmp/dify-src/docker/elasticsearch $(ROOT)/compose/dify/elasticsearch
	cp -r /tmp/dify-src/docker/startupscripts $(ROOT)/compose/dify/startupscripts
	rm -rf /tmp/dify-src

dify-patch: ## Apply OLS-specific patches to Dify vendored compose
	bash $(ROOT)/scripts/dify-patch-compose.sh

dify-up: dify-fetch dify-patch ## Fetch + patch + deploy Dify stack
	bash $(ROOT)/scripts/dify-up.sh

dify-down:
	docker compose -f $(ROOT)/compose/docker-compose.yml -f $(ROOT)/compose/dify/docker-compose.yaml down

n8n-up:
	bash $(ROOT)/scripts/n8n-up.sh

n8n-down:
	docker compose -f $(ROOT)/compose/docker-compose.yml -f $(ROOT)/compose/n8n/docker-compose.n8n.yml down

ollama-up:
	bash $(ROOT)/scripts/ollama-up.sh

ollama-down:
	docker compose -f $(ROOT)/compose/docker-compose.yml -f $(ROOT)/compose/ollama/docker-compose.ollama.yml down

proxy-up:
	docker compose -f $(ROOT)/compose/docker-compose.yml -f $(ROOT)/compose/caddy/docker-compose.caddy.yml up -d

proxy-down:
	docker compose -f $(ROOT)/compose/docker-compose.yml -f $(ROOT)/compose/caddy/docker-compose.caddy.yml down

status:
	docker compose ls
	docker ps --filter network=ols-chatbot

logs:
	docker compose -f $(ROOT)/compose/docker-compose.yml logs -f

seed-ollama:
	docker exec ollama ollama pull $$(grep OLLAMA_EMBED_MODEL $(ROOT)/.env | cut -d= -f2- | sed 's/[[:space:]]*#.*//' | xargs)

all-up:
	bash $(ROOT)/scripts/ollama-up.sh
	bash $(ROOT)/scripts/dify-up.sh
	bash $(ROOT)/scripts/n8n-up.sh
	docker compose -f $(ROOT)/compose/docker-compose.yml -f $(ROOT)/compose/caddy/docker-compose.caddy.yml up -d

all-down:
	docker compose -f $(ROOT)/compose/docker-compose.yml -f $(ROOT)/compose/n8n/docker-compose.n8n.yml down
	docker compose -f $(ROOT)/compose/docker-compose.yml -f $(ROOT)/compose/dify/docker-compose.yaml down || true
	docker compose -f $(ROOT)/compose/docker-compose.yml -f $(ROOT)/compose/ollama/docker-compose.ollama.yml down
	docker compose -f $(ROOT)/compose/docker-compose.yml -f $(ROOT)/compose/caddy/docker-compose.caddy.yml down

logs-dify:
	docker compose -f $(ROOT)/compose/docker-compose.yml -f $(ROOT)/compose/dify/docker-compose.yaml logs -f

logs-n8n:
	docker compose -f $(ROOT)/compose/docker-compose.yml -f $(ROOT)/compose/n8n/docker-compose.n8n.yml logs -f

logs-ollama:
	docker compose -f $(ROOT)/compose/docker-compose.yml -f $(ROOT)/compose/ollama/docker-compose.ollama.yml logs -f

backup:
	bash $(ROOT)/scripts/backup.sh

restore:
	bash $(ROOT)/scripts/restore.sh $(ARCHIVE)
