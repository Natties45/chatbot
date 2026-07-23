#!/usr/bin/env python3
import json
import subprocess

wf = json.load(open('/tmp/01-github-dify-sync.json'))
nodes_json = json.dumps(wf['nodes'])
escaped_nodes = nodes_json.replace("'", "''")

sql = "UPDATE workflow_entity SET nodes = '" + escaped_nodes + "' WHERE id IN ('w1-github-dify-sync', 'pOOgvZjGpMmiaMe2');"

res = subprocess.run(
    ["docker", "exec", "-i", "n8n-postgres", "psql", "-U", "n8n", "-d", "n8n", "-c", sql],
    capture_output=True,
    text=True
)
print("STDOUT:", res.stdout)
print("STDERR:", res.stderr)
