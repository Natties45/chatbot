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

python3 /dev/stdin "$COMPOSE_FILE" << 'PYEOF'
import re, sys

with open(sys.argv[1]) as f:
    content = f.read()

# 1. Remove profiles from db_postgres
content = re.sub(r'^\s+profiles:\s*\[.*\]\s*$', '', content, flags=re.MULTILINE)

# 2. Fix volume paths: ./xxx/ -> ./compose/dify/xxx/
for d in ['nginx', 'envs', 'volumes', 'ssrf_proxy', 'certbot', 'elasticsearch', 'startupscripts', 'pgvector']:
    content = re.sub(r'\./' + d + '/', './compose/dify/' + d + '/', content)

# 3. Fix env_file paths
content = re.sub(r'path: \./envs/', 'path: ./compose/dify/envs/', content)

# 4. Remove nginx port mapping
content = re.sub(r'^\s+-\s+\${EXPOSE_NGINX_PORT:-80}:80\s*$', '', content, flags=re.MULTILINE)

# 5. Remove milvus/opensearch network refs
content = re.sub(r'^\s+-\s+milvus\s*$', '', content, flags=re.MULTILINE)
content = re.sub(r'^\s+-\s+opensearch-net\s*$', '', content, flags=re.MULTILINE)

# 6. Remove milvus service + opensearch-net network
content = re.sub(r'^  milvus:.*?(?=^[a-z])', '', content, flags=re.MULTILINE | re.DOTALL)
content = re.sub(r'^  opensearch-net:.*?(?=^[a-z])', '', content, flags=re.MULTILINE | re.DOTALL)

# 7. Remove oracle service + iris service (not needed)
content = re.sub(r'^  oracle:.*?(?=^[a-z])', '', content, flags=re.MULTILINE | re.DOTALL)
content = re.sub(r'^  iris:.*?(?=^[a-z])', '', content, flags=re.MULTILINE | re.DOTALL)

# 8. Remove empty networks: lines (left after milvus removal)
content = re.sub(r'^(\s+)networks:\s*\n(?!\s+\-)', '', content, flags=re.MULTILINE)

# 9. Fix oradata: under networks: -> remove (iris/oracle removed)
content = re.sub(r'^  oradata:.*', '', content, flags=re.MULTILINE)

# 10. Remove dify_es01_data volume
content = re.sub(r'^  dify_es01_data:.*', '', content, flags=re.MULTILINE)

# 11. Replace 'default' network with 'ols-chatbot'
content = content.replace('network: default', 'network: ols-chatbot')
content = re.sub(r'^\s+-\s+default\s*$', '      - ols-chatbot', content, flags=re.MULTILINE)

# 12. Add ols-chatbot network definition if not present
if 'ols-chatbot:\n    external:' not in content:
    # Insert after the LAST 'networks:' line (top-level networks section)
    last_net = content.rfind('\nnetworks:')
    if last_net > 0:
        insert_at = content.find('\n', last_net + 1) + 1
        content = content[:insert_at] + '  ols-chatbot:\n    driver: bridge\n' + content[insert_at:]

# 13. Ensure volumes section has entries (Dify needs these)
content = re.sub(r'^volumes:\s*$', 'volumes:\n  dify-data:\n    external: true\n  oradata:\n  pgvector_data:\n  storage:', content, flags=re.MULTILINE)

with open(sys.argv[1], 'w') as f:
    f.write(content)

print('✅ Dify compose patched for OLS deployment')
PYEOF
