#!/usr/bin/env python3
import subprocess
import sys

sys.stdout.reconfigure(encoding='utf-8')
sys.stderr.reconfigure(encoding='utf-8')

def run_sql(sql):
    cmd = ["ssh", "chatbot", "docker", "exec", "-i", "dify-db_postgres-1", "psql", "-U", "postgres", "-d", "dify"]
    res = subprocess.run(cmd, input=sql, capture_output=True, text=True, encoding="utf-8")
    return res.stdout, res.stderr

def main():
    print("=== INSPECTING SITE CODE RkR9oyJYtCImpeuW IN DIFY DB ===")
    sql = """
    SELECT s.id, s.app_id, s.code, a.name, a.app_model_config_id, c.model
    FROM sites s
    JOIN apps a ON s.app_id = a.id
    LEFT JOIN app_model_configs c ON a.app_model_config_id = c.id
    WHERE s.code = 'RkR9oyJYtCImpeuW';
    """
    out, err = run_sql(sql)
    print(out)

if __name__ == "__main__":
    main()
