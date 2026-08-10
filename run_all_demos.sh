#!/bin/bash
# =============================================================================
# run_all_demos.sh
# -----------------------------------------------------------------------------
# Master orchestration script to run all runnable demo scenarios in sequence.
# Handles environment setup and handles potential gcloud SSL teardown crashes.
# =============================================================================

# Ensure Google Cloud SDK is in PATH and Client Cert is enabled
if ! command -v gcloud &> /dev/null; then
    if [ -d "/Users/prabhaarya/Downloads/google-cloud-sdk/bin" ]; then
        export PATH="/Users/prabhaarya/Downloads/google-cloud-sdk/bin:$PATH"
    elif [ -d "$HOME/google-cloud-sdk/bin" ]; then
        export PATH="$HOME/google-cloud-sdk/bin:$PATH"
    fi
fi
export CLOUDSDK_CONTEXT_AWARE_USE_CERTIFICATE=true

# Dataplex Project Configuration
ACTIVE_PROJECT=$(gcloud config get-value project 2>/dev/null)
export ASPECT_TYPES_PROJECT="${ACTIVE_PROJECT:-prabha-test}"
export DATA_PRODUCTS_PROJECT="${ACTIVE_PROJECT:-prabha-test}"
export DBT_PROJECT_ID="${ACTIVE_PROJECT:-prabha-test}"

echo "========================================================"
echo "📧 Starting Scenario A: SMS Delivery Receipts Demo"
echo "========================================================"
echo "1. Provisioning BQ tables..."
bq query --project_id="${DBT_PROJECT_ID}" --location=europe-west3 --use_legacy_sql=false < sms-delivery-receipts/setup_sms_tables.sql

echo "2. Deploying Dataplex resources..."
# We don't use set -e so we can continue if gcloud crashes during teardown
./sms-delivery-receipts/deploy.sh || echo "⚠️ Warning: deploy.sh returned non-zero, continuing..."

echo "3. Triggering Data Quality Scan..."
gcloud dataplex datascans run sms-dr-dq-scan --location=europe-west3 || echo "⚠️ Warning: scan trigger returned non-zero..."

echo "4. Checking Scan Job Status..."
gcloud dataplex datascans jobs list --datascan=sms-dr-dq-scan --location=europe-west3 --limit=1

echo "========================================================"
echo "📞 Starting Scenario B: Voice Onboarding Demo"
echo "========================================================"
echo "1. Provisioning BQ tables..."
bq query --project_id="${DBT_PROJECT_ID}" --location=europe-west3 --use_legacy_sql=false < voice-onboarding/setup_voice_tables.sql

echo "2. Deploying Dataplex resources..."
./voice-onboarding/deploy.sh || echo "⚠️ Warning: deploy.sh returned non-zero, continuing..."

echo "3. Triggering Data Quality Scan..."
gcloud dataplex datascans run voice-rtc-dq-scan --location=europe-west3 || echo "⚠️ Warning: scan trigger returned non-zero..."

echo "4. Checking Scan Job Status..."
gcloud dataplex datascans jobs list --datascan=voice-rtc-dq-scan --location=europe-west3 --limit=1

echo "========================================================"
echo "📊 Starting Scenario C: DBT Physical Schema Sync Demo"
echo "========================================================"

# Auto-setup virtual environment and requirements
PYTHON_BIN=$(gcloud info --format="value(basic.python_location)" 2>/dev/null || echo "python3")
cd dbt-metadata-sync
if [ ! -d ".venv" ]; then
    echo "Creating virtual environment in dbt-metadata-sync..."
    "$PYTHON_BIN" -m venv .venv
fi
source .venv/bin/activate
echo "Installing dependencies..."
pip install --upgrade pip
pip install google-auth pyyaml dbt-bigquery
cd ..

./dbt-metadata-sync/run_demo.sh

echo "========================================================"
echo "📦 Starting Scenario D: Data Product Sync (Full)"
echo "========================================================"
./dbt-metadata-sync/run_dbt_sync_aspect_and_dp.sh

echo "========================================================"
echo "🎉 All runnable scenarios executed!"
echo "========================================================"

