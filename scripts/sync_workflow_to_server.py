#!/usr/bin/env python3
"""
Sync n8n workflow JSON to n8n database securely via environment variables or docker exec.
"""
import os
import json
import subprocess

WORKFLOW_FILE = os.getenv("WORKFLOW_FILE", "n8n/workflows/n8n-kb-sync-workflow.json")

if not os.path.exists(WORKFLOW_FILE):
    print(f"[ERROR] Workflow file '{WORKFLOW_FILE}' not found.")
    exit(1)

with open(WORKFLOW_FILE, "r", encoding="utf-8") as f:
    wf_data = json.load(f)

nodes_str = json.dumps(wf_data.get("nodes", []))

# Use docker exec psql directly to avoid hardcoding database passwords in script files
sql_query = f"UPDATE workflow_entity SET nodes = %s WHERE id IN ('w1-github-dify-sync', 'pOOgvZjGpMmiaMe2');"

print(f"Syncing workflow '{WORKFLOW_FILE}' to n8n postgres database...")

try:
    # Safely pass SQL and parameters via python execution inside n8n-postgres container or host
    cmd = [
        "docker", "exec", "-i", "n8n-postgres",
        "psql", "-U", "n8n", "-d", "n8n",
        "-c", f"UPDATE workflow_entity SET nodes = '{nodes_str.replace(\"'\", \"''\")}' WHERE id IN ('w1-github-dify-sync', 'pOOgvZjGpMmiaMe2');"
    ]
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode == 0:
        print("[SUCCESS] Workflow updated in n8n database.")
    else:
        print(f"[WARN] Postgres update notice: {res.stderr.strip()}")
except Exception as e:
    print(f"[ERROR] Failed to sync workflow: {e}")
