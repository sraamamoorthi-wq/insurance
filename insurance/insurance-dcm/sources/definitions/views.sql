-- ============================================================================
-- VIEWS: Analytics, monitoring, and consumption views
-- ============================================================================

-- Pipeline monitoring
DEFINE VIEW INSURANCE_DB.PROCESSED.V_PIPELINE_STATUS AS
SELECT
    cs.claim_id,
    cl.customer_id,
    cl.lob_type,
    cl.claimed_amount,
    cs.current_state,
    cs.started_at,
    cs.completed_at,
    DATEDIFF(second, cs.started_at, COALESCE(cs.completed_at, CURRENT_TIMESTAMP())) AS elapsed_seconds,
    cs.fraud_output:composite_fraud_score::FLOAT AS fraud_score,
    cs.fraud_output:risk_level::VARCHAR AS fraud_risk,
    cs.resolution_output:decision::VARCHAR AS decision,
    cs.resolution_output:settlement_amount::FLOAT AS settlement,
    c.customer_segment,
    c.lifetime_value_score
FROM INSURANCE_DB.PROCESSED.CLAIM_STATE cs
JOIN INSURANCE_DB.RAW.CLAIMS_LANDING cl ON cs.claim_id = cl.claim_id
JOIN INSURANCE_DB.RAW.CUSTOMERS c ON cl.customer_id = c.customer_id
ORDER BY cs.started_at DESC;

-- Customer 360 wrapper view
DEFINE VIEW INSURANCE_DB.PROCESSED.FCT_CUSTOMER_360_VIEW AS
SELECT * FROM INSURANCE_DB.PROCESSED.FCT_CUSTOMER_360;

-- Policy portfolio aggregation
DEFINE VIEW INSURANCE_DB.PROCESSED.V_AGG_POLICY_PORTFOLIO AS
SELECT
    customer_id,
    COUNT_IF(policy_status = 'ACTIVE') AS active_policy_count,
    SUM(CASE WHEN policy_status = 'ACTIVE' THEN premium_annual ELSE 0 END) AS total_annual_premium,
    COUNT(DISTINCT CASE WHEN policy_status = 'ACTIVE' THEN lob_type END) AS lob_diversity,
    MIN(CASE WHEN policy_status = 'ACTIVE' AND renewal_date >= CURRENT_DATE() THEN DATEDIFF(day, CURRENT_DATE(), renewal_date) END) AS days_to_nearest_renewal,
    SUM(CASE WHEN policy_status = 'ACTIVE' THEN coverage_limit ELSE 0 END) /
        NULLIF(SUM(CASE WHEN policy_status = 'ACTIVE' THEN premium_annual ELSE 0 END) * 20, 0) AS coverage_adequacy_ratio,
    COUNT_IF(policy_status IN ('LAPSED', 'CANCELLED')) AS lapse_count_historical,
    ARRAY_AGG(CASE WHEN policy_status = 'ACTIVE' THEN policy_id END) AS policy_ids_array
FROM INSURANCE_DB.RAW.POLICIES
GROUP BY customer_id;

-- Claims history aggregation
DEFINE VIEW INSURANCE_DB.PROCESSED.V_AGG_CLAIMS_HISTORY AS
SELECT
    customer_id,
    COUNT_IF(incident_date >= DATEADD(month, -12, CURRENT_DATE())) AS claim_count_12m,
    COUNT(*) AS claim_count_lifetime,
    COUNT_IF(claim_status = 'APPROVED') / NULLIF(COUNT(*), 0)::FLOAT AS claims_approved_ratio,
    AVG(claimed_amount) AS avg_claim_amount,
    MAX(claimed_amount) AS max_claim_amount,
    SUM(CASE WHEN claim_status = 'APPROVED' THEN claimed_amount ELSE 0 END) AS total_amount_paid,
    AVG(DATEDIFF(day, submission_date,
        CASE WHEN claim_status IN ('APPROVED', 'DENIED') THEN submission_date ELSE NULL END)) AS avg_resolution_time_days,
    COUNT_IF(claim_status NOT IN ('APPROVED', 'DENIED', 'REFERRED', 'COMPLETED')) AS open_claims_count,
    0 AS fraud_flag_count,
    SUM(CASE WHEN claim_status = 'APPROVED' THEN claimed_amount ELSE 0 END) AS total_claims_paid,
    COUNT_IF(incident_date >= DATEADD(month, -3, CURRENT_DATE())) /
        NULLIF(COUNT_IF(incident_date >= DATEADD(month, -12, CURRENT_DATE())), 0)::FLOAT AS claim_acceleration_ratio
FROM INSURANCE_DB.RAW.CLAIMS_LANDING
GROUP BY customer_id;

-- Payment behavior aggregation
DEFINE VIEW INSURANCE_DB.PROCESSED.V_AGG_PAYMENT_BEHAVIOR AS
SELECT
    customer_id,
    AVG(days_delayed) AS payment_delay_avg_days,
    COUNT_IF(payment_status = 'MISSED' AND payment_date >= DATEADD(month, -12, CURRENT_DATE())) AS missed_payments_12m,
    COUNT_IF(payment_status = 'PAID' AND days_delayed <= 5) / NULLIF(COUNT(*), 0)::FLOAT AS payment_regularity_score,
    DATEDIFF(day, MAX(payment_date), CURRENT_DATE()) AS last_payment_days_ago,
    MAX(CASE WHEN payment_method = 'AUTO_DEBIT' THEN TRUE ELSE FALSE END) AS auto_pay_enrolled
FROM INSURANCE_DB.RAW.PAYMENTS
GROUP BY customer_id;

-- Interaction signals via Cortex Sentiment
DEFINE VIEW INSURANCE_DB.PROCESSED.V_AGG_INTERACTION_SIGNALS AS
SELECT
    customer_id,
    AVG(CASE WHEN interaction_date >= DATEADD(day, -30, CURRENT_TIMESTAMP())
        THEN SNOWFLAKE.CORTEX.SENTIMENT(transcript_text) END) AS sentiment_score_last_30d,
    AVG(CASE WHEN interaction_date >= DATEADD(day, -30, CURRENT_TIMESTAMP())
        THEN SNOWFLAKE.CORTEX.SENTIMENT(transcript_text) END)
    - COALESCE(AVG(CASE WHEN interaction_date BETWEEN DATEADD(day, -60, CURRENT_TIMESTAMP()) AND DATEADD(day, -30, CURRENT_TIMESTAMP())
        THEN SNOWFLAKE.CORTEX.SENTIMENT(transcript_text) END), 0)
    AS sentiment_trend,
    COUNT_IF(resolution_status = 'ESCALATED'
        AND interaction_date >= DATEADD(day, -90, CURRENT_TIMESTAMP())) AS complaint_count_90d,
    MAX(nps_score) AS nps_score_latest,
    MODE(channel) AS channel_preference,
    DATEDIFF(day, MAX(interaction_date), CURRENT_TIMESTAMP()) AS last_interaction_days_ago,
    MAX(CASE WHEN resolution_status = 'ESCALATED'
        AND interaction_date >= DATEADD(day, -30, CURRENT_TIMESTAMP()) THEN TRUE ELSE FALSE END) AS escalation_flag
FROM INSURANCE_DB.RAW.INTERACTIONS
GROUP BY customer_id;

-- Embedding features
DEFINE VIEW INSURANCE_DB.PROCESSED.V_AGG_EMBEDDING_FEATURES AS
SELECT
    cl.customer_id,
    MAX(INSURANCE_DB.VECTORS.COMPUTE_FRAUD_SIMILARITY(cl.claim_text)) AS fraud_similarity_score,
    CASE
        WHEN MAX(INSURANCE_DB.VECTORS.COMPUTE_FRAUD_SIMILARITY(cl.claim_text)) > 0.7 THEN 1
        WHEN MAX(INSURANCE_DB.VECTORS.COMPUTE_FRAUD_SIMILARITY(cl.claim_text)) > 0.4 THEN 2
        ELSE 3
    END AS claim_cluster_id,
    MAX(CASE WHEN p.risk_flag = TRUE THEN 0.8 ELSE 0.0 END) AS provider_anomaly_score
FROM INSURANCE_DB.RAW.CLAIMS_LANDING cl
LEFT JOIN INSURANCE_DB.RAW.PROVIDERS p ON p.lob_type = cl.lob_type AND p.risk_flag = TRUE
GROUP BY cl.customer_id;

-- Churn dashboard
DEFINE VIEW INSURANCE_DB.PROCESSED.V_CHURN_DASHBOARD AS
SELECT
    ca.alert_id, ca.customer_id, ca.alert_date, ca.churn_propensity,
    ca.sentiment_score, ca.complaint_count, ca.trigger_reason,
    ca.root_cause, ca.root_cause_confidence, ca.priority, ca.status,
    c360.customer_segment, c360.lifetime_value_score, c360.total_annual_premium,
    c360.tenure_months, c360.lob_diversity, c360.days_to_nearest_renewal,
    c360.competitor_mentions_count, c360.intent_cancel_detected,
    nba.action_type AS nba_action, nba.offer_details AS nba_offer,
    nba.channel AS nba_channel, nba.expected_success_rate, nba.status AS nba_status
FROM INSURANCE_DB.PROCESSED.CHURN_ALERTS ca
JOIN INSURANCE_DB.PROCESSED.FCT_CUSTOMER_360 c360 ON ca.customer_id = c360.customer_id
LEFT JOIN INSURANCE_DB.PROCESSED.NEXT_BEST_ACTIONS nba ON ca.customer_id = nba.customer_id
    AND nba.created_date = ca.alert_date
ORDER BY ca.priority ASC, ca.alert_date DESC;

-- NBA for CRM export
DEFINE SECURE VIEW INSURANCE_DB.PROCESSED.V_NBA_FOR_CRM AS
SELECT
    nba.nba_id, nba.customer_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    c.email, c.phone,
    c360.customer_segment, c360.total_annual_premium,
    nba.action_type, nba.offer_details, nba.channel, nba.timing,
    nba.priority, nba.expected_success_rate, nba.root_cause,
    nba.rationale, nba.status, nba.expiry_date
FROM INSURANCE_DB.PROCESSED.NEXT_BEST_ACTIONS nba
JOIN INSURANCE_DB.RAW.CUSTOMERS c ON nba.customer_id = c.customer_id
JOIN INSURANCE_DB.PROCESSED.FCT_CUSTOMER_360 c360 ON nba.customer_id = c360.customer_id
WHERE nba.status = 'PENDING'
  AND nba.expiry_date >= CURRENT_DATE()
ORDER BY nba.priority ASC;

-- NOTE: V_TASK_HISTORY and V_TASK_STATUS moved to post_deploy.sql
-- (DCM cannot compile views referencing INFORMATION_SCHEMA table functions)
