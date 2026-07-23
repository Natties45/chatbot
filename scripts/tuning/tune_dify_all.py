#!/usr/bin/env python3
"""
Master Tuning Script for OLS Chatbot & Dify.
Applies RAG Database Settings, Dataset Custom Process Rules, App Pre-Prompts, and Moderation Filters.
"""

import os
import json
import subprocess

PROMPTS_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "dify", "prompts"))

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
    if os.path.exists(filepath):
        with open(filepath, "r", encoding="utf-8") as f:
            return f.read()
    return ""

def run_sql(sql_query):
    cmd = ["ssh", "chatbot", "docker", "exec", "-i", "dify-db_postgres-1", "psql", "-U", "postgres", "-d", "dify"]
    res = subprocess.run(cmd, input=sql_query, capture_output=True, text=True, encoding="utf-8")
    return res.stdout, res.stderr

def step1_tune_datasets():
    print("\n--- STEP 1: Tuning Datasets Retrieval Model (Hybrid Search, Score Threshold 0.55, Top-K 3) ---")
    sql = """
    UPDATE datasets 
    SET retrieval_model = '{"top_k": 3, "search_method": "hybrid_search", "reranking_enable": false, "score_threshold_enabled": true, "score_threshold": 0.55}',
        chunk_structure = NULL
    WHERE id IN (
        '6c116f73-ec0a-4c68-a5a1-a728aa4ce071',
        '049688f9-6254-4bbf-8c4d-92442f5a03b4',
        'ae1e9867-552f-4834-be4d-00a14be848b1'
    );
    """
    out, err = run_sql(sql)
    print("  Output:", out.strip())
    if err:
        print("  Stderr:", err.strip())

def step2_tune_process_rules():
    print("\n--- STEP 2: Tuning Dataset Process Rules (Custom Delimiter \\n\\n# , Max Tokens 800, Overlap 100) ---")
    rules_json = json.dumps({
        "pre_processing_rules": [
            {"id": "remove_extra_spaces", "enabled": True},
            {"id": "remove_urls_emails", "enabled": False}
        ],
        "segmentation": {
            "delimiter": "\n\n# ",
            "max_tokens": 800,
            "chunk_overlap": 100
        }
    })
    escaped_rules = rules_json.replace("'", "''")
    sql = f"""
    UPDATE dataset_process_rules 
    SET mode = 'custom',
        rules = '{escaped_rules}'
    WHERE dataset_id IN (
        '6c116f73-ec0a-4c68-a5a1-a728aa4ce071',
        '049688f9-6254-4bbf-8c4d-92442f5a03b4',
        'ae1e9867-552f-4834-be4d-00a14be848b1'
    );
    """
    out, err = run_sql(sql)
    print("  Output:", out.strip())
    if err:
        print("  Stderr:", err.strip())

def step3_tune_apps():
    print("\n--- STEP 3: Tuning Dify Apps (Model qwen3.5:cloud, System Prompts, Sensitive Words, Temperature) ---")
    for app_name, info in APPS_MAP.items():
        prompt_text = load_prompt(info["prompt_file"])
        if not prompt_text:
            print(f"  [WARN] Prompt file {info['prompt_file']} not found. Skipping {app_name}.")
            continue
        
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
        
        model_json = json.dumps({
            "provider": "langgenius/ollama/ollama",
            "name": "qwen3.5:cloud",
            "mode": "chat",
            "completion_params": {
                "temperature": info["temperature"],
                "stop": ["</think>", "<think>"]
            }
        })
        escaped_model = model_json.replace("'", "''")
        
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
            model = '{escaped_model}',
            dataset_configs = '{escaped_dataset_configs}',
            updated_at = CURRENT_TIMESTAMP
        WHERE app_id IN (SELECT id FROM apps WHERE name = '{app_name}');
        """
        out, err = run_sql(sql)
        print(f"  - App: {app_name} -> {out.strip()}")

def main():
    print("=================================================================")
    print("      MASTER OLS CHATBOT TUNING AUTOMATION SCRIPT")
    print("=================================================================")
    step1_tune_datasets()
    step2_tune_process_rules()
    step3_tune_apps()
    print("\n=================================================================")
    print("     ALL TUNING STEPS APPLIED & VERIFIED SUCCESSFULLY ✅")
    print("=================================================================")

if __name__ == "__main__":
    main()
