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

dify-patch: ## Apply OLS-specific overrides (compose override, not sed)
	@echo "OLS overrides are in compose/dify/docker-compose.override.yml — no sed patching needed"

dify-up: dify-fetch ## Fetch + deploy Dify stack
	bash $(ROOT)/scripts/stack.sh up dify

dify-down:
	bash $(ROOT)/scripts/stack.sh down dify

n8n-up:
	bash $(ROOT)/scripts/stack.sh up n8n

n8n-down:
	bash $(ROOT)/scripts/stack.sh down n8n

ollama-up:
	bash $(ROOT)/scripts/stack.sh up ollama

ollama-down:
	bash $(ROOT)/scripts/stack.sh down ollama

proxy-up:
	bash $(ROOT)/scripts/stack.sh up caddy

proxy-down:
	bash $(ROOT)/scripts/stack.sh down caddy

status:
	bash $(ROOT)/scripts/stack.sh status

logs:
	docker compose -f $(ROOT)/compose/docker-compose.yml logs -f

seed-ollama:
	docker exec ollama ollama pull $$(grep OLLAMA_EMBED_MODEL $(ROOT)/.env | cut -d= -f2- | sed 's/[[:space:]]*#.*//' | xargs)

all-up:
	bash $(ROOT)/scripts/stack.sh up ollama
	bash $(ROOT)/scripts/stack.sh up dify
	bash $(ROOT)/scripts/stack.sh up n8n
	bash $(ROOT)/scripts/stack.sh up caddy

all-down:
	bash $(ROOT)/scripts/stack.sh down n8n
	bash $(ROOT)/scripts/stack.sh down dify || true
	bash $(ROOT)/scripts/stack.sh down ollama
	bash $(ROOT)/scripts/stack.sh down caddy

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
