#!/usr/bin/env python3
import os
import json
import subprocess

PROMPTS_DIR = r"c:\Users\natti\OneDrive\Documents\natties45\chatbot\dify\prompts"

APPS_MAP = {
    "Customer FAQ Bot": {
        "prompt_file": "customer-system-prompt.txt",
        "temperature": 0.1,
        "sensitive_words": ["OpenStack", "Dante", "backend", "internal tool", "internal path", "API", "CLI"]
    },
    "NOC Bot": {
        "prompt_file": "noc-system-prompt.txt",
        "temperature": 0.1,
        "sensitive_words": []
    },
    "Operation Bot": {
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
    print("=== UPDATING ALL APP_MODEL_CONFIGS AND APPS IN DIFY DB ===")
    
    # Update active app_model_config_id in apps
    for app_name, info in APPS_MAP.items():
        prompt_text = load_prompt(info["prompt_file"])
        escaped_prompt = prompt_text.replace("'", "''")
        
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
        
        # Model JSON with STOP parameters to force stop at </think>
        model_json = json.dumps({
            "provider": "langgenius/ollama/ollama",
            "name": "qwen2.5:7b",
            "mode": "chat",
            "completion_params": {
                "temperature": info["temperature"],
                "stop": ["</think>", "<think>"]
            }
        })
        escaped_model = model_json.replace("'", "''")

        sql = f"""
        UPDATE app_model_configs 
        SET pre_prompt = '{escaped_prompt}',
            sensitive_word_avoidance = '{escaped_sensitive}',
            model = '{escaped_model}',
            updated_at = CURRENT_TIMESTAMP
        WHERE app_id IN (SELECT id FROM apps WHERE name = '{app_name}');
        """
        out, err = run_sql(sql)
        print(f"  - Updated Configs for {app_name} -> Output: {out.strip()} | Error: {err.strip()}")

if __name__ == "__main__":
    main()
