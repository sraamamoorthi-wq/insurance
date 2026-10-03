-- ============================================================================
-- POST-DEPLOY: Complete platform bootstrap
-- Run AFTER: pre_deploy.sql → DCM deploy → seed_data.sql
-- This script wires everything together: Cortex Search, embeddings,
-- DMF schedules, pipeline execution, and Cortex Agent.
-- ============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE INSURANCE_DB;
USE WAREHOUSE AGENT_WH;

-- ============================================================================
-- 1. COMPLEX UDF (DCM analyzer can't compile vector + subquery UDFs)
-- ============================================================================
CREATE OR REPLACE FUNCTION INSURANCE_DB.VECTORS.FIND_SIMILAR_FRAUD_PATTERNS(
    claim_text VARCHAR, lob VARCHAR, top_k INT
)
RETURNS VARIANT
LANGUAGE SQL
AS
$$
    SELECT ARRAY_AGG(OBJECT_CONSTRUCT(
        'pattern_type', pattern_type, 'severity', severity,
        'similarity_score', VECTOR_COSINE_SIMILARITY(
            SNOWFLAKE.CORTEX.EMBED_TEXT_768('snowflake-arctic-embed-m', claim_text)::VECTOR(FLOAT, 768),
            pattern_embedding),
        'description', LEFT(pattern_description, 200)
    )) WITHIN GROUP (ORDER BY VECTOR_COSINE_SIMILARITY(
        SNOWFLAKE.CORTEX.EMBED_TEXT_768('snowflake-arctic-embed-m', claim_text)::VECTOR(FLOAT, 768),
        pattern_embedding) DESC)
    FROM (
        SELECT * FROM INSURANCE_DB.VECTORS.FRAUD_PATTERN_EMBEDDINGS
        WHERE lob_type = lob OR lob_type = 'ALL'
        ORDER BY VECTOR_COSINE_SIMILARITY(
            SNOWFLAKE.CORTEX.EMBED_TEXT_768('snowflake-arctic-embed-m', claim_text)::VECTOR(FLOAT, 768),
            pattern_embedding) DESC
        LIMIT top_k
    )
$$;

-- ============================================================================
-- 2. VIEWS using INFORMATION_SCHEMA (DCM can't compile these)
-- ============================================================================
CREATE OR REPLACE VIEW INSURANCE_DB.PROCESSED.V_TASK_HISTORY AS
SELECT name AS task_name, state, scheduled_time, completed_time,
       DATEDIFF(second, scheduled_time, completed_time) AS duration_seconds,
       error_code, error_message, return_value
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
    SCHEDULED_TIME_RANGE_START => DATEADD(hour, -24, CURRENT_TIMESTAMP()),
    RESULT_LIMIT => 100
)) ORDER BY scheduled_time DESC;

CREATE OR REPLACE VIEW INSURANCE_DB.PROCESSED.V_TASK_STATUS AS
SELECT name AS task_name, schema_name, state, scheduled_time, completed_time,
       DATEDIFF(second, scheduled_time, completed_time) AS duration_seconds,
       error_code, error_message
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(RESULT_LIMIT => 50))
ORDER BY scheduled_time DESC;

-- ============================================================================
-- 3. FRAUD PATTERN EMBEDDINGS (vectorize fraud indicators)
-- ============================================================================
MERGE INTO INSURANCE_DB.VECTORS.FRAUD_PATTERN_EMBEDDINGS tgt
USING (
    SELECT indicator_id AS pattern_id, pattern_type, pattern_description,
           SNOWFLAKE.CORTEX.EMBED_TEXT_768('snowflake-arctic-embed-m', pattern_description)::VECTOR(FLOAT, 768) AS pattern_embedding,
           severity, lob_type
    FROM INSURANCE_DB.RAW.FRAUD_INDICATORS
) src ON tgt.pattern_id = src.pattern_id
WHEN NOT MATCHED THEN INSERT (pattern_id, pattern_type, pattern_description, pattern_embedding, severity, lob_type)
VALUES (src.pattern_id, src.pattern_type, src.pattern_description, src.pattern_embedding, src.severity, src.lob_type);

-- ============================================================================
-- 4. CORTEX SEARCH SERVICES (5 services — need data loaded first)
-- ============================================================================
CREATE OR REPLACE CORTEX SEARCH SERVICE INSURANCE_DB.VECTORS.FRAUD_INDICATORS_SEARCH_SERVICE
    ON pattern_description
    ATTRIBUTES pattern_type, lob_type, severity
    WAREHOUSE = AGENT_WH
    TARGET_LAG = '1 hour'
    AS (SELECT indicator_id, pattern_type, pattern_description, lob_type, severity, example_narrative
        FROM INSURANCE_DB.RAW.FRAUD_INDICATORS);

CREATE OR REPLACE CORTEX SEARCH SERVICE INSURANCE_DB.VECTORS.UNDERWRITING_GUIDELINES_SEARCH_SERVICE
    ON content
    ATTRIBUTES lob_type, risk_level, section_name
    WAREHOUSE = AGENT_WH
    TARGET_LAG = '1 hour'
    AS (SELECT guideline_id, lob_type, section_name, content, risk_level, regulatory_reference
        FROM INSURANCE_DB.RAW.UNDERWRITING_GUIDELINES WHERE status = 'CURRENT');

CREATE OR REPLACE CORTEX SEARCH SERVICE INSURANCE_DB.VECTORS.RETENTION_PLAYBOOKS_SEARCH_SERVICE
    ON content
    ATTRIBUTES customer_segment, root_cause, applicable_lob
    WAREHOUSE = AGENT_WH
    TARGET_LAG = '1 hour'
    AS (SELECT playbook_id, customer_segment, root_cause, playbook_name, content, recommended_actions, success_rate, applicable_lob
        FROM INSURANCE_DB.RAW.RETENTION_PLAYBOOKS);

CREATE OR REPLACE CORTEX SEARCH SERVICE INSURANCE_DB.VECTORS.CLAIMS_HISTORY_SEARCH_SERVICE
    ON claim_text
    ATTRIBUTES lob_type, claim_status, customer_id
    WAREHOUSE = AGENT_WH
    TARGET_LAG = '1 hour'
    AS (SELECT claim_id, customer_id, policy_id, lob_type, claim_text, claim_status, claimed_amount, incident_date
        FROM INSURANCE_DB.RAW.CLAIMS_LANDING);

CREATE OR REPLACE CORTEX SEARCH SERVICE INSURANCE_DB.VECTORS.INTERACTIONS_SEARCH_SERVICE
    ON transcript_text
    ATTRIBUTES customer_id, channel, topic, resolution_status
    WAREHOUSE = AGENT_WH
    TARGET_LAG = '1 hour'
    AS (SELECT interaction_id, customer_id, channel, interaction_date, transcript_text, topic, resolution_status, nps_score
        FROM INSURANCE_DB.RAW.INTERACTIONS);

-- ============================================================================
-- 5. DMF SCHEDULES (trigger on changes for all monitored tables)
-- ============================================================================
ALTER TABLE INSURANCE_DB.RAW.CLAIMS_LANDING SET DATA_METRIC_SCHEDULE = 'TRIGGER_ON_CHANGES';
ALTER TABLE INSURANCE_DB.RAW.CUSTOMERS SET DATA_METRIC_SCHEDULE = 'TRIGGER_ON_CHANGES';
ALTER TABLE INSURANCE_DB.RAW.POLICIES SET DATA_METRIC_SCHEDULE = 'TRIGGER_ON_CHANGES';
ALTER TABLE INSURANCE_DB.PROCESSED.FCT_CUSTOMER_360 SET DATA_METRIC_SCHEDULE = 'TRIGGER_ON_CHANGES';
ALTER TABLE INSURANCE_DB.PROCESSED.CHURN_ALERTS SET DATA_METRIC_SCHEDULE = 'TRIGGER_ON_CHANGES';
ALTER TABLE INSURANCE_DB.RESULTS.RESOLUTIONS SET DATA_METRIC_SCHEDULE = 'TRIGGER_ON_CHANGES';
ALTER TABLE INSURANCE_DB.RAW.FRAUD_INDICATORS SET DATA_METRIC_SCHEDULE = 'TRIGGER_ON_CHANGES';

-- ============================================================================
-- 6. DATA SHARING
-- ============================================================================
ALTER VIEW INSURANCE_DB.PROCESSED.V_NBA_FOR_CRM SET SECURE;

CREATE OR REPLACE SHARE RETENTION_ACTIONS_SHARE
    COMMENT = 'Zero-copy share of Next Best Actions to CRM';
GRANT USAGE ON DATABASE INSURANCE_DB TO SHARE RETENTION_ACTIONS_SHARE;
GRANT USAGE ON SCHEMA INSURANCE_DB.PROCESSED TO SHARE RETENTION_ACTIONS_SHARE;
GRANT SELECT ON VIEW INSURANCE_DB.PROCESSED.V_NBA_FOR_CRM TO SHARE RETENTION_ACTIONS_SHARE;

-- ============================================================================
-- 7. TABLE-LEVEL GRANTS (ON ALL TABLES)
-- ============================================================================
GRANT SELECT ON ALL TABLES IN SCHEMA INSURANCE_DB.RESULTS TO ROLE INSURANCE_ADJUSTER_ROLE;
GRANT SELECT ON ALL TABLES IN SCHEMA INSURANCE_DB.PROCESSED TO ROLE INSURANCE_ADJUSTER_ROLE;
GRANT SELECT ON ALL TABLES IN SCHEMA INSURANCE_DB.RESULTS TO ROLE INSURANCE_UNDERWRITER_ROLE;
GRANT SELECT ON ALL TABLES IN SCHEMA INSURANCE_DB.PROCESSED TO ROLE INSURANCE_RETENTION_ROLE;

-- ============================================================================
-- 8. PIPELINE BOOTSTRAP: Build Customer 360 + Process All Claims
-- ============================================================================

-- 8a. Build FCT_CUSTOMER_360 (without embedding view due to subquery limitation)
MERGE INTO INSURANCE_DB.PROCESSED.FCT_CUSTOMER_360 tgt
USING (
    SELECT c.customer_id, c.customer_segment, c.lifetime_value_score,
        DATEDIFF(month, c.onboarding_date, CURRENT_DATE()) AS tenure_months,
        COALESCE(pp.active_policy_count, 0) AS active_policy_count,
        COALESCE(pp.total_annual_premium, 0) AS total_annual_premium,
        COALESCE(pp.lob_diversity, 0) AS lob_diversity,
        pp.days_to_nearest_renewal,
        COALESCE(pp.coverage_adequacy_ratio, 0) AS coverage_adequacy_ratio,
        COALESCE(pp.lapse_count_historical, 0) AS lapse_count_historical,
        pp.policy_ids_array,
        COALESCE(ch.claim_count_12m, 0) AS claim_count_12m,
        COALESCE(ch.claim_count_lifetime, 0) AS claim_count_lifetime,
        COALESCE(ch.claims_approved_ratio, 0) AS claims_approved_ratio,
        COALESCE(ch.avg_claim_amount, 0) AS avg_claim_amount,
        COALESCE(ch.max_claim_amount, 0) AS max_claim_amount,
        COALESCE(ch.total_amount_paid, 0) AS total_amount_paid,
        ch.avg_resolution_time_days,
        COALESCE(ch.open_claims_count, 0) AS open_claims_count,
        COALESCE(ch.fraud_flag_count, 0) AS fraud_flag_count,
        CASE WHEN pp.total_annual_premium > 0 THEN COALESCE(ch.total_claims_paid, 0) / pp.total_annual_premium ELSE 0 END AS loss_ratio,
        COALESCE(ch.claim_acceleration_ratio, 0) AS claim_acceleration_ratio,
        COALESCE(pay.payment_delay_avg_days, 0) AS payment_delay_avg_days,
        COALESCE(pay.missed_payments_12m, 0) AS missed_payments_12m,
        COALESCE(pay.payment_regularity_score, 1.0) AS payment_regularity_score,
        COALESCE(pay.last_payment_days_ago, 0) AS last_payment_days_ago,
        COALESCE(pay.auto_pay_enrolled, FALSE) AS auto_pay_enrolled,
        COALESCE(ints.sentiment_score_last_30d, 0) AS sentiment_score_last_30d,
        COALESCE(ints.sentiment_trend, 0) AS sentiment_trend,
        COALESCE(ints.escalation_flag, FALSE) AS escalation_flag,
        COALESCE(ints.complaint_count_90d, 0) AS complaint_count_90d,
        ints.nps_score_latest,
        ints.channel_preference,
        COALESCE(ints.last_interaction_days_ago, 999) AS last_interaction_days_ago
    FROM INSURANCE_DB.RAW.CUSTOMERS c
    LEFT JOIN INSURANCE_DB.PROCESSED.V_AGG_POLICY_PORTFOLIO pp ON c.customer_id = pp.customer_id
    LEFT JOIN INSURANCE_DB.PROCESSED.V_AGG_CLAIMS_HISTORY ch ON c.customer_id = ch.customer_id
    LEFT JOIN INSURANCE_DB.PROCESSED.V_AGG_PAYMENT_BEHAVIOR pay ON c.customer_id = pay.customer_id
    LEFT JOIN INSURANCE_DB.PROCESSED.V_AGG_INTERACTION_SIGNALS ints ON c.customer_id = ints.customer_id
) src ON tgt.customer_id = src.customer_id
WHEN MATCHED THEN UPDATE SET
    customer_segment=src.customer_segment, lifetime_value_score=src.lifetime_value_score,
    tenure_months=src.tenure_months, active_policy_count=src.active_policy_count,
    total_annual_premium=src.total_annual_premium, lob_diversity=src.lob_diversity,
    days_to_nearest_renewal=src.days_to_nearest_renewal, coverage_adequacy_ratio=src.coverage_adequacy_ratio,
    lapse_count_historical=src.lapse_count_historical, policy_ids_array=src.policy_ids_array,
    claim_count_12m=src.claim_count_12m, claim_count_lifetime=src.claim_count_lifetime,
    claims_approved_ratio=src.claims_approved_ratio, avg_claim_amount=src.avg_claim_amount,
    max_claim_amount=src.max_claim_amount, total_amount_paid=src.total_amount_paid,
    avg_resolution_time_days=src.avg_resolution_time_days, open_claims_count=src.open_claims_count,
    fraud_flag_count=src.fraud_flag_count, loss_ratio=src.loss_ratio,
    claim_acceleration_ratio=src.claim_acceleration_ratio,
    payment_delay_avg_days=src.payment_delay_avg_days, missed_payments_12m=src.missed_payments_12m,
    payment_regularity_score=src.payment_regularity_score, last_payment_days_ago=src.last_payment_days_ago,
    auto_pay_enrolled=src.auto_pay_enrolled,
    sentiment_score_last_30d=src.sentiment_score_last_30d, sentiment_trend=src.sentiment_trend,
    escalation_flag=src.escalation_flag, complaint_count_90d=src.complaint_count_90d,
    nps_score_latest=src.nps_score_latest, channel_preference=src.channel_preference,
    last_interaction_days_ago=src.last_interaction_days_ago,
    last_refreshed_at=CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN INSERT (
    customer_id, customer_segment, lifetime_value_score, tenure_months,
    active_policy_count, total_annual_premium, lob_diversity,
    days_to_nearest_renewal, coverage_adequacy_ratio, lapse_count_historical,
    policy_ids_array, claim_count_12m, claim_count_lifetime,
    claims_approved_ratio, avg_claim_amount, max_claim_amount,
    total_amount_paid, avg_resolution_time_days, open_claims_count,
    fraud_flag_count, loss_ratio, claim_acceleration_ratio,
    payment_delay_avg_days, missed_payments_12m, payment_regularity_score,
    last_payment_days_ago, auto_pay_enrolled,
    sentiment_score_last_30d, sentiment_trend, escalation_flag,
    complaint_count_90d, nps_score_latest, channel_preference,
    last_interaction_days_ago, last_refreshed_at
) VALUES (
    src.customer_id, src.customer_segment, src.lifetime_value_score, src.tenure_months,
    src.active_policy_count, src.total_annual_premium, src.lob_diversity,
    src.days_to_nearest_renewal, src.coverage_adequacy_ratio, src.lapse_count_historical,
    src.policy_ids_array, src.claim_count_12m, src.claim_count_lifetime,
    src.claims_approved_ratio, src.avg_claim_amount, src.max_claim_amount,
    src.total_amount_paid, src.avg_resolution_time_days, src.open_claims_count,
    src.fraud_flag_count, src.loss_ratio, src.claim_acceleration_ratio,
    src.payment_delay_avg_days, src.missed_payments_12m, src.payment_regularity_score,
    src.last_payment_days_ago, src.auto_pay_enrolled,
    src.sentiment_score_last_30d, src.sentiment_trend, src.escalation_flag,
    src.complaint_count_90d, src.nps_score_latest, src.channel_preference,
    src.last_interaction_days_ago, CURRENT_TIMESTAMP()
);

-- 8b. Compute churn propensity scores
UPDATE INSURANCE_DB.PROCESSED.FCT_CUSTOMER_360
SET churn_propensity_score = ROUND(LEAST(1.0, GREATEST(0.0,
    (CASE WHEN missed_payments_12m >= 3 THEN 0.3 WHEN missed_payments_12m >= 1 THEN 0.15 ELSE 0.0 END)
    + (CASE WHEN sentiment_score_last_30d < -0.5 THEN 0.25 WHEN sentiment_score_last_30d < -0.2 THEN 0.15 WHEN sentiment_score_last_30d < 0 THEN 0.05 ELSE 0.0 END)
    + (CASE WHEN complaint_count_90d >= 5 THEN 0.2 WHEN complaint_count_90d >= 3 THEN 0.15 WHEN complaint_count_90d >= 1 THEN 0.05 ELSE 0.0 END)
    + (CASE WHEN days_to_nearest_renewal IS NOT NULL AND days_to_nearest_renewal <= 30 THEN 0.15 WHEN days_to_nearest_renewal IS NOT NULL AND days_to_nearest_renewal <= 60 THEN 0.08 ELSE 0.0 END)
    + (CASE WHEN payment_regularity_score < 0.5 THEN 0.15 WHEN payment_regularity_score < 0.7 THEN 0.08 ELSE 0.0 END)
    + (CASE WHEN escalation_flag = TRUE THEN 0.1 ELSE 0.0 END)
    + (CASE WHEN loss_ratio > 2.0 THEN 0.1 WHEN loss_ratio > 1.0 THEN 0.05 ELSE 0.0 END)
    + (CASE WHEN nps_score_latest IS NOT NULL AND nps_score_latest <= 3 THEN 0.15 WHEN nps_score_latest IS NOT NULL AND nps_score_latest <= 5 THEN 0.08 ELSE 0.0 END)
    + (CASE WHEN lapse_count_historical > 0 THEN 0.1 ELSE 0.0 END)
    - (CASE WHEN tenure_months > 60 THEN 0.1 WHEN tenure_months > 36 THEN 0.05 ELSE 0.0 END)
    - (CASE WHEN lifetime_value_score > 80 THEN 0.05 ELSE 0.0 END)
    + 0.08
)), 2),
churn_time_to_event_days = COALESCE(days_to_nearest_renewal, 180),
last_refreshed_at = CURRENT_TIMESTAMP();

-- 8c. Refresh Dynamic Table
ALTER DYNAMIC TABLE INSURANCE_DB.PROCESSED.DT_CUSTOMER_360 REFRESH;

-- 8d. Process ALL claims through the 5-agent pipeline
CALL INSURANCE_DB.PROCESSED.SP_PROCESS_ALL_CLAIMS();

-- 8e. Run churn scan
CALL INSURANCE_DB.PROCESSED.SP_CHURN_SCAN();

-- ============================================================================
-- 9. VERIFICATION: Check everything is populated
-- ============================================================================
SELECT 'POST-DEPLOY COMPLETE' AS status,
    (SELECT COUNT(*) FROM INSURANCE_DB.PROCESSED.FCT_CUSTOMER_360) AS c360_rows,
    (SELECT COUNT(*) FROM INSURANCE_DB.RESULTS.RESOLUTIONS) AS resolutions,
    (SELECT COUNT(*) FROM INSURANCE_DB.PROCESSED.CLAIM_STATE) AS claim_states,
    (SELECT COUNT(*) FROM INSURANCE_DB.VECTORS.FRAUD_PATTERN_EMBEDDINGS) AS embeddings,
    (SELECT COUNT(*) FROM INSURANCE_DB.PROCESSED.CHURN_ALERTS) AS churn_alerts;
