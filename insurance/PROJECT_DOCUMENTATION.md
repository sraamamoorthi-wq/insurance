# Insurance Claims Agentic AI Platform — Complete Documentation

## Table of Contents
0. [Start Here: End-to-End Data Flow (Beginner's Guide)](#0-start-here-end-to-end-data-flow-beginners-guide)
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

## 0. Start Here: End-to-End Data Flow (Beginner's Guide)

This section explains the whole platform in plain language. You do not need to know Snowflake beforehand. Read it top to bottom once and the rest of this document will make sense.

### 0.1 Five words you need to know first

| Term | Plain-English meaning | Analogy |
|------|----------------------|---------|
| **Table** | Where data is stored, in rows and columns | A spreadsheet tab |
| **Stream** | A "change tracker" on a table. It remembers which rows are new since the last time someone looked | A "new mail" badge on an inbox |
| **Task** | A scheduled job. It wakes up on a timer (e.g. every 1 minute) and runs some work, optionally only if a stream has new rows | An alarm clock that checks the inbox |
| **Stored Procedure (SP)** | A saved program that runs inside Snowflake. In this project, each "AI agent" is a stored procedure | A worker who follows a written checklist |
| **Cortex AI** | Snowflake's built-in AI functions: `COMPLETE` (ask an LLM a question), `CLASSIFY_TEXT`, `SENTIMENT`, `EMBED_TEXT_768` (turn text into numbers for similarity search), `PARSE_DOCUMENT` (read a PDF), and **Cortex Search** (look up relevant reference documents) | A smart assistant the worker can consult |

> **What is an "agent" here?** An agent is simply a stored procedure that does one focused job (e.g. "check for fraud"), uses Cortex AI to reason about the data, writes its answer down, and hands off to the next agent. Five agents in a row form the claims "pipeline", like an assembly line.

### 0.2 The big picture (one diagram)

```
                         ┌──────────────────────────────────────────┐
                         │      IDP LANDING PAGE  (Streamlit app)    │
                         │      idp-landing/streamlit_app.py         │
                         └──────────────────────────────────────────┘
                             │              │              │            │
            ┌────────────────┘              │              │            └───────────────┐
            ▼                               ▼              ▼                            ▼
 ┌─────────────────────┐   ┌──────────────────────┐  ┌──────────────────┐   ┌──────────────────────┐
 │ A. New Claim form   │   │ B. Policy Application│  │ C. Document      │   │ D. Intelligent Chat  │
 │                     │   │    form              │  │    Upload        │   │  (Agent / Customer)  │
 └─────────────────────┘   └──────────────────────┘  └──────────────────┘   └──────────────────────┘
            │                          │                      │                        │
            ▼                          ▼                      ▼                        ▼
   RAW.CLAIMS_LANDING     RAW.AUTO_ / PROPERTY_ /     RAW.DOCUMENTS_STAGE        Cortex COMPLETE
   (+ DOCUMENT_REGISTRY)  WORKERS_COMP_POLICY_        (file)  +                  (answer shown on
            │             APPLICATIONS                RAW.DOCUMENT_REGISTRY       screen) and
            │                          │              (row, status=PENDING)      RAW.INTERACTIONS
            ▼                          ▼                      │                  (chat logged)
  ┌───────────────────┐   ┌──────────────────────┐            ▼                        │
  │ CLAIMS PIPELINE   │   │ UNDERWRITING PIPELINE│   ┌──────────────────┐            │
  │ 5 AI agents       │   │ 3 steps              │   │ DOCUMENT PIPELINE│            │
  │ (section 0.4)     │   │ (section 0.5)        │   │ PARSE + EMBED    │            │
  └───────────────────┘   └──────────────────────┘   │ (section 0.6)    │            │
            │                          │              └──────────────────┘            │
            ▼                          ▼                                              │
   RESULTS.RESOLUTIONS     PROCESSED.UNDERWRITING_                                    │
   (decision)              DECISIONS                                                  │
            │                                                                         │
            └──────────────────────────────┬──────────────────────────────────────────┘
                                           ▼
            ┌──────────────────────────────────────────────────────────────┐
            │ CUSTOMER 360  (one row per customer, ~60 features)           │
            │ PROCESSED.DT_CUSTOMER_360 (auto-refresh ≤ 1 hour)             │
            │ PROCESSED.FCT_CUSTOMER_360 (scored table used by the app)     │
            └──────────────────────────────────────────────────────────────┘
                                           │
                                           ▼  daily 6 AM UTC
            ┌──────────────────────────────────────────────────────────────┐
            │ CHURN & RETENTION PIPELINE  (section 0.7)                    │
            │ → PROCESSED.CHURN_ALERTS → PROCESSED.NEXT_BEST_ACTIONS        │
            └──────────────────────────────────────────────────────────────┘
                                           │
                                           ▼
            Back to the IDP Landing Page: Customer 360 dashboard + Chat side panel
```

### 0.3 Where data lives (the four "schemas")

Think of `INSURANCE_DB` as a filing cabinet with four drawers:

| Drawer (schema) | What goes in it | Examples |
|-----------------|-----------------|----------|
| `RAW` | Data exactly as it arrived from users or source systems | `CUSTOMERS`, `POLICIES`, `CLAIMS_LANDING`, `PAYMENTS`, `INTERACTIONS`, `DOCUMENT_REGISTRY` |
| `PROCESSED` | Work-in-progress and derived data created by the agents | `CLAIM_STATE`, `FCT_CUSTOMER_360`, `CHURN_ALERTS`, `NEXT_BEST_ACTIONS` |
| `RESULTS` | Final outcomes and the audit trail | `RESOLUTIONS`, `AUDIT_LOG` |
| `VECTORS` | Text converted to numbers for "find similar" searches | `FRAUD_PATTERN_EMBEDDINGS` |

### 0.4 Journey of a claim (step by step)

**Example:** Ananya (CUST-001) is rear-ended on MG Road and files an AUTO claim for 4,500 on policy POL-001.

**Step 1 — The user fills in the form** (Landing page → *Claims & Policy Intake* → *New Claim*).

**Step 2 — The app checks the basics before saving** (front-end data-quality checks):

| Check | If it fails |
|-------|-------------|
| Customer ID exists in `RAW.CUSTOMERS` | ❌ Blocked |
| Policy ID exists in `RAW.POLICIES` | ❌ Blocked |
| Policy belongs to this customer | ❌ Blocked |
| Policy status is `ACTIVE` or `RENEWAL_PENDING` | ❌ Blocked |
| Claim line of business matches the policy's | ⚠️ Warning only |
| Claimed amount ≤ coverage limit | ⚠️ Warning only |

**Step 3 — The claim is saved.** A new row goes into `RAW.CLAIMS_LANDING` with status `SUBMITTED` and a generated ID like `CLM-341FC5`. If a file was attached, it is uploaded to `@RAW.DOCUMENTS_STAGE/<claim_id>/` and recorded in `RAW.DOCUMENT_REGISTRY`.

**Step 4 — Snowflake notices the new claim automatically.**
- `RAW.CLAIMS_LANDING_STREAM` marks the row as "new".
- Every minute, `PROCESSED.TASK_CLAIMS_ORCHESTRATOR` wakes up and asks: *"does the stream have new rows?"* If yes, it calls `SP_PROCESS_ALL_CLAIMS`, which picks up to 20 `SUBMITTED` claims.
- **Data-quality gate:** for each claim, `SP_DQ_VALIDATE_CLAIM` re-checks the same rules as the form, plus a duplicate check (same customer + LOB within 30 days). If there are errors, the claim is marked `DQ_FAILED`, logged, and skipped. If it passes, `SP_PROCESS_CLAIM` runs the five agents.

**Step 5 — Five agents process the claim, one after another** (each writes its result into `PROCESSED.CLAIM_STATE` and a line into `RESULTS.AUDIT_LOG`):

```
 CLAIMS_LANDING row (SUBMITTED)
        │
        ▼
 ┌──────────────┐  "How serious is this?"
 │ 1. INTAKE    │  Cortex CLASSIFY_TEXT reads the description → low / medium / high / critical
 └──────────────┘  (if AI fails: assumes "medium")
        │
        ▼
 ┌──────────────┐  "Is the policy valid for this claim?"
 │ 2. VALIDATION│  Plain SQL rules: policy status, LOB match, coverage limit
 └──────────────┘  (no AI needed — these are hard facts)
        │
        ▼
 ┌──────────────┐  "Does this look like fraud?"
 │ 3. FRAUD     │  • Cortex Search finds similar known fraud patterns
 └──────────────┘  • Vector similarity vs VECTORS.FRAUD_PATTERN_EMBEDDINGS
        │          • Cortex SENTIMENT on the text
        │          • Cortex COMPLETE (llama3.1-8b) combines it all → fraud score 0–1
        ▼
 ┌──────────────┐  "How much should we pay?"
 │ 4. ASSESSMENT│  Cortex Search pulls underwriting guidelines; Cortex COMPLETE recommends
 └──────────────┘  a settlement amount (if AI fails: 85% of claimed amount)
        │
        ▼
 ┌──────────────┐  "Final decision"
 │ 5. RESOLUTION│  Fraud > 0.7 → REFERRED   |  policy invalid → DENIED
 └──────────────┘  Fraud 0.4–0.7 → PARTIALLY_APPROVED  |  otherwise → APPROVED
        │          Cortex COMPLETE writes a human-readable explanation
        ▼
 RESULTS.RESOLUTIONS  (decision + settlement amount + reasoning)
```

**Step 6 — After the decision.** `RESULTS.RESOLUTIONS_STREAM` sees the new decision; every minute `RESULTS.TASK_POST_DECISION_ACTIONS` writes a final "notification sent" entry (step 99) to `AUDIT_LOG`.

**Step 7 — You see it in the app.** Landing page → *Customer 360* → *AI Pipeline Monitor* shows the claim in `V_PIPELINE_STATUS`, the decision in *Recent Resolutions*, and each agent's step, model and latency in the *Claims Audit Log*.

**Safety nets**
- Every AI call is wrapped in TRY/CATCH. If the LLM returns junk, a rule-based fallback is used, so a claim never gets stuck because of the AI.
- `PROCESSED.TASK_HEALTH_CHECK` (every 3 hours) marks any claim stuck for more than 5 minutes as `FAILED` and moves it to `MANUAL_REVIEW` for a human.

### 0.5 Journey of a policy application (underwriting)

**What the app does:** Landing page → *Claims & Policy Intake* → *Policy Application* saves the form into one of three LOB tables, with status `PENDING`:
`RAW.AUTO_POLICY_APPLICATIONS`, `RAW.PROPERTY_POLICY_APPLICATIONS`, or `RAW.WORKERS_COMP_POLICY_APPLICATIONS`.

**What the pipeline does:** The underwriting pipeline is triggered by `RAW.APPLICATIONS_STREAM` on the generic `RAW.APPLICATIONS` table. `PROCESSED.TASK_UNDERWRITING_ORCHESTRATOR` checks every minute and calls `SP_PROCESS_APPLICATION` for up to 10 `PENDING` applications:

```
 RAW.APPLICATIONS row (PENDING)
        │
        ▼
 1. SP_UW_RISK_SCORE       Credit score → risk tier (LOW / MEDIUM / HIGH),
                           actuarial table lookup, 10% existing-customer discount
        ▼
 2. SP_UW_GUIDELINE_LOOKUP Cortex Search returns the top 3 underwriting guidelines
                           for this LOB + risk tier
        ▼
 3. SP_UW_DECISION         LOW → auto-approve | MEDIUM → manual review |
                           HIGH → senior underwriter, premium × 1.5
        ▼
 PROCESSED.UNDERWRITING_DECISIONS  +  APPLICATIONS.status updated  +  AUDIT_LOG
```

> ⚠️ **Gap to be aware of:** in the current definitions there is no stream or task that moves rows from the three LOB application tables into `RAW.APPLICATIONS`. Applications submitted from the IDP Landing page are therefore stored, but they do not automatically start the underwriting pipeline. See [Known Issues](#20-known-issues-and-future-work).

### 0.6 Journey of an uploaded document

1. Landing page → *Document Upload* (or a file attached to a new claim).
2. The file is stored in `@INSURANCE_DB.RAW.DOCUMENTS_STAGE/<claim_id>/` (a "stage" is Snowflake's file storage folder).
3. A row is added to `RAW.DOCUMENT_REGISTRY` (`extraction_status = PENDING`).
4. `RAW.SP_PROCESS_ALL_PENDING_DOCUMENTS` calls `RAW.SP_PROCESS_UPLOADED_DOCUMENT` for each pending file:
   - **Cortex PARSE_DOCUMENT** reads the PDF/image and extracts its text.
   - **Cortex EMBED_TEXT_768** turns the text into a vector so it can be searched by meaning.
   - Status becomes `EXTRACTED` (or `FAILED` if nothing could be read).

> ⚠️ **Note:** no task currently schedules `SP_PROCESS_ALL_PENDING_DOCUMENTS`; it must be run manually (`CALL INSURANCE_DB.RAW.SP_PROCESS_ALL_PENDING_DOCUMENTS();`).

### 0.7 Customer 360 and the churn & retention pipeline

**Customer 360 = one summary row per customer.** Four aggregation views each summarise one topic, and a Dynamic Table joins them:

```
 RAW.POLICIES      → V_AGG_POLICY_PORTFOLIO    (premium, renewals, lapses)      ┐
 RAW.CLAIMS_LANDING→ V_AGG_CLAIMS_HISTORY      (claim counts, amounts, approvals)│
 RAW.PAYMENTS      → V_AGG_PAYMENT_BEHAVIOR    (delays, missed payments)         ├─► PROCESSED.DT_CUSTOMER_360
 RAW.INTERACTIONS  → V_AGG_INTERACTION_SIGNALS (sentiment, complaints, NPS)      ┘   (Dynamic Table: refreshes
 RAW.CUSTOMERS  ─────────────────────────────────────────────────────────────────►    itself within 1 hour)
                                                                                         │
                                                                                         ▼
                                                                          PROCESSED.FCT_CUSTOMER_360
                                                                          (+ churn propensity score,
                                                                             used by the dashboard & chat)
```

> A **Dynamic Table** is a table defined by a query that Snowflake keeps up to date automatically — you never have to "rebuild" it by hand.

**Daily churn pipeline** (a chain of three tasks, starting 6 AM UTC):

```
 TASK_EXTRACT_UNSTRUCTURED_FEATURES  → SP_EXTRACT_UNSTRUCTURED_FEATURES_BATCH
   Cortex COMPLETE reads recent call/chat transcripts and extracts
   frustration level, intent, competitor mentions → updates FCT_CUSTOMER_360
        │ (runs after)
        ▼
 TASK_CHURN_SCAN  → SP_CHURN_SCAN
   Flags customers with risk signals (churn score > 0.5, sentiment < -0.3,
   3+ complaints, renewal soon + falling sentiment, cancel intent, competitor mentions)
   → inserts PROCESSED.CHURN_ALERTS  (status = NEW, priority, propensity)
        │ (runs after)
        ▼
 TASK_CHURN_NBA  → SP_CHURN_PIPELINE_FULL
   For each NEW alert:
     1. SP_CHURN_ROOT_CAUSE        Cortex COMPLETE explains WHY the customer may leave
     2. SP_GENERATE_RETENTION_NBA  Looks up matching playbooks in RAW.RETENTION_PLAYBOOKS,
                                   Cortex COMPLETE writes a personalised offer
   → inserts PROCESSED.NEXT_BEST_ACTIONS  ("NBA" = Next-Best-Action)
```

**Where you see it:** Landing page → *Customer 360* → *Churn & Retention* (`V_CHURN_DASHBOARD`, `V_NBA_FOR_CRM`). An agent can also click **Generate NBA** in the chat side panel to run `SP_GENERATE_RETENTION_NBA` on demand for one customer.

### 0.8 The Intelligent Chat (two modes)

```
 User types a message
        │
        ▼
 App gathers context for the selected customer:
   • FCT_CUSTOMER_360 profile   • CHURN_ALERTS   • NEXT_BEST_ACTIONS
        │
        ▼
 App builds a "system prompt" depending on the mode:
   Agent Mode    → internal assistant: may show churn score, LTV, strategies, draft outreach
   Customer Mode → friendly care agent: must NEVER reveal internal scores or IDs
        │
        ▼
 SNOWFLAKE.CORTEX.COMPLETE('llama3.1-8b', prompt)  →  answer shown on screen
        │
        ▼
 Conversation saved to RAW.INTERACTIONS (channel = CHAT)
        │
        ▼
 Next refresh: interaction feeds V_AGG_INTERACTION_SIGNALS → Customer 360 → churn scan
```

This closes the loop: what customers say in chat influences their sentiment features, which can trigger tomorrow's churn alert and a new retention offer.

### 0.9 Automation cheat-sheet (what runs on its own)

| What | Trigger | Runs | Writes to |
|------|---------|------|-----------|
| Claims pipeline (5 agents) | New row in `CLAIMS_LANDING` | `TASK_CLAIMS_ORCHESTRATOR` (checks every 1 min) | `CLAIM_STATE`, `RESOLUTIONS`, `AUDIT_LOG` |
| Post-decision audit | New row in `RESOLUTIONS` | `TASK_POST_DECISION_ACTIONS` (every 1 min) | `AUDIT_LOG` |
| Underwriting (3 steps) | New row in `APPLICATIONS` | `TASK_UNDERWRITING_ORCHESTRATOR` (every 1 min) | `UNDERWRITING_DECISIONS`, `AUDIT_LOG` |
| Customer 360 refresh | Any source table change | Dynamic Table `DT_CUSTOMER_360` (≤ 1 hour lag) | `DT_CUSTOMER_360` |
| Churn + NBA | Daily 6 AM UTC | 3-task chain | `CHURN_ALERTS`, `NEXT_BEST_ACTIONS` |
| Fraud pattern vectors | Sundays 2 AM UTC | `TASK_REFRESH_EMBEDDINGS` | `FRAUD_PATTERN_EMBEDDINGS` |
| Health check | Every 3 hours | `TASK_HEALTH_CHECK` | `CLAIM_STATE`, `CLAIMS_LANDING`, `AUDIT_LOG` |
| Document extraction | **Manual** | `SP_PROCESS_ALL_PENDING_DOCUMENTS` | `DOCUMENT_REGISTRY` |

> All tasks are created **SUSPENDED**. Nothing runs automatically until each task is resumed (see [Section 13](#13-task-automation-reference)).

### 0.10 How to follow one claim yourself

```sql
-- 1. The claim as submitted
SELECT * FROM INSURANCE_DB.RAW.CLAIMS_LANDING WHERE claim_id = 'CLM-001';

-- 2. Each agent's output
SELECT * FROM INSURANCE_DB.PROCESSED.CLAIM_STATE WHERE claim_id = 'CLM-001';

-- 3. Step-by-step trail (which agent, which AI model, how long)
SELECT step_number, agent_name, cortex_module_used, model_used, latency_ms, status
FROM INSURANCE_DB.RESULTS.AUDIT_LOG
WHERE flow_type = 'CLAIMS' AND reference_id = 'CLM-001'
ORDER BY step_number;

-- 4. Final decision
SELECT * FROM INSURANCE_DB.RESULTS.RESOLUTIONS WHERE claim_id = 'CLM-001';
```

### 0.11 What each SQL object does (plain-English reference)

Every object below lives in `INSURANCE_DB`. The **Called by** column tells you what starts it, so you can trace any step back to the landing page or a task.

#### A. Claims pipeline: orchestrators and the data-quality gate

| Object | What it does, in plain words | Reads | Writes | Called by |
|--------|------------------------------|-------|--------|-----------|
| `PROCESSED.SP_PROCESS_ALL_CLAIMS()` | The "dispatcher". Takes up to 20 `SUBMITTED` claims (oldest first), runs the DQ gate on each, then sends passing claims to `SP_PROCESS_CLAIM`. Failing claims are marked `DQ_FAILED`. | `RAW.CLAIMS_LANDING` | `CLAIMS_LANDING.claim_status`, `AUDIT_LOG` (step 0) | `TASK_CLAIMS_ORCHESTRATOR` |
| `PROCESSED.SP_DQ_VALIDATE_CLAIM(claim_id)` | The "gatekeeper". Errors (block): customer not found, policy not found, policy not `ACTIVE`, policy belongs to someone else, amount missing or ≤ 0. Warnings (allow): LOB mismatch, amount above coverage, similar claim in the last 30 days. Returns `{passed, errors, warnings}`. | `CLAIMS_LANDING`, `CUSTOMERS`, `POLICIES` | — (returns a result only) | `SP_PROCESS_ALL_CLAIMS` |
| `PROCESSED.SP_PROCESS_CLAIM(claim_id)` | The "assembly line". Calls the 5 agents in order and returns the final decision text. | `RESULTS.RESOLUTIONS` | — (through the agents) | `SP_PROCESS_ALL_CLAIMS`, or run manually |

#### B. Claims pipeline: the 5 agents

Each agent reads the claim, does one job, writes its JSON result to a column of `PROCESSED.CLAIM_STATE`, moves `current_state` forward, and adds one row to `RESULTS.AUDIT_LOG`.

| # | Agent | Its question | How it answers | Saved to | State after | Fallback if AI fails |
|---|-------|--------------|----------------|----------|-------------|----------------------|
| 1 | `SP_AGENT_INTAKE` | "How serious is this claim?" | `CORTEX.CLASSIFY_TEXT` labels the description as low / medium / high / critical severity. Creates the `CLAIM_STATE` row and records `started_at`. | `intake_output` | `VALIDATION` | severity = medium |
| 2 | `SP_AGENT_VALIDATION` | "Is the policy valid?" | Plain SQL: policy must be `ACTIVE` or `RENEWAL_PENDING`. It also notes when the amount is above the coverage limit (a note only, not a rejection). | `validation_output` (`valid`, `issues`) | `FRAUD_CHECK` | `valid = true`, "lookup skipped" |
| 3 | `SP_AGENT_FRAUD` | "Does it look like fraud?" | Gathers 3 pieces of evidence: (a) `COMPUTE_FRAUD_SIMILARITY`, a vector match against known fraud patterns, (b) Cortex Search on `FRAUD_INDICATORS_SEARCH_SERVICE` filtered by LOB (top 3), (c) `CORTEX.SENTIMENT`. Then `CORTEX.COMPLETE` (llama3.1-8b) turns the evidence into a 0–1 score. Score > 0.7 = HIGH, > 0.4 = MEDIUM, otherwise LOW. | `fraud_output` | `ASSESSMENT` | Formula: 0.4 × vector + 0.3 × negative-sentiment + 0.1 |
| 4 | `SP_AGENT_ASSESSMENT` | "How much should we pay?" | Cortex Search on `UNDERWRITING_GUIDELINES_SEARCH_SERVICE` (top 2 for this LOB), then `CORTEX.COMPLETE` (llama3.1-8b) suggests a settlement, a confidence, and a damage category (minor / moderate / major / total loss). | `assessment_output` | `RESOLUTION` | 85% of claimed amount, confidence 0.75 |
| 5 | `SP_AGENT_RESOLUTION` | "Final decision?" | Applies fixed rules: fraud > 0.7 → **REFERRED** (pays 0). Policy invalid → **DENIED** (pays 0). Fraud 0.4–0.7 → **PARTIALLY_APPROVED** (pays 50% of the suggested settlement). Otherwise → **APPROVED**. `CORTEX.COMPLETE` writes a 2–3 sentence explanation. Records total processing time. | `resolution_output`, plus a new row in `RESULTS.RESOLUTIONS` | `COMPLETED` | Settlement = 80% of claimed amount if assessment is missing |

> The AI never makes the final decision alone. The LLM provides scores and explanations, and fixed SQL rules decide the outcome. That makes every decision repeatable and easy to audit.

#### C. Underwriting pipeline

| Object | What it does | Reads | Writes |
|--------|--------------|-------|--------|
| `PROCESSED.SP_PROCESS_APPLICATION(app_id)` | Orchestrator. Runs the 3 steps below in order and passes each step's output to the next. | — | — |
| `PROCESSED.SP_UW_RISK_SCORE(app_id)` | Credit score ≥ 750 → LOW, ≥ 650 → MEDIUM, otherwise HIGH. Looks up `base_rate × risk_multiplier × geographic_factor × history_factor` in the actuarial table (defaults 0.03 / 1.3 / 1.1 / 1.0 if no match). Existing customers get 10% off the history factor. Premium = coverage × score. | `RAW.APPLICATIONS`, `RAW.ACTUARIAL_TABLES` | — (returns JSON) |
| `PROCESSED.SP_UW_GUIDELINE_LOOKUP(app_id, risk_tier)` | Cortex Search on `UNDERWRITING_GUIDELINES_SEARCH_SERVICE` for "<LOB> <tier> underwriting risk assessment", returning the top 3 guidelines. | `RAW.APPLICATIONS` | — (returns JSON) |
| `PROCESSED.SP_UW_DECISION(app_id, risk, guidelines)` | LOW → auto-approved (confidence 0.95). MEDIUM → manual review (0.7). HIGH → senior underwriter, premium × 1.5 (0.5). | `RAW.APPLICATIONS` | `RESULTS.UNDERWRITING_DECISIONS`, `APPLICATIONS.status` (`APPROVED` / `REVIEW`), `AUDIT_LOG` |

#### D. Customer 360 (feature building)

| Object | Type | What it calculates per customer |
|--------|------|---------------------------------|
| `PROCESSED.V_AGG_POLICY_PORTFOLIO` | View | Active policy count, total annual premium, number of different LOBs, days to the nearest renewal, coverage adequacy, lapse count |
| `PROCESSED.V_AGG_CLAIMS_HISTORY` | View | Claims in the last 12 months and lifetime, approval ratio, average and maximum claim, total paid, open claims, "claim acceleration" (last 3 months vs last 12) |
| `PROCESSED.V_AGG_PAYMENT_BEHAVIOR` | View | Average days late, missed payments in 12 months, on-time ratio, days since last payment, auto-pay enrolment |
| `PROCESSED.V_AGG_INTERACTION_SIGNALS` | View | `CORTEX.SENTIMENT` average over the last 30 days and trend vs the 30 days before, escalations in 90 days, latest NPS, preferred channel |
| `PROCESSED.V_AGG_EMBEDDING_FEATURES` | View | Highest fraud-similarity score across the customer's claims, a cluster label (1 / 2 / 3), provider anomaly score |
| `PROCESSED.DT_CUSTOMER_360` | Dynamic Table | Joins `CUSTOMERS` with the first four views and adds derived flags (renewal risk, complaint rate per claim, lifetime loss ratio, high value at risk). Snowflake refreshes it automatically within 1 hour. |
| `PROCESSED.SP_BUILD_CUSTOMER_360()` | Procedure | Older, manual way to build `FCT_CUSTOMER_360` (MERGE from all 5 views). See Known Issue #1. |
| `PROCESSED.FCT_CUSTOMER_360_VIEW` | View | A plain `SELECT *` wrapper over `FCT_CUSTOMER_360` |

#### E. Churn and retention

| Object | What it does | Writes |
|--------|--------------|--------|
| `PROCESSED.SP_EXTRACT_UNSTRUCTURED_FEATURES_BATCH()` | For every customer with interactions in the last 90 days, sends the transcripts to `CORTEX.COMPLETE` (llama3.3-70b) and extracts: frustration level, intent to cancel, competitor mentions, digital engagement trend, emotional manipulation flag. | `FCT_CUSTOMER_360` (those 5 columns) |
| `PROCESSED.SP_EXTRACT_INTERACTION_FEATURES(customer_id)` | The same extraction for a single customer. Returns the JSON without saving it. | — |
| `PROCESSED.SP_CHURN_SCAN()` | Creates a `NEW` alert for customers matching any risk rule: churn score > 0.5, sentiment < -0.3, 3+ complaints, renewal soon with falling sentiment, cancel intent, or 2+ competitor mentions. Labels the main trigger. Priority is set by lifetime value (most valuable = 1). Skips customers who already have an open alert from the last 7 days. | `CHURN_ALERTS` |
| `PROCESSED.SP_CHURN_ROOT_CAUSE(customer_id)` | Sends the customer profile and the last 90 days of transcripts to `CORTEX.COMPLETE` (llama3.3-70b), which picks one of 7 root causes (price, claims experience, service, coverage gap, competitor, life event, payment difficulty) with a confidence. | `CHURN_ALERTS.root_cause`, status → `IN_PROGRESS` |
| `PROCESSED.SP_GENERATE_RETENTION_NBA(customer_id)` | Finds up to 3 playbooks in `RAW.RETENTION_PLAYBOOKS` matching the segment or root cause. `CORTEX.COMPLETE` (llama3.3-70b) writes an action (RETAIN / CROSS_SELL / ESCALATE / MONITOR), offer, channel, timing, expected success rate, and talking points. The NBA expires after 14 days. | `NEXT_BEST_ACTIONS` (status `PENDING`), alert → `ACTIONED` |
| `PROCESSED.SP_CHURN_PIPELINE_FULL()` | Runs the scan, then root cause + NBA for each of today's `NEW` alerts (up to 100, highest priority first). | (through the above) + `AUDIT_LOG` |
| `PROCESSED.V_CHURN_DASHBOARD` | View: each alert joined with the customer's 360 features and that day's NBA. Shown on the *Churn & Retention* tab. | — |
| `PROCESSED.V_NBA_FOR_CRM` | **Secure** view: pending, unexpired NBAs with customer name, email, and phone, ready to export to a CRM. "Secure" means the view's SQL logic is hidden from consumers. | — |

#### F. Documents

| Object | What it does |
|--------|--------------|
| `RAW.SP_PROCESS_UPLOADED_DOCUMENT(document_id)` | Runs `CORTEX.PARSE_DOCUMENT` (LAYOUT mode) on the staged file to get its text, then `CORTEX.EMBED_TEXT_768` on the first 8,000 characters. Sets `extraction_status` to `EXTRACTED` or `FAILED`. |
| `RAW.SP_PROCESS_ALL_PENDING_DOCUMENTS()` | Runs the procedure above for up to 50 `PENDING` documents. |

#### G. Helper functions (UDFs)

| Function | Input → Output | How |
|----------|---------------|-----|
| `PROCESSED.CLASSIFY_LOB(text)` | claim text → `AUTO` / `PROPERTY` / `WORKERS_COMP` | `CORTEX.COMPLETE` (llama3.3-70b) |
| `PROCESSED.CLAIM_SENTIMENT(text)` | text → -1 (negative) … +1 (positive) | `CORTEX.SENTIMENT` |
| `PROCESSED.SUMMARIZE_CLAIM(text)` | long text → short summary | `CORTEX.SUMMARIZE` |
| `VECTORS.COMPUTE_FRAUD_SIMILARITY(text)` | claim text → 0…1 | Embeds the text (arctic-embed-m) and returns the highest cosine similarity to any row in `FRAUD_PATTERN_EMBEDDINGS` |

#### H. Monitoring

| Object | What it shows or does |
|--------|----------------------|
| `PROCESSED.V_PIPELINE_STATUS` | One row per claim in `CLAIM_STATE`: current step, seconds elapsed, fraud score and risk, decision, settlement, customer segment. Used by the *AI Pipeline Monitor* tab. |
| `PROCESSED.TASK_HEALTH_CHECK` | Every 3 hours: claims stuck for more than 5 minutes → `FAILED` and `MANUAL_REVIEW`. Logs pending, failed, and completed-today counts to `AUDIT_LOG` (`flow_type = SYSTEM`). |
| `RESULTS.TASK_POST_DECISION_ACTIONS` | For each new resolution, adds an audit row (step 99) recording decision, settlement, and `notification_sent = true`. |
| `VECTORS.TASK_REFRESH_EMBEDDINGS` | Weekly: embeds any new rows in `RAW.FRAUD_INDICATORS` into `FRAUD_PATTERN_EMBEDDINGS`, so the fraud agent recognises new patterns. |

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
4. **Policy applications don't trigger underwriting** — The IDP Landing page writes to `AUTO_/PROPERTY_/WORKERS_COMP_POLICY_APPLICATIONS`, but `TASK_UNDERWRITING_ORCHESTRATOR` only watches `RAW.APPLICATIONS_STREAM`. Fix: insert into `RAW.APPLICATIONS` as well, or add streams on the LOB tables.
5. **Document extraction is manual** — No task schedules `SP_PROCESS_ALL_PENDING_DOCUMENTS`; uploaded documents stay `PENDING` until it is called.

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
