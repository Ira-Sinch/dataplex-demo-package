#!/bin/bash
set -e

# Determine script directory for execution context
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Set up gcloud path and env vars for Context Aware Access
if ! command -v gcloud &> /dev/null; then
    if [ -d "/Users/prabhaarya/Downloads/google-cloud-sdk/bin" ]; then
        export PATH="/Users/prabhaarya/Downloads/google-cloud-sdk/bin:$PATH"
    elif [ -d "$HOME/google-cloud-sdk/bin" ]; then
        export PATH="$HOME/google-cloud-sdk/bin:$PATH"
    fi
fi
export CLOUDSDK_CONTEXT_AWARE_USE_CERTIFICATE=true

# Activate virtual environment
if [ -d ".venv" ]; then
    source .venv/bin/activate
fi

# Detect active gcloud project, fallback to prabha-test
export DBT_PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
export DBT_PROJECT_ID=${DBT_PROJECT_ID:-"prabha-test"}

echo "========================================================================="
echo "📊 STARTING DBT TO BIGQUERY TO DATAPLEX METADATA SYNC DEMO"
echo "========================================================================="
echo "Target GCP Project: ${DBT_PROJECT_ID}"
echo "========================================================================="

check_metadata() {
    python -c "
from google.cloud import bigquery
import os
project_id = os.getenv('DBT_PROJECT_ID', 'prabha-test')
client = bigquery.Client(project=project_id)
query = f'''
SELECT
  column_name,
  data_type,
  description
FROM
  \`{project_id}.analytics_edp.INFORMATION_SCHEMA.COLUMN_FIELD_PATHS\`
WHERE
  table_name = 'sms_delivery_receipts_demo';
'''
print('%-20s | %-15s | %s' % ('column_name', 'data_type', 'description'))
print('-' * 60)
for r in client.query(query).result():
    print('%-20s | %-15s | %s' % (r.column_name, r.data_type, r.description or 'NULL'))
"
}

# 1. Prerequisite verification
# (Since we activate venv, 'dbt' should be available if installed there)
if ! command -v dbt &> /dev/null; then
    echo "ERROR: 'dbt' command not found."
    echo "Please install dbt with BigQuery support before running this demo:"
    echo "  pip install dbt-bigquery"
    exit 1
fi


# ---------------------------------------------------------
# Deploy dbt model
# ---------------------------------------------------------
echo "Deploying dbt model..."
dbt run --profiles-dir .

echo "Checking schema metadata in BigQuery (COLUMN_FIELD_PATHS)..."
check_metadata

echo "---------------------------------------------------------"
echo "If any column or table descriptions are configured in models/schema.yml,"
echo "they have now been synced and populated in BigQuery!"
echo "---------------------------------------------------------"
echo "Step 2: Harvesting by Dataplex Catalog"
echo "1. Because BigQuery is natively integrated with Dataplex Catalog, Dataplex"
echo "   automatically harvests physical metadata from BigQuery schemas."
echo "2. Any Catalog Entry created for this table (e.g. via 'gcloud dataplex entries create')"
echo "   or discovered automatically in Dataplex Search will now display these schema"
echo "   descriptions directly under the schema tab in the GCP Dataplex Console."
echo "========================================================================="
