-- Find the claim you just submitted
SELECT claim_id, customer_id, lob_type, claimed_amount, claim_status, submission_date
FROM INSURANCE_DB.RAW.CLAIMS_LANDING
WHERE customer_id = 'CUST001' AND lob_type = 'AUTO'
ORDER BY submission_date DESC
LIMIT 3;

-- Run the pipeline (paste the claim_id)
CALL INSURANCE_DB.PROCESSED.SP_PROCESS_CLAIM('62ff9fbe-3eda-46fd-afe9-548ddd0b9c72');

-- View the decision
SELECT decision, settlement_amount, fraud_risk_level, confidence_score, reasoning_summary
FROM INSURANCE_DB.RESULTS.RESOLUTIONS
WHERE claim_id = '62ff9fbe-3eda-46fd-afe9-548ddd0b9c72'
ORDER BY decided_at DESC LIMIT 1;

SELECT *
FROM INSURANCE_DB.VECTORS.FRAUD_PATTERN_EMBEDDINGS


ORDER BY severity;