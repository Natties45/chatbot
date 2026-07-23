#!/usr/bin/env python3
import json
import subprocess

def run_sql(sql_query):
    cmd = ["ssh", "chatbot", "docker", "exec", "-i", "dify-db_postgres-1", "psql", "-U", "postgres", "-d", "dify"]
    res = subprocess.run(cmd, input=sql_query, capture_output=True, text=True, encoding="utf-8")
    return res.stdout, res.stderr

def main():
    print("=== ENFORCING STOP PARAMETERS FOR QWEN3.5:CLOUD IN DIFY POSTGRES DB ===")
    
    # Model config for Operation Bot (qwen3.5:cloud, temp 0.3, stop ["</think>", "<think>"])
    model_op = json.dumps({
        "provider": "langgenius/ollama/ollama",
        "name": "qwen3.5:cloud",
        "mode": "chat",
        "completion_params": {
            "temperature": 0.3,
            "stop": ["</think>", "<think>"]
        }
    })
    escaped_model_op = model_op.replace("'", "''")
    
    # Model config for NOC Bot & Customer Bot (qwen3.5:cloud, temp 0.1, stop ["</think>", "<think>"])
    model_std = json.dumps({
        "provider": "langgenius/ollama/ollama",
        "name": "qwen3.5:cloud",
        "mode": "chat",
        "completion_params": {
            "temperature": 0.1,
            "stop": ["</think>", "<think>"]
        }
    })
    escaped_model_std = model_std.replace("'", "''")

    sql = f"""
    UPDATE app_model_configs 
    SET model = '{escaped_model_op}',
        updated_at = CURRENT_TIMESTAMP
    WHERE app_id IN (SELECT id FROM apps WHERE name = 'Operation Bot');
    
    UPDATE app_model_configs 
    SET model = '{escaped_model_std}',
        updated_at = CURRENT_TIMESTAMP
    WHERE app_id IN (SELECT id FROM apps WHERE name IN ('NOC Bot', 'Customer FAQ Bot'));
    """
    
    out, err = run_sql(sql)
    print("Output:", out.strip())
    if err:
        print("Stderr:", err.strip())

    print("\n=== VERIFYING ACTIVE APP MODEL CONFIGS IN POSTGRES DB ===")
    check_sql = "SELECT a.name, c.id, c.model FROM apps a JOIN app_model_configs c ON a.app_model_config_id = c.id;"
    out_check, _ = run_sql(check_sql)
    print(out_check)

if __name__ == "__main__":
    main()
