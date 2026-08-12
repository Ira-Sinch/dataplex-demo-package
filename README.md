# Dataplex Logical Onboarding & Data Quality Provisioning Demo

This project demonstrates a Proof of Concept (PoC) for logical onboarding of corporate data products and automated data quality provisioning on Google Cloud Platform (GCP) using **Dataplex Catalog** and **Dataplex Data Quality Scans**.

It covers two key enterprise scenarios:
1. **SMS Delivery Receipts (SMS DR) Demo**: Governance profiling for transactional notifications.
2. **Voice Onboarding (Voice RTC) Demo**: High-reliability telecom quality metrics and SLA monitoring.

---

## 📖 Scenario Context & Architecture

![Dataplex Catalog Governance Architecture](./System%20Architecture.png)

---

## 🛠️ The Role of dbt in this PoC

**dbt (data build tool)** is not just used for SQL transformations in this demo; it serves as the **metadata engine** and **source of truth** for governance. Here is what dbt is doing:

1.  **Data Materialization**: It compiles SQL models (in `models/`) and creates the physical tables and views in BigQuery (under `analytics_edp` dataset).
2.  **Physical Metadata Sync (`persist_docs`)**: We configured `persist_docs` in [`dbt_project.yml`](file:///Users/prabhaarya/work/dataplex-demo-package/dbt-metadata-sync/dbt_project.yml). When you run `dbt run`, dbt automatically pushes the table and column descriptions defined in [`schema.yml`](file:///Users/prabhaarya/work/dataplex-demo-package/dbt-metadata-sync/models/schema.yml) to BigQuery. Dataplex Catalog then automatically harvests these descriptions.
3.  **Governance Metadata Declarations (`meta` tags)**: Custom aspects (like table grain, residency regions, data sensitivity, and constraints) are declared directly in dbt schema YAMLs under the `meta` configuration.
4.  **Asset Resolution & Change Detection**: dbt compiles a [`manifest.json`](file:///Users/prabhaarya/work/dataplex-demo-package/dbt-metadata-sync/target/manifest.json) that maps logical dbt models to physical BigQuery paths. The Python sync scripts read this manifest to:
    *   Resolve logical model assets listed in Data Product YAMLs to physical BigQuery resources.
    *   Find models with custom `meta` tags and patch them to the corresponding Dataplex Catalog entries.

---

## 🏗️ Codebase Components

This showcase is partitioned into dedicated folders containing self-contained databases, scripts, configuration, and data-quality specifications:

### 1. SMS DR Governance Assets (`sms-delivery-receipts/`)
All resources required for the SMS delivery receipt governance and cataloging PoC:
*   [deploy.sh](./sms-delivery-receipts/deploy.sh): Automatically registers the Entry Group, Entry, dynamic aspects metadata, and configures active Data Quality scans.
*   [setup_sms_tables.sql](./sms-delivery-receipts/setup_sms_tables.sql): Independently provisions schemas, metadata tables, and inserts control verification rows for the SMS receipts.
*   [sms_delivery_receipts.yaml](./sms-delivery-receipts/sms_delivery_receipts.yaml): Defines completeness, validity, and E.164 phone number formatting regex standards.
*   [aspect_values.json](./sms-delivery-receipts/aspect_values.json): Schema properties mapping the owner, steward, SLA target tier, and validation status aspects.
*   [governance_profile_template.json](./sms-delivery-receipts/governance_profile_template.json): Template schema definition for the custom aspect type `data-product-governance-profile` in JSON format.

### 2. Voice Onboarding Governance Assets (`voice-onboarding/`)
All resources required for the Voice RTC SLA monitoring and onboarding PoC:
*   [deploy.sh](./voice-onboarding/deploy.sh): Registers entry groups, catalog entries, aspect profiles, and configurations for data scans.
*   [setup_voice_tables.sql](./voice-onboarding/setup_voice_tables.sql): Provisions BigQuery schemas, tables, and inserts control data for Voice onboarding.
*   [rtc_session_logs.yaml](./voice-onboarding/rtc_session_logs.yaml): Defines rules validating active session duration, international caller formats, and connection states.
*   [variables.env](./voice-onboarding/variables.env): Configuration parameters centralizing project, database, and location mappings.
*   [aspect_values.json](./voice-onboarding/aspect_values.json): Schema properties mapping the owner, steward, SLA target tier, and validation status aspects.

### 3. DBT Schema & Aspect Metadata Synchronization (`dbt-metadata-sync/`)
Illustrates how model schema descriptions documented in dbt are propagated to BigQuery and harvested automatically by Dataplex Catalog, as well as syncing custom aspects and Data Product specifications to **Dataplex Universal Catalog**:
*   [dbt_project.yml](./dbt-metadata-sync/dbt_project.yml): Defines project structure and configures `persist_docs` (relation and columns) to sync descriptions to BigQuery.
*   [profiles.yml](./dbt-metadata-sync/profiles.yml): BigQuery database connectivity variables.
*   [models/](./dbt-metadata-sync/models/): Includes SQL models and metadata YAMLs for the SMS receipts demo, and an expanded Customer & Orders demo:
    *   [customer_demo.sql](./dbt-metadata-sync/models/customer_demo.sql), [orders.sql](./dbt-metadata-sync/models/orders.sql), [customer_summary.sql](./dbt-metadata-sync/models/customer_summary.sql): Construct tables/views.
    *   [sms_delivery_receipts_demo.sql](./dbt-metadata-sync/models/sms_delivery_receipts_demo.sql): DBT SQL model file constructing the database table fields.
    *   [schema.yml](./dbt-metadata-sync/models/schema.yml), [customer_summary.yml](./dbt-metadata-sync/models/customer_summary.yml), [order_schema.yml](./dbt-metadata-sync/models/order_schema.yml): Schema mappings containing column descriptions and custom `meta` tags (e.g. `custom-table-metadata`, `custom-column-metadata`).
*   [data_products/](./dbt-metadata-sync/data_products/): Declarative specifications for Dataplex Knowledge Catalog Data Products:
    *   [sms_delivery_receipts_demo.yml](./dbt-metadata-sync/data_products/sms_delivery_receipts_demo.yml), [customer.yml](./dbt-metadata-sync/data_products/customer.yml), [customer_orders.yml](./dbt-metadata-sync/data_products/customer_orders.yml), [sms_data_records.yml](./dbt-metadata-sync/data_products/sms_data_records.yml): Map a data product to its dbt model assets, set owners/approvers, and attach OOB (overview, queries, refresh-cadence) or custom aspects.
    *   [_TEMPLATE.yml](./dbt-metadata-sync/data_products/_TEMPLATE.yml): Template for creating new data products.
*   [scripts/](./dbt-metadata-sync/scripts/): Python synchronization automation scripts:
    *   [aspect_registry.yml](./dbt-metadata-sync/scripts/aspect_registry.yml): Mapping configuration registry linking aspect aliases to full Dataplex Aspect Type resource paths.
    *   [sync_table_aspects.py](./dbt-metadata-sync/scripts/sync_table_aspects.py): Parses the compiled dbt `manifest.json` for model/column `meta` blocks and patches custom aspect data on Dataplex Catalog entries.
    *   [sync_data_products.py](./dbt-metadata-sync/scripts/sync_data_products.py): Imports, updates, or deletes Data Products in Knowledge Catalog from local YAMLs, attaches aspects, and binds BigQuery table assets (resolved via dbt).
*   [run_dbt_sync_aspect_and_dp.sh](./dbt-metadata-sync/run_dbt_sync_aspect_and_dp.sh): Shell script executing dbt run, table aspect synchronization, and data product synchronization.
*   [run_demo.sh](./dbt-metadata-sync/run_demo.sh): Shell script demonstrating native BigQuery physical description harvesting.

---

## 🔐 Required IAM Roles & GCP Setup

To successfully run this PoC, your GCP environment must be configured with specific APIs and IAM permission grants.

### 1. Required Google Cloud Service APIs
Ensure the following APIs are fully enabled in your target Google Cloud Platform project:
*   **BigQuery API** (`bigquery.googleapis.com`)
*   **Cloud Dataplex API** (`dataplex.googleapis.com`)

### 2. IAM Permissions for the Executor (User or Service Account)
The user or execution account running the deployment scripts (`deploy.sh` scripts), SQL setups, and metadata sync Python scripts must hold appropriate roles.

#### A. Basic PoC Permissions
| Role Name | IAM Role ID | Purpose |
| :--- | :--- | :--- |
| **BigQuery Data Owner** | `roles/bigquery.dataOwner` | Required to create datasets, construct schema tables, and insert control payloads. |
| **Dataplex Catalog Admin** | `roles/dataplex.catalogAdmin` | Required to construct metadata Entry Groups, catalog Entries, and bind governance Aspects. |
| **Dataplex Data Scan Admin** | `roles/dataplex.dataScanAdmin` | Required to declare, configure, update, and run automated Data Quality Scans. |

#### B. Additional Permissions for Aspect & Data Product Sync Scripts
If running `sync_table_aspects.py` and `sync_data_products.py` under a service account or user, grant:

*   **On the target GCP Project hosting BigQuery Assets (Data Project):**
    *   **BigQuery Metadata Viewer** (`roles/bigquery.metadataViewer`): To resolve physical table locations dynamically.
    *   **Dataplex Catalog Editor** (`roles/dataplex.catalogEditor`): To patch custom aspect values on BigQuery entries.
*   **On the target GCP Project where Aspect Types are defined (`ASPECT_TYPES_PROJECT`):**
    *   **Dataplex Viewer** (`roles/dataplex.viewer`): To read Aspect Type schemas and validate payload structures before writing.
*   **On the target GCP Project where Data Products are registered (`DATA_PRODUCTS_PROJECT`):**
    *   **Dataplex Data Products Editor** (`roles/dataplex.dataProductsEditor`) & **Admin** (`roles/dataplex.dataProductsAdmin`): To manage Data Product lifecycle and link physical assets.
    *   **Dataplex Catalog Admin** (`roles/dataplex.catalogAdmin`) & **Catalog Editor** (`roles/dataplex.catalogEditor`): To attach contact/overview/aspect info on the DP entries.
    *   **Dataplex Entry Owner** (`roles/dataplex.entryOwner`): To edit ownership and entry descriptions.

### 3. IAM Permissions for the Google-Managed Dataplex Service Agent
When a Dataplex Data Quality Scan runs, it issues query jobs against your BigQuery tables. These queries are executed by the Google-Managed Dataplex Service Agent rather than the user's credentials.

1. Find your Google-Managed Dataplex Service Agent service account email under **IAM & Admin**. The email conforms to this structure:
   ```text
   service-<PROJECT_NUMBER>@gcp-sa-dataplex.iam.gserviceaccount.com
   ```
2. Grant this service account the following roles:
   *   **BigQuery Data Viewer** (`roles/bigquery.dataViewer`) on the datasets (`analytics_edp` and `voice_rtc_edp`) or tables.
   *   **BigQuery Job User** (`roles/bigquery.jobUser`) at the **Project Level** (required to allocate query execution resources).

---

## 🏃 How to Run the Demos End-to-End

### ⚡ Quick Start: Run All Scenarios End-to-End

We have provided a master orchestration script [`run_all_demos.sh`](./run_all_demos.sh) in the repository root. This script will automatically set up a Python virtual environment, install all required dependencies (like `dbt-bigquery`, `google-auth`, and `pyyaml`), provision the BigQuery tables, and execute Scenario A, B, C, and the full Scenario D in sequence.

To run everything in one go:
```bash
./run_all_demos.sh
```

---

### Individual Scenarios

### Scenario A: SMS Delivery Receipts Demo

1. **Provision Database and Control Payloads**:
   ```bash
   bq query --location=europe-west3 --use_legacy_sql=false < sms-delivery-receipts/setup_sms_tables.sql
   ```
2. **Deploy Dataplex Catalog & Quality Scan**:
   ```bash
   ./sms-delivery-receipts/deploy.sh
   ```
3. **Trigger the Quality Scan**:
   ```bash
   gcloud dataplex datascans run sms-dr-dq-scan --location=europe-west3
   ```
4. **Monitor Scan Jobs status**:
   ```bash
   gcloud dataplex datascans jobs list --datascan=sms-dr-dq-scan --location=europe-west3
   ```

### Scenario B: Voice Onboarding (Voice RTC) Demo

1. **Provision Database and Control Payloads**:
   ```bash
   bq query --location=europe-west3 --use_legacy_sql=false < voice-onboarding/setup_voice_tables.sql
   ```
2. **Deploy Dataplex Catalog & Quality Scan**:
   ```bash
   ./voice-onboarding/deploy.sh
   ```
3. **Trigger the Quality Scan**:
   ```bash
   gcloud dataplex datascans run voice-rtc-dq-scan --location=europe-west3
   ```
4. **Monitor Scan Jobs status**:
   ```bash
   gcloud dataplex datascans jobs list --datascan=voice-rtc-dq-scan --location=europe-west3
   ```
### Scenario C: Basic DBT-to-BigQuery Metadata Synchronization (Physical Schema)

This scenario demonstrates basic physical schema description harvesting (automatic sync of table and column descriptions from dbt schema.yml to BigQuery and then Dataplex Catalog).

Ensure you have installed the dbt-bigquery adapter:
```bash
pip install dbt-bigquery
```

Run the sync demo script:
```bash
./dbt-metadata-sync/run_demo.sh
```
*   The script runs `dbt run` to build the model table.
*   Because `persist_docs` is enabled under `models` configuration in `dbt_project.yml`, dbt will physically push all table and column descriptions defined in `models/schema.yml` to BigQuery.
*   The script then queries BigQuery's `INFORMATION_SCHEMA.COLUMN_FIELD_PATHS` to show the successfully synced descriptions.
*   Once descriptions reside in BigQuery, they are automatically harvested by the native Dataplex Catalog schema synchronization.

### Scenario D: Advanced Metadata Synchronization (Aspects & Data Products)

This scenario demonstrates syncing custom aspect metadata defined within dbt models to the Dataplex Catalog, as well as publishing Data Product configurations.

1. **Install python requirements**:
   Ensure you have installed the google-auth, PyYAML, and dbt-bigquery adapter:
   ```bash
   pip install google-auth pyyaml dbt-bigquery
   ```

2. **Configure Environment Variables**:
   Set the projects where your aspect definitions reside and where you want to create your Data Products:
   ```bash
   export ASPECT_TYPES_PROJECT="your-gcp-project"
   export DATA_PRODUCTS_PROJECT="your-gcp-project"
   ```

3. **Compile dbt models & execute the sync**:
   Run the orchestration wrapper script:
   ```bash
   ./dbt-metadata-sync/run_dbt_sync_aspect_and_dp.sh
   ```
   This script:
   * Compiles and runs all models in the local dbt project (like `customer_summary`, `orders`, `sms_delivery_receipts_demo`).
   * Runs `sync_table_aspects.py` to compile metadata from the `meta` blocks (e.g. `custom-table-metadata` and `custom-column-metadata` in `models/schema.yml` and `models/customer_summary.yml`) and sync them to Dataplex Catalog.
   * Runs `sync_data_products.py` to parse definitions under `data_products/`, register them, and link the appropriate BigQuery table assets.

4. **Verify execution**:
   * Navigate to the **Dataplex Catalog** in the GCP Console.
   * Look up your data products (e.g., `sms-delivery-receipts-demo`) or the generated tables.
   * Check the **Aspects** section to verify the custom metadata is attached.

### 🔍 How to Verify Automatic Harvesting

#### A. In the GCP Console (UI):

1. **Verify in BigQuery**:
   * Go to the [BigQuery Console](https://console.cloud.google.com/bigquery).
   * Navigate to your project (`prabha-test`) -> `analytics_edp` -> `sms_delivery_receipts_demo`.
   * Select the **Schema** tab to see your column descriptions.

2. **Verify in Dataplex Catalog**:
   * Go to the [Dataplex Console](https://console.cloud.google.com/dataplex).
   * Click on **Search** in the left navigation panel.
   * Search for `sms_delivery_receipts_demo` and select the entry of type `bigquery-table` in location `eu`.
   * Click on the **Schema** tab. The column descriptions are automatically harvested and displayed here.

#### B. Via the `gcloud` CLI:

1. **Search for the Catalog Entry**:
   ```bash
   gcloud dataplex entries search "sms_delivery_receipts_demo" --project=prabha-test
   ```
2. **Lookup the Entry Schema**:
   ```bash
   gcloud dataplex entries lookup \
     "bigquery.googleapis.com/projects/prabha-test/datasets/analytics_edp/tables/sms_delivery_receipts_demo" \
     --entry-group="@bigquery" \
     --location="eu" \
     --project="prabha-test"
   ```
