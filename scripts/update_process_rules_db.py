#!/usr/bin/env python3
import subprocess
import json

def run_sql(sql_query):
    cmd = ["ssh", "chatbot", "docker", "exec", "-i", "dify-db_postgres-1", "psql", "-U", "postgres", "-d", "dify"]
    res = subprocess.run(cmd, input=sql_query, capture_output=True, text=True, encoding="utf-8")
    return res.stdout, res.stderr

def main():
    print("=== UPDATING DATASET PROCESS RULES TO CUSTOM PIPELINE (DELIMITER \\n\\n# , MAX_TOKENS 800, OVERLAP 100) ===")
    
    # Custom segmentation rules JSON
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
    
    UPDATE datasets
    SET chunk_structure = 'custom'
    WHERE id IN (
        '6c116f73-ec0a-4c68-a5a1-a728aa4ce071',
        '049688f9-6254-4bbf-8c4d-92442f5a03b4',
        'ae1e9867-552f-4834-be4d-00a14be848b1'
    );
    """
    
    out, err = run_sql(sql)
    print("Output:", out.strip())
    if err:
        print("Stderr:", err.strip())

    print("\n=== VERIFYING UPDATED PROCESS RULES IN DB ===")
    check_sql = """
    SELECT d.name, r.mode, r.rules 
    FROM datasets d
    JOIN dataset_process_rules r ON d.id = r.dataset_id
    LIMIT 3;
    """
    out, err = run_sql(check_sql)
    print(out)

if __name__ == "__main__":
    main()
