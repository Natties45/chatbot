#!/usr/bin/env python3
"""
Script to clear all documents from Dify Knowledge Base datasets via Dify API.
Reads Dataset IDs and API Keys strictly from environment variables.
"""

import os
import time
import requests

def load_dotenv():
    env_file = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), ".env")
    if os.path.exists(env_file):
        with open(env_file, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    k, v = line.split("=", 1)
                    k, v = k.strip(), v.strip()
                    if k not in os.environ:
                        os.environ[k] = v

load_dotenv()

DIFY_API_BASE = os.getenv("DIFY_API_BASE", "http://203.154.16.45/v1")

DATASETS = [
    {
        "name": "kb-operation",
        "dataset_id": os.getenv("DIFY_OPERATION_DATASET_ID", ""),
        "api_key": os.getenv("DIFY_OPERATION_API_KEY", ""),
    },
    {
        "name": "kb-noc",
        "dataset_id": os.getenv("DIFY_NOC_DATASET_ID", ""),
        "api_key": os.getenv("DIFY_NOC_API_KEY", ""),
    },
    {
        "name": "kb-customer",
        "dataset_id": os.getenv("DIFY_CUSTOMER_DATASET_ID", ""),
        "api_key": os.getenv("DIFY_CUSTOMER_API_KEY", ""),
    },
]

def clear_dataset(name, dataset_id, api_key):
    if not dataset_id or not api_key:
        print(f"[SKIP] {name}: Missing dataset_id or api_key in environment variables.")
        return

    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }

    url = f"{DIFY_API_BASE}/datasets/{dataset_id}/documents"
    total_deleted = 0

    while True:
        try:
            res = requests.get(url, headers=headers, params={"page": 1, "limit": 100}, timeout=10)
            res.raise_for_status()
            data = res.json().get("data", [])
            if not data:
                print(f"[INFO] Dataset '{name}' ({dataset_id}) is now empty.")
                break

            print(f"[INFO] Deleting batch of {len(data)} document(s) from '{name}'...")
            for doc in data:
                doc_id = doc.get("id")
                doc_name = doc.get("name", doc_id)
                del_url = f"{DIFY_API_BASE}/datasets/{dataset_id}/documents/{doc_id}"
                del_res = requests.delete(del_url, headers=headers, timeout=10)
                if del_res.status_code in [200, 204]:
                    total_deleted += 1
                else:
                    print(f"  - Failed to delete {doc_name} ({doc_id}): HTTP {del_res.status_code} {del_res.text}")
                time.sleep(0.05)

        except Exception as e:
            print(f"[ERROR] Exception while clearing dataset '{name}': {e}")
            break

    print(f"[SUCCESS] Deleted total {total_deleted} document(s) from '{name}'.")

def main():
    print(f"=== Clearing Dify KB Datasets at {DIFY_API_BASE} ===")
    for ds in DATASETS:
        clear_dataset(ds["name"], ds["dataset_id"], ds["api_key"])
    print("=== Cleanup Completed ===")

if __name__ == "__main__":
    main()
