-- ============================================================================
-- TASKS: Event-driven + scheduled task DAG for automation
-- ============================================================================

-- Event-driven: processes new claims through 5-agent pipeline (1-min poll)
DEFINE TASK INSURANCE_DB.PROCESSED.TASK_CLAIMS_ORCHESTRATOR
    WAREHOUSE = AGENT_WH
    SCHEDULE = '1 MINUTE'
    ALLOW_OVERLAPPING_EXECUTION = FALSE
    COMMENT = 'Processes new claims through 5-agent pipeline when stream has data'
    WHEN SYSTEM$STREAM_HAS_DATA('INSURANCE_DB.RAW.CLAIMS_LANDING_STREAM')
AS
    CALL INSURANCE_DB.PROCESSED.SP_ORCHESTRATE_BATCH();

-- Event-driven: processes new applications through underwriting pipeline (1-min poll)
DEFINE TASK INSURANCE_DB.PROCESSED.TASK_UNDERWRITING_ORCHESTRATOR
    WAREHOUSE = AGENT_WH
    SCHEDULE = '1 MINUTE'
    ALLOW_OVERLAPPING_EXECUTION = FALSE
    COMMENT = 'Processes new policy applications through 3-step underwriting pipeline'
    WHEN SYSTEM$STREAM_HAS_DATA('INSURANCE_DB.RAW.APPLICATIONS_STREAM')
AS
BEGIN
    FOR app IN (
        SELECT application_id FROM INSURANCE_DB.RAW.APPLICATIONS
        WHERE status = 'PENDING'
        ORDER BY submission_date ASC LIMIT 10
    ) DO
        CALL INSURANCE_DB.PROCESSED.SP_PROCESS_APPLICATION(app.application_id);
    END FOR;
END;

-- Daily churn pipeline root: extract unstructured features (6 AM UTC)
-- (Replaces old TASK_BUILD_CUSTOMER_360 - C360 is now a Dynamic Table)
DEFINE TASK INSURANCE_DB.PROCESSED.TASK_EXTRACT_UNSTRUCTURED_FEATURES
    WAREHOUSE = AGENT_WH
    SCHEDULE = 'USING CRON 0 6 * * * UTC'
    ALLOW_OVERLAPPING_EXECUTION = FALSE
    COMMENT = 'Batch LLM extraction of unstructured features from interactions'
AS
    CALL INSURANCE_DB.PROCESSED.SP_EXTRACT_UNSTRUCTURED_FEATURES_BATCH();

-- DAG child 1: churn scan (after unstructured features)
DEFINE TASK INSURANCE_DB.PROCESSED.TASK_CHURN_SCAN
    WAREHOUSE = EVAL_WH
    COMMENT = 'Daily churn risk scan on Customer 360 - identifies at-risk customers'
    AFTER INSURANCE_DB.PROCESSED.TASK_EXTRACT_UNSTRUCTURED_FEATURES
AS
    CALL INSURANCE_DB.PROCESSED.SP_CHURN_SCAN();

-- DAG child 3: churn NBA (after churn scan)
DEFINE TASK INSURANCE_DB.PROCESSED.TASK_CHURN_NBA
    WAREHOUSE = AGENT_WH
    COMMENT = 'Generates retention NBAs for at-risk customers using RAG + LLM'
    AFTER INSURANCE_DB.PROCESSED.TASK_CHURN_SCAN
AS
    CALL INSURANCE_DB.PROCESSED.SP_CHURN_PIPELINE_FULL();

-- Event-driven: post-decision audit logging (1-min poll)
DEFINE TASK INSURANCE_DB.RESULTS.TASK_POST_DECISION_ACTIONS
    WAREHOUSE = EVAL_WH
    SCHEDULE = '1 MINUTE'
    ALLOW_OVERLAPPING_EXECUTION = FALSE
    COMMENT = 'Post-decision: audit logging and stakeholder notifications'
    WHEN SYSTEM$STREAM_HAS_DATA('INSURANCE_DB.RESULTS.RESOLUTIONS_STREAM')
AS
BEGIN
    INSERT INTO INSURANCE_DB.RESULTS.AUDIT_LOG
        (flow_type, reference_id, agent_name, step_number, status, output_payload)
    SELECT
        'CLAIMS',
        s.claim_id,
        'POST_DECISION_TASK',
        99,
        'SUCCESS',
        OBJECT_CONSTRUCT(
            'decision', s.decision,
            'settlement', s.settlement_amount,
            'notification_sent', TRUE
        )
    FROM INSURANCE_DB.RESULTS.RESOLUTIONS_STREAM s;
END;

-- Weekly: refresh fraud pattern embeddings (Sunday 2 AM UTC)
DEFINE TASK INSURANCE_DB.VECTORS.TASK_REFRESH_EMBEDDINGS
    WAREHOUSE = AGENT_WH
    SCHEDULE = 'USING CRON 0 2 * * 0 UTC'
    ALLOW_OVERLAPPING_EXECUTION = FALSE
    COMMENT = 'Weekly refresh of fraud pattern embeddings'
AS
BEGIN
    MERGE INTO INSURANCE_DB.VECTORS.FRAUD_PATTERN_EMBEDDINGS tgt
    USING (
        SELECT
            indicator_id AS pattern_id,
            pattern_type,
            pattern_description,
            SNOWFLAKE.CORTEX.EMBED_TEXT_768('snowflake-arctic-embed-m', pattern_description)::VECTOR(FLOAT, 768) AS pattern_embedding,
            severity,
            lob_type
        FROM INSURANCE_DB.RAW.FRAUD_INDICATORS
    ) src
    ON tgt.pattern_id = src.pattern_id
    WHEN NOT MATCHED THEN INSERT
        (pattern_id, pattern_type, pattern_description, pattern_embedding, severity, lob_type)
    VALUES
        (src.pattern_id, src.pattern_type, src.pattern_description, src.pattern_embedding, src.severity, src.lob_type);
END;

-- Monitoring: system health check (every 3 hours)
DEFINE TASK INSURANCE_DB.PROCESSED.TASK_HEALTH_CHECK
    WAREHOUSE = EVAL_WH
    SCHEDULE = '180 MINUTE'
    ALLOW_OVERLAPPING_EXECUTION = FALSE
    COMMENT = 'System health monitoring - checks for stuck claims, errors'
AS
BEGIN
    UPDATE INSURANCE_DB.PROCESSED.CLAIM_STATE
    SET error_message = 'TIMEOUT: Stuck in pipeline > 5 minutes',
        current_state = 'FAILED'
    WHERE current_state NOT IN ('COMPLETED', 'FAILED')
      AND started_at < DATEADD(minute, -5, CURRENT_TIMESTAMP())
      AND completed_at IS NULL;

    UPDATE INSURANCE_DB.RAW.CLAIMS_LANDING
    SET claim_status = 'MANUAL_REVIEW'
    WHERE claim_id IN (
        SELECT claim_id FROM INSURANCE_DB.PROCESSED.CLAIM_STATE
        WHERE current_state = 'FAILED'
    )
    AND claim_status NOT IN ('MANUAL_REVIEW', 'APPROVED', 'DENIED', 'REFERRED');

    INSERT INTO INSURANCE_DB.RESULTS.AUDIT_LOG
        (flow_type, reference_id, agent_name, step_number, status, output_payload)
    VALUES (
        'SYSTEM', 'HEALTH_CHECK', 'MONITOR', 0, 'SUCCESS',
        OBJECT_CONSTRUCT(
            'timestamp', CURRENT_TIMESTAMP(),
            'pending_claims', (SELECT COUNT(*) FROM INSURANCE_DB.PROCESSED.CLAIM_STATE WHERE current_state NOT IN ('COMPLETED', 'FAILED')),
            'failed_claims', (SELECT COUNT(*) FROM INSURANCE_DB.PROCESSED.CLAIM_STATE WHERE current_state = 'FAILED'),
            'completed_today', (SELECT COUNT(*) FROM INSURANCE_DB.PROCESSED.CLAIM_STATE WHERE completed_at >= CURRENT_DATE())
        )
    );
END;
