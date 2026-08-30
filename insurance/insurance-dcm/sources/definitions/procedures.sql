-- ============================================================================
-- SQL STORED PROCEDURES: Orchestrators, Customer 360, Churn, Document processing
-- NOTE: Python agent procedures (SP_AGENT_*) are in post_deploy.sql
-- ============================================================================

-- Claims orchestrator (chains all 5 agents)
DEFINE PROCEDURE INSURANCE_DB.PROCESSED.SP_PROCESS_CLAIM(claim_id VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    decision VARCHAR;
BEGIN
    CALL INSURANCE_DB.PROCESSED.SP_AGENT_INTAKE(:claim_id);
    CALL INSURANCE_DB.PROCESSED.SP_AGENT_VALIDATION(:claim_id);
    CALL INSURANCE_DB.PROCESSED.SP_AGENT_FRAUD(:claim_id);
    CALL INSURANCE_DB.PROCESSED.SP_AGENT_ASSESSMENT(:claim_id);
    CALL INSURANCE_DB.PROCESSED.SP_AGENT_RESOLUTION(:claim_id);

    decision := (
        SELECT decision FROM INSURANCE_DB.RESULTS.RESOLUTIONS
        WHERE claim_id = :claim_id
        ORDER BY decided_at DESC LIMIT 1
    );

    RETURN 'Claim ' || :claim_id || ' processed. Decision: ' || COALESCE(:decision, 'UNKNOWN');
END;
$$;

-- Batch claims processor
DEFINE PROCEDURE INSURANCE_DB.PROCESSED.SP_PROCESS_ALL_CLAIMS()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    cnt INT DEFAULT 0;
    cur_claim VARCHAR;
BEGIN
    FOR rec IN (
        SELECT claim_id FROM INSURANCE_DB.RAW.CLAIMS_LANDING
        WHERE claim_status = 'SUBMITTED'
        ORDER BY submission_date ASC LIMIT 20
    ) DO
        cur_claim := rec.claim_id;
        CALL INSURANCE_DB.PROCESSED.SP_PROCESS_CLAIM(:cur_claim);
        cnt := cnt + 1;
    END FOR;

    RETURN 'Batch complete. Processed ' || :cnt::VARCHAR || ' claims.';
END;
$$;

-- Single customer interaction feature extraction
DEFINE PROCEDURE INSURANCE_DB.PROCESSED.SP_EXTRACT_INTERACTION_FEATURES(p_customer_id VARCHAR)
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    result VARIANT;
BEGIN
    LET interaction_text VARCHAR := (
        SELECT LISTAGG(transcript_text, '\n---\n') WITHIN GROUP (ORDER BY interaction_date DESC)
        FROM INSURANCE_DB.RAW.INTERACTIONS
        WHERE customer_id = :p_customer_id
          AND interaction_date >= DATEADD(day, -90, CURRENT_TIMESTAMP())
        LIMIT 5
    );

    result := (
        SELECT PARSE_JSON(
            SNOWFLAKE.CORTEX.COMPLETE(
                'mistral-large2',
                CONCAT(
                    'Analyze these customer interaction transcripts and extract numerical signals. Return ONLY valid JSON.\n',
                    '{"frustration_level": 0.0-1.0, "intent_cancel_detected": true/false, ',
                    '"competitor_mentions_count": integer, "emotional_manipulation_flag": true/false, ',
                    '"digital_engagement_trend": -1.0 to 1.0, "overall_satisfaction": 0.0-1.0}\n\n',
                    'TRANSCRIPTS:\n', COALESCE(:interaction_text, 'No recent interactions')
                ),
                OBJECT_CONSTRUCT('temperature', 0.1, 'max_tokens', 300)
            )
        )
    );

    RETURN :result;
END;
$$;

-- Customer 360 build (MERGE from all feature views)
DEFINE PROCEDURE INSURANCE_DB.PROCESSED.SP_BUILD_CUSTOMER_360()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    MERGE INTO INSURANCE_DB.PROCESSED.FCT_CUSTOMER_360 tgt
    USING (
        SELECT
            c.customer_id,
            c.customer_segment, c.lifetime_value_score,
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
            CASE WHEN pp.total_annual_premium > 0
                 THEN ch.total_claims_paid / pp.total_annual_premium
                 ELSE 0 END AS loss_ratio,
            COALESCE(ch.claim_acceleration_ratio, 0) AS claim_acceleration_ratio,
            COALESCE(pay.payment_delay_avg_days, 0) AS payment_delay_avg_days,
            COALESCE(pay.missed_payments_12m, 0) AS missed_payments_12m,
            COALESCE(pay.payment_regularity_score, 1.0) AS payment_regularity_score,
            COALESCE(pay.last_payment_days_ago, 0) AS last_payment_days_ago,
            COALESCE(pay.auto_pay_enrolled, FALSE) AS auto_pay_enrolled,
            COALESCE(ints.sentiment_score_last_30d, 0) AS sentiment_score_last_30d,
            COALESCE(ints.sentiment_trend, 0) AS sentiment_trend,
            0.0 AS frustration_level,
            COALESCE(ints.escalation_flag, FALSE) AS escalation_flag,
            COALESCE(ints.complaint_count_90d, 0) AS complaint_count_90d,
            ints.nps_score_latest,
            FALSE AS intent_cancel_detected,
            0 AS competitor_mentions_count,
            ints.channel_preference,
            COALESCE(ints.last_interaction_days_ago, 999) AS last_interaction_days_ago,
            0.0 AS digital_engagement_trend,
            FALSE AS emotional_manipulation_flag,
            0.0 AS inconsistency_score,
            0.0 AS vagueness_score,
            COALESCE(emb.fraud_similarity_score, 0) AS fraud_similarity_score,
            COALESCE(emb.claim_cluster_id, 3) AS claim_cluster_id,
            COALESCE(emb.provider_anomaly_score, 0) AS provider_anomaly_score,
            (pp.days_to_nearest_renewal < 60 AND COALESCE(ints.sentiment_score_last_30d, 0) < -0.2) AS renewal_risk_signal,
            CASE WHEN ch.claim_count_lifetime > 0
                 THEN COALESCE(ints.complaint_count_90d, 0)::FLOAT / ch.claim_count_lifetime
                 ELSE 0 END AS complaint_rate_per_claim,
            CASE WHEN pp.total_annual_premium > 0
                 THEN ch.total_claims_paid / (pp.total_annual_premium * GREATEST(DATEDIFF(year, c.onboarding_date, CURRENT_DATE()), 1))
                 ELSE 0 END AS lifetime_loss_ratio,
            (c.lifetime_value_score > 0.7 AND COALESCE(ints.sentiment_score_last_30d, 0) < -0.2) AS high_value_at_risk,
            0.5 AS geographic_risk_score,
            NULL AS churn_propensity_score, NULL AS churn_time_to_event_days,
            NULL AS fraud_propensity_score, NULL AS underwriting_risk_tier,
            NULL AS expected_loss_ratio, NULL AS cross_sell_propensity,
            NULL AS recommended_lob, NULL AS next_best_action,
            NULL AS nba_rationale, NULL AS nba_priority
        FROM INSURANCE_DB.RAW.CUSTOMERS c
        LEFT JOIN INSURANCE_DB.PROCESSED.V_AGG_POLICY_PORTFOLIO pp ON c.customer_id = pp.customer_id
        LEFT JOIN INSURANCE_DB.PROCESSED.V_AGG_CLAIMS_HISTORY ch ON c.customer_id = ch.customer_id
        LEFT JOIN INSURANCE_DB.PROCESSED.V_AGG_PAYMENT_BEHAVIOR pay ON c.customer_id = pay.customer_id
        LEFT JOIN INSURANCE_DB.PROCESSED.V_AGG_INTERACTION_SIGNALS ints ON c.customer_id = ints.customer_id
        LEFT JOIN INSURANCE_DB.PROCESSED.V_AGG_EMBEDDING_FEATURES emb ON c.customer_id = emb.customer_id
    ) src
    ON tgt.customer_id = src.customer_id
    WHEN MATCHED THEN UPDATE SET
        customer_segment = src.customer_segment, lifetime_value_score = src.lifetime_value_score,
        tenure_months = src.tenure_months, active_policy_count = src.active_policy_count,
        total_annual_premium = src.total_annual_premium, lob_diversity = src.lob_diversity,
        days_to_nearest_renewal = src.days_to_nearest_renewal,
        coverage_adequacy_ratio = src.coverage_adequacy_ratio,
        lapse_count_historical = src.lapse_count_historical, policy_ids_array = src.policy_ids_array,
        claim_count_12m = src.claim_count_12m, claim_count_lifetime = src.claim_count_lifetime,
        claims_approved_ratio = src.claims_approved_ratio, avg_claim_amount = src.avg_claim_amount,
        max_claim_amount = src.max_claim_amount, total_amount_paid = src.total_amount_paid,
        avg_resolution_time_days = src.avg_resolution_time_days, open_claims_count = src.open_claims_count,
        fraud_flag_count = src.fraud_flag_count, loss_ratio = src.loss_ratio,
        claim_acceleration_ratio = src.claim_acceleration_ratio,
        payment_delay_avg_days = src.payment_delay_avg_days, missed_payments_12m = src.missed_payments_12m,
        payment_regularity_score = src.payment_regularity_score,
        last_payment_days_ago = src.last_payment_days_ago, auto_pay_enrolled = src.auto_pay_enrolled,
        sentiment_score_last_30d = src.sentiment_score_last_30d, sentiment_trend = src.sentiment_trend,
        frustration_level = src.frustration_level, escalation_flag = src.escalation_flag,
        complaint_count_90d = src.complaint_count_90d, nps_score_latest = src.nps_score_latest,
        intent_cancel_detected = src.intent_cancel_detected,
        competitor_mentions_count = src.competitor_mentions_count, channel_preference = src.channel_preference,
        last_interaction_days_ago = src.last_interaction_days_ago,
        digital_engagement_trend = src.digital_engagement_trend,
        emotional_manipulation_flag = src.emotional_manipulation_flag,
        inconsistency_score = src.inconsistency_score, vagueness_score = src.vagueness_score,
        fraud_similarity_score = src.fraud_similarity_score, claim_cluster_id = src.claim_cluster_id,
        provider_anomaly_score = src.provider_anomaly_score, renewal_risk_signal = src.renewal_risk_signal,
        complaint_rate_per_claim = src.complaint_rate_per_claim, lifetime_loss_ratio = src.lifetime_loss_ratio,
        high_value_at_risk = src.high_value_at_risk, geographic_risk_score = src.geographic_risk_score,
        last_refreshed_at = CURRENT_TIMESTAMP()
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
        sentiment_score_last_30d, sentiment_trend, frustration_level,
        escalation_flag, complaint_count_90d, nps_score_latest,
        intent_cancel_detected, competitor_mentions_count, channel_preference,
        last_interaction_days_ago, digital_engagement_trend,
        emotional_manipulation_flag, inconsistency_score, vagueness_score,
        fraud_similarity_score, claim_cluster_id, provider_anomaly_score,
        renewal_risk_signal, complaint_rate_per_claim, lifetime_loss_ratio,
        high_value_at_risk, geographic_risk_score, last_refreshed_at
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
        src.sentiment_score_last_30d, src.sentiment_trend, src.frustration_level,
        src.escalation_flag, src.complaint_count_90d, src.nps_score_latest,
        src.intent_cancel_detected, src.competitor_mentions_count, src.channel_preference,
        src.last_interaction_days_ago, src.digital_engagement_trend,
        src.emotional_manipulation_flag, src.inconsistency_score, src.vagueness_score,
        src.fraud_similarity_score, src.claim_cluster_id, src.provider_anomaly_score,
        src.renewal_risk_signal, src.complaint_rate_per_claim, src.lifetime_loss_ratio,
        src.high_value_at_risk, src.geographic_risk_score, CURRENT_TIMESTAMP()
    );

    RETURN 'Customer 360 build complete. Rows: ' ||
           (SELECT COUNT(*) FROM INSURANCE_DB.PROCESSED.FCT_CUSTOMER_360)::VARCHAR;
END;
$$;

-- Batch unstructured feature extraction via LLM
DEFINE PROCEDURE INSURANCE_DB.PROCESSED.SP_EXTRACT_UNSTRUCTURED_FEATURES_BATCH()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    UPDATE INSURANCE_DB.PROCESSED.FCT_CUSTOMER_360 tgt
    SET
        frustration_level = features.val:frustration_level::FLOAT,
        intent_cancel_detected = features.val:intent_cancel_detected::BOOLEAN,
        competitor_mentions_count = features.val:competitor_mentions_count::INT,
        digital_engagement_trend = features.val:digital_engagement_trend::FLOAT,
        emotional_manipulation_flag = features.val:emotional_manipulation_flag::BOOLEAN
    FROM (
        SELECT
            i.customer_id,
            PARSE_JSON(
                SNOWFLAKE.CORTEX.COMPLETE(
                    'mistral-large2',
                    CONCAT(
                        'Analyze these customer interactions. Return JSON only: ',
                        '{"frustration_level": 0.0-1.0, "intent_cancel_detected": bool, ',
                        '"competitor_mentions_count": int, "digital_engagement_trend": -1 to 1, ',
                        '"emotional_manipulation_flag": bool}\n\nTranscripts:\n',
                        LISTAGG(LEFT(i.transcript_text, 500), '\n---\n')
                            WITHIN GROUP (ORDER BY i.interaction_date DESC)
                    ),
                    OBJECT_CONSTRUCT('temperature', 0.1, 'max_tokens', 200)
                )
            ) AS val
        FROM INSURANCE_DB.RAW.INTERACTIONS i
        WHERE i.interaction_date >= DATEADD(day, -90, CURRENT_TIMESTAMP())
        GROUP BY i.customer_id
    ) features
    WHERE tgt.customer_id = features.customer_id;

    RETURN 'Unstructured feature extraction complete for ' ||
           (SELECT COUNT(DISTINCT customer_id) FROM INSURANCE_DB.RAW.INTERACTIONS
            WHERE interaction_date >= DATEADD(day, -90, CURRENT_TIMESTAMP()))::VARCHAR ||
           ' customers';
END;
$$;

-- Churn scan
DEFINE PROCEDURE INSURANCE_DB.PROCESSED.SP_CHURN_SCAN()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    INSERT INTO INSURANCE_DB.PROCESSED.CHURN_ALERTS
        (customer_id, alert_date, churn_propensity, sentiment_score,
         complaint_count, trigger_reason, priority, status)
    SELECT
        customer_id, CURRENT_DATE(), churn_propensity_score, sentiment_score_last_30d,
        complaint_count_90d,
        CASE
            WHEN churn_propensity_score > 0.7 THEN 'VERY_HIGH_CHURN_PROPENSITY'
            WHEN churn_propensity_score > 0.5 THEN 'HIGH_CHURN_PROPENSITY'
            WHEN sentiment_score_last_30d < -0.5 THEN 'VERY_NEGATIVE_SENTIMENT'
            WHEN sentiment_score_last_30d < -0.3 THEN 'NEGATIVE_SENTIMENT'
            WHEN complaint_count_90d >= 5 THEN 'EXCESSIVE_COMPLAINTS'
            WHEN complaint_count_90d >= 3 THEN 'HIGH_COMPLAINTS'
            WHEN renewal_risk_signal = TRUE THEN 'RENEWAL_AT_RISK'
            WHEN intent_cancel_detected = TRUE THEN 'CANCELLATION_INTENT'
            WHEN competitor_mentions_count >= 2 THEN 'COMPETITOR_SHOPPING'
            ELSE 'MULTIPLE_SIGNALS'
        END,
        ROW_NUMBER() OVER (ORDER BY lifetime_value_score DESC),
        'NEW'
    FROM INSURANCE_DB.PROCESSED.FCT_CUSTOMER_360
    WHERE (
        churn_propensity_score > 0.5
        OR sentiment_score_last_30d < -0.3
        OR complaint_count_90d >= 3
        OR (renewal_risk_signal = TRUE AND sentiment_trend < -0.1)
        OR intent_cancel_detected = TRUE
        OR competitor_mentions_count >= 2
    )
    AND customer_id NOT IN (
        SELECT customer_id FROM INSURANCE_DB.PROCESSED.CHURN_ALERTS
        WHERE alert_date >= DATEADD(day, -7, CURRENT_DATE())
          AND status IN ('NEW', 'IN_PROGRESS')
    );

    RETURN 'Churn scan complete. New alerts: ' ||
           (SELECT COUNT(*) FROM INSURANCE_DB.PROCESSED.CHURN_ALERTS WHERE alert_date = CURRENT_DATE())::VARCHAR;
END;
$$;

-- Churn root cause analysis (uses Cortex Complete)
DEFINE PROCEDURE INSURANCE_DB.PROCESSED.SP_CHURN_ROOT_CAUSE(p_customer_id VARCHAR)
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    customer_context VARCHAR;
    interaction_history VARCHAR;
    root_cause_result VARIANT;
BEGIN
    customer_context := (
        SELECT CONCAT(
            'Customer: ', customer_id,
            ' | Segment: ', customer_segment,
            ' | LTV: ', lifetime_value_score::VARCHAR,
            ' | Tenure: ', tenure_months::VARCHAR, ' months',
            ' | Premium: Rs ', total_annual_premium::VARCHAR,
            ' | LOBs: ', lob_diversity::VARCHAR,
            ' | Sentiment(30d): ', COALESCE(sentiment_score_last_30d::VARCHAR, 'N/A'),
            ' | Sentiment Trend: ', COALESCE(sentiment_trend::VARCHAR, 'N/A'),
            ' | Complaints(90d): ', complaint_count_90d::VARCHAR,
            ' | Missed Payments(12m): ', missed_payments_12m::VARCHAR,
            ' | NPS: ', COALESCE(nps_score_latest::VARCHAR, 'N/A'),
            ' | Days to Renewal: ', COALESCE(days_to_nearest_renewal::VARCHAR, 'N/A'),
            ' | Open Claims: ', open_claims_count::VARCHAR,
            ' | Avg Resolution Days: ', COALESCE(avg_resolution_time_days::VARCHAR, 'N/A'),
            ' | Competitor Mentions: ', competitor_mentions_count::VARCHAR,
            ' | Cancel Intent: ', intent_cancel_detected::VARCHAR
        )
        FROM INSURANCE_DB.PROCESSED.FCT_CUSTOMER_360
        WHERE customer_id = :p_customer_id
    );

    interaction_history := (
        SELECT COALESCE(
            LISTAGG(
                CONCAT('[', channel, ' ', interaction_date::VARCHAR, '] ', LEFT(transcript_text, 300)),
                '\n'
            ) WITHIN GROUP (ORDER BY interaction_date DESC),
            'No recent interactions'
        )
        FROM INSURANCE_DB.RAW.INTERACTIONS
        WHERE customer_id = :p_customer_id
          AND interaction_date >= DATEADD(day, -90, CURRENT_TIMESTAMP())
    );

    root_cause_result := (
        SELECT PARSE_JSON(
            SNOWFLAKE.CORTEX.COMPLETE(
                'mistral-large2',
                CONCAT(
                    'You are a customer retention analyst. Analyze this at-risk customer and determine the PRIMARY root cause of potential churn.\n\n',
                    'CUSTOMER PROFILE:\n', :customer_context, '\n\n',
                    'RECENT INTERACTIONS:\n', :interaction_history, '\n\n',
                    'Classify the PRIMARY root cause as one of:\n',
                    '- price_sensitivity: Pricing concerns, premium too high relative to perceived value\n',
                    '- poor_claims_experience: Bad claims resolution, slow processing, denied claims\n',
                    '- service_quality: Poor customer service, long wait times, unresolved issues\n',
                    '- coverage_gap: Coverage doesnt meet needs, exclusions frustrating\n',
                    '- competitor_offer: Actively shopping, received competitor quote\n',
                    '- life_event: Moving, downsizing, life change reducing need\n',
                    '- payment_difficulty: Financial stress, struggling to pay premium\n\n',
                    'Return ONLY valid JSON:\n',
                    '{"root_cause": "one_of_above", "confidence": 0.0-1.0, ',
                    '"evidence": "2-3 sentence explanation of why this is the root cause", ',
                    '"secondary_cause": "one_of_above or null", ',
                    '"urgency": "LOW|MEDIUM|HIGH|CRITICAL"}'
                ),
                OBJECT_CONSTRUCT('temperature', 0.2, 'max_tokens', 400)
            )
        )
    );

    UPDATE INSURANCE_DB.PROCESSED.CHURN_ALERTS
    SET root_cause = :root_cause_result:root_cause::VARCHAR,
        root_cause_confidence = :root_cause_result:confidence::FLOAT,
        status = 'IN_PROGRESS'
    WHERE customer_id = :p_customer_id
      AND status = 'NEW'
      AND alert_date = CURRENT_DATE();

    RETURN :root_cause_result;
END;
$$;

-- Generate retention NBA (uses Cortex Search RAG + Complete)
DEFINE PROCEDURE INSURANCE_DB.PROCESSED.SP_GENERATE_RETENTION_NBA(p_customer_id VARCHAR)
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    customer_segment VARCHAR;
    root_cause VARCHAR;
    ltv_score FLOAT;
    playbook_context VARCHAR;
    nba_result VARIANT;
BEGIN
    SELECT customer_segment, lifetime_value_score
    INTO :customer_segment, :ltv_score
    FROM INSURANCE_DB.PROCESSED.FCT_CUSTOMER_360
    WHERE customer_id = :p_customer_id;

    root_cause := (
        SELECT root_cause FROM INSURANCE_DB.PROCESSED.CHURN_ALERTS
        WHERE customer_id = :p_customer_id
          AND status = 'IN_PROGRESS'
        ORDER BY alert_date DESC LIMIT 1
    );

    playbook_context := (
        SELECT SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
            'INSURANCE_DB.VECTORS.RETENTION_PLAYBOOKS_SEARCH_SERVICE',
            CONCAT(
                '{"query": "', COALESCE(:root_cause, 'general retention'),
                ' ', COALESCE(:customer_segment, 'standard'), ' customer retention strategy",',
                '"columns": ["playbook_name", "content", "success_rate"],',
                '"filter": {"@eq": {"customer_segment": "', COALESCE(:customer_segment, 'STANDARD'), '"}},',
                '"limit": 2}'
            )
        )
    );

    nba_result := (
        SELECT PARSE_JSON(
            SNOWFLAKE.CORTEX.COMPLETE(
                'mistral-large2',
                CONCAT(
                    'You are a retention specialist. Generate a personalized retention action for this customer.\n\n',
                    'CUSTOMER: ', :p_customer_id,
                    ' | Segment: ', COALESCE(:customer_segment, 'STANDARD'),
                    ' | LTV: ', COALESCE(:ltv_score::VARCHAR, '0.5'),
                    ' | Root Cause: ', COALESCE(:root_cause, 'unknown'), '\n\n',
                    'RETENTION PLAYBOOKS (RAG):\n', COALESCE(:playbook_context, 'No playbook found'), '\n\n',
                    'Generate a specific, actionable retention plan. Return ONLY valid JSON:\n',
                    '{"action_type": "RETAIN|CROSS_SELL|ESCALATE|MONITOR",\n',
                    '"offer_details": "specific personalized offer description",\n',
                    '"channel": "CALL|EMAIL|SMS",\n',
                    '"timing": "IMMEDIATE|WITHIN_24H|WITHIN_WEEK|AT_RENEWAL",\n',
                    '"expected_success_rate": 0.0-1.0,\n',
                    '"talking_points": ["point1", "point2", "point3"],\n',
                    '"escalation_needed": true/false,\n',
                    '"budget_required": "amount in INR or null"}'
                ),
                OBJECT_CONSTRUCT('temperature', 0.3, 'max_tokens', 500)
            )
        )
    );

    INSERT INTO INSURANCE_DB.PROCESSED.NEXT_BEST_ACTIONS
        (customer_id, action_type, offer_details, channel, timing,
         priority, expected_success_rate, root_cause, rationale, status,
         expiry_date)
    VALUES (
        :p_customer_id,
        :nba_result:action_type::VARCHAR,
        :nba_result:offer_details::VARCHAR,
        :nba_result:channel::VARCHAR,
        :nba_result:timing::VARCHAR,
        (SELECT priority FROM INSURANCE_DB.PROCESSED.CHURN_ALERTS
         WHERE customer_id = :p_customer_id ORDER BY alert_date DESC LIMIT 1),
        :nba_result:expected_success_rate::FLOAT,
        :root_cause,
        CONCAT('Root cause: ', COALESCE(:root_cause, 'unknown'),
               '. Talking points: ', COALESCE(:nba_result:talking_points::VARCHAR, 'N/A')),
        'PENDING',
        DATEADD(day, 14, CURRENT_DATE())
    );

    UPDATE INSURANCE_DB.PROCESSED.CHURN_ALERTS
    SET status = 'ACTIONED'
    WHERE customer_id = :p_customer_id
      AND status = 'IN_PROGRESS';

    RETURN :nba_result;
END;
$$;

-- Full churn pipeline (scan + root cause + NBA)
DEFINE PROCEDURE INSURANCE_DB.PROCESSED.SP_CHURN_PIPELINE_FULL()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    alert_count INT;
    processed_count INT DEFAULT 0;
    cur_customer VARCHAR;
BEGIN
    CALL INSURANCE_DB.PROCESSED.SP_CHURN_SCAN();

    alert_count := (SELECT COUNT(*) FROM INSURANCE_DB.PROCESSED.CHURN_ALERTS WHERE alert_date = CURRENT_DATE() AND status = 'NEW');

    FOR record IN (
        SELECT customer_id
        FROM INSURANCE_DB.PROCESSED.CHURN_ALERTS
        WHERE alert_date = CURRENT_DATE() AND status = 'NEW'
        ORDER BY priority ASC
        LIMIT 100
    ) DO
        cur_customer := record.customer_id;
        CALL INSURANCE_DB.PROCESSED.SP_CHURN_ROOT_CAUSE(:cur_customer);
        CALL INSURANCE_DB.PROCESSED.SP_GENERATE_RETENTION_NBA(:cur_customer);
        processed_count := processed_count + 1;
    END FOR;

    INSERT INTO INSURANCE_DB.RESULTS.AUDIT_LOG
        (flow_type, reference_id, agent_name, step_number, status, output_payload)
    VALUES
        ('CHURN', 'BATCH_' || CURRENT_DATE()::VARCHAR, 'CHURN_PIPELINE', 0, 'SUCCESS',
         PARSE_JSON(CONCAT('{"alerts_found": ', :alert_count::VARCHAR,
                          ', "processed": ', :processed_count::VARCHAR, '}')));

    RETURN CONCAT('Churn pipeline complete. Alerts: ', :alert_count::VARCHAR,
                  ', Processed: ', :processed_count::VARCHAR);
END;
$$;

-- Document processing: extract text + embed from uploaded PDF
DEFINE PROCEDURE INSURANCE_DB.RAW.SP_PROCESS_UPLOADED_DOCUMENT(p_document_id VARCHAR)
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    stage_ref VARCHAR;
    file_name VARCHAR;
    extracted VARCHAR;
BEGIN
    SELECT stage_path, file_name
    INTO :stage_ref, :file_name
    FROM INSURANCE_DB.RAW.DOCUMENT_REGISTRY
    WHERE document_id = :p_document_id;

    BEGIN
        extracted := (
            SELECT TO_VARCHAR(
                SNOWFLAKE.CORTEX.PARSE_DOCUMENT(
                    '@INSURANCE_DB.RAW.DOCUMENTS_STAGE',
                    :file_name,
                    OBJECT_CONSTRUCT('mode', 'LAYOUT')
                ):content
            )
        );
    EXCEPTION
        WHEN OTHER THEN
            extracted := NULL;
    END;

    IF (extracted IS NOT NULL) THEN
        UPDATE INSURANCE_DB.RAW.DOCUMENT_REGISTRY
        SET extracted_text = :extracted,
            text_embedding = SNOWFLAKE.CORTEX.EMBED_TEXT_768('snowflake-arctic-embed-m', LEFT(:extracted, 8000))::VECTOR(FLOAT, 768),
            extraction_status = 'EXTRACTED',
            extraction_date = CURRENT_TIMESTAMP()
        WHERE document_id = :p_document_id;

        RETURN OBJECT_CONSTRUCT('status', 'SUCCESS', 'document_id', :p_document_id,
                                'extraction_status', 'EXTRACTED', 'text_length', LENGTH(:extracted));
    ELSE
        UPDATE INSURANCE_DB.RAW.DOCUMENT_REGISTRY
        SET extraction_status = 'FAILED',
            extraction_date = CURRENT_TIMESTAMP()
        WHERE document_id = :p_document_id;

        RETURN OBJECT_CONSTRUCT('status', 'FAILED', 'document_id', :p_document_id,
                                'reason', 'PARSE_DOCUMENT returned no content');
    END IF;
END;
$$;

-- Batch document processing
DEFINE PROCEDURE INSURANCE_DB.RAW.SP_PROCESS_ALL_PENDING_DOCUMENTS()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    processed_count INT DEFAULT 0;
BEGIN
    FOR doc IN (
        SELECT document_id, stage_path
        FROM INSURANCE_DB.RAW.DOCUMENT_REGISTRY
        WHERE extraction_status = 'PENDING'
        LIMIT 50
    ) DO
        BEGIN
            CALL INSURANCE_DB.RAW.SP_PROCESS_UPLOADED_DOCUMENT(doc.document_id);
            processed_count := processed_count + 1;
        EXCEPTION
            WHEN OTHER THEN
                UPDATE INSURANCE_DB.RAW.DOCUMENT_REGISTRY
                SET extraction_status = 'FAILED'
                WHERE document_id = doc.document_id;
        END;
    END FOR;

    RETURN 'Processed ' || :processed_count::VARCHAR || ' documents';
END;
$$;
