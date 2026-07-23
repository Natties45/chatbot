#!/usr/bin/env python3
import subprocess

def main():
    sql = "SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND table_name LIKE '%provider%';"
    cmd = ["ssh", "chatbot", "docker", "exec", "-i", "dify-db_postgres-1", "psql", "-U", "postgres", "-d", "dify"]
    res = subprocess.run(cmd, input=sql, capture_output=True, text=True)
    print("Tables matching '%provider%':")
    print(res.stdout)

if __name__ == "__main__":
    main()
