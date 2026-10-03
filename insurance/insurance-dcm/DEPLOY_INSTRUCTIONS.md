# Insurance DCM Project — Deployment to a New Account

## CoCo Prompt

Copy-paste the following into CoCo on the target account. Replace the two placeholders first.

---

```
Deploy the Insurance DCM project from this workspace's `insurance/insurance-dcm/` directory.

BEFORE YOU START:
1. Update manifest.yml — set the PROD target:
   - account_identifier: <PASTE_YOUR_ACCOUNT_IDENTIFIER>  (e.g. AB12345.us-east-2.aws)
   - project_owner: <YOUR_USERNAME>

STEP 1 — Create parent containers (DCM cannot define its own parent DB/schema):
   CREATE DATABASE IF NOT EXISTS INSURANCE_DB;
   CREATE SCHEMA IF NOT EXISTS INSURANCE_DB.RAW;

STEP 2 — Run pre_deploy.sql with ACCOUNTADMIN role.
   NOTE: Update the ALLOWED_RECIPIENTS email address in the notification integration
   to the correct email for this account before running.

STEP 3 — Deploy DCM:
   cd insurance/insurance-dcm
   snow dcm raw-analyze INSURANCE_DB.RAW.INSURANCE_DCM_PROJECT -c default --target PROD
   snow dcm plan INSURANCE_DB.RAW.INSURANCE_DCM_PROJECT -c default --target PROD --save-output
   Review the plan — everything should be CREATE (fresh account). Then:
   snow dcm deploy INSURANCE_DB.RAW.INSURANCE_DCM_PROJECT -c default --target PROD --alias initial-setup

STEP 4 — Run post_deploy.sql with ACCOUNTADMIN role.
   This creates: complex UDFs, Cortex Search services, data shares, table-level grants,
   and the Cortex Agent. Review and adjust warehouse/share settings if needed.

STEP 5 — Run seed_data.sql if it contains seed data.

STEP 6 — Resume tasks (they are created SUSPENDED by default):
   ALTER TASK INSURANCE_DB.PROCESSED.TASK_BUILD_CUSTOMER_360 RESUME;
   ALTER TASK INSURANCE_DB.PROCESSED.TASK_CLAIMS_ORCHESTRATOR RESUME;
   ALTER TASK INSURANCE_DB.PROCESSED.TASK_REFRESH_SENTIMENT RESUME;
   ALTER TASK INSURANCE_DB.RESULTS.TASK_POST_DECISION_ACTIONS RESUME;
   ALTER TASK INSURANCE_DB.PROCESSED.TASK_REFRESH_PAYMENTS RESUME;
   ALTER TASK INSURANCE_DB.VECTORS.TASK_REFRESH_EMBEDDINGS RESUME;
   ALTER TASK INSURANCE_DB.PROCESSED.TASK_HEALTH_CHECK RESUME;
   NOTE: Child tasks (TASK_EXTRACT_UNSTRUCTURED_FEATURES, TASK_CHURN_SCAN, TASK_CHURN_NBA)
   are triggered by their parents — resume them too:
   ALTER TASK INSURANCE_DB.PROCESSED.TASK_EXTRACT_UNSTRUCTURED_FEATURES RESUME;
   ALTER TASK INSURANCE_DB.PROCESSED.TASK_CHURN_SCAN RESUME;
   ALTER TASK INSURANCE_DB.PROCESSED.TASK_CHURN_NBA RESUME;

STEP 7 — Deploy Streamlit apps (separate from DCM):
   cd insurance/claim_policy_ui
   snow streamlit deploy -c default
   cd ../customer360-dashboard
   snow streamlit deploy -c default

Report the results of each step.
```

---

## What Gets Deployed

### Via DCM (Step 3)
- 6 schemas: RAW (pre-existing), PROCESSED, RESULTS, VECTORS, FEATURES, STAGES
- 3 warehouses: AGENT_WH, EVAL_WH, INGEST_WH
- 22 tables across RAW, PROCESSED, RESULTS, VECTORS schemas
- 5 streams (CDC on CLAIMS_LANDING, APPLICATIONS, INTERACTIONS, PAYMENTS, RESOLUTIONS)
- 10 tasks (event-driven + scheduled DAG)
- 6 internal stages (3 in STAGES, 3 in RAW)
- 3 SQL functions (classify, sentiment, summarize)
- 4+ SQL stored procedures (orchestration, claim processing, document parsing)
- 5 roles + role hierarchy + grants
- 10 views (pipeline status, Customer 360, aggregations, churn dashboard)
- File format, tags, data quality expectations

### Via post_deploy.sql (Step 4)
- 1 complex SQL UDF (FIND_SIMILAR_FRAUD_PATTERNS)
- 2 INFORMATION_SCHEMA views (V_TASK_HISTORY, V_TASK_STATUS)
- 6 Cortex Search services (fraud, underwriting, retention, documents, claims)
- 1 Cortex Agent (INSURANCE_AGENT)
- 1 data share (RETENTION_ACTIONS_SHARE)
- Table-level grants (ON ALL TABLES)

### Via pre_deploy.sql (Step 2)
- 1 notification integration (EMAIL)
- Cortex user role grant
- Warehouse usage grants

## Account-Specific Values to Update

| File | Value | What to Change |
|------|-------|----------------|
| `manifest.yml` | `account_identifier` in PROD target | Target account identifier |
| `manifest.yml` | `project_owner` in PROD target | Deploying user's username |
| `pre_deploy.sql` | `ALLOWED_RECIPIENTS` | Email address for notifications |
| `post_deploy.sql` | Share recipients | Add consumer accounts if needed |

## Prerequisites on Target Account

- Snowflake CLI v3.17+ installed
- ACCOUNTADMIN role access (for integrations, Cortex grants, shares)
- Cortex AI functions available in the account's region
- Sufficient warehouse credits for Cortex Search service indexing
