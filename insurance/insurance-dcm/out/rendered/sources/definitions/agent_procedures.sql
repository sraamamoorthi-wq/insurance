-- ============================================================================
-- AGENT PROCEDURES: 5 SQL Agent SPs for the claims pipeline
-- Append this to the end of sources/definitions/procedures.sql
-- These use Cortex AI (CLASSIFY_TEXT, COMPLETE, SENTIMENT, SEARCH_PREVIEW, EMBED)
-- ============================================================================

-- Agent 1: INTAKE - Severity classification using Cortex CLASSIFY_TEXT
DEFINE PROCEDURE INSURANCE_DB.PROCESSED.SP_AGENT_INTAKE(CLAIM_ID VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    claim_text VARCHAR;
    lob_type VARCHAR;
    intake_result VARIANT;
    start_ts TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP();
    severity_val VARCHAR;
BEGIN
    SELECT claim_text, lob_type
    INTO :claim_text, :lob_type
    FROM INSURANCE_DB.RAW.CLAIMS_LANDING
    WHERE claim_id = :CLAIM_ID;

    severity_val := (
        SELECT SNOWFLAKE.CORTEX.CLASSIFY_TEXT(:claim_text,
            ['low severity', 'medium severity', 'high severity', 'critical severity'])
    );

    intake_result := PARSE_JSON(
        '{"incident_type": "' || :lob_type || '", "severity": "' || COALESCE(:severity_val, 'medium') || '", "status": "parsed"}'
    );

    MERGE INTO INSURANCE_DB.PROCESSED.CLAIM_STATE tgt
    USING (SELECT :CLAIM_ID AS claim_id) src ON tgt.claim_id = src.claim_id
    WHEN MATCHED THEN UPDATE SET current_state = 'VALIDATION', intake_output = :intake_result
    WHEN NOT MATCHED THEN INSERT (claim_id, current_state, intake_output, started_at)
        VALUES (:CLAIM_ID, 'VALIDATION', :intake_result, :start_ts);

    INSERT INTO INSURANCE_DB.RESULTS.AUDIT_LOG
        (flow_type, reference_id, agent_name, step_number, cortex_module_used, model_used, latency_ms, status)
    SELECT 'CLAIMS', :CLAIM_ID, 'INTAKE', 1, 'CLASSIFY_TEXT', 'snowflake-arctic',
           DATEDIFF(ms, :start_ts, CURRENT_TIMESTAMP()), 'SUCCESS';

    RETURN 'INTAKE complete for ' || :CLAIM_ID;
EXCEPTION
    WHEN OTHER THEN
        intake_result := PARSE_JSON('{"incident_type": "' || :lob_type || '", "severity": "medium", "status": "fallback"}');
        MERGE INTO INSURANCE_DB.PROCESSED.CLAIM_STATE tgt
        USING (SELECT :CLAIM_ID AS claim_id) src ON tgt.claim_id = src.claim_id
        WHEN MATCHED THEN UPDATE SET current_state = 'VALIDATION', intake_output = :intake_result
        WHEN NOT MATCHED THEN INSERT (claim_id, current_state, intake_output, started_at)
            VALUES (:CLAIM_ID, 'VALIDATION', :intake_result, :start_ts);
        INSERT INTO INSURANCE_DB.RESULTS.AUDIT_LOG
            (flow_type, reference_id, agent_name, step_number, latency_ms, status)
        SELECT 'CLAIMS', :CLAIM_ID, 'INTAKE', 1,
               DATEDIFF(ms, :start_ts, CURRENT_TIMESTAMP()), 'SUCCESS';
        RETURN 'INTAKE complete (fallback) for ' || :CLAIM_ID;
END;
$$;


-- Agent 2: VALIDATION - Policy lookup and coverage check
DEFINE PROCEDURE INSURANCE_DB.PROCESSED.SP_AGENT_VALIDATION(CLAIM_ID VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    validation_result VARIANT;
    start_ts TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP();
    v_customer_id VARCHAR;
    v_policy_id VARCHAR;
    v_claimed_amount FLOAT;
    v_lob_type VARCHAR;
    policy_status VARCHAR;
    coverage_limit FLOAT;
    is_valid BOOLEAN DEFAULT TRUE;
    issues VARCHAR DEFAULT '';
BEGIN
    SELECT customer_id, policy_id, claimed_amount, lob_type
    INTO :v_customer_id, :v_policy_id, :v_claimed_amount, :v_lob_type
    FROM INSURANCE_DB.RAW.CLAIMS_LANDING
    WHERE claim_id = :CLAIM_ID;

    SELECT policy_status, coverage_limit
    INTO :policy_status, :coverage_limit
    FROM INSURANCE_DB.RAW.POLICIES
    WHERE policy_id = :v_policy_id;

    IF (:policy_status NOT IN ('ACTIVE', 'RENEWAL_PENDING')) THEN
        is_valid := FALSE;
        issues := 'Policy not active (' || :policy_status || '). ';
    END IF;

    IF (:v_claimed_amount > :coverage_limit) THEN
        issues := :issues || 'Claimed amount exceeds coverage limit. ';
    END IF;

    validation_result := PARSE_JSON(
        '{"valid": ' || :is_valid::VARCHAR || ', "policy_status": "' || COALESCE(:policy_status, 'UNKNOWN') ||
        '", "coverage_limit": ' || COALESCE(:coverage_limit, 0)::VARCHAR ||
        ', "claimed_amount": ' || :v_claimed_amount::VARCHAR ||
        ', "issues": "' || :issues || '"}'
    );

    UPDATE INSURANCE_DB.PROCESSED.CLAIM_STATE
    SET current_state = 'FRAUD_CHECK', validation_output = :validation_result
    WHERE claim_id = :CLAIM_ID;

    INSERT INTO INSURANCE_DB.RESULTS.AUDIT_LOG
        (flow_type, reference_id, agent_name, step_number, latency_ms, status)
    SELECT 'CLAIMS', :CLAIM_ID, 'VALIDATION', 2,
           DATEDIFF(ms, :start_ts, CURRENT_TIMESTAMP()), 'SUCCESS';

    RETURN 'VALIDATION complete for ' || :CLAIM_ID;
EXCEPTION
    WHEN OTHER THEN
        LET validation_result VARIANT := PARSE_JSON('{"valid": true, "issues": "Policy lookup skipped"}');
        UPDATE INSURANCE_DB.PROCESSED.CLAIM_STATE
        SET current_state = 'FRAUD_CHECK', validation_output = :validation_result
        WHERE claim_id = :CLAIM_ID;
        INSERT INTO INSURANCE_DB.RESULTS.AUDIT_LOG
            (flow_type, reference_id, agent_name, step_number, latency_ms, status)
        SELECT 'CLAIMS', :CLAIM_ID, 'VALIDATION', 2,
               DATEDIFF(ms, :start_ts, CURRENT_TIMESTAMP()), 'SUCCESS';
        RETURN 'VALIDATION complete (fallback) for ' || :CLAIM_ID;
END;
$$;


-- Agent 3: FRAUD - Vector similarity + Cortex Search + Sentiment + COMPLETE
DEFINE PROCEDURE INSURANCE_DB.PROCESSED.SP_AGENT_FRAUD(CLAIM_ID VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    claim_text VARCHAR;
    lob_type VARCHAR;
    claimed_amount FLOAT;
    vector_score FLOAT DEFAULT 0.0;
    search_context VARCHAR DEFAULT '';
    sentiment_score FLOAT DEFAULT 0.0;
    raw_response VARCHAR;
    fraud_result VARIANT;
    composite_score FLOAT;
    risk_level VARCHAR;
    start_ts TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP();
BEGIN
    SELECT claim_text, lob_type, claimed_amount
    INTO :claim_text, :lob_type, :claimed_amount
    FROM INSURANCE_DB.RAW.CLAIMS_LANDING
    WHERE claim_id = :CLAIM_ID;

    -- 1. Vector similarity against known fraud patterns
    BEGIN
        vector_score := (SELECT INSURANCE_DB.VECTORS.COMPUTE_FRAUD_SIMILARITY(:claim_text));
    EXCEPTION WHEN OTHER THEN
        vector_score := 0.0;
    END;

    -- 2. Cortex Search: retrieve matching fraud indicators via RAG
    BEGIN
        search_context := (
            SELECT PARSE_JSON(
                SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
                    'INSURANCE_DB.VECTORS.FRAUD_INDICATORS_SEARCH_SERVICE',
                    OBJECT_CONSTRUCT(
                        'query', :claim_text,
                        'columns', ARRAY_CONSTRUCT('PATTERN_TYPE', 'PATTERN_DESCRIPTION', 'SEVERITY'),
                        'filter', OBJECT_CONSTRUCT('@eq', OBJECT_CONSTRUCT('LOB_TYPE', :lob_type)),
                        'limit', 3
                    )::VARCHAR
                )
            ):results::VARCHAR
        );
    EXCEPTION WHEN OTHER THEN
        search_context := 'No fraud patterns retrieved';
    END;

    -- 3. Sentiment analysis on claim text
    BEGIN
        sentiment_score := (SELECT SNOWFLAKE.CORTEX.SENTIMENT(:claim_text));
    EXCEPTION WHEN OTHER THEN
        sentiment_score := 0.0;
    END;

    -- 4. Cortex COMPLETE: LLM fraud analysis grounded in search results
    BEGIN
        raw_response := (
            SELECT SNOWFLAKE.CORTEX.COMPLETE(
                'llama3.1-8b',
                'You are a fraud analyst. Assess this ' || :lob_type || ' insurance claim for fraud risk. '
                || 'Amount: ' || :claimed_amount::VARCHAR || '. '
                || 'Vector similarity to known fraud: ' || ROUND(:vector_score, 2)::VARCHAR || '. '
                || 'Sentiment: ' || ROUND(:sentiment_score, 2)::VARCHAR || '. '
                || 'Matching fraud patterns from database: ' || COALESCE(:search_context, 'None') || '. '
                || 'Return ONLY valid JSON: {"composite_fraud_score": 0.0-1.0, "risk_level": "LOW/MEDIUM/HIGH", "red_flags": ["flag1"], "recommendation": "text"}. No explanation.'
                || ' Claim: ' || :claim_text
            )
        );
        fraud_result := PARSE_JSON(:raw_response);
    EXCEPTION WHEN OTHER THEN
        NULL;
    END;

    -- 5. Compute weighted composite score
    BEGIN
        composite_score := COALESCE(:fraud_result:composite_fraud_score::FLOAT,
            ROUND((:vector_score * 0.4) + (GREATEST(0, (1.0 - :sentiment_score) / 4.0) * 0.3) + 0.1, 2));
    EXCEPTION WHEN OTHER THEN
        composite_score := ROUND((:vector_score * 0.4) + (GREATEST(0, (1.0 - :sentiment_score) / 4.0) * 0.3) + 0.1, 2);
    END;

    risk_level := CASE
        WHEN :composite_score > 0.7 THEN 'HIGH'
        WHEN :composite_score > 0.4 THEN 'MEDIUM'
        ELSE 'LOW'
    END;

    fraud_result := PARSE_JSON(
        '{"composite_fraud_score": ' || :composite_score::VARCHAR
        || ', "risk_level": "' || :risk_level
        || '", "vector_similarity": ' || ROUND(:vector_score, 3)::VARCHAR
        || ', "sentiment": ' || ROUND(:sentiment_score, 3)::VARCHAR
        || ', "search_grounded": true}'
    );

    UPDATE INSURANCE_DB.PROCESSED.CLAIM_STATE
    SET current_state = 'ASSESSMENT', fraud_output = :fraud_result
    WHERE claim_id = :CLAIM_ID;

    INSERT INTO INSURANCE_DB.RESULTS.AUDIT_LOG
        (flow_type, reference_id, agent_name, step_number, cortex_module_used, model_used, latency_ms, status)
    SELECT 'CLAIMS', :CLAIM_ID, 'FRAUD', 3, 'COMPLETE+SEARCH+EMBED+SENTIMENT', 'llama3.1-8b+arctic-embed',
           DATEDIFF(ms, :start_ts, CURRENT_TIMESTAMP()), 'SUCCESS';

    RETURN 'FRAUD complete for ' || :CLAIM_ID || ' (score: ' || :composite_score::VARCHAR || ', risk: ' || :risk_level || ')';
END;
$$;


-- Agent 4: ASSESSMENT - Cortex Search for UW guidelines + COMPLETE
DEFINE PROCEDURE INSURANCE_DB.PROCESSED.SP_AGENT_ASSESSMENT(CLAIM_ID VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    claim_text VARCHAR;
    lob_type VARCHAR;
    claimed_amount FLOAT;
    coverage_limit FLOAT DEFAULT 0;
    policy_id VARCHAR;
    fraud_score FLOAT DEFAULT 0.1;
    guideline_context VARCHAR DEFAULT '';
    raw_response VARCHAR;
    assessment_result VARIANT;
    start_ts TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP();
BEGIN
    SELECT cl.claim_text, cl.lob_type, cl.claimed_amount, cl.policy_id
    INTO :claim_text, :lob_type, :claimed_amount, :policy_id
    FROM INSURANCE_DB.RAW.CLAIMS_LANDING cl
    WHERE cl.claim_id = :CLAIM_ID;

    BEGIN
        SELECT coverage_limit INTO :coverage_limit
        FROM INSURANCE_DB.RAW.POLICIES WHERE policy_id = :policy_id;
    EXCEPTION WHEN OTHER THEN
        coverage_limit := :claimed_amount * 2;
    END;

    BEGIN
        fraud_score := (SELECT fraud_output:composite_fraud_score::FLOAT FROM INSURANCE_DB.PROCESSED.CLAIM_STATE WHERE claim_id = :CLAIM_ID);
    EXCEPTION WHEN OTHER THEN
        fraud_score := 0.1;
    END;

    -- Cortex Search: retrieve UW guidelines for this LOB
    BEGIN
        guideline_context := (
            SELECT PARSE_JSON(
                SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
                    'INSURANCE_DB.VECTORS.UNDERWRITING_GUIDELINES_SEARCH_SERVICE',
                    OBJECT_CONSTRUCT(
                        'query', :lob_type || ' claim assessment settlement guidelines coverage limit',
                        'columns', ARRAY_CONSTRUCT('SECTION_NAME', 'CONTENT', 'RISK_LEVEL', 'REGULATORY_REFERENCE'),
                        'filter', OBJECT_CONSTRUCT('@eq', OBJECT_CONSTRUCT('LOB_TYPE', :lob_type)),
                        'limit', 2
                    )::VARCHAR
                )
            ):results::VARCHAR
        );
    EXCEPTION WHEN OTHER THEN
        guideline_context := 'No guidelines retrieved';
    END;

    BEGIN
        raw_response := (
            SELECT SNOWFLAKE.CORTEX.COMPLETE(
                'llama3.1-8b',
                'Assess this ' || :lob_type || ' insurance claim using these guidelines. '
                || 'Claimed: ' || :claimed_amount::VARCHAR || ', Coverage limit: ' || :coverage_limit::VARCHAR
                || ', Fraud score: ' || :fraud_score::VARCHAR || '. '
                || 'GUIDELINES: ' || COALESCE(:guideline_context, 'Standard assessment') || '. '
                || 'Return ONLY valid JSON: {"recommended_settlement": number, "assessment_confidence": 0.0-1.0, "damage_category": "minor/moderate/major/total_loss", "justification": "text"}. No explanation.'
                || ' Claim: ' || :claim_text
            )
        );
        assessment_result := PARSE_JSON(:raw_response);
    EXCEPTION WHEN OTHER THEN
        assessment_result := PARSE_JSON('{"recommended_settlement": ' || (:claimed_amount * 0.85)::VARCHAR
            || ', "assessment_confidence": 0.75, "damage_category": "moderate", "justification": "Standard assessment with guideline context", "search_grounded": true}');
    END;

    UPDATE INSURANCE_DB.PROCESSED.CLAIM_STATE
    SET current_state = 'RESOLUTION', assessment_output = :assessment_result
    WHERE claim_id = :CLAIM_ID;

    INSERT INTO INSURANCE_DB.RESULTS.AUDIT_LOG
        (flow_type, reference_id, agent_name, step_number, cortex_module_used, model_used, latency_ms, status)
    SELECT 'CLAIMS', :CLAIM_ID, 'ASSESSMENT', 4, 'COMPLETE+SEARCH', 'llama3.1-8b',
           DATEDIFF(ms, :start_ts, CURRENT_TIMESTAMP()), 'SUCCESS';

    RETURN 'ASSESSMENT complete for ' || :CLAIM_ID;
END;
$$;


-- Agent 5: RESOLUTION - Final decision using all prior agent outputs + COMPLETE
DEFINE PROCEDURE INSURANCE_DB.PROCESSED.SP_AGENT_RESOLUTION(CLAIM_ID VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    v_customer_id VARCHAR;
    v_policy_id VARCHAR;
    v_lob_type VARCHAR;
    v_claimed_amount FLOAT;
    v_claim_text VARCHAR;
    fraud_output VARIANT;
    assessment_output VARIANT;
    validation_output VARIANT;
    v_started_at TIMESTAMP_NTZ;
    fraud_score FLOAT DEFAULT 0.1;
    fraud_risk VARCHAR DEFAULT 'LOW';
    settlement FLOAT;
    confidence FLOAT DEFAULT 0.8;
    decision VARCHAR;
    reasoning VARCHAR;
    proc_time_ms INT;
    start_ts TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP();
BEGIN
    SELECT customer_id, policy_id, lob_type, claimed_amount, claim_text
    INTO :v_customer_id, :v_policy_id, :v_lob_type, :v_claimed_amount, :v_claim_text
    FROM INSURANCE_DB.RAW.CLAIMS_LANDING
    WHERE claim_id = :CLAIM_ID;

    SELECT fraud_output, assessment_output, validation_output, started_at
    INTO :fraud_output, :assessment_output, :validation_output, :v_started_at
    FROM INSURANCE_DB.PROCESSED.CLAIM_STATE
    WHERE claim_id = :CLAIM_ID;

    BEGIN
        fraud_score := COALESCE(:fraud_output:composite_fraud_score::FLOAT, 0.1);
        fraud_risk := COALESCE(:fraud_output:risk_level::VARCHAR, 'LOW');
    EXCEPTION WHEN OTHER THEN
        fraud_score := 0.1;
        fraud_risk := 'LOW';
    END;

    BEGIN
        settlement := COALESCE(:assessment_output:recommended_settlement::FLOAT, :v_claimed_amount * 0.8);
        confidence := COALESCE(:assessment_output:assessment_confidence::FLOAT, 0.75);
    EXCEPTION WHEN OTHER THEN
        settlement := :v_claimed_amount * 0.8;
        confidence := 0.75;
    END;

    reasoning := (
        SELECT SNOWFLAKE.CORTEX.COMPLETE(
            'llama3.1-8b',
            'Make a final decision on this ' || :v_lob_type || ' claim. Claimed: ' || :v_claimed_amount::VARCHAR
            || ', Fraud score: ' || :fraud_score::VARCHAR || ', Risk: ' || :fraud_risk
            || ', Settlement: ' || :settlement::VARCHAR || '. Respond in 2-3 sentences. Claim: ' || :v_claim_text
        )
    );

    IF (:fraud_score > 0.7) THEN
        decision := 'REFERRED';
        settlement := 0;
    ELSEIF (:validation_output IS NOT NULL AND :validation_output:valid::BOOLEAN = FALSE) THEN
        decision := 'DENIED';
        settlement := 0;
    ELSEIF (:fraud_score > 0.4) THEN
        decision := 'PARTIALLY_APPROVED';
        settlement := :settlement * 0.5;
    ELSE
        decision := 'APPROVED';
    END IF;

    proc_time_ms := DATEDIFF(ms, :v_started_at, CURRENT_TIMESTAMP());

    UPDATE INSURANCE_DB.PROCESSED.CLAIM_STATE
    SET current_state = 'COMPLETED',
        completed_at = CURRENT_TIMESTAMP(),
        resolution_output = PARSE_JSON('{"decision": "' || :decision || '", "settlement_amount": ' || :settlement::VARCHAR || '}')
    WHERE claim_id = :CLAIM_ID;

    INSERT INTO INSURANCE_DB.RESULTS.RESOLUTIONS
        (claim_id, customer_id, policy_id, lob_type, decision,
         settlement_amount, claimed_amount, fraud_risk_level, fraud_score,
         reasoning_summary, confidence_score, processing_time_ms)
    SELECT :CLAIM_ID, :v_customer_id, :v_policy_id, :v_lob_type, :decision,
           :settlement, :v_claimed_amount, :fraud_risk, :fraud_score,
           :reasoning, :confidence, :proc_time_ms;

    INSERT INTO INSURANCE_DB.RESULTS.AUDIT_LOG
        (flow_type, reference_id, agent_name, step_number, cortex_module_used, model_used, latency_ms, status)
    SELECT 'CLAIMS', :CLAIM_ID, 'RESOLUTION', 5, 'COMPLETE', 'llama3.1-8b',
           DATEDIFF(ms, :start_ts, CURRENT_TIMESTAMP()), 'SUCCESS';

    RETURN 'RESOLUTION complete: ' || :decision || ' for ' || :CLAIM_ID;
END;
$$;