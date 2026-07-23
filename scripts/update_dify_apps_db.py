#!/usr/bin/env python3
import subprocess
import json

def main():
    print("=== INSPECTING DIFY APPS AND MODEL CONFIGS IN POSTGRES DB ===")
    
    # Query apps table
    cmd_apps = ["ssh", "chatbot", "docker", "exec", "-i", "dify-db_postgres-1", "psql", "-U", "postgres", "-d", "dify", "-c", "SELECT id, name, mode, app_model_config_id FROM apps;"]
    res_apps = subprocess.run(cmd_apps, capture_output=True, text=True)
    print("APPS TABLE:")
    print(res_apps.stdout)
    
    # Query app_model_configs table
    cmd_configs = ["ssh", "chatbot", "docker", "exec", "-i", "dify-db_postgres-1", "psql", "-U", "postgres", "-d", "dify", "-c", "SELECT id, app_id, model, dataset_configs FROM app_model_configs;"]
    res_configs = subprocess.run(cmd_configs, capture_output=True, text=True)
    print("APP_MODEL_CONFIGS TABLE:")
    print(res_configs.stdout)

if __name__ == "__main__":
    main()
