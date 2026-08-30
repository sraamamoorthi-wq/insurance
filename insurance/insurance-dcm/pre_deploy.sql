-- ============================================================================
-- PRE-DEPLOY: Objects that must exist BEFORE DCM definitions are applied
-- Run with ACCOUNTADMIN role
-- ============================================================================

USE ROLE ACCOUNTADMIN;

-- Notification integration (requires ACCOUNTADMIN, not supported by DEFINE)
CREATE NOTIFICATION INTEGRATION IF NOT EXISTS CLAIMS_EMAIL_NOTIFICATION
    TYPE = EMAIL
    ENABLED = TRUE
    ALLOWED_RECIPIENTS = ('raamamoorthi.s@idp.com')
    COMMENT = 'Email notifications for claim decisions and escalations';

-- Grant Cortex access to app role (cross-database grant, needs ACCOUNTADMIN)
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE INSURANCE_APP_ROLE;

-- Warehouse grants (DCM has constraints with warehouse grants)
GRANT USAGE ON WAREHOUSE AGENT_WH TO ROLE INSURANCE_APP_ROLE;
GRANT USAGE ON WAREHOUSE EVAL_WH TO ROLE INSURANCE_APP_ROLE;
GRANT USAGE ON WAREHOUSE INGEST_WH TO ROLE INSURANCE_APP_ROLE;
GRANT USAGE ON WAREHOUSE AGENT_WH TO ROLE INSURANCE_ADJUSTER_ROLE;
GRANT USAGE ON WAREHOUSE EVAL_WH TO ROLE INSURANCE_RETENTION_ROLE;
GRANT USAGE ON WAREHOUSE AGENT_WH TO ROLE INSURANCE_UNDERWRITER_ROLE;
