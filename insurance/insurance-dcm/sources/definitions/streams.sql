-- ============================================================================
-- STREAMS: Change Data Capture for event-driven automation
-- ============================================================================

DEFINE STREAM INSURANCE_DB.RAW.CLAIMS_LANDING_STREAM
    ON TABLE INSURANCE_DB.RAW.CLAIMS_LANDING
    APPEND_ONLY = TRUE
    SHOW_INITIAL_ROWS = FALSE
    COMMENT = 'CDC stream for new claim submissions - triggers orchestrator';

DEFINE STREAM INSURANCE_DB.RAW.INTERACTIONS_STREAM
    ON TABLE INSURANCE_DB.RAW.INTERACTIONS
    APPEND_ONLY = TRUE
    SHOW_INITIAL_ROWS = FALSE
    COMMENT = 'CDC stream for new interactions - triggers sentiment recalculation';

DEFINE STREAM INSURANCE_DB.RAW.APPLICATIONS_STREAM
    ON TABLE INSURANCE_DB.RAW.APPLICATIONS
    APPEND_ONLY = TRUE
    SHOW_INITIAL_ROWS = FALSE
    COMMENT = 'CDC stream for new policy applications - triggers underwriting';

DEFINE STREAM INSURANCE_DB.RAW.PAYMENTS_STREAM
    ON TABLE INSURANCE_DB.RAW.PAYMENTS
    SHOW_INITIAL_ROWS = FALSE
    COMMENT = 'CDC stream for payment events - updates payment behavior features';

DEFINE STREAM INSURANCE_DB.RESULTS.RESOLUTIONS_STREAM
    ON TABLE INSURANCE_DB.RESULTS.RESOLUTIONS
    APPEND_ONLY = TRUE
    SHOW_INITIAL_ROWS = FALSE
    COMMENT = 'CDC stream for new decisions - triggers notifications + 360 refresh';
