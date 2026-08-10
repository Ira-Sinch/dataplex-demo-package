#!/usr/bin/env python3
import json
import logging
import os
import sys
import urllib.request
import urllib.error
import time

import google.auth
import google.auth.transport.requests

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger(__name__)

PROJECT_ID = os.environ.get("PROJECT_ID")
if not PROJECT_ID:
    log.error("PROJECT_ID env var is required (e.g. export PROJECT_ID=prabha-test)")
    sys.exit(1)

BASE_URL = "https://dataplex.googleapis.com/v1"

ASPECT_TYPES = {
    "custom-dbt-sync-metadata": {
        "description": "DBT Sync Bookkeeping Metadata",
        "metadataTemplate": {
            "name": "custom-dbt-sync-metadata",
            "type": "record",
            "recordFields": [
                {"name": "custom-content-hash", "type": "string", "index": 1},
                {"name": "custom-sync-status", "type": "string", "index": 2},
                {"name": "custom-synched-at", "type": "string", "index": 3},
                {"name": "custom-dbt-invocation-id", "type": "string", "index": 4}
            ]
        }
    },
    "custom-table-metadata": {
        "description": "Custom Table Metadata for DBT models",
        "metadataTemplate": {
            "name": "custom-table-metadata",
            "type": "record",
            "recordFields": [
                {"name": "custom-grain", "type": "string", "index": 1},
                {"name": "custom-external-description", "type": "string", "index": 2},
                {"name": "custom-data-residency-apply", "type": "string", "index": 3},
                {
                    "name": "custom-data-residency-regions",
                    "type": "array",
                    "arrayItems": {
                        "name": "item",
                        "type": "string"
                    },
                    "index": 4
                },
                {"name": "custom-dbt-model-reference", "type": "string", "index": 5},
                {"name": "custom-data-retention", "type": "string", "index": 6}
            ]
        }
    },
    "custom-column-metadata": {
        "description": "Custom Column Metadata for DBT models",
        "metadataTemplate": {
            "name": "custom-column-metadata",
            "type": "record",
            "recordFields": [
                {"name": "custom-business-description", "type": "string", "index": 1},
                {"name": "custom-is-encrypted", "type": "string", "index": 2},
                {"name": "custom-has-pii", "type": "string", "index": 3},
                {
                    "name": "custom-constraints",
                    "type": "array",
                    "arrayItems": {
                        "name": "item",
                        "type": "record",
                        "recordFields": [
                            {"name": "custom-constraint", "type": "string", "index": 1}
                        ]
                    },
                    "index": 4
                }
            ]
        }
    },
    "custom-data-product-profile": {
        "description": "Custom Data Product Profile",
        "metadataTemplate": {
            "name": "custom-data-product-profile",
            "type": "record",
            "recordFields": [
                {"name": "custom-data-product-type", "type": "string", "index": 1},
                {"name": "custom-domain", "type": "string", "index": 2},
                {
                    "name": "custom-external-references",
                    "type": "array",
                    "arrayItems": {
                        "name": "item",
                        "type": "record",
                        "recordFields": [
                            {"name": "custom-document-type", "type": "string", "index": 1},
                            {"name": "custom-document-link", "type": "string", "index": 2}
                        ]
                    },
                    "index": 3
                },
                {
                    "name": "custom-contacts",
                    "type": "array",
                    "arrayItems": {
                        "name": "item",
                        "type": "record",
                        "recordFields": [
                            {"name": "custom-role", "type": "string", "index": 1},
                            {"name": "custom-name", "type": "string", "index": 2},
                            {"name": "custom-email-id", "type": "string", "index": 3}
                        ]
                    },
                    "index": 4
                }
            ]
        }
    },
    "custom-data-product-status": {
        "description": "Custom Data Product Status",
        "metadataTemplate": {
            "name": "custom-data-product-status",
            "type": "record",
            "recordFields": [
                {"name": "custom-lifecycle-status", "type": "string", "index": 1},
                {"name": "custom-maturity-level", "type": "string", "index": 2}
            ]
        }
    }
}

def get_access_token():
    log.info("Acquiring GCP access token...")
    credentials, project = google.auth.default(
        scopes=["https://www.googleapis.com/auth/cloud-platform"]
    )
    auth_req = google.auth.transport.requests.Request()
    credentials.refresh(auth_req)
    if not credentials.token:
        raise RuntimeError("Failed to refresh credentials token.")
    return credentials.token

def create_aspect_type(token, aspect_id, payload):
    url = f"{BASE_URL}/projects/{PROJECT_ID}/locations/global/aspectTypes?aspectTypeId={aspect_id}"
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=data, method="POST")
    req.add_header("Authorization", f"Bearer {token}")
    req.add_header("Content-Type", "application/json")
    
    try:
        log.info(f"Creating Aspect Type: {aspect_id}...")
        with urllib.request.urlopen(req) as resp:
            body = resp.read()
            res = json.loads(body) if body else {}
            # Create Aspect Type is an LRO
            op_name = res.get("name")
            if op_name:
                wait_for_operation(token, op_name, f"Create Aspect Type '{aspect_id}'")
            else:
                log.info(f"Aspect Type {aspect_id} created immediately?")
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        if e.code == 409:
            log.info(f"Aspect Type {aspect_id} already exists.")
        else:
            log.error(f"Failed to create Aspect Type {aspect_id}: HTTP {e.code}: {body}")
            raise e

def wait_for_operation(token, operation_name, task_description="Operation"):
    log.info("  - waiting: %s", task_description)
    delay = 2
    op_url = f"{BASE_URL}/{operation_name}"
    while True:
        time.sleep(delay)
        req = urllib.request.Request(op_url, method="GET")
        req.add_header("Authorization", f"Bearer {token}")
        try:
            with urllib.request.urlopen(req) as resp:
                op = json.loads(resp.read().decode("utf-8"))
                if op.get("done"):
                    error = op.get("error")
                    if error:
                        log.error("❌ %s failed: %s", task_description, error)
                        return False
                    log.info("✅ %s finished successfully", task_description)
                    return True
        except Exception as e:
            log.warning("Error polling operation %s: %s, retrying...", operation_name, e)
        delay = min(delay * 2, 30)

def main():
    token = get_access_token()
    for aspect_id, payload in ASPECT_TYPES.items():
        try:
            create_aspect_type(token, aspect_id, payload)
        except Exception as e:
            log.error(f"Failed processing {aspect_id}: {e}")
            # Continue to next even if one fails
            pass

if __name__ == "__main__":
    main()
