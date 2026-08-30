# Snowflake Notebooks — Insurance Claims Agentic AI

Seven consolidated Snowflake Notebooks that build the full solution. Import each `.ipynb` into Snowsight and run top to bottom, in order.

## Run Order

| # | Notebook | What it does | SQL cells |
|---|----------|-------------|-----------|
| 1 | `NB_01_Setup.ipynb` | Database, schemas, warehouses, roles, all tables + Manapakkam sample data | 29 |
| 2 | `NB_02_Cortex_Search.ipynb` | 5 Cortex Search services + fraud embedding infrastructure | 10 |
| 3 | `NB_03_Agents.ipynb` | 5-agent pipeline + orchestrator (Cortex COMPLETE/SENTIMENT/EMBED/SEARCH/Guardrails) | 10 |
| 4 | `NB_04_Customer360.ipynb` | FCT_CUSTOMER_360 build with unstructured feature extraction | 7 |
| 5 | `NB_05_Churn.ipynb` | Churn scan + root cause + retention NBA | 6 |
| 6 | `NB_06_Streams_Tasks.ipynb` | Streams + Task DAG for automation | 15 |
| 7 | `NB_07_Documents.ipynb` | Internal stages, LOB tables, PARSE_DOCUMENT + EMBED pipeline | 8 |

## How to Import into Snowsight

1. In Snowsight, go to **Projects → Notebooks**
2. Click the **▼** next to "+ Notebook" → **Import .ipynb file**
3. Select the notebook file
4. Set:
   - **Database:** `INSURANCE_DB` (after NB_01 creates it; for NB_01 use any DB)
   - **Schema:** `RAW`
   - **Warehouse:** `AGENT_WH` (after NB_01 creates it; for NB_01 use a default warehouse)
5. Click **Create**, then **Run All** (or run cells one at a time)

> For **NB_01**, since the database/warehouse don't exist yet, create the notebook against any existing database + your default warehouse. The first cells create `INSURANCE_DB` and `AGENT_WH`.

## Cell Format

- **Markdown cells** — section headers and explanations
- **SQL cells** — each tagged with `language: sql`; run against the notebook's warehouse
- Each **stored procedure** is isolated in its own cell so you can re-run individual agents

## Quick Demo (after all notebooks run)

Run these in NB_03 (or any SQL cell / worksheet):

```sql
-- Process the legitimate HNW multi-LOB claim
CALL PROCESSED.SP_PROCESS_CLAIM('CLM-001-AUTO');

-- Process the suspicious claim
CALL PROCESSED.SP_PROCESS_CLAIM('CLM-005-AUTO');

-- View results
SELECT * FROM PROCESSED.V_PIPELINE_STATUS;
SELECT * FROM RESULTS.RESOLUTIONS ORDER BY decided_at DESC;
```

## Regenerating the Notebooks

The notebooks are generated from the `.sql` files in the parent folder by `build_notebooks.py`:

```powershell
python build_notebooks.py
```

Edit the SQL files, then re-run to regenerate. The generator splits each SQL file on the `-- ====` banner comments into markdown + SQL cells.

## Streamlit Apps (deploy separately, not as notebooks)

- `14_streamlit_app.py` — main Customer 360 + claims dashboard
- `16_streamlit_intake_forms.py` — LOB intake forms + document upload

Deploy these as **Streamlit in Snowflake** apps (Projects → Streamlit), database `INSURANCE_DB`, schema `RAW`, warehouse `AGENT_WH`.

## Semantic Model (upload to stage)

- `04_semantic_model.yaml` — upload to `@INSURANCE_DB.STAGES.SEMANTIC_MODELS_STAGE` for Cortex Analyst
