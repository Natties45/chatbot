#!/usr/bin/env python3
import subprocess

def main():
    sql = "SELECT id, provider_name, provider_type, encrypted_config FROM provider_credentials;"
    cmd = ["ssh", "chatbot", "docker", "exec", "-i", "dify-db_postgres-1", "psql", "-U", "postgres", "-d", "dify"]
    res = subprocess.run(cmd, input=sql, capture_output=True, text=True)
    print("PROVIDER CREDENTIALS:")
    print(res.stdout)

    sql2 = "SELECT provider_name, provider_type, is_valid FROM providers;"
    res2 = subprocess.run(cmd, input=sql2, capture_output=True, text=True)
    print("\nPROVIDERS:")
    print(res2.stdout)

if __name__ == "__main__":
    main()
