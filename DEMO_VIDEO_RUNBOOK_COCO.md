# IDP Insurance — CoCo-Driven Demo Video Runbook

> **Target Duration:** 3-5 minutes | **Format:** Screen recording of CoCo chat
> **Resolution:** 1920x1080 | Record the CoCo Snowsight workspace

---

## HOW THIS DEMO WORKS

Instead of switching between SQL worksheets and Streamlit apps, you **stay in CoCo** and type natural language prompts. CoCo runs the SQL, shows results, and narrates the pipeline step by step.

**Recording setup:**
1. Open Snowsight → Workspaces → insurance workspace
2. Open CoCo chat panel (right side)
3. Start screen recording (Cmd+Shift+5 on Mac)
4. Type the prompts below — CoCo does the rest

---

## PRE-RECORDING: Reset Demo State

Type this in CoCo before recording:

> **You type:** `Reset claim CLM-001 for demo and reset churn alerts to NEW`

CoCo will run:
```sql
CALL INSURANCE_DB.PROCESSED.SP_RESET_DEMO('CLM-001');
UPDATE INSURANCE_DB.PROCESSED.CHURN_ALERTS SET status = 'NEW';
```

`SP_RESET_DEMO` clears CLAIM_STATE, RESOLUTIONS, AUDIT_LOG, resets claim status to SUBMITTED, and reverses any coverage deduction on the policy. Safe to run repeatedly.

---

## SCENE 1: Platform Overview (0:00 - 0:40)

### You type:
> `Show me the IDP Insurance platform — how many tables, views, procedures, stages, and Streamlit apps do we have in INSURANCE_DB? Also show the customer and claims counts.`

### CoCo will run & show:
- Object counts from INFORMATION_SCHEMA
- Customer count (8), policy count (13), claims count, churn alerts

### Speaking point (voiceover):
> "I'm using Cortex Code — Snowflake's AI coding agent — to orchestrate our entire insurance platform. Let me ask CoCo to show the platform inventory."

---

## SCENE 2: Claim Intake via Streamlit (0:40 - 1:30)

### You type:
> `Open the IDP Landing Streamlit app — I need to submit a new claim`

### Action:
- CoCo can't launch Streamlit, so **switch to the Streamlit tab** (pre-opened)
- Fill in the claim form: CUST-001, POL-001, AUTO, "Rear-ended at traffic light on MG Road", $4500
- Attach the garage estimate document
- Submit → note the Claim ID shown (e.g. CLM-A3F2B1)

### Back in CoCo, you type:
> `Verify claim CLM-001 landed in CLAIMS_LANDING — show me the raw record`

### CoCo will run:
```sql
SELECT claim_id, customer_id, policy_id, lob_type, claimed_amount, claim_status
FROM INSURANCE_DB.RAW.CLAIMS_LANDING WHERE claim_id = 'CLM-001';
```

### Speaking point:
> "The claim is in our landing table — status SUBMITTED. Now let me ask CoCo to run it through the AI pipeline."

---

## SCENE 3: AI Pipeline — CoCo Orchestrated (1:30 - 3:15) ⭐ KEY SCENE

### You type:
> `Process claim CLM-001 through the 5-agent AI pipeline, then show me the results step by step — the claim state, fraud score, assessment, resolution decision, and the full audit trail with latency per agent`

### CoCo will:

**Step 1 — Trigger the pipeline:**
```sql
CALL INSURANCE_DB.PROCESSED.SP_PROCESS_CLAIM('CLM-001');
```
→ Returns: `Claim CLM-001 processed. Decision: PARTIALLY_APPROVED`

**Step 2 — Show claim state machine:**
```sql
SELECT claim_id, current_state,
    intake_output:severity::VARCHAR AS severity,
    validation_output:valid::BOOLEAN AS policy_valid,
    ROUND(fraud_output:composite_fraud_score::FLOAT, 2) AS fraud_score,
    fraud_output:risk_level::VARCHAR AS fraud_risk,
    assessment_output:damage_category::VARCHAR AS damage_category,
    ROUND(assessment_output:recommended_settlement::FLOAT, 0) AS recommended_settlement,
    resolution_output:decision::VARCHAR AS decision,
    ROUND(resolution_output:settlement_amount::FLOAT, 0) AS final_settlement
FROM INSURANCE_DB.PROCESSED.CLAIM_STATE
WHERE claim_id = 'CLM-001';
```

**Step 3 — Show audit trail:**
```sql
SELECT agent_name, step_number, cortex_module_used, model_used, latency_ms, status
FROM INSURANCE_DB.RESULTS.AUDIT_LOG
WHERE reference_id = 'CLM-001'
ORDER BY step_number;
```

**Step 4 — Show resolution with LLM reasoning:**
```sql
SELECT claim_id, decision, settlement_amount, claimed_amount,
       fraud_risk_level, fraud_score, reasoning_summary, processing_time_ms
FROM INSURANCE_DB.RESULTS.RESOLUTIONS
WHERE claim_id = 'CLM-001';
```

### CoCo will narrate (in its response):
- Intake: CLASSIFY_TEXT tagged severity as medium
- Validation: policy confirmed active
- Fraud: vector similarity + sentiment + Cortex Search + LLM → composite score
- Assessment: Cortex Search retrieved UW guidelines → recommended settlement
- Resolution: final decision with LLM reasoning

### Speaking point:
> "With one prompt, CoCo triggered 5 AI agents, each using different Cortex functions — CLASSIFY_TEXT, SENTIMENT, SEARCH_PREVIEW, EMBED_TEXT, and COMPLETE. It then pulled the results across 3 tables and explained the entire decision chain. This is the power of CoCo as an orchestration layer."

---

## SCENE 4: Customer 360 Dashboard (3:15 - 4:15) — Streamlit

**Switch to:** IDP Landing Streamlit app → Customer 360 Dashboard (sidebar)

### Walkthrough — 5 tabs to show:

**Tab 1 — Executive Overview (10s)**
- Point to the KPI cards: total customers, total premium, claims in pipeline, churn alerts
- Quick glance at the churn alerts table and resolution distribution

**Tab 2 — Portfolio Analytics (10s)**
- Show policies by LOB breakdown
- Point to premium distribution across customer segments

**Tab 3 — Churn & Retention (15s)**
- Show the V_CHURN_DASHBOARD with 4 at-risk customers
- Point to churn propensity, trigger reasons, and priority ranking
- Show the NBA for CRM table with AI-generated retention offers

**Tab 4 — Customer Deep-Dive (15s)**
- Select **CUST-001 (Ananya Sharma)** from the dropdown
- Show her profile: Segment PREMIUM, LTV 92.5, Tenure 88 months
- Point to her policies (Auto + Home), claims, payment history, interactions
- Then select **CUST-004 (James Wilson)** — highest churn risk
- Show his late payments, low NPS, escalated complaints

**Tab 5 — AI Pipeline Monitor (10s)**
- Show the pipeline status table: all 10 claims with their current state
- Point to the resolutions table and audit log
- Highlight per-agent latency tracking

### Speaking point:
> "The Customer 360 Dashboard gives operations teams a complete view — executive KPIs, portfolio analytics, churn monitoring, individual customer deep-dives, and real-time AI pipeline observability. Everything is powered by the 60-feature fact table and the views we built."

---

## SCENE 5: Churn + NBA via CoCo (4:15 - 5:00)

### You type:
> `Run the churn scanner and show me at-risk customers. For the highest-priority alert, generate a retention NBA.`

### CoCo will:

**Step 1 — Run churn scan:**
```sql
CALL INSURANCE_DB.PROCESSED.SP_CHURN_SCAN();
```

**Step 2 — Show alerts:**
```sql
SELECT customer_id, churn_propensity, trigger_reason, priority, status
FROM INSURANCE_DB.PROCESSED.CHURN_ALERTS
WHERE status = 'NEW'
ORDER BY priority;
```

**Step 3 — Generate NBA for highest priority:**
```sql
CALL INSURANCE_DB.PROCESSED.SP_GENERATE_RETENTION_NBA('CUST-004');

SELECT customer_id, action_type, offer_details, channel,
       expected_success_rate, rationale
FROM INSURANCE_DB.PROCESSED.NEXT_BEST_ACTIONS
WHERE customer_id = 'CUST-004'
ORDER BY created_date DESC LIMIT 1;
```

### Speaking point:
> "CoCo ran the churn scanner, found 4 at-risk customers, and generated a personalized retention offer for the highest-priority case — using Cortex COMPLETE with RAG over our retention playbooks."

---

## SCENE 6: NBA Chatbot (5:00 - 5:45) — Streamlit

**Switch to:** IDP Landing Streamlit app → Intelligent Chat (sidebar)

### Walkthrough — Agent Mode:

**Step 1 — Agent Mode (internal view) (20s)**
- Mode toggle is on **Agent Mode** (default)
- Select **CUST-004 — James Wilson** from the customer context panel
- Point to the context panel: Segment, Churn Risk, LTV Score, Annual Premium
- Point to the **Next-Best-Actions** shown in the sidebar
- Click the **"Retention strategy"** suggestion pill
- Show the AI response: Cortex COMPLETE generates a data-driven retention strategy referencing James's specific profile — late payments, low NPS, escalated complaint
- Highlight: the AI references actual numbers from FCT_CUSTOMER_360

**Step 2 — Customer Mode (external view) (15s)**
- Toggle to **Customer Mode**
- Customer is still CUST-004
- Click **"Check my policy"** suggestion pill
- Show the AI response: speaks as a friendly customer care agent, uses first name, references policy details
- Key: the AI **never reveals** internal scores (churn, LTV) in customer mode

**Step 3 — Generate NBA button (10s)**
- Toggle back to **Agent Mode**
- Click the **"Generate NBA"** button in the context panel
- Show `SP_GENERATE_RETENTION_NBA` running → NBA appears in the sidebar
- Point to: action type, offer details, priority, expected success rate

### Speaking point:
> "The chatbot has dual modes. Agent Mode gives internal staff a data-driven AI assistant — it knows the customer's churn risk, payment history, and recommends retention strategies grounded in real data. Customer Mode speaks directly to the customer as a friendly agent — warm, empathetic, and never reveals internal scores. Both powered by Cortex COMPLETE with full Customer 360 context."

---

## SCENE 7: Wrap-up (5:45 - 6:00)

### You type:
> `Summarize what we just demonstrated — the Cortex AI functions used, the pipeline stages, and the Snowflake-native components`

### CoCo will summarize:
- 5-agent claims pipeline (CLASSIFY_TEXT, COMPLETE, SENTIMENT, SEARCH_PREVIEW, EMBED_TEXT_768)
- 60-feature Customer 360 with Dynamic Table
- Customer 360 Dashboard with 5 analytics tabs
- Churn prediction + AI-generated retention NBAs
- Dual-mode AI chatbot (Agent Mode + Customer Mode)
- Document intelligence with internal stages
- Coverage balance tracking across claims
- Full audit trail with per-agent observability
- Event-driven automation (8 tasks + 5 streams)
- 100% Snowflake-native, zero external infrastructure

### Speaking point:
> "From raw data to AI-powered decisions — orchestrated through CoCo, entirely within Snowflake."

---

## EXACT PROMPTS CHEAT SHEET

Copy-paste these during recording:

```
RESET:   Reset claim CLM-001 for demo and reset churn alerts to NEW

PROMPT 1: Show me the IDP Insurance platform — how many tables, views, procedures, stages, and Streamlit apps do we have in INSURANCE_DB? Also show the customer and claims counts.

PROMPT 2: Verify claim CLM-001 landed in CLAIMS_LANDING — show me the raw record

PROMPT 3: Process claim CLM-001 through the 5-agent AI pipeline, then show me the results step by step — the claim state, fraud score, assessment, resolution decision, and the full audit trail with latency per agent

         [SCENE 4: Switch to Streamlit → Customer 360 Dashboard — walk through 5 tabs]

PROMPT 4: Run the churn scanner and show me at-risk customers. For the highest-priority alert, generate a retention NBA.

         [SCENE 6: Switch to Streamlit → Intelligent Chat — show Agent Mode + Customer Mode]

PROMPT 5: Summarize what we just demonstrated — the Cortex AI functions used, the pipeline stages, and the Snowflake-native components
```

---

## TIMING GUIDE

| Scene | What | Format | Duration |
|-------|------|--------|----------|
| 1 | Platform Overview | CoCo prompt | 40s |
| 2 | Claims Intake + Verify | Streamlit + CoCo | 50s |
| 3 | **5-Agent AI Pipeline** | CoCo prompt | 105s |
| 4 | **Customer 360 Dashboard** | Streamlit (5 tabs) | 60s |
| 5 | Churn Scan + NBA | CoCo prompt | 45s |
| 6 | **NBA Chatbot** (Agent + Customer Mode) | Streamlit | 45s |
| 7 | Summary | CoCo prompt | 15s |
| **Total** | | | **~6 min** |

> **Note:** If you need to stay under 5 minutes, compress Scenes 4 and 6 by showing 2-3 tabs instead of all 5, and only one chatbot mode.

---

## WHY THIS FORMAT WORKS FOR THE HACKATHON

1. **CoCo IS the demo** — You're not just showing an app, you're showing Snowflake's AI agent orchestrating an AI pipeline
2. **Natural language → SQL → Results** — Judges see the full loop in one screen
3. **CoCo + Streamlit interplay** — CoCo runs the backend, Streamlit shows the frontend: claims intake, Customer 360 dashboard, dual-mode chatbot
4. **Step-by-step narration** — CoCo explains each agent's Cortex function and output
5. **Dual-mode chatbot** — Agent Mode (internal, data-driven) vs Customer Mode (external, empathetic) shows production-grade AI separation
6. **Reproducible** — Anyone can paste these prompts and get the same walkthrough. `SP_RESET_DEMO` makes re-recording painless
