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
  sed -i "s|\./$dir/|./compose/dify/$dir/|g" "$COMPOSE_FILE"
done

# 3. Fix env_file paths: ./envs/ → ./compose/dify/envs/
sed -i 's|path: \./envs/|path: ./compose/dify/envs/|g' "$COMPOSE_FILE"

# 4. Remove nginx port mapping (Caddy handles port 80)
sed -i '/EXPOSE_NGINX_PORT/d' "$COMPOSE_FILE"

# 5. Remove milvus/opensearch network refs from service network lists
sed -i '/- milvus/d; /- opensearch-net/d' "$COMPOSE_FILE"

# 6. Remove milvus/opensearch service + network definitions
sed -i '/^  milvus:/,/^[a-z]/d; /^  opensearch-net:/,/^[a-z]/d' "$COMPOSE_FILE"

# 6b. Remove empty networks: lines left behind (etcd, minio had networks: with only milvus ref)
python3 -c "
import re, sys
with open(sys.argv[1]) as f:
    lines = f.readlines()
result = []
i = 0
while i < len(lines):
    line = lines[i]
    m = re.match(r'^(\s+)networks:\s*$', line)
    if m:
        indent = m.group(1)
        j = i + 1
        while j < len(lines) and lines[j].strip() == '':
            j += 1
        if j < len(lines) and lines[j].startswith(indent + '  - '):
            result.append(line)
    else:
        result.append(line)
    i += 1
with open(sys.argv[1], 'w') as f:
    f.writelines(result)
" "$COMPOSE_FILE"

# 7. Remove dify_es01_data volume
sed -i '/dify_es01_data:/d' "$COMPOSE_FILE"

# 7b. Remove oracle service (not needed) and fix oradata volume placement
sed -i '/^  oracle:/,/^[a-z]/d' "$COMPOSE_FILE"
# oradata is defined under networks: instead of volumes: — move it
sed -i 's/^  oradata:/# oradata: (moved to volumes)/' "$COMPOSE_FILE"
# Add oradata to volumes section
sed -i '/^volumes:/a\  oradata:' "$COMPOSE_FILE"

# 8. Replace 'default' network with 'ols-chatbot'
sed -i 's/network: default/network: ols-chatbot/g; s/    - default/    - ols-chatbot/g' "$COMPOSE_FILE"

# 8b. Add ols-chatbot network definition (services reference it but it's not defined yet)
python3 -c "
import sys
with open(sys.argv[1]) as f:
    content = f.read()
# Add ols-chatbot network after the last network definition
marker = 'networks:'
last_net = content.rfind(marker)
if last_net > 0:
    insert_at = content.find('\n', last_net)
    insert_at = content.find('\n', insert_at + 1)  # skip first line
    insert_at = content.find('\n', insert_at + 1)  # skip second line
    insert_at = content.find('\n', insert_at + 1)  # skip third line
    # Find where the networks section ends (next top-level key or end of file)
    rest = content[insert_at+1:]
    # Insert ols-chatbot before the last network entry
    content = content[:insert_at+1] + '  ols-chatbot:\n    external: true\n' + content[insert_at+1:]
with open(sys.argv[1], 'w') as f:
    f.write(content)
" "$COMPOSE_FILE"

# 9. Add dify-data external volume
sed -i '/^volumes:/a\  dify-data:\n    external: true' "$COMPOSE_FILE"

echo "✅ Dify compose patched for OLS deployment"
