# Data Governance & Data Quality PoC

## Executive Summary
In a modern enterprise, data is often scattered, undocumented, and difficult to trust. This codebase provides a working prototype (Proof of Concept) demonstrating how to automate data governance, cataloging, and quality control on Google Cloud Platform (GCP).

Instead of relying on manual documentation, spreadsheets, and ad-hoc quality checks, this solution showcases a "Metadata-as-Code" approach where everything is automated.

## Business Value
This demo package solves three major data challenges for an organization:

*   **"Where is my data, and who owns it?" (Data Cataloging)**
    *   It creates a searchable Data Catalog (like a Google Search for your corporate data) where business users can find "Data Products" (e.g., Customer Master Profile, SMS Records).
    *   It automatically attaches key metadata to these products, such as who the owner is, who approves access requests, and links to design specifications.
*   **"Can I trust this data?" (Automated Data Quality)**
    *   It sets up continuous, automated guardrails that scan the data for issues (e.g., verifying phone numbers are formatted correctly, checking for missing values).
    *   It reports these results in a simple Passed/Failed dashboard in the Google Cloud Console.
*   **"Why is our documentation always out of date?" (Automatic Sync)**
    *   It bridges the gap between data developers and business users by automatically syncing documentation directly from the developer's workspace to the cloud catalog.

## The Role of dbt: Automating Documentation
dbt (data build tool) is the industry-standard software that data engineers use to clean and prepare raw data for business analytics.

Typically, there is a gap between the developers (working in dbt code) and the business users (looking for data in a catalog like Knowledge Catalog). This PoC bridges that gap by using dbt as the single source of truth for documentation:

1.  **Document Once**: Data engineers write column descriptions and define governance details (owners, sensitivity levels) directly inside their dbt configuration files.
2.  **Define Data Products logically**: In our configuration files (under `data_products/`), we define Data Products by simply referencing the logical dbt model names (e.g. `dbtModel: customer_demo`) rather than hardcoding physical database paths.
3.  **Automatic Propagation & Asset Resolution**: When the dbt pipeline runs:
    *   It builds the actual tables in BigQuery and pushes the column descriptions there.
    *   It compiles a master blueprint (the `manifest.json`) mapping the logical dbt models to the physical BigQuery paths.
    *   Our sync scripts read this blueprint to dynamically resolve the logical model names, register the Data Products in Dataplex Catalog, and bind the correct physical BigQuery tables as assets.

**The Result**: Zero manual documentation. If a developer updates a description in their code, it is immediately updated in the searchable business catalog on GCP.

The dbt compiles and deploys the underlying data tables in BigQuery, while our sync script reads dbt's configuration to deploy and wire up the Data Product catalog wrapper in Dataplex.

## Demo
The repository runs four scenarios to show different aspects of this governance framework:

*   **Scenario A (SMS Delivery Receipts)**: Registers a logical "SMS" data product in the catalog and sets up automated rules to check that phone numbers are in the correct international format.
*   **Scenario B (Voice Onboarding)**: Simulates voice call logs and checks that connection states are valid and session durations make sense.
*   **Scenario C (Automatic Documentation)**: Demonstrates how technical column descriptions defined by developers automatically flow into the user-facing search catalog.
*   **Scenario D (Advanced Data Products)**: Packages raw database tables into clean, consumer-ready Data Products (e.g. Customer Profile), setting up access approval workflows and attaching business documentation links.

## Run end-to-end
We have simplified the deployment into a single master command. Running this command will provision the database tables, run the data models, set up the quality scans, and publish the catalog.

### Prerequisites (For the IT/GCP team)
Ensure you are logged into your GCP account via the terminal and have selected the target project (`prabha-test`).

### Execution
Run the master script in your terminal:

```bash
./run_all_demos.sh
```

*(Note: Because Dataplex requires a few seconds to register new resources, if running on a completely fresh project, you might need to run the script a second time to complete the catalog sync).*

### View the Results
Once the script completes, you can log into the Google Cloud Console to see the results:

*   **Search the Catalog**: Go to **Dataplex > Search** and search for `customer-master` or `sms-delivery-receipts-demo`. You will see the Data Products populated with descriptions, owners, and contact details.
*   **Verify Data Quality**: Go to **Dataplex > Data Quality** to see the dashboards for `sms-dr-dq-scan` showing whether the phone number format checks passed or failed.
*   **View Database Documentation**: Go to **BigQuery**, select a table (e.g., `sms_delivery_receipts_demo`), and click the **Schema** tab. You will see that the column descriptions are automatically populated.
