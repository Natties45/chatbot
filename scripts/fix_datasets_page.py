#!/usr/bin/env python3
import subprocess

def run_sql(sql_query):
    cmd = ["ssh", "chatbot", "docker", "exec", "-i", "dify-db_postgres-1", "psql", "-U", "postgres", "-d", "dify"]
    res = subprocess.run(cmd, input=sql_query, capture_output=True, text=True, encoding="utf-8")
    return res.stdout, res.stderr

def main():
    print("=== FIXING DIFY DATASETS PAGE UI (RESET CHUNK_STRUCTURE TO NULL) ===")
    sql = """
    UPDATE datasets 
    SET chunk_structure = NULL 
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

    print("\n=== VERIFYING UPDATED DATASETS TABLE IN DB ===")
    check_sql = "SELECT id, name, runtime_mode, chunk_structure, indexing_technique, retrieval_model FROM datasets;"
    out_check, _ = run_sql(check_sql)
    print(out_check)

if __name__ == "__main__":
    main()
