-- ============================================================================
-- FUNCTIONS: SQL UDFs for classification, sentiment, search, embeddings
-- ============================================================================

DEFINE FUNCTION INSURANCE_DB.PROCESSED.CLASSIFY_LOB(claim_text VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
    SELECT SNOWFLAKE.CORTEX.COMPLETE(
        'mistral-large2',
        CONCAT('Classify into one LOB. Reply with ONLY: AUTO or PROPERTY or WORKERS_COMP\n\nClaim: ', LEFT(claim_text, 1000))
    )
$$;

DEFINE FUNCTION INSURANCE_DB.PROCESSED.CLAIM_SENTIMENT(claim_text VARCHAR)
RETURNS FLOAT
LANGUAGE SQL
AS
$$
    SELECT SNOWFLAKE.CORTEX.SENTIMENT(claim_text)
$$;

DEFINE FUNCTION INSURANCE_DB.PROCESSED.SUMMARIZE_CLAIM(claim_text VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
    SELECT SNOWFLAKE.CORTEX.SUMMARIZE(claim_text)
$$;

DEFINE FUNCTION INSURANCE_DB.VECTORS.COMPUTE_FRAUD_SIMILARITY(claim_text VARCHAR)
RETURNS FLOAT
LANGUAGE SQL
AS
$$
    SELECT MAX(VECTOR_COSINE_SIMILARITY(
        SNOWFLAKE.CORTEX.EMBED_TEXT_768('snowflake-arctic-embed-m', claim_text)::VECTOR(FLOAT, 768),
        pattern_embedding
    ))
    FROM INSURANCE_DB.VECTORS.FRAUD_PATTERN_EMBEDDINGS
$$;

-- NOTE: FIND_SIMILAR_FRAUD_PATTERNS moved to post_deploy.sql
-- (DCM analyzer cannot compile complex nested SQL UDFs with subqueries)
