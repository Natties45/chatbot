#!/usr/bin/env bash
# Apply OLS-specific patches to Dify vendored compose
# Run after `make dify-fetch`, before `make dify-up`
# The compose file is at compose/dify/docker-compose.yaml
# All relative paths (./nginx/, ./envs/) resolve relative to compose/dify/ — correct!
set -euo pipefail

COMPOSE_FILE="compose/dify/docker-compose.yaml"

if [ ! -f "$COMPOSE_FILE" ]; then
  echo "❌ $COMPOSE_FILE not found. Run 'make dify-fetch' first."
  exit 1
fi

echo "🔧 Patching Dify compose for OLS deployment..."

python3 -c "
import re, sys

with open(sys.argv[1]) as f:
    content = f.read()

# 1. Remove profiles from db_postgres
content = re.sub(r'^\s+profiles:\s*\[.*\]\s*$', '', content, flags=re.MULTILINE)

# 2-3. Volume/env_file paths are correct relative to compose/dify/ — no change needed

# 4. Remove nginx port mapping
content = re.sub(r'^\s+-\s+\${EXPOSE_NGINX_PORT:-80}:80\s*$', '', content, flags=re.MULTILINE)

# 5. Remove milvus/opensearch network refs
content = re.sub(r'^\s+-\s+milvus\s*$', '', content, flags=re.MULTILINE)
content = re.sub(r'^\s+-\s+opensearch-net\s*$', '', content, flags=re.MULTILINE)

# 6. Remove milvus service + opensearch-net network
content = re.sub(r'^  milvus:.*?(?=^[a-z])', '', content, flags=re.MULTILINE | re.DOTALL)
content = re.sub(r'^  opensearch-net:.*?(?=^[a-z])', '', content, flags=re.MULTILINE | re.DOTALL)

# 7. Remove oracle + iris services (not needed)
content = re.sub(r'^  oracle:.*?(?=^[a-z])', '', content, flags=re.MULTILINE | re.DOTALL)
content = re.sub(r'^  iris:.*?(?=^[a-z])', '', content, flags=re.MULTILINE | re.DOTALL)

# 8. Remove empty networks: lines (left after milvus removal)
content = re.sub(r'^(\s+)networks:\s*\n(?!\s+\-)', '', content, flags=re.MULTILINE)

# 9. Remove oradata (was under networks: in upstream)
content = re.sub(r'^  oradata:.*', '', content, flags=re.MULTILINE)

# 10. Remove dify_es01_data volume
content = re.sub(r'^  dify_es01_data:.*', '', content, flags=re.MULTILINE)

# 11. Replace 'default' network with 'ols-chatbot'
content = content.replace('network: default', 'network: ols-chatbot')
content = re.sub(r'^\s+-\s+default\s*$', '      - ols-chatbot', content, flags=re.MULTILINE)

# 12. Add ols-chatbot network definition
if 'ols-chatbot:\n    driver:' not in content:
    last_net = content.rfind('\nnetworks:')
    if last_net > 0:
        insert_at = content.find('\n', last_net + 1) + 1
        content = content[:insert_at] + '  ols-chatbot:\n    driver: bridge\n' + content[insert_at:]

# 13. Ensure volumes section has entries
content = re.sub(r'^volumes:\s*$', 'volumes:\n  dify-data:\n    external: true\n  oradata:\n  pgvector_data:\n  storage:', content, flags=re.MULTILINE)

# 14. Fix nginx entrypoint: cp needs -r for directory
content = content.replace(
    'cp /docker-entrypoint-mount.sh /docker-entrypoint.sh',
    'cp -r /docker-entrypoint-mount.sh /docker-entrypoint.sh'
)

with open(sys.argv[1], 'w') as f:
    f.write(content)

print('✅ Dify compose patched for OLS deployment')
" "$COMPOSE_FILE"
