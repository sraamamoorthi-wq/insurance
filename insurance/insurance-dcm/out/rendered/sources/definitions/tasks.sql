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

-- Daily DAG root: Customer 360 build (6 AM UTC)
DEFINE TASK INSURANCE_DB.PROCESSED.TASK_BUILD_CUSTOMER_360
    WAREHOUSE = AGENT_WH
    SCHEDULE = 'USING CRON 0 6 * * * UTC'
    ALLOW_OVERLAPPING_EXECUTION = FALSE
    COMMENT = 'Daily Customer 360 materialization - aggregates all features'
AS
    CALL INSURANCE_DB.PROCESSED.SP_BUILD_CUSTOMER_360();

-- DAG child 1: extract unstructured features (after Customer 360 build)
DEFINE TASK INSURANCE_DB.PROCESSED.TASK_EXTRACT_UNSTRUCTURED_FEATURES
    WAREHOUSE = AGENT_WH
    COMMENT = 'Batch LLM extraction of unstructured features from interactions'
    AFTER INSURANCE_DB.PROCESSED.TASK_BUILD_CUSTOMER_360
AS
    CALL INSURANCE_DB.PROCESSED.SP_EXTRACT_UNSTRUCTURED_FEATURES_BATCH();

-- DAG child 2: churn scan (after unstructured features)
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

-- Event-driven: refresh sentiment on new interactions (5-min poll)
DEFINE TASK INSURANCE_DB.PROCESSED.TASK_REFRESH_SENTIMENT
    WAREHOUSE = EVAL_WH
    SCHEDULE = '5 MINUTE'
    ALLOW_OVERLAPPING_EXECUTION = FALSE
    COMMENT = 'Refreshes sentiment scores when new interactions arrive'
    WHEN SYSTEM$STREAM_HAS_DATA('INSURANCE_DB.RAW.INTERACTIONS_STREAM')
AS
BEGIN
    MERGE INTO INSURANCE_DB.PROCESSED.FCT_CUSTOMER_360 tgt
    USING (
        SELECT DISTINCT
            s.customer_id,
            SNOWFLAKE.CORTEX.SENTIMENT(s.transcript_text) AS new_sentiment
        FROM INSURANCE_DB.RAW.INTERACTIONS_STREAM s
    ) src
    ON tgt.customer_id = src.customer_id
    WHEN MATCHED THEN UPDATE SET
        sentiment_score_last_30d = src.new_sentiment,
        last_interaction_days_ago = 0,
        last_refreshed_at = CURRENT_TIMESTAMP();
END;

-- Event-driven: post-decision actions (1-min poll)
DEFINE TASK INSURANCE_DB.RESULTS.TASK_POST_DECISION_ACTIONS
    WAREHOUSE = EVAL_WH
    SCHEDULE = '1 MINUTE'
    ALLOW_OVERLAPPING_EXECUTION = FALSE
    COMMENT = 'Post-decision: notifications, 360 update, stakeholder alerts'
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

    UPDATE INSURANCE_DB.PROCESSED.FCT_CUSTOMER_360 tgt
    SET open_claims_count = open_claims_count - 1,
        last_refreshed_at = CURRENT_TIMESTAMP()
    FROM INSURANCE_DB.RESULTS.RESOLUTIONS_STREAM s
    WHERE tgt.customer_id = s.customer_id;
END;

-- Event-driven: refresh payment features (15-min poll)
DEFINE TASK INSURANCE_DB.PROCESSED.TASK_REFRESH_PAYMENTS
    WAREHOUSE = EVAL_WH
    SCHEDULE = '15 MINUTE'
    ALLOW_OVERLAPPING_EXECUTION = FALSE
    COMMENT = 'Updates payment behavior features when new payments recorded'
    WHEN SYSTEM$STREAM_HAS_DATA('INSURANCE_DB.RAW.PAYMENTS_STREAM')
AS
BEGIN
    MERGE INTO INSURANCE_DB.PROCESSED.FCT_CUSTOMER_360 tgt
    USING (
        SELECT
            s.customer_id,
            AVG(s.days_delayed) AS latest_delay,
            SUM(CASE WHEN s.payment_status = 'MISSED' THEN 1 ELSE 0 END) AS new_missed
        FROM INSURANCE_DB.RAW.PAYMENTS_STREAM s
        GROUP BY s.customer_id
    ) src
    ON tgt.customer_id = src.customer_id
    WHEN MATCHED THEN UPDATE SET
        payment_delay_avg_days = (tgt.payment_delay_avg_days + src.latest_delay) / 2,
        missed_payments_12m = tgt.missed_payments_12m + src.new_missed,
        last_payment_days_ago = 0,
        last_refreshed_at = CURRENT_TIMESTAMP();
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