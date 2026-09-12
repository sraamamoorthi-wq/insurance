-- ============================================================================
-- DATA QUALITY: DMF expectations for key tables
-- ============================================================================

-- Claims: claim_id must not be null
ATTACH DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT
    TO TABLE INSURANCE_DB.RAW.CLAIMS_LANDING
    ON (claim_id)
    EXPECTATION CLAIMS_NO_NULL_ID (value = 0);

-- Claims: claim_id must be unique
ATTACH DATA METRIC FUNCTION SNOWFLAKE.CORE.DUPLICATE_COUNT
    TO TABLE INSURANCE_DB.RAW.CLAIMS_LANDING
    ON (claim_id)
    EXPECTATION CLAIMS_UNIQUE_ID (value = 0);

-- Claims: claimed_amount must not be null
ATTACH DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT
    TO TABLE INSURANCE_DB.RAW.CLAIMS_LANDING
    ON (claimed_amount)
    EXPECTATION CLAIMS_NO_NULL_AMOUNT (value = 0);

-- Customers: customer_id must not be null
ATTACH DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT
    TO TABLE INSURANCE_DB.RAW.CUSTOMERS
    ON (customer_id)
    EXPECTATION CUSTOMERS_NO_NULL_ID (value = 0);

-- Customers: customer_id must be unique
ATTACH DATA METRIC FUNCTION SNOWFLAKE.CORE.DUPLICATE_COUNT
    TO TABLE INSURANCE_DB.RAW.CUSTOMERS
    ON (customer_id)
    EXPECTATION CUSTOMERS_UNIQUE_ID (value = 0);

-- Policies: policy_id must not be null and unique
ATTACH DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT
    TO TABLE INSURANCE_DB.RAW.POLICIES
    ON (policy_id)
    EXPECTATION POLICIES_NO_NULL_ID (value = 0);

ATTACH DATA METRIC FUNCTION SNOWFLAKE.CORE.DUPLICATE_COUNT
    TO TABLE INSURANCE_DB.RAW.POLICIES
    ON (policy_id)
    EXPECTATION POLICIES_UNIQUE_ID (value = 0);

-- Resolutions: settlement_amount must not be null
ATTACH DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT
    TO TABLE INSURANCE_DB.RESULTS.RESOLUTIONS
    ON (settlement_amount)
    EXPECTATION RESOLUTIONS_NO_NULL_SETTLEMENT (value = 0);

-- Resolutions: claim_id must be unique (one resolution per claim)
ATTACH DATA METRIC FUNCTION SNOWFLAKE.CORE.DUPLICATE_COUNT
    TO TABLE INSURANCE_DB.RESULTS.RESOLUTIONS
    ON (claim_id)
    EXPECTATION RESOLUTIONS_UNIQUE_CLAIM (value = 0);

-- Fraud Indicators: pattern descriptions must not be null
ATTACH DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT
    TO TABLE INSURANCE_DB.RAW.FRAUD_INDICATORS
    ON (pattern_description)
    EXPECTATION FRAUD_INDICATORS_NO_NULL_DESC (value = 0);
