#!/usr/bin/env bash
# Apply OLS-specific patches to Dify vendored compose
# Run after `make dify-fetch`, before `make dify-up`
set -euo pipefail

COMPOSE_FILE="compose/dify/docker-compose.yaml"

if [ ! -f "$COMPOSE_FILE" ]; then
  echo "❌ $COMPOSE_FILE not found. Run 'make dify-fetch' first."
  exit 1
fi

echo "🔧 Patching Dify compose for OLS deployment..."

# 1. Remove profiles from db_postgres (always needed)
sed -i '/profiles:/d' "$COMPOSE_FILE"

# 2. Fix volume paths: ./xxx/ → ./compose/dify/xxx/
for dir in nginx envs volumes ssrf_proxy certbot elasticsearch startupscripts pgvector; do
  sed -i "s|\\./$dir/|./compose/dify/$dir/|g" "$COMPOSE_FILE"
done

# 3. Fix env_file paths: ./envs/ → ./compose/dify/envs/
sed -i 's|path: \./envs/|path: ./compose/dify/envs/|g' "$COMPOSE_FILE"

# 4. Remove nginx port mapping (Caddy handles port 80)
sed -i '/EXPOSE_NGINX_PORT/d' "$COMPOSE_FILE"

# 5. Remove milvus/opensearch network refs from service network lists
sed -i '/- milvus/d; /- opensearch-net/d' "$COMPOSE_FILE"

# 6. Remove milvus/opensearch network definitions
sed -i '/^  milvus:/,/^[a-z]/d; /^  opensearch-net:/,/^[a-z]/d' "$COMPOSE_FILE"

# 6b. Remove empty networks: lines left behind (etcd, minio, milvus had networks: with only milvus ref)
sed -i '/^    networks:$/d' "$COMPOSE_FILE"

# 7. Remove dify_es01_data volume
sed -i '/dify_es01_data:/d' "$COMPOSE_FILE"

# 8. Replace 'default' network with 'ols-chatbot'
sed -i 's/network: default/network: ols-chatbot/g; s/    - default/    - ols-chatbot/g' "$COMPOSE_FILE"

# 9. Add dify-data external volume
sed -i '/^volumes:/a\  dify-data:\n    external: true' "$COMPOSE_FILE"

echo "✅ Dify compose patched for OLS deployment"
