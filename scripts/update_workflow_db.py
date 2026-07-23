#!/usr/bin/env python3
import subprocess
import json
import os

def run_psql(sql):
    cmd = ["ssh", "chatbot", f"docker exec -i n8n-postgres psql -U n8n -d n8n"]
    res = subprocess.run(cmd, input=sql, capture_output=True, text=True)
    print("STDOUT:", res.stdout)
    print("STDERR:", res.stderr)

if __name__ == "__main__":
    print("Deleting old workflow 01-github-dify-sync...")
    run_psql("DELETE FROM workflow_entity WHERE id IN ('pOOgvZjGpMmiaMe2', 'w1-github-dify-sync');")
    run_psql("SELECT id, name, active FROM workflow_entity;")
