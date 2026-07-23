#!/usr/bin/env python3
import json
import subprocess

with open('n8n/workflows/01-github-dify-sync.json', 'r', encoding='utf-8') as f:
    wf = json.load(f)

nodes_str = json.dumps(wf['nodes'])
escaped_nodes = nodes_str.replace("'", "''")

sql = f"UPDATE workflow_entity SET nodes = '{escaped_nodes}' WHERE id IN ('w1-github-dify-sync', 'pOOgvZjGpMmiaMe2');\n"

p = subprocess.run(
    ["ssh", "chatbot", "docker exec -i n8n-postgres psql -U n8n -d n8n"],
    input=sql,
    capture_output=True,
    text=True
)
print("STDOUT:", p.stdout)
print("STDERR:", p.stderr)

