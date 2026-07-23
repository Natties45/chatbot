#!/usr/bin/env python3
import subprocess

def main():
    sql = """
    SELECT d.name, d.id as dataset_id, d.runtime_mode, r.mode as rule_mode, r.rules 
    FROM datasets d
    LEFT JOIN dataset_process_rules r ON d.id = r.dataset_id;
    """
    cmd = ["ssh", "chatbot", "docker", "exec", "-i", "dify-db_postgres-1", "psql", "-U", "postgres", "-d", "dify"]
    res = subprocess.run(cmd, input=sql, capture_output=True, text=True)
    print("DATASET PROCESS RULES:")
    print(res.stdout)

if __name__ == "__main__":
    main()
