#!/usr/bin/env python3
"""
Script to parse selfservice-repo knowledge YAML files and sync them to Dify KB datasets.
Reads Dataset IDs and API Keys strictly from environment variables.
"""

import os
import sys
import glob
import time
import requests
import yaml

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
REPO_PATH = os.getenv("REPO_PATH", "/tmp/selfservice-repo/data/knowledge")
if not os.path.exists(REPO_PATH):
    local_kb = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "KB", "data", "knowledge"))
    if os.path.exists(local_kb):
        REPO_PATH = local_kb

DATASETS = {
    "operation": {
        "name": "kb-operation",
        "dataset_id": os.getenv("DIFY_OPERATION_DATASET_ID", ""),
        "api_key": os.getenv("DIFY_OPERATION_API_KEY", ""),
    },
    "noc": {
        "name": "kb-noc",
        "dataset_id": os.getenv("DIFY_NOC_DATASET_ID", ""),
        "api_key": os.getenv("DIFY_NOC_API_KEY", ""),
    },
    "customer": {
        "name": "kb-customer-faq",
        "dataset_id": os.getenv("DIFY_CUSTOMER_DATASET_ID", ""),
        "api_key": os.getenv("DIFY_CUSTOMER_API_KEY", ""),
    },
}

def upload_document(dataset_id, api_key, title, content):
    if not dataset_id or not api_key:
        return False

    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }
    payload = {
        "name": title,
        "text": content,
        "indexing_technique": "high_quality",
        "process_rule": {"mode": "automatic"}
    }
    url = f"{DIFY_API_BASE}/datasets/{dataset_id}/document/create_by_text"
    try:
        res = requests.post(url, headers=headers, json=payload, timeout=10)
        return res.status_code == 200
    except Exception as e:
        print(f"  [WARN] Failed to upload '{title}': {e}")
        return False

def parse_yaml_file(file_path):
    documents = []
    filename = os.path.basename(file_path)
    is_noc_internal = "noc-scripts" in filename or "internal" in filename

    with open(file_path, "r", encoding="utf-8") as f:
        data = yaml.safe_load(f)

    if not data or "categories" not in data:
        return documents

    for cat_id, cat_data in data["categories"].items():
        cat_name = cat_data.get("name", cat_id)
        sections = cat_data.get("sections", {})

        for sec_id, sec_data in sections.items():
            sec_name = sec_data.get("name", sec_id)
            entries = sec_data.get("entries", [])

            for entry in entries:
                doc_id = entry.get("id", f"{cat_id}-{sec_id}")
                keywords = ", ".join(entry.get("keywords", []))
                intent = entry.get("intent", "")
                answer = entry.get("answer", "").strip()
                refs = entry.get("refs", [])

                refs_md = ""
                if refs:
                    refs_md = "\n\n**อ้างอิง:**\n" + "\n".join([f"- [{r.get('title')}]({r.get('url')})" for r in refs])

                md_text = f"# {cat_name} — {sec_name}\n\n"
                md_text += f"**ID:** `{doc_id}`\n"
                if keywords:
                    md_text += f"**คำค้นหา / Keywords:** {keywords}\n"
                if intent:
                    md_text += f"**Intent:** {intent}\n"
                md_text += f"\n### คำตอบ / ขั้นตอนการให้บริการ:\n{answer}{refs_md}\n"

                documents.append({
                    "id": doc_id,
                    "title": f"{filename} — {doc_id}",
                    "content": md_text,
                    "is_noc_internal": is_noc_internal,
                })

    return documents

def main():
    print(f"=== Syncing selfservice-repo from {REPO_PATH} to Dify API ({DIFY_API_BASE}) ===")

    if not os.path.exists(REPO_PATH):
        print(f"[WARN] Repository path '{REPO_PATH}' not found. Skipping sync.")
        return

    yaml_files = glob.glob(os.path.join(REPO_PATH, "*.yaml"))
    print(f"[INFO] Found {len(yaml_files)} YAML file(s).")

    all_docs = []
    for yf in sorted(yaml_files):
        docs = parse_yaml_file(yf)
        all_docs.extend(docs)
        print(f"  - {os.path.basename(yf)}: parsed {len(docs)} entry(ies).")

    print(f"[INFO] Total parsed entries: {len(all_docs)}")

    counts = {"operation": 0, "noc": 0, "customer": 0}

    for doc in all_docs:
        # 1. Operation dataset gets all docs
        if upload_document(DATASETS["operation"]["dataset_id"], DATASETS["operation"]["api_key"], doc["title"], doc["content"]):
            counts["operation"] += 1

        # 2. NOC dataset gets all non-restricted docs
        if not doc["is_noc_internal"]:
            if upload_document(DATASETS["noc"]["dataset_id"], DATASETS["noc"]["api_key"], doc["title"], doc["content"]):
                counts["noc"] += 1

        # 3. Customer dataset gets public docs only
        if not doc["is_noc_internal"]:
            if upload_document(DATASETS["customer"]["dataset_id"], DATASETS["customer"]["api_key"], doc["title"], doc["content"]):
                counts["customer"] += 1

        time.sleep(0.02)

    print("\n=== SYNC COMPLETE ===")
    print(f"kb-operation: {counts['operation']} document(s) uploaded.")
    print(f"kb-noc:       {counts['noc']} document(s) uploaded.")
    print(f"kb-customer:  {counts['customer']} document(s) uploaded.")

if __name__ == "__main__":
    main()
