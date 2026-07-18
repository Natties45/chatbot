.PHONY: preflight dify-up dify-down n8n-up n8n-down ollama-up ollama-down proxy-up backup restore status logs seed-ollama dify-fetch

SHELL := /bin/bash
ROOT := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

preflight:
	bash $(ROOT)/scripts/preflight.sh

dify-fetch:
	git clone --depth 1 --branch $$(grep DIFY_IMAGE_TAG $(ROOT)/.env | cut -d= -f2) https://github.com/langgenius/dify.git /tmp/dify-src
	cp /tmp/dify-src/docker/docker-compose.yaml $(ROOT)/compose/dify/docker-compose.yaml
	cp /tmp/dify-src/docker/.env.example $(ROOT)/.env.example.dify
	rm -rf /tmp/dify-src

dify-up:
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
	docker compose -f $(ROOT)/compose/docker-compose.yml -f $(ROOT)/compose/caddy/Caddyfile up -d

status:
	docker compose ls
	docker ps --filter network=ols-chatbot

logs:
	docker compose -f $(ROOT)/compose/docker-compose.yml logs -f

seed-ollama:
	docker exec ollama ollama pull $$(grep OLLAMA_EMBED_MODEL $(ROOT)/.env | cut -d= -f2)

backup:
	bash $(ROOT)/scripts/backup.sh

restore:
	bash $(ROOT)/scripts/restore.sh $(ARCHIVE)
