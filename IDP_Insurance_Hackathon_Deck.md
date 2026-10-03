# IDP Insurance — Snowflake GCC Hackathon Presentation

> **Instructions for PPT generation:** Create a 6-slide presentation matching the exact style described below. Use a **dark navy (#0F2440 / #1B3A5C) background** with **gold (#C9A84C) accents** throughout. Text is white (#FFFFFF) with light gray (#E8DCC8) for secondary text. Section headers use gold. Use clean, modern typography (Arial or Calibri). Each slide has a subtle gradient background from dark navy to slightly lighter navy. Include the IDP shield logo (gold shield with "IDP" text and "INSURANCE" below it) on the title slide. All other slides should have a small IDP logo in the bottom-left corner and "Snowflake GCC India Hackathon" in the bottom-right footer.

---

## Slide 1: Title Slide

**Layout:** Centered, full-bleed dark navy background with subtle radial gradient

**Content:**

- **[IDP Shield Logo]** — Gold shield icon with "IDP" in bold and "INSURANCE" below
- **Main Title:** `IDP Insurance`
- **Subtitle:** `Intelligent Digital Platform`
- **Tagline:** `AI-Powered Insurance Operations — From Claims Intake to Customer Retention`
- **Event Badge:** `Snowflake GCC India Hackathon`
- **Team:** `IDP @ Data`
- **Team Leader:** `Raamamoorthi Sundar`

---

## Slide 2: Problem Statement

**Layout:** Title on top (gold), two-column layout below

**Slide Title:** `The Challenge`

**Left Column — "Traditional Insurance Operations":**

| Pain Point | Impact |
|---|---|
| Manual claims processing | 5–7 day avg. turnaround |
| No unified customer view | Siloed data across LOBs |
| Reactive churn management | Customers lost before intervention |
| Paper-based document handling | Slow intake, no searchability |
| No fraud detection at scale | High leakage, manual audits |

**Right Column — "What We Built":**

> A fully **Snowflake-native**, **AI-powered** insurance platform that automates the entire lifecycle — from LOB-specific claims intake and intelligent document processing to real-time Customer 360 analytics, churn prediction, and Next-Best-Action generation — **all running inside Snowflake** with zero external infrastructure.

**Bottom Callout (gold border box):**
> **Key Constraint:** Everything runs on Snowflake. Internal stages for documents. Cortex AI for intelligence. No external APIs, no S3, no third-party ML platforms.

---

## Slide 3: Architecture & Data Flow

**Layout:** Full-width architecture diagram

**Slide Title:** `Platform Architecture`

**Diagram — show this as a left-to-right pipeline with 4 layers:**

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        IDP INSURANCE PLATFORM                          │
├─────────────┬──────────────────┬───────────────────┬───────────────────┤
│  DATA LAYER │  AI AGENT LAYER  │   FEATURE STORE   │   APPLICATIONS   │
│  (RAW)      │  (PROCESSED)     │   (PROCESSED)     │   (STREAMLIT)    │
├─────────────┼──────────────────┼───────────────────┼───────────────────┤
│             │                  │                   │                   │
│ 8 Customers │  5-Agent Claims  │  FCT_CUSTOMER_360 │ Claims & Policy  │
│ 13 Policies │  Pipeline:       │  (60 features)    │ Intake Portal    │
│ 10 Claims   │  ┌─Intake        │                   │                   │
│ 15 Payments │  ├─Validation    │  DT_CUSTOMER_360  │ Customer 360     │
│ 10 Interact.│  ├─Fraud Detect. │  (Dynamic Table)  │ Dashboard        │
│ 8 Providers │  ├─Assessment    │                   │                   │
│             │  └─Resolution    │  Churn Propensity │ NBA Chatbot      │
│ 3 LOBs:     │                  │  Scoring Model    │ (Cortex AI)      │
│ Auto        │  Churn Pipeline: │                   │                   │
│ Home        │  ┌─Scan          │  9 Aggregation    │ IDP Landing      │
│ Life        │  ├─Root Cause    │  Views            │ Page + Test      │
│             │  └─NBA Gen       │                   │ Suite            │
│ 5 Internal  │                  │                   │                   │
│ Stages      │  Cortex AI:      │                   │                   │
│ (Documents) │  COMPLETE         │                   │                   │
│             │  CLASSIFY_TEXT   │                   │                   │
│             │  SENTIMENT       │                   │                   │
│             │  EMBED_TEXT_768  │                   │                   │
│             │  PARSE_DOCUMENT  │                   │                   │
└─────────────┴──────────────────┴───────────────────┴───────────────────┘
```

**Bottom stats bar (gold on dark):**

| 41 Tables | 9 Views | 14 Procedures | 5 AI Agents | 4 Streamlit Apps | 5 Internal Stages |
|---|---|---|---|---|---|

---

## Slide 4: Cortex AI — The Intelligence Layer

**Layout:** Title + 3 feature cards + demo metrics

**Slide Title:** `Cortex AI in Action`

**Card 1 — "5-Agent Claims Pipeline":**
- Each claim flows through 5 Cortex-powered agents: **Intake → Validation → Fraud Detection → Assessment → Resolution**
- Uses `CORTEX.COMPLETE` (llama3.1-8b) for fraud analysis, damage assessment, and resolution reasoning
- Uses `CORTEX.CLASSIFY_TEXT` for severity classification
- **Result:** 10 claims processed end-to-end. Avg. processing time: **15.8 seconds/claim**
- Decisions: **7 Approved** · **2 Partially Approved** · **1 Denied**
- Full audit trail with per-agent latency tracking

**Card 2 — "Churn Prediction & NBA":**
- Feature-based churn propensity scoring (payment regularity, sentiment, complaints, NPS, renewal proximity, loss ratio, tenure)
- `SP_CHURN_SCAN` auto-detects at-risk customers from FCT_CUSTOMER_360
- `SP_GENERATE_RETENTION_NBA` uses `CORTEX.COMPLETE` (llama3.3-70b) with RAG over retention playbooks
- Generates personalized retention offers with channel, timing, and success probability

**Card 3 — "Document Intelligence":**
- PDFs uploaded to Snowflake Internal Stages (zero external storage)
- `CORTEX.PARSE_DOCUMENT` extracts text from claim documents (police FIR, medical reports, garage estimates)
- `CORTEX.EMBED_TEXT_768` generates vector embeddings for semantic search
- `COMPUTE_FRAUD_SIMILARITY` compares claim text against known fraud patterns via vector cosine similarity

---

## Slide 5: Live Demo — The 4 Applications

**Layout:** 2×2 grid of app screenshots with descriptions

**Slide Title:** `Live Applications`

**App 1 (top-left) — "Claims & Policy Intake Portal":**
- 3 LOB-specific claim forms: Auto, Property, Workers Comp
- 3 policy application forms per LOB
- Document upload to Snowflake Internal Stage
- Real-time DQ validation (customer exists, policy active, LOB match, coverage limits)
- One-click AI pipeline trigger per claim

**App 2 (top-right) — "Customer 360 Dashboard":**
- 5 tabs: Executive Overview, Portfolio Analytics, Churn & Retention, Customer Deep-Dive, AI Pipeline Monitor
- Real-time KPIs: churn risk, sentiment, premium at risk, resolution decisions
- Fraud risk distribution, agent latency breakdown, segment analytics
- Drill-down to individual customer profiles with full history

**App 3 (bottom-left) — "NBA Chatbot":**
- Cortex AI-powered customer service chat (llama3.1-70b)
- Interaction logging to RAW.INTERACTIONS
- One-click NBA generation for customers with churn alerts
- Displays personalized retention offers with expected success rate

**App 4 (bottom-right) — "IDP Landing Page":**
- Central hub linking all 3 operational apps
- Platform-at-a-glance metrics (customers, policies, claims, alerts)
- **13-test integration test suite** validating all apps end-to-end
- Self-cleaning tests: insert → validate → cleanup

---

## Slide 6: What Makes This Special

**Layout:** Title + key differentiators list + closing statement

**Slide Title:** `Key Differentiators`

**Differentiators (use gold bullet icons):**

1. **100% Snowflake-Native** — No external infrastructure. Internal stages for documents, Cortex AI for intelligence, Snowpark for processing. Zero S3, zero third-party ML.

2. **Agentic AI Pipeline** — 5 specialized AI agents process each claim through a structured pipeline with full audit trail, latency tracking, and deterministic fallbacks for non-JSON LLM responses.

3. **Real-Time Feature Store** — `DT_CUSTOMER_360` (Dynamic Table, auto-refresh hourly) + `FCT_CUSTOMER_360` (60-feature fact table) built from 5 aggregation views spanning policies, claims, payments, interactions, and fraud embeddings.

4. **Production-Grade Testing** — 13-test integration suite embedded in the IDP landing page. Tests every app's data flow end-to-end with automatic cleanup. No separate test infra needed.

5. **AI at Every Layer** — Cortex `COMPLETE` for reasoning, `CLASSIFY_TEXT` for severity, `SENTIMENT` for interaction analysis, `PARSE_DOCUMENT` for OCR, `EMBED_TEXT_768` for semantic search, vector cosine similarity for fraud detection.

6. **DCM (Database Change Management)** — Full infrastructure-as-code with `manifest.yml`, rendering pipeline, and reproducible deployments.

**Closing Statement (centered, gold text):**

> *"From raw data to AI-powered decisions — entirely within Snowflake."*

**Bottom:** `IDP Insurance — Snowflake GCC India Hackathon`

---

## Appendix: Technical Inventory

*(Optional reference slide — include if time allows)*

| Category | Count | Details |
|---|---|---|
| **Database** | INSURANCE_DB | 4 schemas: RAW, PROCESSED, RESULTS, VECTORS |
| **RAW Tables** | 22 | Customers, Policies, Claims (3 LOBs), Payments, Interactions, Providers, Applications (3 LOBs), Document Registry |
| **PROCESSED Tables** | 5 | FCT_CUSTOMER_360, DT_CUSTOMER_360, CLAIM_STATE, CHURN_ALERTS, NEXT_BEST_ACTIONS |
| **Views** | 9 | 5 aggregation views, V_CHURN_DASHBOARD, V_PIPELINE_STATUS, V_NBA_FOR_CRM, FCT_CUSTOMER_360_VIEW |
| **Stored Procedures** | 14 | 5 Agent SPs, SP_BUILD_CUSTOMER_360, SP_PROCESS_CLAIM, SP_CHURN_PIPELINE_FULL, SP_GENERATE_RETENTION_NBA, + more |
| **Stages** | 5 | DOCUMENTS_STAGE, EVIDENCE_STAGE, POLICY_DOCS_STAGE, KNOWLEDGE_BASE_STAGE, SEMANTIC_MODELS_STAGE |
| **Streamlit Apps** | 4 | Claims Intake, Customer 360 Dashboard, NBA Chatbot, IDP Landing |
| **Cortex AI Functions** | 6 | COMPLETE, CLASSIFY_TEXT, SENTIMENT, PARSE_DOCUMENT, EMBED_TEXT_768, Vector Cosine Similarity |
| **Dynamic Tables** | 1 | DT_CUSTOMER_360 (hourly refresh, FULL mode) |
| **UDFs** | 1 | COMPUTE_FRAUD_SIMILARITY (vector-based) |
