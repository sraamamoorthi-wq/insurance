-- ============================================================================
-- INFRASTRUCTURE: Schemas, Warehouses, Stages, File Formats, Tags
-- ============================================================================
-- NOTE: INSURANCE_DB (database) and INSURANCE_DB.RAW (schema) are NOT defined
-- here because they are the DCM project's parent containers and must pre-exist.
-- ============================================================================

-- Schemas (all except RAW which is the project's parent schema)
DEFINE SCHEMA INSURANCE_DB.PROCESSED
    COMMENT = 'Enriched data - agent outputs, Customer 360, NBA';

DEFINE SCHEMA INSURANCE_DB.RESULTS
    COMMENT = 'Final decisions - resolutions, underwriting, audit trail';

DEFINE SCHEMA INSURANCE_DB.VECTORS
    COMMENT = 'RAG embeddings - document chunks, fraud patterns';

-- Warehouses
DEFINE WAREHOUSE AGENT_WH
    WAREHOUSE_SIZE = 'MEDIUM'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    MIN_CLUSTER_COUNT = 1
    MAX_CLUSTER_COUNT = 3
    SCALING_POLICY = 'STANDARD'
    COMMENT = 'Agent pipeline processing - Cortex LLM/Analyst/Search calls';

DEFINE WAREHOUSE EVAL_WH
    WAREHOUSE_SIZE = 'X-SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    COMMENT = 'Lightweight evaluation tasks - daily scans, monitoring';

DEFINE WAREHOUSE INGEST_WH
    WAREHOUSE_SIZE = 'SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    COMMENT = 'Data ingestion - Snowpipe, Stream consumption';

-- Internal Stages (all in RAW schema)
DEFINE STAGE INSURANCE_DB.RAW.SEMANTIC_MODELS_STAGE
    COMMENT = 'Cortex Analyst semantic model YAML files';

DEFINE STAGE INSURANCE_DB.RAW.KNOWLEDGE_BASE_STAGE
    COMMENT = 'RAG knowledge base documents (underwriting guides, playbooks)';

DEFINE STAGE INSURANCE_DB.RAW.DOCUMENTS_STAGE
    DIRECTORY = (ENABLE = TRUE)
    ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')
    COMMENT = 'Internal stage for claim documents - PDFs, photos, reports. No external storage needed.';

DEFINE STAGE INSURANCE_DB.RAW.POLICY_DOCS_STAGE
    DIRECTORY = (ENABLE = TRUE)
    ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')
    COMMENT = 'Internal stage for policy application documents';

DEFINE STAGE INSURANCE_DB.RAW.EVIDENCE_STAGE
    DIRECTORY = (ENABLE = TRUE)
    ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')
    COMMENT = 'Internal stage for evidence documents (FIR, medical, fire investigation)';

-- File Format
DEFINE FILE FORMAT INSURANCE_DB.RAW.CSV_FORMAT
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    NULL_IF = ('NULL', 'null', '')
    COMMENT = 'Standard CSV format for bulk data loads';

-- Tags
DEFINE TAG INSURANCE_DB.RAW.PII_TAG
    COMMENT = 'Marks columns containing Personally Identifiable Information';

DEFINE TAG INSURANCE_DB.RAW.SENSITIVITY_TAG
    ALLOWED_VALUES 'LOW', 'MEDIUM', 'HIGH', 'CRITICAL'
    COMMENT = 'Data sensitivity classification';
