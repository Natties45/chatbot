#!/usr/bin/env python3
import os
import json
import subprocess

PROMPTS_DIR = r"c:\Users\natti\OneDrive\Documents\natties45\chatbot\dify\prompts"

APPS_MAP = {
    "Customer FAQ Bot": {
        "config_id": "2f9e05cb-037e-4d66-9147-3f58633c185e",
        "prompt_file": "customer-system-prompt.txt",
        "temperature": 0.1,
        "sensitive_words": ["OpenStack", "Dante", "backend", "internal tool", "internal path", "API", "CLI"]
    },
    "NOC Bot": {
        "config_id": "5e1cb439-c986-41fa-8c90-609e242f78e8",
        "prompt_file": "noc-system-prompt.txt",
        "temperature": 0.1,
        "sensitive_words": []
    },
    "Operation Bot": {
        "config_id": "e0c2d64d-170a-4202-ba78-4e7591f8a98f",
        "prompt_file": "operation-system-prompt.txt",
        "temperature": 0.3,
        "sensitive_words": []
    }
}

def load_prompt(filename):
    filepath = os.path.join(PROMPTS_DIR, filename)
    with open(filepath, "r", encoding="utf-8") as f:
        return f.read()

def run_sql(sql_query):
    cmd = ["ssh", "chatbot", "docker", "exec", "-i", "dify-db_postgres-1", "psql", "-U", "postgres", "-d", "dify"]
    res = subprocess.run(cmd, input=sql_query, capture_output=True, text=True, encoding="utf-8")
    return res.stdout, res.stderr

def main():
    print("=== UPDATING DIFY APP MODEL CONFIGS (PRE_PROMPT, SENSITIVE WORDS, MODEL TEMP) ===")
    for app_name, info in APPS_MAP.items():
        config_id = info["config_id"]
        prompt_text = load_prompt(info["prompt_file"])
        
        # Escape single quotes in SQL
        escaped_prompt = prompt_text.replace("'", "''")
        
        # Model config JSON
        model_json = json.dumps({
            "provider": "ollama",
            "model": "qwen2.5:7b",
            "mode": "chat",
            "completion_params": {
                "temperature": info["temperature"],
                "top_p": 0.8
            }
        })
        escaped_model = model_json.replace("'", "''")
        
        # Sensitive word avoidance JSON
        sensitive_json = "{}"
        if info["sensitive_words"]:
            sensitive_json = json.dumps({
                "type": "keywords",
                "enabled": True,
                "config": {
                    "words": "\n".join(info["sensitive_words"]),
                    "action": "banned_response",
                    "banned_response": "เรียน ผู้ใช้บริการ ไม่สามารถให้ข้อมูลหรือประมวลผลคำขอที่เกี่ยวข้องได้ครับ ขอบคุณครับ"
                }
            })
        escaped_sensitive = sensitive_json.replace("'", "''")
        
        # Dataset configs JSON
        dataset_configs_json = json.dumps({
            "retrieval_model": "hybrid_search",
            "top_k": 3,
            "score_threshold_enabled": True,
            "score_threshold": 0.55
        })
        escaped_dataset_configs = dataset_configs_json.replace("'", "''")
        
        sql = f"""
        UPDATE app_model_configs 
        SET pre_prompt = '{escaped_prompt}',
            sensitive_word_avoidance = '{escaped_sensitive}',
            dataset_configs = '{escaped_dataset_configs}',
            updated_at = CURRENT_TIMESTAMP
        WHERE id = '{config_id}';
        """
        
        out, err = run_sql(sql)
        print(f"  - App: {app_name} (Config ID: {config_id}) -> Output: {out.strip()} | Error: {err.strip()}")

    print("\n=== VERIFYING UPDATED PRE_PROMPTS IN POSTGRES DB ===")
    check_sql = "SELECT a.name, LENGTH(c.pre_prompt) as prompt_len, c.sensitive_word_avoidance FROM apps a JOIN app_model_configs c ON a.app_model_config_id = c.id;"
    out, err = run_sql(check_sql)
    print(out)

if __name__ == "__main__":
    main()
