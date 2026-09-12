USE ROLE ACCOUNTADMIN;
-- Verify Cortex is available in your new account's region
SELECT SNOWFLAKE.CORTEX.COMPLETE('mistral-large2', 'Say OK');