#!/usr/bin/env python3
import subprocess

sql = """
UPDATE datasets 
SET retrieval_model = '{"top_k": 3, "search_method": "hybrid_search", "reranking_enable": false, "score_threshold_enabled": true, "score_threshold": 0.55}';
"""

def main():
    print("=== UPDATING DIFY DATASETS RETRIEVAL SETTINGS IN POSTGRES DB ===")
    cmd = [
        "ssh", "chatbot", "docker", "exec", "-i", "dify-db_postgres-1", "psql", "-U", "postgres", "-d", "dify"
    ]
    res = subprocess.run(cmd, input=sql, capture_output=True, text=True)
    print("STDOUT:", res.stdout)
    print("STDERR:", res.stderr)

    check_cmd = [
        "ssh", "chatbot", "docker", "exec", "-i", "dify-db_postgres-1", "psql", "-U", "postgres", "-d", "dify", "-c", "SELECT name, retrieval_model FROM datasets;"
    ]
    check_res = subprocess.run(check_cmd, capture_output=True, text=True)
    print("\n--- UPDATED DATASETS RETRIEVAL MODEL ---")
    print(check_res.stdout)

if __name__ == "__main__":
    main()
