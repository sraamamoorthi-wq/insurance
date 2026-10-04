SELECT
    claim_id,
    current_state,
    intake_output:severity::VARCHAR AS severity,
    validation_output:valid::BOOLEAN AS policy_valid,
    ROUND(fraud_output:composite_fraud_score::FLOAT, 2) AS fraud_score,
    fraud_output:risk_level::VARCHAR AS fraud_risk,
    assessment_output:damage_category::VARCHAR AS damage_category,
    ROUND(assessment_output:recommended_settlement::FLOAT, 0) AS recommended_settlement,
    resolution_output:decision::VARCHAR AS decision,
    ROUND(resolution_output:settlement_amount::FLOAT, 0) AS final_settlement
FROM INSURANCE_DB.PROCESSED.CLAIM_STATE
WHERE claim_id = 'CLM-001';