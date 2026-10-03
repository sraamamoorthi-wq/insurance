# Insurance Claims Agentic AI Platform — Complete Documentation

## Table of Contents
1. [Project Overview](#1-project-overview)
2. [Architecture](#2-architecture)
3. [Directory Structure](#3-directory-structure)
4. [Deployment Guide](#4-deployment-guide)
5. [DCM Definition Files Reference](#5-dcm-definition-files-reference)
6. [Companion Scripts Reference](#6-companion-scripts-reference)
7. [Agent Stored Procedures Reference](#7-agent-stored-procedures-reference)
8. [Streamlit Apps Reference](#8-streamlit-apps-reference)
9. [Semantic Model Reference](#9-semantic-model-reference)
10. [How the Claims Pipeline Works](#10-how-the-claims-pipeline-works)
11. [How the Underwriting Pipeline Works](#11-how-the-underwriting-pipeline-works)
12. [How the Churn Pipeline Works](#12-how-the-churn-pipeline-works)
13. [Task Automation Reference](#13-task-automation-reference)
14. [RBAC Model](#14-rbac-model)
15. [Cortex AI Services Used](#15-cortex-ai-services-used)
16. [Data Quality](#16-data-quality)
17. [Quick Reference Commands](#17-quick-reference-commands)
18. [Integration Test Suite](#18-integration-test-suite)
19. [Churn Propensity Scoring Model](#19-churn-propensity-scoring-model)
20. [Known Issues and Future Work](#20-known-issues-and-future-work)

---

## 1. Project Overview

This is a Snowflake-native insurance claims processing platform that uses Cortex AI to automate claim intake, fraud detection, settlement assessment, and resolution — replacing manual multi-department workflows with a 5-agent AI pipeline. It also includes underwriting automation, customer churn prediction, and retention action generation.

**Key capabilities:**
- 5-agent claims pipeline (Intake → Validation → Fraud → Assessment → Resolution) — all agents implemented as SQL SPs with Cortex AI, processing 10 claims end-to-end with avg. 15.8s latency
- 3-step underwriting pipeline (Risk Score → Guideline Lookup → Decision)
- Customer 360 profile with 60 features (`FCT_CUSTOMER_360`) + auto-refreshing Dynamic Table (`DT_CUSTOMER_360`)
- Feature-based churn propensity scoring model (9 weighted signals)
- Churn prediction with LLM-generated root cause and retention actions
- 5 Cortex Search services for RAG-grounded AI responses
- 1 Cortex Agent for conversational access to all data
- 4 Streamlit apps: Claims & Policy Intake, Customer 360 Dashboard, NBA Chatbot, IDP Landing Page
- 13-test integration test suite embedded in the IDP Landing Page
- Full RBAC with 5 roles
- 10 data quality expectations (DMFs)
- Event-driven automation via streams + tasks

**Technology stack:** Snowflake DCM, Cortex AI (COMPLETE, CLASSIFY_TEXT, SENTIMENT, EMBED_TEXT_768, PARSE_DOCUMENT, SEARCH, Guardrails), Streamlit in Snowflake (SPCS), Dynamic Tables.

**Team:** IDP @ Data | **Lead:** Raamamoorthi Sundar

**Geography/Currency:** Chennai/Manapakkam, India. All amounts in INR.

---

## 2. Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    INSURANCE_DB                              │
├──────────┬──────────┬──────────┬──────────┐                 │
│   RAW    │ PROCESSED│ RESULTS  │ VECTORS  │                 │
│ 22 tables│ 14 tables│ 3 tables │ 2 tables │                 │
│ 5 stages │ 9 views  │          │          │                 │
│ 5 streams│ 1 DT     │          │          │                 │
│ 1 FF     │ 8 tasks  │          │ 5 Cortex │                 │
│ 2 tags   │ 19 SPs   │          │ Search   │                 │
│          │ 4 UDFs   │          │ Services │                 │
└──────────┴──────────┴──────────┴──────────┘

Data Flow:
  Claims → CLAIMS_LANDING → [5-Agent AI Pipeline] → CLAIM_STATE → RESOLUTIONS
  Applications → APPLICATIONS → [3-Step UW Pipeline] → UNDERWRITING_DECISIONS
  All sources → [5 Agg Views] → DT_CUSTOMER_360 → FCT_CUSTOMER_360 → Churn Scoring
  FCT_CUSTOMER_360 → [SP_CHURN_SCAN] → CHURN_ALERTS → [SP_GENERATE_RETENTION_NBA] → NEXT_BEST_ACTIONS

Streamlit Apps (4):
  IDP Landing Page (hub) → Claims & Policy Intake | Customer 360 Dashboard | NBA Chatbot
```

---

## 3. Directory Structure

```
insurance/
├── insurance-dcm/                          # DCM project (infrastructure-as-code)
│   ├── manifest.yml                        # Account + project config
│   ├── pre_deploy.sql                      # Run BEFORE DCM deploy
│   ├── post_deploy.sql                     # Run AFTER DCM deploy
│   ├── seed_data.sql                       # Sample data inserts
│   ├── insurance_semantic_model.yaml       # Cortex Analyst YAML
│   └── sources/definitions/                # DCM definition files
│       ├── infrastructure.sql              # Schemas, warehouses, stages, tags
│       ├── tables.sql                      # 31 tables
│       ├── views.sql                       # 9 views + 1 secure view
│       ├── procedures.sql                  # 16 SQL stored procedures
│       ├── functions.sql                   # 4 SQL UDFs
│       ├── streams.sql                     # 5 CDC streams
│       ├── tasks.sql                       # 8 tasks
│       ├── access.sql                      # 5 roles + grants
│       ├── analytics.sql                   # 1 Dynamic Table (C360)
│       └── expectations.sql               # 10 DMF expectations
│
├── claim_policy_ui/                        # Streamlit App 1
│   ├── snowflake.yml                       # Deploy config
│   ├── streamlit_app.py                    # 755-line intake forms app
│   ├── pyproject.toml                      # Dependencies
│   ├── .streamlit/config.toml              # Theme config
│   ├── sample_garage_estimate.pdf          # Test document
│   └── sample_police_fir.pdf              # Test document
│
├── customer360-dashboard/                  # Streamlit App 2
│   ├── snowflake.yml                       # Deploy config
│   ├── streamlit_app.py                    # 430-line analytics dashboard (5 tabs)
│   ├── pyproject.toml                      # Dependencies
│   └── .streamlit/config.toml              # Theme config
│
├── nba-chatbot/                            # Streamlit App 3
│   ├── snowflake.yml                       # Deploy config
│   ├── streamlit_app.py                    # Cortex AI chat + NBA generation
│   ├── pyproject.toml                      # Dependencies
│   └── .streamlit/config.toml              # Theme config
│
├── idp-landing/                            # Streamlit App 4 (Hub)
│   ├── snowflake.yml                       # Deploy config
│   ├── streamlit_app.py                    # Landing page + 13-test integration suite
│   ├── pyproject.toml                      # Dependencies
│   └── .streamlit/config.toml              # Theme config
│
├── IDP_Insurance_Hackathon_Deck.md         # Presentation deck (for PPT generation)
│
└── PROJECT_DOCUMENTATION.md                # This file
```

> **Note:** The 5 SQL agent stored procedures (`SP_AGENT_INTAKE` through `SP_AGENT_RESOLUTION`) use Cortex AI (COMPLETE, CLASSIFY_TEXT, SENTIMENT) and are now fully implemented. See [Section 7](#7-agent-stored-procedures-reference).

---

## 4. Deployment Guide

### Prerequisites
- Snowflake account with ACCOUNTADMIN role
- Snowflake CLI v3.16+ (`snow --version`)
- Parent database and schema must exist

### Deployment Order

**Step 1: Create parent containers**
```sql
CREATE DATABASE IF NOT EXISTS INSURANCE_DB;
CREATE SCHEMA IF NOT EXISTS INSURANCE_DB.RAW;
```

**Step 2: Create DCM project object**
```sql
CREATE DCM PROJECT IF NOT EXISTS INSURANCE_DB.RAW.INSURANCE_DCM_PROJECT;
```

**Step 3: Update manifest.yml**
Set `account_identifier` to your account (format: `ORG-ACCOUNT`).

**Step 4: Run pre-deploy script**
```bash
snow sql -f pre_deploy.sql --role ACCOUNTADMIN
```
Creates: notification integration, cross-DB grants, warehouse grants to roles.

**Step 5: DCM analyze → plan → deploy**
```bash
cd insurance/insurance-dcm
snow dcm raw-analyze INSURANCE_DB.RAW.INSURANCE_DCM_PROJECT
snow dcm plan INSURANCE_DB.RAW.INSURANCE_DCM_PROJECT --save-output
snow dcm deploy INSURANCE_DB.RAW.INSURANCE_DCM_PROJECT --alias "v1"
```

**Step 6: Run post-deploy script**
```bash
snow sql -f post_deploy.sql
```
Creates: Cortex Search services, complex UDFs, views, shares, Cortex Agent, bulk grants.

**Step 7: Load sample data**
> **Note:** `seed_data.sql` is currently an empty placeholder. Populate it with INSERT statements for your test data before running, or insert sample data manually.

**Step 8: Create Python agent SPs** <a id="step-8-create-python-agent-sps"></a>
The 5 Python agent stored procedures (`SP_AGENT_INTAKE`, `SP_AGENT_VALIDATION`, `SP_AGENT_FRAUD`, `SP_AGENT_ASSESSMENT`, `SP_AGENT_RESOLUTION`) are not included in the DCM definitions (DCM only supports SQL procedures). Create them manually in Snowsight or via a notebook. See `post_deploy.sql` Section 1 for the procedure list and cell references.

**Step 9: Seed fraud embeddings**
```sql
-- Run the TASK_REFRESH_EMBEDDINGS SQL once manually
MERGE INTO INSURANCE_DB.VECTORS.FRAUD_PATTERN_EMBEDDINGS ...
```

**Step 10: Deploy Streamlit apps**
```sql
CREATE OR REPLACE STREAMLIT INSURANCE_DB.RAW.CLAIM_POLICY_UI
    ROOT_LOCATION = '@<stage_path>'
    MAIN_FILE = 'streamlit_app.py'
    QUERY_WAREHOUSE = AGENT_WH
    COMPUTE_POOL = SYSTEM_COMPUTE_POOL_CPU
    RUNTIME_NAME = 'SYSTEM$ST_CONTAINER_RUNTIME_PY3_11';
```

---

## 5. DCM Definition Files Reference

### 5.1 infrastructure.sql (78 lines)
Defines the foundational Snowflake objects.

| Object Type | Name | Key Properties |
|-------------|------|----------------|
| SCHEMA | `INSURANCE_DB.PROCESSED` | Enriched data, agent outputs, C360, NBA |
| SCHEMA | `INSURANCE_DB.RESULTS` | Final decisions, audit trail |
| SCHEMA | `INSURANCE_DB.VECTORS` | RAG embeddings, fraud patterns |
| WAREHOUSE | `AGENT_WH` | MEDIUM, 1-3 clusters, auto-suspend 60s |
| WAREHOUSE | `EVAL_WH` | X-SMALL, auto-suspend 60s |
| WAREHOUSE | `INGEST_WH` | SMALL, auto-suspend 60s |
| STAGE | `RAW.SEMANTIC_MODELS_STAGE` | Cortex Analyst YAML files |
| STAGE | `RAW.KNOWLEDGE_BASE_STAGE` | RAG knowledge base documents |
| STAGE | `RAW.DOCUMENTS_STAGE` | Claim documents (directory enabled, SSE encrypted) |
| STAGE | `RAW.POLICY_DOCS_STAGE` | Policy application documents (directory enabled) |
| STAGE | `RAW.EVIDENCE_STAGE` | Evidence documents (directory enabled) |
| FILE FORMAT | `RAW.CSV_FORMAT` | CSV with comma delimiter, header skip |
| TAG | `RAW.PII_TAG` | Marks PII columns |
| TAG | `RAW.SENSITIVITY_TAG` | Allowed values: LOW, MEDIUM, HIGH, CRITICAL |

### 5.2 tables.sql (572 lines)
Defines all 31 tables across 4 schemas.

**RAW Schema — Core Tables (8):**

| Table | PK | Purpose | Special Columns |
|-------|-----|---------|-----------------|
| `CUSTOMERS` | customer_id | Customer master | segment, LTV score, KYC status |
| `POLICIES` | policy_id | Policy details | LOB type, premium, coverage, exclusions (VARIANT) |
| `CLAIMS_LANDING` | claim_id (UUID) | Claim intake | claim_text (10K chars), status, metadata (VARIANT) |
| `PROVIDERS` | provider_id | Service providers | risk_flag, fraud_flag_count |
| `INTERACTIONS` | interaction_id | Customer touchpoints | transcript (50K chars), NPS, channel |
| `PAYMENTS` | payment_id | Premium payments | CHANGE_TRACKING=TRUE, days_delayed |
| `APPLICATIONS` | application_id (UUID) | Policy applications | credit_score, asset_details (VARIANT) |
| `DOCUMENTS` | document_id (UUID) | Uploaded documents | extracted_text (100K chars), extraction_status |

**RAW Schema — Reference Tables (6):**

| Table | PK | Purpose |
|-------|-----|---------|
| `FRAUD_INDICATORS` | indicator_id | Historical fraud patterns for RAG |
| `UNDERWRITING_GUIDELINES` | guideline_id | Regulatory guidelines for RAG |
| `RETENTION_PLAYBOOKS` | playbook_id | Churn prevention playbooks for RAG |
| `ACTUARIAL_TABLES` | table_id | Rate tables by LOB/risk/geography |
| `GEOGRAPHIC_RISK` | zipcode | Flood, fire, crime risk scores |
| `CREDIT_BUREAU` | — | Credit scores, delinquencies |

**RAW Schema — LOB-Specific Tables (6):**

| Table | Purpose | Special |
|-------|---------|---------|
| `AUTO_CLAIMS` | Auto-specific claim fields | VECTOR(FLOAT,768) embedding |
| `PROPERTY_CLAIMS` | Property-specific claim fields | VECTOR embedding |
| `WORKERS_COMP_CLAIMS` | WC-specific claim fields | VECTOR embedding |
| `AUTO_POLICY_APPLICATIONS` | Auto policy app details | VIN, mileage |
| `PROPERTY_POLICY_APPLICATIONS` | Property app details | sqft, replacement cost |
| `WORKERS_COMP_POLICY_APPLICATIONS` | WC app details | payroll, OSHA |

**RAW Schema — Document Processing (2):**

| Table | Purpose |
|-------|---------|
| `POLICE_REPORTS` | FIR reports linked to claims |
| `DOCUMENT_REGISTRY` | Document tracking with VECTOR embedding |

**PROCESSED Schema (4 tables):**

| Table | PK | Purpose |
|-------|-----|---------|
| `CLAIM_STATE` | claim_id | Pipeline state machine — stores each agent's VARIANT output |
| `FCT_CUSTOMER_360` | customer_id | 60-column unified customer profile (legacy table, replaced by DT) |
| `CHURN_ALERTS` | alert_id (UUID) | At-risk customer alerts with propensity scores |
| `NEXT_BEST_ACTIONS` | nba_id (UUID) | LLM-generated retention actions |

**RESULTS Schema (3 tables):**

| Table | PK | Purpose |
|-------|-----|---------|
| `RESOLUTIONS` | resolution_id (UUID) | Final claim decisions with settlement amounts |
| `UNDERWRITING_DECISIONS` | decision_id (UUID) | Policy application decisions |
| `AUDIT_LOG` | audit_id (UUID) | Complete agent execution trace |

**VECTORS Schema (2 tables):**

| Table | Purpose | Vector Column |
|-------|---------|--------------|
| `DOCUMENT_CHUNKS` | Parsed document chunks | `chunk_embedding` VECTOR(FLOAT,768) |
| `FRAUD_PATTERN_EMBEDDINGS` | Fraud pattern vectors | `pattern_embedding` VECTOR(FLOAT,768) |

### 5.3 views.sql (149 lines)
Defines 10 views for analytics and data consumption.

| View | Type | Purpose | Key Joins/Functions |
|------|------|---------|---------------------|
| `V_PIPELINE_STATUS` | VIEW | Pipeline monitoring dashboard | CLAIM_STATE + CLAIMS_LANDING + CUSTOMERS |
| `FCT_CUSTOMER_360_VIEW` | VIEW | Wrapper over C360 table | SELECT * FROM FCT_CUSTOMER_360 |
| `V_AGG_POLICY_PORTFOLIO` | VIEW | Per-customer policy aggregation | GROUP BY customer_id from POLICIES |
| `V_AGG_CLAIMS_HISTORY` | VIEW | Per-customer claims aggregation | GROUP BY customer_id from CLAIMS_LANDING |
| `V_AGG_PAYMENT_BEHAVIOR` | VIEW | Per-customer payment patterns | GROUP BY customer_id from PAYMENTS |
| `V_AGG_INTERACTION_SIGNALS` | VIEW | Sentiment + escalation signals | Uses `CORTEX.SENTIMENT()` on transcripts |
| `V_AGG_EMBEDDING_FEATURES` | VIEW | Fraud similarity features | Uses `COMPUTE_FRAUD_SIMILARITY()` UDF |
| `V_CHURN_DASHBOARD` | VIEW | Churn analytics | CHURN_ALERTS + C360 + NBA |
| `V_NBA_FOR_CRM` | **SECURE** | CRM export of pending actions | Filtered: status=PENDING, not expired |

### 5.4 procedures.sql (861 lines)
Defines 16 SQL stored procedures.

**Claims Pipeline Orchestration (2):**

| Procedure | Args | Returns | Purpose |
|-----------|------|---------|---------|
| `SP_PROCESS_CLAIM` | claim_id | VARCHAR | Chains 5 agents sequentially for one claim |
| `SP_PROCESS_ALL_CLAIMS` | — | VARCHAR | Batch: processes up to 20 SUBMITTED claims |

**Customer 360 & Features (3):**

| Procedure | Args | Returns | Purpose |
|-----------|------|---------|---------|
| `SP_BUILD_CUSTOMER_360` | — | VARCHAR | MERGE into FCT_CUSTOMER_360 from 6 agg views |
| `SP_EXTRACT_INTERACTION_FEATURES` | customer_id | VARIANT | LLM extraction: frustration, intent, competitor mentions |
| `SP_EXTRACT_UNSTRUCTURED_FEATURES_BATCH` | — | VARCHAR | Batch LLM extraction for all customers |

**Churn Pipeline (3):**

| Procedure | Args | Returns | Purpose |
|-----------|------|---------|---------|
| `SP_CHURN_SCAN` | — | VARCHAR | INSERT alerts where churn_propensity > 0.6 |
| `SP_CHURN_ROOT_CAUSE` | customer_id | VARIANT | LLM root cause analysis via Cortex COMPLETE |
| `SP_GENERATE_RETENTION_NBA` | customer_id | VARIANT | RAG (Cortex Search playbooks) + LLM action generation |
| `SP_CHURN_PIPELINE_FULL` | — | VARCHAR | Full pipeline: scan → root cause → NBA (up to 100) |

**Document Processing (2):**

| Procedure | Args | Returns | Purpose |
|-----------|------|---------|---------|
| `SP_PROCESS_UPLOADED_DOCUMENT` | document_id | VARIANT | CORTEX.PARSE_DOCUMENT + EMBED_TEXT_768 |
| `SP_PROCESS_ALL_PENDING_DOCUMENTS` | — | VARCHAR | Batch: processes up to 50 PENDING docs |

**Underwriting Pipeline (4):**

| Procedure | Args | Returns | Purpose |
|-----------|------|---------|---------|
| `SP_UW_RISK_SCORE` | app_id | VARIANT | Step 1: Credit score → risk tier → actuarial rate lookup |
| `SP_UW_GUIDELINE_LOOKUP` | app_id, risk_tier | VARIANT | Step 2: Cortex Search for relevant UW guidelines |
| `SP_UW_DECISION` | app_id, risk_output, guideline_output | VARIANT | Step 3: Decision logic + INSERT to UNDERWRITING_DECISIONS |
| `SP_PROCESS_APPLICATION` | app_id | VARCHAR | Orchestrator: chains Steps 1→2→3 via RESULT_SCAN |

### 5.5 functions.sql (45 lines)
Defines 4 SQL UDFs.

| Function | Returns | Cortex Module | Purpose |
|----------|---------|---------------|---------|
| `CLASSIFY_LOB(claim_text)` | VARCHAR | CORTEX.COMPLETE (mistral-large2) | Classifies claim into AUTO/PROPERTY/WORKERS_COMP |
| `CLAIM_SENTIMENT(claim_text)` | FLOAT | CORTEX.SENTIMENT | Returns sentiment score (-1.0 to 1.0) |
| `SUMMARIZE_CLAIM(claim_text)` | VARCHAR | CORTEX.SUMMARIZE | Generates claim summary |
| `COMPUTE_FRAUD_SIMILARITY(claim_text)` | FLOAT | CORTEX.EMBED_TEXT_768 + VECTOR_COSINE_SIMILARITY | Max similarity to known fraud patterns |

### 5.6 streams.sql (33 lines)
Defines 5 CDC streams for event-driven automation.

| Stream | Source Table | Mode | Triggers Task |
|--------|-------------|------|---------------|
| `CLAIMS_LANDING_STREAM` | RAW.CLAIMS_LANDING | APPEND_ONLY | TASK_CLAIMS_ORCHESTRATOR |
| `INTERACTIONS_STREAM` | RAW.INTERACTIONS | APPEND_ONLY | (was TASK_REFRESH_SENTIMENT, now removed) |
| `APPLICATIONS_STREAM` | RAW.APPLICATIONS | APPEND_ONLY | TASK_UNDERWRITING_ORCHESTRATOR |
| `PAYMENTS_STREAM` | RAW.PAYMENTS | DEFAULT | (was TASK_REFRESH_PAYMENTS, now removed) |
| `RESOLUTIONS_STREAM` | RESULTS.RESOLUTIONS | APPEND_ONLY | TASK_POST_DECISION_ACTIONS |

### 5.7 tasks.sql (145 lines)
Defines 8 tasks. See [Task Automation Reference](#13-task-automation-reference).

### 5.8 access.sql (48 lines)
Defines 5 roles and grants. See [RBAC Model](#14-rbac-model).

### 5.9 analytics.sql (62 lines)
Defines 1 Dynamic Table that auto-refreshes Customer 360.

| Object | Warehouse | Target Lag | Source Views |
|--------|-----------|-----------|--------------|
| `DT_CUSTOMER_360` | AGENT_WH | 1 hour | V_AGG_POLICY_PORTFOLIO, V_AGG_CLAIMS_HISTORY, V_AGG_PAYMENT_BEHAVIOR, V_AGG_INTERACTION_SIGNALS |

Replaces the old `SP_BUILD_CUSTOMER_360` + `TASK_BUILD_CUSTOMER_360` pattern. The Dynamic Table auto-refreshes within 1 hour of any source data change.

### 5.10 expectations.sql (63 lines)
Defines 10 data quality expectations. See [Data Quality](#16-data-quality).

---

## 6. Companion Scripts Reference

### 6.1 pre_deploy.sql (25 lines)
**Run BEFORE `snow dcm deploy`. Requires ACCOUNTADMIN.**

| # | Command | Object | Why not in DCM |
|---|---------|--------|----------------|
| 1 | CREATE NOTIFICATION INTEGRATION | CLAIMS_EMAIL_NOTIFICATION | Integrations not DEFINE-able |
| 2 | GRANT DATABASE ROLE | SNOWFLAKE.CORTEX_USER → APP_ROLE | Cross-database grant |
| 3-8 | GRANT USAGE ON WAREHOUSE | 3 warehouses → 4 roles | DCM constraint with warehouse grants |

### 6.2 post_deploy.sql (210 lines)
**Run AFTER `snow dcm deploy`.**

| Section | Objects Created | Count |
|---------|----------------|-------|
| Complex SQL UDF | `FIND_SIMILAR_FRAUD_PATTERNS()` | 1 |
| Info Schema views | `V_TASK_HISTORY`, `V_TASK_STATUS` | 2 |
| Python SP placeholders | Comments referencing SP_AGENT_* procedures | (see Section 7) |
| Cortex Search Services | Fraud, UW Guidelines, Playbooks, Documents, Historical Claims | 5 unique |
| Data Sharing | `RETENTION_ACTIONS_SHARE` + grants | 1 |
| Bulk table grants | SELECT ON ALL TABLES to 3 roles | 4 |
| Cortex Agent | `INSURANCE_AGENT` (uses 4 search services) | 1 |

> **Note:** `CLAIM_DOCUMENTS_SEARCH_SERVICE` is created twice in the script — the second CREATE (sourcing from `DOCUMENT_REGISTRY`) replaces the first (sourcing from `DOCUMENTS`). The final state has 5 unique Cortex Search Services.

### 6.3 seed_data.sql
**Currently an empty placeholder.** Intended to hold sample Manapakkam insurance data for development/testing. Populate with INSERT statements for the following tables before running:

| Table | Suggested Content |
|-------|-------------------|
| CUSTOMERS | HNW, SME, STANDARD segment customers |
| POLICIES | Multi-LOB policies (AUTO, PROPERTY, WORKERS_COMP) |
| CLAIMS_LANDING | Sample claims with claim_text narratives |
| PROVIDERS | In-network and suspicious providers |
| FRAUD_INDICATORS | Known fraud patterns (disaster opportunism, duplicates, staged) |
| UNDERWRITING_GUIDELINES | IRDAI-referenced guidelines by LOB |
| RETENTION_PLAYBOOKS | Churn mitigation playbooks by segment |
| INTERACTIONS | Customer transcripts (calls, chats) |
| PAYMENTS | On-time and delayed premium payments |
| ACTUARIAL_TABLES | Rate tables by LOB/risk/geography |

---

## 7. Agent Stored Procedures Reference

The 5-agent claims pipeline uses **SQL stored procedures with Cortex AI** functions. Each agent writes its output to `CLAIM_STATE` and logs to `AUDIT_LOG`.

### Agent Procedures (5)

| Procedure | Language | Cortex AI Used | Fallback Strategy |
|-----------|----------|----------------|-------------------|
| `SP_AGENT_INTAKE` | SQL | `CLASSIFY_TEXT` (severity classification) | Defaults to "medium" severity |
| `SP_AGENT_VALIDATION` | SQL | Pure SQL (policy status, coverage limits) | Skips policy lookup, marks valid |
| `SP_AGENT_FRAUD` | SQL | `COMPLETE` (llama3.1-8b) for fraud analysis | `SENTIMENT` as proxy score |
| `SP_AGENT_ASSESSMENT` | SQL | `COMPLETE` (llama3.1-8b) for damage assessment | 85% of claimed amount |
| `SP_AGENT_RESOLUTION` | SQL | `COMPLETE` (llama3.1-8b) for reasoning | Rule-based decision from scores |

**Key design decisions:**
- All LLM calls use `TRY/CATCH` with `PARSE_JSON` — if the LLM returns non-JSON, deterministic fallback logic activates
- Fraud score > 0.7 → `REFERRED`, 0.4-0.7 → `PARTIALLY_APPROVED`, < 0.4 → `APPROVED`, policy invalid → `DENIED`
- Each agent logs to `RESULTS.AUDIT_LOG` with cortex_module_used, model_used, latency_ms, and status
- Processing time is tracked end-to-end from CLAIM_STATE.started_at to resolution

### Pipeline Results (current data)

| Metric | Value |
|--------|-------|
| Claims processed | 10 |
| Avg. processing time | 15.8 seconds |
| Approved | 7 |
| Partially Approved | 2 |
| Denied | 1 |
| Audit log entries | 50+ (5 agents × 10 claims) |

### Orchestrator Procedures (2)

| Procedure | Language | Purpose |
|-----------|----------|---------|
| `SP_PROCESS_CLAIM` | SQL | Chains the 5 agents sequentially for one claim |
| `SP_PROCESS_ALL_CLAIMS` | SQL | Batch processor: up to 20 SUBMITTED claims with DQ gate |

---

## 8. Streamlit Apps Reference

### 8.1 Claim Policy UI (`claim_policy_ui/`)

| Property | Value |
|----------|-------|
| **Snowflake object** | `INSURANCE_DB.RAW.CLAIM_POLICY_UI` |
| **Warehouse** | AGENT_WH |
| **Compute Pool** | SYSTEM_COMPUTE_POOL_CPU |
| **Lines of code** | 755 |

**Pages (8):**
1. Auto Claim — vehicle damage claim form
2. Property Claim — property damage claim form
3. Workers Comp Claim — workplace injury claim form
4. Auto Policy Application — new auto policy intake
5. Property Policy Application — new property policy intake
6. Workers Comp Application — new WC policy intake
7. Document Upload — upload PDFs to internal stages
8. Claim Status Dashboard — track claim progress

### 8.2 Customer 360 Dashboard (`customer360-dashboard/`)

| Property | Value |
|----------|-------|
| **Snowflake object** | `INSURANCE_DB.PROCESSED.CUSTOMER360_DASHBOARD` |
| **Warehouse** | COMPUTE_WH |
| **Compute Pool** | MY_STREAMLIT_POOL |
| **Lines of code** | 430 |

**Tabs (5):**
1. Executive Overview — KPIs (total customers, avg churn, sentiment, premium, high-risk count), segment distribution, churn risk bands
2. Portfolio Analytics — policies by LOB, claims by status, monthly claims trend, payment health
3. Churn & Retention — alert KPIs, alerts by trigger, churn vs sentiment scatter, high-risk customer table
4. Customer Deep-Dive — individual customer 360 profile with claims history, payments, interactions, churn alerts, NBA
5. AI Pipeline Monitor — resolution KPIs (approved/denied/partial), decisions by LOB, fraud distribution, agent latency, recent resolutions

### 8.3 NBA Chatbot (`nba-chatbot/`)

| Property | Value |
|----------|-------|
| **Snowflake object** | `INSURANCE_DB.RAW.NBA_CHATBOT` |
| **Warehouse** | COMPUTE_WH |
| **Compute Pool** | SYSTEM_COMPUTE_POOL_CPU |
| **Lines of code** | 198 |

**Features:**
- **Sidebar:** Customer selector (from RAW.CUSTOMERS), channel picker, topic selector, recent interactions viewer
- **Chat UI:** Cortex AI-powered conversation using `CORTEX.COMPLETE` (llama3.1-70b) with streaming
- **Suggestion chips:** Pre-built prompts for common scenarios (claim status, billing, renewal)
- **Interaction logging:** Saves transcript, channel, topic, resolution status, NPS to `RAW.INTERACTIONS`
- **NBA generation:** One-click call to `SP_GENERATE_RETENTION_NBA` for customers with churn alerts
- **NBA viewer:** Shows existing NBAs (action_type, offer_details, channel, timing, status)

### 8.4 IDP Landing Page (`idp-landing/`)

| Property | Value |
|----------|-------|
| **Snowflake object** | `INSURANCE_DB.RAW.IDP_LANDING` |
| **Warehouse** | COMPUTE_WH |
| **Compute Pool** | SYSTEM_COMPUTE_POOL_CPU |
| **Lines of code** | 518 |

**Features:**
- **Hero section:** IDP Insurance branding with shield logo
- **App cards:** 3 cards linking to Claims Intake, Customer 360 Dashboard, and NBA Chatbot
- **Platform stats:** Live metrics (customers, policies, claims, active churn alerts)
- **Integration test suite:** 13 automated tests covering all 3 apps (see [Section 18](#18-integration-test-suite))

---

## 9. Semantic Model Reference

**File:** `insurance_semantic_model.yaml`
**Stage location:** `@INSURANCE_DB.RAW.SEMANTIC_MODELS_STAGE/insurance_semantic_model.yaml`
**Status:** Empty placeholder — not yet populated.

When populated, this file should define the Cortex Analyst semantic model with logical tables and relationships for natural language querying. Recommended tables to include:

| Logical Table | Key Columns |
|---------------|-------------|
| CLAIMS_LANDING | claim_id, lob_type, claim_status, incident_date, claimed_amount |
| RESOLUTIONS | decision, fraud_risk_level, settlement_amount, decided_at |
| CUSTOMERS | customer_id, customer_segment |
| POLICIES | policy_id, lob_type, policy_status, premium, coverage |

Suggested relationships: claims→customers, claims→policies, resolutions→claims.
Suggested verified queries: claims by LOB, approval rate by LOB.

---

## 10. How the Claims Pipeline Works

```
INSERT INTO CLAIMS_LANDING
        │
        ▼ (CLAIMS_LANDING_STREAM detects new row)
        │
        ▼ (TASK_CLAIMS_ORCHESTRATOR fires)
        │
        ▼ CALL SP_PROCESS_CLAIM(claim_id)
        │
   ┌────┴────────────────────────────────────────────┐
   │                                                  │
   │  1. SP_AGENT_INTAKE (SQL)                        │
   │     • Cortex CLASSIFY_TEXT (severity)             │
   │     • Classifies: low/medium/high/critical        │
   │     • Fallback: defaults to "medium"             │
   │     • Writes: CLAIM_STATE.intake_output          │
   │                                                  │
   │  2. SP_AGENT_VALIDATION (SQL)                    │
   │     • Pure SQL policy lookup                     │
   │     • Checks: status, LOB match, coverage limits  │
   │     • Writes: CLAIM_STATE.validation_output      │
   │                                                  │
   │  3. SP_AGENT_FRAUD (SQL)                         │
   │     • Cortex COMPLETE (llama3.1-8b)              │
   │     • JSON fraud analysis with TRY/CATCH          │
   │     • Fallback: SENTIMENT as proxy score          │
   │     • Composite fraud score (0-1)                 │
   │     • Writes: CLAIM_STATE.fraud_output           │
   │                                                  │
   │  4. SP_AGENT_ASSESSMENT (SQL)                    │
   │     • Cortex COMPLETE (llama3.1-8b)              │
   │     • Recommends settlement, confidence, category │
   │     • Fallback: 85% of claimed amount            │
   │     • Writes: CLAIM_STATE.assessment_output      │
   │                                                  │
   │  5. SP_AGENT_RESOLUTION (SQL)                    │
   │     • Cortex COMPLETE (llama3.1-8b) for reasoning│
   │     • Decision rules:                             │
   │       - fraud > 0.7 → REFERRED                   │
   │       - validation failed → DENIED               │
   │       - fraud 0.4-0.7 → PARTIALLY_APPROVED       │
   │       - else → APPROVED                          │
   │     • Writes: RESOLUTIONS + CLAIM_STATE          │
   │                                                  │
   └──────────────────────────────────────────────────┘
        │
        ▼ (RESOLUTIONS_STREAM detects new row)
        │
        ▼ (TASK_POST_DECISION_ACTIONS fires)
           • INSERT audit log entry
```

**Each agent logs to AUDIT_LOG** with: flow_type, agent_name, step_number, cortex_module_used, tokens, latency, status.

---

## 11. How the Underwriting Pipeline Works

```
INSERT INTO APPLICATIONS
        │
        ▼ (APPLICATIONS_STREAM detects new row)
        │
        ▼ (TASK_UNDERWRITING_ORCHESTRATOR fires)
        │
        ▼ CALL SP_PROCESS_APPLICATION(app_id)
        │
   ┌────┴────────────────────────────────────────┐
   │                                              │
   │  1. SP_UW_RISK_SCORE (SQL)                   │
   │     • Credit score → risk tier (LOW/MED/HIGH)│
   │     • Actuarial table lookup (rates, factors) │
   │     • Existing customer discount (10%)        │
   │     • Output: recommended_premium             │
   │                                              │
   │  2. SP_UW_GUIDELINE_LOOKUP (SQL)             │
   │     • Cortex Search: UW guidelines by LOB+risk│
   │     • Returns top 3 matching guidelines       │
   │                                              │
   │  3. SP_UW_DECISION (SQL)                     │
   │     • LOW risk → auto-approved               │
   │     • MEDIUM → manual review                 │
   │     • HIGH → senior UW, premium * 1.5x       │
   │     • INSERT → UNDERWRITING_DECISIONS        │
   │     • UPDATE → APPLICATIONS.status           │
   │     • INSERT → AUDIT_LOG                     │
   │                                              │
   └──────────────────────────────────────────────┘
```

---

## 12. How the Churn Pipeline Works

```
Daily at 6 AM UTC (TASK_EXTRACT_UNSTRUCTURED_FEATURES)
        │
        ▼ SP_EXTRACT_UNSTRUCTURED_FEATURES_BATCH
        │  • For each customer with recent interactions:
        │    - Cortex COMPLETE: extract frustration, intent, competitor mentions
        │    - UPDATE FCT_CUSTOMER_360 unstructured columns
        │
        ▼ (TASK_CHURN_SCAN — DAG child)
        │
        ▼ SP_CHURN_SCAN
        │  • Query DT_CUSTOMER_360 for risk signals:
        │    - sentiment < -0.3
        │    - missed_payments > 2
        │    - complaint_count_90d > 1
        │    - days_to_renewal < 60
        │  • INSERT into CHURN_ALERTS (propensity score + trigger reason)
        │
        ▼ (TASK_CHURN_NBA — DAG child)
        │
        ▼ SP_CHURN_PIPELINE_FULL
           • For each new alert (up to 100):
             1. SP_CHURN_ROOT_CAUSE → LLM root cause analysis
             2. SP_GENERATE_RETENTION_NBA →
                - Cortex Search: retrieve matching playbooks
                - Cortex COMPLETE: generate personalized actions
             3. INSERT into NEXT_BEST_ACTIONS
```

---

## 13. Task Automation Reference

### Event-Driven Tasks (3)

| Task | Schedule | Stream Trigger | Action |
|------|----------|----------------|--------|
| `TASK_CLAIMS_ORCHESTRATOR` | 1 min poll | CLAIMS_LANDING_STREAM | Processes new claims through 5-agent pipeline |
| `TASK_UNDERWRITING_ORCHESTRATOR` | 1 min poll | APPLICATIONS_STREAM | Processes new applications through 3-step UW pipeline |
| `TASK_POST_DECISION_ACTIONS` | 1 min poll | RESOLUTIONS_STREAM | Audit logging for new decisions |

### Scheduled DAG (3 tasks)

```
TASK_EXTRACT_UNSTRUCTURED_FEATURES [6 AM UTC daily, AGENT_WH]
  └→ TASK_CHURN_SCAN [EVAL_WH]
       └→ TASK_CHURN_NBA [AGENT_WH]
```

### Standalone Scheduled Tasks (2)

| Task | Schedule | Warehouse | Action |
|------|----------|-----------|--------|
| `TASK_REFRESH_EMBEDDINGS` | Sunday 2 AM UTC | AGENT_WH | MERGE fraud pattern vectors |
| `TASK_HEALTH_CHECK` | Every 3 hours | EVAL_WH | Mark stuck claims FAILED, log system health |

**All tasks are created SUSPENDED.** To activate:
```sql
ALTER TASK INSURANCE_DB.PROCESSED.TASK_CLAIMS_ORCHESTRATOR RESUME;
```

---

## 14. RBAC Model

```
ACCOUNTADMIN
  └── SYSADMIN
        └── INSURANCE_ADMIN_ROLE
              ├── INSURANCE_APP_ROLE
              ├── INSURANCE_ADJUSTER_ROLE
              ├── INSURANCE_UNDERWRITER_ROLE
              └── INSURANCE_RETENTION_ROLE
```

| Role | Purpose | Access |
|------|---------|--------|
| `INSURANCE_APP_ROLE` | Pipeline execution | ALL on RAW, PROCESSED, RESULTS, VECTORS + Cortex + 3 warehouses |
| `INSURANCE_ADJUSTER_ROLE` | Claims adjusters | SELECT on RESULTS + PROCESSED + AGENT_WH |
| `INSURANCE_UNDERWRITER_ROLE` | Underwriters | SELECT on RESULTS + RAW + AGENT_WH |
| `INSURANCE_RETENTION_ROLE` | Retention analysts | SELECT on PROCESSED + EVAL_WH |
| `INSURANCE_ADMIN_ROLE` | Database admin | Inherits all 4 roles above |

---

## 15. Cortex AI Services Used

| Service | Model/Config | Where Used | Purpose |
|---------|-------------|-----------|---------|
| `CORTEX.COMPLETE` | llama3.1-8b | Fraud agent (RAG-grounded), Assessment agent (RAG-grounded), Resolution agent | Fraud analysis with search context, guideline-based assessment, decision reasoning |
| `CORTEX.COMPLETE` | llama3.1-70b | NBA Chatbot | Customer service conversation with streaming |
| `CORTEX.COMPLETE` | llama3.3-70b | SP_GENERATE_RETENTION_NBA (RAG-grounded), SP_CHURN_ROOT_CAUSE | NBA generation with playbook RAG, root cause analysis |
| `CORTEX.CLASSIFY_TEXT` | snowflake-arctic | SP_AGENT_INTAKE | Claim severity classification |
| `CORTEX.SENTIMENT` | default | SP_AGENT_FRAUD, V_AGG_INTERACTION_SIGNALS | Sentiment scoring (-1 to 1) — used in fraud composite score |
| `CORTEX.SUMMARIZE` | default | SUMMARIZE_CLAIM UDF | Claim text summarization |
| `CORTEX.EMBED_TEXT_768` | snowflake-arctic-embed-m | COMPUTE_FRAUD_SIMILARITY, document processing, TASK_REFRESH_EMBEDDINGS | Vector embeddings (768-dim) for fraud pattern matching |
| `CORTEX.PARSE_DOCUMENT` | default | SP_PROCESS_UPLOADED_DOCUMENT | PDF text extraction (OCR) |
| `CORTEX.SEARCH_PREVIEW` | — | SP_AGENT_FRAUD (fraud patterns RAG), SP_AGENT_ASSESSMENT (UW guidelines RAG), SP_GENERATE_RETENTION_NBA (playbooks RAG) | Semantic search + retrieval for grounding LLM responses |

### Cortex Search Services (5)

| Service | Schema | Source Table | Search Column | Attributes | Consumers |
|---------|--------|-------------|---------------|------------|-----------|
| `FRAUD_INDICATORS_SEARCH_SERVICE` | VECTORS | RAW.FRAUD_INDICATORS | pattern_description | pattern_type, lob_type, severity | SP_AGENT_FRAUD |
| `UNDERWRITING_GUIDELINES_SEARCH_SERVICE` | VECTORS | RAW.UNDERWRITING_GUIDELINES | content | lob_type, risk_level, section_name | SP_AGENT_ASSESSMENT, SP_UW_GUIDELINE_LOOKUP |
| `RETENTION_PLAYBOOKS_SEARCH_SERVICE` | VECTORS | RAW.RETENTION_PLAYBOOKS | content | customer_segment, root_cause, applicable_lob | SP_GENERATE_RETENTION_NBA |
| `CLAIMS_HISTORY_SEARCH_SERVICE` | VECTORS | RAW.CLAIMS_LANDING | claim_text | lob_type, claim_status, customer_id | Fraud pattern analysis |
| `INTERACTIONS_SEARCH_SERVICE` | VECTORS | RAW.INTERACTIONS | transcript_text | customer_id, channel, topic, resolution_status | Customer interaction analysis |

All services use `TARGET_LAG = '1 hour'`, `WAREHOUSE = AGENT_WH`, and auto-embedded `snowflake-arctic-embed-m-v1.5`.

---

## 16. Data Quality

### DMFs Deployed (live, attached to tables)

All DMFs use `DATA_METRIC_SCHEDULE = 'TRIGGER_ON_CHANGES'` and run automatically when data changes.

| Table | Metric | Column(s) | Expectation | Status |
|-------|--------|-----------|-------------|--------|
| CLAIMS_LANDING | NULL_COUNT | claim_id | CLAIMS_NO_NULL_ID (VALUE = 0) | STARTED |
| CLAIMS_LANDING | NULL_COUNT | claimed_amount | — | STARTED |
| CLAIMS_LANDING | NULL_COUNT | claim_text | — | STARTED |
| CLAIMS_LANDING | DUPLICATE_COUNT | claim_id | — | STARTED |
| CLAIMS_LANDING | REFERENTIAL_INTEGRITY_COUNT | customer_id → CUSTOMERS(customer_id) | CLAIMS_VALID_CUSTOMER (VALUE = 0) | STARTED |
| CUSTOMERS | NULL_COUNT | customer_id | — | STARTED |
| CUSTOMERS | NULL_COUNT | email | — | STARTED |
| CUSTOMERS | DUPLICATE_COUNT | customer_id | — | STARTED |
| POLICIES | NULL_COUNT | customer_id | — | STARTED |
| POLICIES | DUPLICATE_COUNT | policy_id | — | STARTED |
| FCT_CUSTOMER_360 | NULL_COUNT | customer_id | C360_NO_NULL_ID (VALUE = 0) | STARTED |
| FCT_CUSTOMER_360 | DUPLICATE_COUNT | customer_id | — | STARTED |
| CHURN_ALERTS | NULL_COUNT | customer_id | ALERTS_NO_NULL_CUSTOMER (VALUE = 0) | STARTED |
| RESOLUTIONS | NULL_COUNT | settlement_amount | — | STARTED |
| RESOLUTIONS | DUPLICATE_COUNT | claim_id | — | STARTED |
| RESOLUTIONS | REFERENTIAL_INTEGRITY_COUNT | claim_id → CLAIMS_LANDING(claim_id) | RESOLUTIONS_VALID_CLAIM (VALUE = 0) | STARTED |

### Key Design Decisions
- **TRIGGER_ON_CHANGES** — DMFs fire when data changes, not on a cron schedule, so there's zero lag between data insertion and quality check
- **Referential integrity** — CLAIMS_LANDING → CUSTOMERS and RESOLUTIONS → CLAIMS_LANDING are cross-table FK checks, catching orphan rows from the pipeline
- **Pipeline integration** — DMFs cover every table the 5-agent claims pipeline writes to (CLAIMS_LANDING → CLAIM_STATE → RESOLUTIONS), plus the feature store (FCT_CUSTOMER_360) and churn pipeline (CHURN_ALERTS)

---

## 17. Quick Reference Commands

### DCM Operations
```bash
# Validate definitions
snow dcm raw-analyze INSURANCE_DB.RAW.INSURANCE_DCM_PROJECT

# Preview changes
snow dcm plan INSURANCE_DB.RAW.INSURANCE_DCM_PROJECT --save-output

# Deploy
snow dcm deploy INSURANCE_DB.RAW.INSURANCE_DCM_PROJECT --alias "description"

# View deployment history
snow dcm list-deployments INSURANCE_DB.RAW.INSURANCE_DCM_PROJECT
```

### Process a Claim (manual)
```sql
-- Insert a claim
INSERT INTO INSURANCE_DB.RAW.CLAIMS_LANDING (claim_id, policy_id, customer_id, claim_text,
    incident_date, claimed_amount, lob_type, incident_location)
VALUES ('CLM-TEST', 'POL-AUTO-001', 'CUST001', 'Description...', '2025-01-15', 350000, 'AUTO', 'Chennai');

-- Process it through the 5-agent pipeline
CALL INSURANCE_DB.PROCESSED.SP_PROCESS_CLAIM('CLM-TEST');

-- View results
SELECT * FROM INSURANCE_DB.PROCESSED.V_PIPELINE_STATUS WHERE claim_id = 'CLM-TEST';
SELECT * FROM INSURANCE_DB.RESULTS.RESOLUTIONS WHERE claim_id = 'CLM-TEST';
```

### Process an Application (manual)
```sql
INSERT INTO INSURANCE_DB.RAW.APPLICATIONS (application_id, applicant_name, lob_type,
    coverage_requested, credit_score, geographic_zone, existing_customer_id)
VALUES ('APP-TEST', 'Test Applicant', 'AUTO', 500000, 720, 'CHENNAI_GENERAL', 'CUST001');

CALL INSURANCE_DB.PROCESSED.SP_PROCESS_APPLICATION('APP-TEST');

SELECT * FROM INSURANCE_DB.RESULTS.UNDERWRITING_DECISIONS WHERE application_id = 'APP-TEST';
```

### Resume All Tasks
```sql
ALTER TASK INSURANCE_DB.PROCESSED.TASK_CLAIMS_ORCHESTRATOR RESUME;
ALTER TASK INSURANCE_DB.PROCESSED.TASK_UNDERWRITING_ORCHESTRATOR RESUME;
ALTER TASK INSURANCE_DB.PROCESSED.TASK_EXTRACT_UNSTRUCTURED_FEATURES RESUME;
ALTER TASK INSURANCE_DB.PROCESSED.TASK_CHURN_SCAN RESUME;
ALTER TASK INSURANCE_DB.PROCESSED.TASK_CHURN_NBA RESUME;
ALTER TASK INSURANCE_DB.RESULTS.TASK_POST_DECISION_ACTIONS RESUME;
ALTER TASK INSURANCE_DB.VECTORS.TASK_REFRESH_EMBEDDINGS RESUME;
ALTER TASK INSURANCE_DB.PROCESSED.TASK_HEALTH_CHECK RESUME;
```

### Query Cortex Agent
```sql
SELECT SNOWFLAKE.CORTEX.AGENT(
    'INSURANCE_DB.PROCESSED.INSURANCE_AGENT',
    'What fraud patterns are most common in auto claims?'
);
```

---

## 18. Integration Test Suite

The IDP Landing Page (`idp-landing/streamlit_app.py`) includes a **13-test automated integration suite** that validates all 3 operational apps end-to-end. Tests are self-cleaning — they insert test data, validate, and delete it.

### Test Inventory

| # | Test Name | App Covered | What It Validates |
|---|-----------|-------------|-------------------|
| 1 | Source Tables Populated | All | RAW.CUSTOMERS, POLICIES, CLAIMS_LANDING, PAYMENTS, INTERACTIONS, PROVIDERS all have data |
| 2 | Feature Store Populated | Dashboard | FCT_CUSTOMER_360 and DT_CUSTOMER_360 are non-empty |
| 3 | LOB Tables Exist | Claims Intake | AUTO_CLAIMS, PROPERTY_CLAIMS, WORKERS_COMP_CLAIMS, and 3 application tables + DOCUMENT_REGISTRY |
| 4 | Internal Stages Exist | Claims Intake | DOCUMENTS_STAGE, EVIDENCE_STAGE, POLICY_DOCS_STAGE |
| 5 | Claim Submission E2E | Claims Intake | Insert claim → retrieve ID → seed CLAIM_STATE → verify in V_PIPELINE_STATUS → cleanup |
| 6 | Chatbot Interaction Flow | NBA Chatbot | Insert interaction into RAW.INTERACTIONS → verify queryable → cleanup |
| 7 | NBA Generation Pipeline | NBA Chatbot | Find customer with churn alert → call SP_GENERATE_RETENTION_NBA → verify NBA count increases → cleanup |
| 8 | Dashboard: Executive Overview | Dashboard | KPI query returns data, segment breakdown works |
| 9 | Dashboard: Portfolio Analytics | Dashboard | LOB breakdown, claim status queries work |
| 10 | Dashboard: Churn & Retention | Dashboard | Churn alerts join to FCT_CUSTOMER_360, V_CHURN_DASHBOARD works |
| 11 | Dashboard: Customer Deep-Dive | Dashboard | Customer profile loads, claims/payments queryable |
| 12 | Dashboard: AI Pipeline Monitor | Dashboard | V_PIPELINE_STATUS, RESOLUTIONS, AUDIT_LOG queries work |
| 13 | IDP Landing Page Stats | IDP Landing | All 4 stat queries return non-zero values |

### Running Tests

Open the IDP Landing Page Streamlit app and expand the **Integration Test Suite** section at the bottom. Click **Run All Tests**.

---

## 19. Churn Propensity Scoring Model

`FCT_CUSTOMER_360.churn_propensity_score` is computed using a feature-based scoring model with 9 weighted signals. The score ranges from 0.0 (no risk) to 1.0 (maximum risk).

### Scoring Formula

| Signal | Condition | Score Contribution |
|--------|-----------|-------------------|
| **Payment behavior** | missed_payments_12m >= 3 | +0.30 |
| | missed_payments_12m >= 1 | +0.15 |
| **Sentiment** | sentiment_score_last_30d < -0.5 | +0.25 |
| | sentiment_score_last_30d < -0.2 | +0.15 |
| **Complaints** | complaint_count_90d >= 5 | +0.20 |
| | complaint_count_90d >= 3 | +0.15 |
| **Renewal proximity** | days_to_nearest_renewal <= 30 | +0.15 |
| | days_to_nearest_renewal <= 60 | +0.08 |
| **Payment regularity** | payment_regularity_score < 0.5 | +0.15 |
| | payment_regularity_score < 0.7 | +0.08 |
| **Escalation** | escalation_flag = TRUE | +0.10 |
| **Loss ratio** | lifetime_loss_ratio > 2.0 | +0.10 |
| **Low NPS** | nps_score_latest <= 3 | +0.15 |
| | nps_score_latest <= 5 | +0.08 |
| **Lapse history** | lapse_count_historical > 0 | +0.10 |
| **Tenure (protective)** | tenure_months > 60 | -0.10 |
| | tenure_months > 36 | -0.05 |
| **LTV (protective)** | lifetime_value_score > 80 | -0.05 |
| **Base** | (always applied) | +0.08 |

Final score is clamped to [0.0, 1.0] and rounded to 2 decimal places.

### Usage in Churn Pipeline

- `SP_CHURN_SCAN` creates alerts for customers with `churn_propensity_score > 0.5`
- `SP_GENERATE_RETENTION_NBA` generates personalized retention offers for alerted customers
- The Customer 360 Dashboard displays churn scores on the Executive Overview and Churn & Retention tabs

---

## 20. Known Issues and Future Work

### Known Issues
1. **SP_BUILD_CUSTOMER_360** — `V_AGG_EMBEDDING_FEATURES` uses a UDF with a correlated subquery that fails inside MERGE. Embedding features (fraud_similarity_score, claim_cluster_id, provider_anomaly_score) are defaulted to 0. Fix: materialize embedding features into a table before joining.
2. **LOB mismatch** — Seed data policies use LOB types `AUTO`, `HOME`, `LIFE`, but the Property claim form expects `PROPERTY`. Claims submitted for HOME policies via the Property form will fail validation.
3. **Sentiment defaults to 0** — `V_AGG_INTERACTION_SIGNALS` computes sentiment only for interactions within the last 30 days. Historical seed data interactions are from 2024, so sentiment is 0 for most customers.

### Resolved in this version
- **Cortex Search services** — 5 services now created and ACTIVE (previously 0)
- **Reference tables** — FRAUD_INDICATORS (10 rows), UNDERWRITING_GUIDELINES (10 rows), ACTUARIAL_TABLES (15 rows) all populated
- **FRAUD_PATTERN_EMBEDDINGS** — 10 patterns embedded; `COMPUTE_FRAUD_SIMILARITY` now returns real scores (0.73-0.82)
- **SP_AGENT_* procedures** — All 5 agents implemented as SQL SPs with Cortex AI (previously missing)
- **DMFs** — 16 DMFs attached with TRIGGER_ON_CHANGES schedules and expectations (previously 0 active)
- **Agent pipeline** — RAG-grounded via Cortex Search: fraud agent uses search + vector + sentiment, assessment uses UW guidelines search, NBA uses playbook search

### Future Work
- Create Cortex Agent (INSURANCE_AGENT) for conversational access to all data
- Add Cortex Guardrails to Resolution agent for PII-safe output filtering
- Build a semantic model for Cortex Analyst natural language querying
- Add incremental churn propensity scoring via a scheduled task
- Add more customers and claims data for richer dashboard visualizations
- Materialize embedding features to fix SP_BUILD_CUSTOMER_360 MERGE error
