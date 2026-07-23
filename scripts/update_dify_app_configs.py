#!/usr/bin/env python3
import subprocess
import json

def run_sql(sql):
    cmd = ["ssh", "chatbot", "docker", "exec", "-i", "dify-db_postgres-1", "psql", "-U", "postgres", "-d", "dify", "-c", sql]
    res = subprocess.run(cmd, capture_output=True, text=True)
    return res.stdout

def main():
    print("=== INSPECTING APP MODEL CONFIGS ===")
    sql = """
    SELECT a.name, a.mode, c.id as config_id, c.pre_prompt, c.model, c.dataset_configs, c.sensitive_word_avoidance
    FROM apps a
    JOIN app_model_configs c ON a.app_model_config_id = c.id;
    """
    out = run_sql(sql)
    print(out)

if __name__ == "__main__":
    main()
