#!/bin/bash
set -e

# Determine script directory for directory-agnostic execution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Detect active gcloud project, fallback to prabha-test
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
PROJECT_ID=${PROJECT_ID:-"prabha-test"}
LOCATION="europe-west3"
SCAN_LOCATION="europe-west3"
ENTRY_GROUP="mvc-data-products"
ENTRY_ID="sms-dr-edp"

# Define temporary aspect values file to dynamically map project IDs
TEMP_ASPECTS="${SCRIPT_DIR}/aspect_values_temp.json"
trap 'rm -f "${TEMP_ASPECTS}"' EXIT

sed "s/prabha-test/${PROJECT_ID}/g" "${SCRIPT_DIR}/aspect_values.json" > "${TEMP_ASPECTS}"

echo "Step 1: Provisioning Isolated Corporate Entry Group Container [${ENTRY_GROUP}]..."
gcloud dataplex entry-groups create ${ENTRY_GROUP} \
    --project=${PROJECT_ID} \
    --location=${LOCATION} \
    --description="Logical entry group holding Enterprise Data Products (EDP)" || echo "Group already exists, continuing..."

echo "Step 2: Registering Data Product Entry & Binding Governance Profile Metadata..."
# Delete old entry safely if it exists, then recreate
gcloud dataplex entries delete ${ENTRY_ID} --entry-group=${ENTRY_GROUP} --location=${LOCATION} --project=${PROJECT_ID} --quiet || true

gcloud dataplex entries create ${ENTRY_ID} \
    --project=${PROJECT_ID} \
    --location=${LOCATION} \
    --entry-group=${ENTRY_GROUP} \
    --entry-type="projects/dataplex-types/locations/global/entryTypes/generic" \
    --entry-source-description="Enterprise Data Product for SMS Delivery Receipts (SMS DR EDP)" \
    --aspects="${TEMP_ASPECTS}"

echo "Step 3: Initializing Git-Backed Active Dataplex Data Quality Scan..."
gcloud dataplex datascans delete sms-dr-dq-scan --location=${SCAN_LOCATION} --project=${PROJECT_ID} --quiet || true

gcloud dataplex datascans create data-quality sms-dr-dq-scan \
    --project=${PROJECT_ID} \
    --location=${SCAN_LOCATION} \
    --data-source-resource="//bigquery.googleapis.com/projects/${PROJECT_ID}/datasets/analytics_edp/tables/sms_delivery_receipts" \
    --data-quality-spec-file="${SCRIPT_DIR}/sms_delivery_receipts.yaml" \
    --display-name="SMS DR Active Quality Scan"

echo "========================================================================="
echo "✅ SMS PoC ENVIRONMENT DEPLOYED SUCCESSFULLY"
echo "========================================================================="
