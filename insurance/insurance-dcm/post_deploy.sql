-- ============================================================================
-- POST-DEPLOY: Objects not supported by DCM DEFINE statements
-- Run AFTER snow dcm deploy completes
-- ============================================================================

-- ============================================================================
-- 0. COMPLEX SQL UDF (moved from definitions - DCM analyzer can't compile it)
-- ============================================================================

CREATE OR REPLACE FUNCTION INSURANCE_DB.VECTORS.FIND_SIMILAR_FRAUD_PATTERNS(
    claim_text VARCHAR,
    lob VARCHAR,
    top_k INT
)
RETURNS VARIANT
LANGUAGE SQL
AS
$$
    SELECT ARRAY_AGG(OBJECT_CONSTRUCT(
        'pattern_type', pattern_type,
        'severity', severity,
        'similarity_score', VECTOR_COSINE_SIMILARITY(
            SNOWFLAKE.CORTEX.EMBED_TEXT_768('snowflake-arctic-embed-m', claim_text)::VECTOR(FLOAT, 768),
            pattern_embedding
        ),
        'description', LEFT(pattern_description, 200)
    )) WITHIN GROUP (ORDER BY VECTOR_COSINE_SIMILARITY(
        SNOWFLAKE.CORTEX.EMBED_TEXT_768('snowflake-arctic-embed-m', claim_text)::VECTOR(FLOAT, 768),
        pattern_embedding
    ) DESC)
    FROM (
        SELECT *
        FROM INSURANCE_DB.VECTORS.FRAUD_PATTERN_EMBEDDINGS
        WHERE lob_type = lob OR lob_type = 'ALL'
        ORDER BY VECTOR_COSINE_SIMILARITY(
            SNOWFLAKE.CORTEX.EMBED_TEXT_768('snowflake-arctic-embed-m', claim_text)::VECTOR(FLOAT, 768),
            pattern_embedding
        ) DESC
        LIMIT top_k
    )
$$;

USE ROLE INSURANCE_APP_ROLE;
USE DATABASE INSURANCE_DB;
USE WAREHOUSE AGENT_WH;

-- ============================================================================
-- 0B. VIEWS using INFORMATION_SCHEMA table functions (DCM can't compile these)
-- ============================================================================

CREATE OR REPLACE VIEW INSURANCE_DB.PROCESSED.V_TASK_HISTORY AS
SELECT
    name AS task_name, state, scheduled_time, completed_time,
    DATEDIFF(second, scheduled_time, completed_time) AS duration_seconds,
    error_code, error_message, return_value
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
    SCHEDULED_TIME_RANGE_START => DATEADD(hour, -24, CURRENT_TIMESTAMP()),
    RESULT_LIMIT => 100
))
ORDER BY scheduled_time DESC;

CREATE OR REPLACE VIEW INSURANCE_DB.PROCESSED.V_TASK_STATUS AS
SELECT
    name AS task_name, schema_name, state, scheduled_time, completed_time,
    DATEDIFF(second, scheduled_time, completed_time) AS duration_seconds,
    error_code, error_message
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
    RESULT_LIMIT => 50
))
ORDER BY scheduled_time DESC;

-- ============================================================================
-- 1. PYTHON STORED PROCEDURES (5 AI Agent SPs from NB_03)
--    DCM supports SQL procedures; Python SPs go here.
--    These are very large - run NB_03_Agents.ipynb directly in Snowsight
--    to create these, or copy from the notebook SQL.
-- ============================================================================

-- SP_AGENT_INTAKE       -> See NB_03_Agents.ipynb Cell 2
-- SP_AGENT_VALIDATION   -> See NB_03_Agents.ipynb Cell 3
-- SP_AGENT_FRAUD        -> See NB_03_Agents.ipynb Cell 4
-- SP_AGENT_ASSESSMENT   -> See NB_03_Agents.ipynb Cell 5
-- SP_AGENT_RESOLUTION   -> See NB_03_Agents.ipynb Cell 6

-- NOTE: The task TASK_CLAIMS_ORCHESTRATOR calls SP_ORCHESTRATE_BATCH().
-- If this is a renamed version of SP_PROCESS_ALL_CLAIMS, you may need to
-- create an alias or rename accordingly.

-- ============================================================================
-- 2. CORTEX SEARCH SERVICES (6 total, from NB_02 and NB_07)
--    Not supported by DEFINE
-- ============================================================================

CREATE OR REPLACE CORTEX SEARCH SERVICE INSURANCE_DB.VECTORS.FRAUD_PATTERNS_SEARCH_SERVICE
    ON pattern_description
    ATTRIBUTES lob_type, severity, pattern_type
    WAREHOUSE = AGENT_WH
    TARGET_LAG = '1 hour'
    AS (
        SELECT indicator_id, pattern_type, pattern_description, example_narrative,
               lob_type, severity, confirmed_cases, last_seen_date
        FROM INSURANCE_DB.RAW.FRAUD_INDICATORS
    );

CREATE OR REPLACE CORTEX SEARCH SERVICE INSURANCE_DB.VECTORS.UNDERWRITING_GUIDELINES_SEARCH_SERVICE
    ON content
    ATTRIBUTES lob_type, risk_level, section_name, status
    WAREHOUSE = AGENT_WH
    TARGET_LAG = '1 hour'
    AS (
        SELECT guideline_id, lob_type, section_name, content, risk_level,
               regulatory_reference, effective_date, status
        FROM INSURANCE_DB.RAW.UNDERWRITING_GUIDELINES
        WHERE status = 'CURRENT'
    );

CREATE OR REPLACE CORTEX SEARCH SERVICE INSURANCE_DB.VECTORS.RETENTION_PLAYBOOKS_SEARCH_SERVICE
    ON content
    ATTRIBUTES customer_segment, root_cause, playbook_name
    WAREHOUSE = AGENT_WH
    TARGET_LAG = '1 hour'
    AS (
        SELECT playbook_id, customer_segment, root_cause, playbook_name,
               content, success_rate, applicable_lob
        FROM INSURANCE_DB.RAW.RETENTION_PLAYBOOKS
    );

CREATE OR REPLACE CORTEX SEARCH SERVICE INSURANCE_DB.VECTORS.CLAIM_DOCUMENTS_SEARCH_SERVICE
    ON extracted_text
    ATTRIBUTES document_type, lob_type, claim_id
    WAREHOUSE = AGENT_WH
    TARGET_LAG = '30 minutes'
    AS (
        SELECT document_id, claim_id, document_type, file_name, extracted_text,
               lob_type, upload_date
        FROM INSURANCE_DB.RAW.DOCUMENTS
        WHERE extraction_status = 'EXTRACTED'
          AND extracted_text IS NOT NULL
    );

CREATE OR REPLACE CORTEX SEARCH SERVICE INSURANCE_DB.VECTORS.HISTORICAL_CLAIMS_SEARCH_SERVICE
    ON reasoning_summary
    ATTRIBUTES lob_type, decision, fraud_risk_level
    WAREHOUSE = AGENT_WH
    TARGET_LAG = '1 hour'
    AS (
        SELECT r.resolution_id, r.claim_id, r.lob_type, r.decision,
               r.settlement_amount, r.claimed_amount, r.fraud_risk_level,
               r.fraud_score, r.reasoning_summary, r.confidence_score, r.decided_at
        FROM INSURANCE_DB.RESULTS.RESOLUTIONS r
    );

-- NB_07 document search (uses DOCUMENT_REGISTRY instead of DOCUMENTS)
CREATE OR REPLACE CORTEX SEARCH SERVICE INSURANCE_DB.VECTORS.CLAIM_DOCUMENTS_SEARCH_SERVICE
    ON extracted_text
    ATTRIBUTES document_type, lob_type, claim_id, customer_id
    WAREHOUSE = AGENT_WH
    TARGET_LAG = '30 minutes'
    AS (
        SELECT document_id, claim_id, customer_id, document_type,
               lob_type, file_name, extracted_text
        FROM INSURANCE_DB.RAW.DOCUMENT_REGISTRY
        WHERE extraction_status = 'EXTRACTED'
          AND extracted_text IS NOT NULL
    );

-- ============================================================================
-- 3. DATA SHARING (from NB_06)
-- ============================================================================

USE ROLE ACCOUNTADMIN;

ALTER VIEW INSURANCE_DB.PROCESSED.V_NBA_FOR_CRM SET SECURE;

CREATE OR REPLACE SHARE RETENTION_ACTIONS_SHARE
    COMMENT = 'Zero-copy share of Next Best Actions to CRM';

GRANT USAGE ON DATABASE INSURANCE_DB TO SHARE RETENTION_ACTIONS_SHARE;
GRANT USAGE ON SCHEMA INSURANCE_DB.PROCESSED TO SHARE RETENTION_ACTIONS_SHARE;
GRANT SELECT ON VIEW INSURANCE_DB.PROCESSED.V_NBA_FOR_CRM TO SHARE RETENTION_ACTIONS_SHARE;

-- ============================================================================
-- 4. TABLE-LEVEL GRANTS (ON ALL TABLES - not supported in DCM definitions)
-- ============================================================================

USE ROLE ACCOUNTADMIN;

GRANT SELECT ON ALL TABLES IN SCHEMA INSURANCE_DB.RESULTS TO ROLE INSURANCE_ADJUSTER_ROLE;
GRANT SELECT ON ALL TABLES IN SCHEMA INSURANCE_DB.PROCESSED TO ROLE INSURANCE_ADJUSTER_ROLE;
GRANT SELECT ON ALL TABLES IN SCHEMA INSURANCE_DB.RESULTS TO ROLE INSURANCE_UNDERWRITER_ROLE;
GRANT SELECT ON ALL TABLES IN SCHEMA INSURANCE_DB.PROCESSED TO ROLE INSURANCE_RETENTION_ROLE;

-- ============================================================================
-- 5. CORTEX AGENT: Conversational interface to claims + underwriting data
--    Uses Cortex Search services as tools for RAG-grounded answers
-- ============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE INSURANCE_DB;
USE WAREHOUSE AGENT_WH;

CREATE OR REPLACE CORTEX AGENT INSURANCE_DB.PROCESSED.INSURANCE_AGENT
    COMMENT = 'Conversational agent for insurance claims inquiries, fraud patterns, and underwriting guidelines'
    CORTEX_SEARCH_SERVICES = (
        INSURANCE_DB.VECTORS.FRAUD_PATTERNS_SEARCH_SERVICE,
        INSURANCE_DB.VECTORS.UNDERWRITING_GUIDELINES_SEARCH_SERVICE,
        INSURANCE_DB.VECTORS.RETENTION_PLAYBOOKS_SEARCH_SERVICE,
        INSURANCE_DB.VECTORS.HISTORICAL_CLAIMS_SEARCH_SERVICE
    );
