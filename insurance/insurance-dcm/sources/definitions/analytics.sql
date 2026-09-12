-- ============================================================================
-- ANALYTICS: Dynamic Tables for automated data pipelines
-- ============================================================================

-- Customer 360 Dynamic Table - replaces SP_BUILD_CUSTOMER_360 + TASK_BUILD_CUSTOMER_360
-- Automatically refreshes within 1 hour of source data changes
DEFINE DYNAMIC TABLE INSURANCE_DB.PROCESSED.DT_CUSTOMER_360
    WAREHOUSE = AGENT_WH
    TARGET_LAG = '1 hour'
AS
SELECT
    c.customer_id,
    c.customer_segment,
    c.lifetime_value_score,
    DATEDIFF(month, c.onboarding_date, CURRENT_DATE()) AS tenure_months,
    -- Policy features
    COALESCE(pp.active_policy_count, 0) AS active_policy_count,
    COALESCE(pp.total_annual_premium, 0) AS total_annual_premium,
    COALESCE(pp.lob_diversity, 0) AS lob_diversity,
    pp.days_to_nearest_renewal,
    COALESCE(pp.coverage_adequacy_ratio, 0) AS coverage_adequacy_ratio,
    COALESCE(pp.lapse_count_historical, 0) AS lapse_count_historical,
    -- Claims features
    COALESCE(ch.claim_count_12m, 0) AS claim_count_12m,
    COALESCE(ch.claim_count_lifetime, 0) AS claim_count_lifetime,
    COALESCE(ch.claims_approved_ratio, 0) AS claims_approved_ratio,
    COALESCE(ch.avg_claim_amount, 0) AS avg_claim_amount,
    COALESCE(ch.max_claim_amount, 0) AS max_claim_amount,
    COALESCE(ch.total_amount_paid, 0) AS total_amount_paid,
    COALESCE(ch.open_claims_count, 0) AS open_claims_count,
    COALESCE(ch.claim_acceleration_ratio, 0) AS claim_acceleration_ratio,
    -- Payment features
    COALESCE(pb.payment_delay_avg_days, 0) AS payment_delay_avg_days,
    COALESCE(pb.missed_payments_12m, 0) AS missed_payments_12m,
    COALESCE(pb.payment_regularity_score, 0) AS payment_regularity_score,
    COALESCE(pb.last_payment_days_ago, 0) AS last_payment_days_ago,
    COALESCE(pb.auto_pay_enrolled, FALSE) AS auto_pay_enrolled,
    -- Interaction features
    COALESCE(is2.sentiment_score_last_30d, 0) AS sentiment_score_last_30d,
    COALESCE(is2.sentiment_trend, 0) AS sentiment_trend,
    COALESCE(is2.complaint_count_90d, 0) AS complaint_count_90d,
    is2.nps_score_latest,
    is2.channel_preference,
    COALESCE(is2.last_interaction_days_ago, 0) AS last_interaction_days_ago,
    COALESCE(is2.escalation_flag, FALSE) AS escalation_flag,
    -- Derived risk signals
    CASE WHEN pp.days_to_nearest_renewal <= 30 AND COALESCE(is2.sentiment_score_last_30d, 0) < -0.3
         THEN TRUE ELSE FALSE END AS renewal_risk_signal,
    CASE WHEN ch.claim_count_lifetime > 0
         THEN COALESCE(ch.complaint_count_90d, 0) / ch.claim_count_lifetime
         ELSE 0 END AS complaint_rate_per_claim,
    CASE WHEN COALESCE(pp.total_annual_premium, 0) > 0
         THEN COALESCE(ch.total_amount_paid, 0) / (pp.total_annual_premium * GREATEST(DATEDIFF(year, c.onboarding_date, CURRENT_DATE()), 1))
         ELSE 0 END AS lifetime_loss_ratio,
    CASE WHEN c.customer_segment = 'HNW' AND COALESCE(is2.sentiment_score_last_30d, 0) < -0.2
         THEN TRUE ELSE FALSE END AS high_value_at_risk
FROM INSURANCE_DB.RAW.CUSTOMERS c
LEFT JOIN INSURANCE_DB.PROCESSED.V_AGG_POLICY_PORTFOLIO pp ON c.customer_id = pp.customer_id
LEFT JOIN INSURANCE_DB.PROCESSED.V_AGG_CLAIMS_HISTORY ch ON c.customer_id = ch.customer_id
LEFT JOIN INSURANCE_DB.PROCESSED.V_AGG_PAYMENT_BEHAVIOR pb ON c.customer_id = pb.customer_id
LEFT JOIN INSURANCE_DB.PROCESSED.V_AGG_INTERACTION_SIGNALS is2 ON c.customer_id = is2.customer_id;
