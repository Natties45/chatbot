#!/usr/bin/env python3
import subprocess

def main():
    sql = "SELECT table_name FROM information_schema.tables WHERE table_schema='public';"
    cmd = ["ssh", "chatbot", "docker", "exec", "-i", "dify-db_postgres-1", "psql", "-U", "postgres", "-d", "dify", "-t", "-A"]
    res = subprocess.run(cmd, input=sql, capture_output=True, text=True)
    tables = [t.strip() for t in res.stdout.splitlines() if t.strip()]
    print(f"Total Tables in Dify DB: {len(tables)}")
    print("Tables related to datasets/pipelines/process/rules:")
    for t in sorted(tables):
        if any(k in t for k in ["data", "pipe", "rule", "process", "segment", "doc"]):
            print(" -", t)

if __name__ == "__main__":
    main()
