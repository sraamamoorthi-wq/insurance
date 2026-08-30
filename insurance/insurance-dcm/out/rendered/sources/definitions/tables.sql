-- ============================================================================
-- TABLES: All table definitions across RAW, PROCESSED, RESULTS, VECTORS schemas
-- ============================================================================

-- ======================== RAW SCHEMA ========================

DEFINE TABLE INSURANCE_DB.RAW.CUSTOMERS (
    customer_id         VARCHAR(50) NOT NULL,
    first_name          VARCHAR(100),
    last_name           VARCHAR(100),
    email               VARCHAR(200),
    phone               VARCHAR(20),
    date_of_birth       DATE,
    address             VARCHAR(500),
    city                VARCHAR(100),
    state_province      VARCHAR(50),
    pin_code            VARCHAR(10),
    customer_segment    VARCHAR(20),
    lifetime_value_score FLOAT,
    onboarding_date     DATE,
    kyc_status          VARCHAR(20),
    preferred_channel   VARCHAR(20),
    created_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_customers PRIMARY KEY (customer_id)
);

DEFINE TABLE INSURANCE_DB.RAW.POLICIES (
    policy_id           VARCHAR(50) NOT NULL,
    customer_id         VARCHAR(50) NOT NULL,
    lob_type            VARCHAR(30) NOT NULL,
    policy_status       VARCHAR(20),
    start_date          DATE,
    end_date            DATE,
    renewal_date        DATE,
    premium_annual      FLOAT,
    coverage_limit      FLOAT,
    deductible          FLOAT,
    exclusions          VARIANT,
    asset_details       VARIANT,
    underwriting_tier   VARCHAR(20),
    geographic_zone     VARCHAR(50),
    provider_network    VARCHAR(20),
    created_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_policies PRIMARY KEY (policy_id)
);

DEFINE TABLE INSURANCE_DB.RAW.CLAIMS_LANDING (
    claim_id            VARCHAR(50) NOT NULL DEFAULT UUID_STRING(),
    policy_id           VARCHAR(50),
    customer_id         VARCHAR(50),
    claim_text          VARCHAR(10000),
    incident_date       DATE,
    submission_date     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    claimed_amount      FLOAT,
    lob_type            VARCHAR(30),
    claim_status        VARCHAR(30) DEFAULT 'SUBMITTED',
    incident_location   VARCHAR(500),
    supporting_docs     VARIANT,
    metadata            VARIANT,
    created_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_claims_landing PRIMARY KEY (claim_id)
);

DEFINE TABLE INSURANCE_DB.RAW.PROVIDERS (
    provider_id         VARCHAR(50) NOT NULL,
    provider_name       VARCHAR(200),
    provider_type       VARCHAR(50),
    lob_type            VARCHAR(30),
    network_status      VARCHAR(20),
    risk_flag           BOOLEAN DEFAULT FALSE,
    avg_billing_amount  FLOAT,
    total_claims_served INT,
    fraud_flag_count    INT DEFAULT 0,
    location_city       VARCHAR(100),
    location_state      VARCHAR(50),
    license_number      VARCHAR(100),
    created_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_providers PRIMARY KEY (provider_id)
);

DEFINE TABLE INSURANCE_DB.RAW.FRAUD_INDICATORS (
    indicator_id        VARCHAR(50) NOT NULL,
    pattern_type        VARCHAR(100),
    pattern_description VARCHAR(5000),
    lob_type            VARCHAR(30),
    severity            VARCHAR(20),
    detection_signals   VARIANT,
    example_narrative   VARCHAR(5000),
    confirmed_cases     INT,
    last_seen_date      DATE,
    created_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_fraud_indicators PRIMARY KEY (indicator_id)
);

DEFINE TABLE INSURANCE_DB.RAW.INTERACTIONS (
    interaction_id      VARCHAR(50) NOT NULL,
    customer_id         VARCHAR(50),
    channel             VARCHAR(20),
    interaction_date    TIMESTAMP_NTZ,
    transcript_text     VARCHAR(50000),
    direction           VARCHAR(10),
    topic               VARCHAR(100),
    resolution_status   VARCHAR(20),
    agent_id            VARCHAR(50),
    duration_seconds    INT,
    nps_score           INT,
    created_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_interactions PRIMARY KEY (interaction_id)
);

DEFINE TABLE INSURANCE_DB.RAW.PAYMENTS (
    payment_id          VARCHAR(50) NOT NULL,
    policy_id           VARCHAR(50),
    customer_id         VARCHAR(50),
    payment_date        DATE,
    due_date            DATE,
    amount              FLOAT,
    payment_status      VARCHAR(20),
    payment_method      VARCHAR(30),
    days_delayed        INT DEFAULT 0,
    created_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_payments PRIMARY KEY (payment_id)
)
CHANGE_TRACKING = TRUE;

DEFINE TABLE INSURANCE_DB.RAW.APPLICATIONS (
    application_id      VARCHAR(50) NOT NULL DEFAULT UUID_STRING(),
    applicant_name      VARCHAR(200),
    applicant_email     VARCHAR(200),
    existing_customer_id VARCHAR(50),
    lob_type            VARCHAR(30),
    coverage_requested  FLOAT,
    asset_details       VARIANT,
    self_declared_history VARIANT,
    credit_score        INT,
    geographic_zone     VARCHAR(50),
    employer_name       VARCHAR(200),
    submission_date     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    status              VARCHAR(20) DEFAULT 'PENDING',
    CONSTRAINT pk_applications PRIMARY KEY (application_id)
);

DEFINE TABLE INSURANCE_DB.RAW.DOCUMENTS (
    document_id         VARCHAR(50) NOT NULL DEFAULT UUID_STRING(),
    claim_id            VARCHAR(50),
    document_type       VARCHAR(50),
    file_name           VARCHAR(200),
    stage_path          VARCHAR(500),
    lob_type            VARCHAR(30),
    upload_date         TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    extracted_text      VARCHAR(100000),
    extraction_status   VARCHAR(20) DEFAULT 'PENDING',
    page_count          INT,
    file_size_bytes     INT,
    CONSTRAINT pk_documents PRIMARY KEY (document_id)
);

DEFINE TABLE INSURANCE_DB.RAW.ACTUARIAL_TABLES (
    table_id            VARCHAR(50) NOT NULL,
    lob_type            VARCHAR(30),
    risk_tier           VARCHAR(20),
    geographic_zone     VARCHAR(50),
    base_rate           FLOAT,
    risk_multiplier     FLOAT,
    geographic_factor   FLOAT,
    claims_history_factor FLOAT,
    effective_date      DATE,
    expiry_date         DATE,
    CONSTRAINT pk_actuarial PRIMARY KEY (table_id)
);

DEFINE TABLE INSURANCE_DB.RAW.UNDERWRITING_GUIDELINES (
    guideline_id        VARCHAR(50) NOT NULL,
    lob_type            VARCHAR(30),
    section_name        VARCHAR(200),
    content             VARCHAR(10000),
    risk_level          VARCHAR(20),
    regulatory_reference VARCHAR(200),
    effective_date      DATE,
    status              VARCHAR(20) DEFAULT 'CURRENT',
    CONSTRAINT pk_guidelines PRIMARY KEY (guideline_id)
);

DEFINE TABLE INSURANCE_DB.RAW.RETENTION_PLAYBOOKS (
    playbook_id         VARCHAR(50) NOT NULL,
    customer_segment    VARCHAR(20),
    root_cause          VARCHAR(100),
    playbook_name       VARCHAR(200),
    content             VARCHAR(10000),
    recommended_actions VARIANT,
    success_rate        FLOAT,
    applicable_lob      VARCHAR(30),
    CONSTRAINT pk_playbooks PRIMARY KEY (playbook_id)
);

-- NB_07 Document ingestion tables
DEFINE TABLE INSURANCE_DB.RAW.AUTO_CLAIMS (
    claim_id                VARCHAR(50) DEFAULT UUID_STRING(),
    customer_id             VARCHAR(50),
    policy_number           VARCHAR(50),
    incident_date           DATE,
    claim_amount            FLOAT,
    paid_amount             FLOAT DEFAULT 0,
    claim_type              VARCHAR(50),
    fault_determination     VARCHAR(30),
    repair_shop_id          VARCHAR(50),
    claim_status            VARCHAR(30) DEFAULT 'PENDING',
    fraud_flag              BOOLEAN DEFAULT FALSE,
    resolution_days         INT,
    claim_description       VARCHAR(10000),
    claim_description_embedding VECTOR(FLOAT, 768),
    witness_statement       VARCHAR(10000),
    submitted_by            VARCHAR(100),
    submission_date         TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_auto_claims PRIMARY KEY (claim_id)
);

DEFINE TABLE INSURANCE_DB.RAW.AUTO_POLICY_APPLICATIONS (
    application_id          VARCHAR(50) DEFAULT UUID_STRING(),
    applicant_name          VARCHAR(200),
    date_of_birth           DATE,
    address                 VARCHAR(500),
    zipcode                 VARCHAR(10),
    vehicle_make_model_year VARCHAR(200),
    vin                     VARCHAR(20),
    annual_mileage          INT,
    coverage_type_requested VARCHAR(50),
    coverage_limit          FLOAT,
    deductible_amount       FLOAT,
    annual_premium          FLOAT,
    policy_start_date       DATE,
    renewal_date            DATE,
    driving_history_violations INT DEFAULT 0,
    prior_insurance_carrier VARCHAR(100),
    number_of_drivers       INT DEFAULT 1,
    submitted_by            VARCHAR(100),
    submission_date         TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    status                  VARCHAR(20) DEFAULT 'PENDING',
    CONSTRAINT pk_auto_apps PRIMARY KEY (application_id)
);

DEFINE TABLE INSURANCE_DB.RAW.PROPERTY_CLAIMS (
    claim_id                VARCHAR(50) DEFAULT UUID_STRING(),
    customer_id             VARCHAR(50),
    incident_date           DATE,
    claim_amount            FLOAT,
    paid_amount             FLOAT DEFAULT 0,
    damage_type             VARCHAR(50),
    cause_of_loss           VARCHAR(200),
    contractor_id           VARCHAR(50),
    claim_status            VARCHAR(30) DEFAULT 'PENDING',
    fraud_flag              BOOLEAN DEFAULT FALSE,
    replacement_cost_claimed FLOAT,
    claim_description       VARCHAR(10000),
    claim_description_embedding VECTOR(FLOAT, 768),
    fire_investigation_report VARCHAR(500),
    contractor_repair_estimate VARCHAR(500),
    property_inspection_photos VARCHAR(500),
    submitted_by            VARCHAR(100),
    submission_date         TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_property_claims PRIMARY KEY (claim_id)
);

DEFINE TABLE INSURANCE_DB.RAW.PROPERTY_POLICY_APPLICATIONS (
    application_id          VARCHAR(50) DEFAULT UUID_STRING(),
    applicant_name          VARCHAR(200),
    property_address        VARCHAR(500),
    zipcode                 VARCHAR(10),
    property_type           VARCHAR(50),
    year_built              INT,
    construction_type       VARCHAR(50),
    square_footage          INT,
    replacement_cost_value  FLOAT,
    annual_premium          FLOAT,
    coverage_limit          FLOAT,
    deductible_amount       FLOAT,
    policy_start_date       DATE,
    renewal_date            DATE,
    security_system_flag    BOOLEAN DEFAULT FALSE,
    prior_claims_declared   INT DEFAULT 0,
    property_inspection_report VARCHAR(500),
    submitted_by            VARCHAR(100),
    submission_date         TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    status                  VARCHAR(20) DEFAULT 'PENDING',
    CONSTRAINT pk_property_apps PRIMARY KEY (application_id)
);

DEFINE TABLE INSURANCE_DB.RAW.WORKERS_COMP_CLAIMS (
    claim_id                VARCHAR(50) DEFAULT UUID_STRING(),
    customer_id             VARCHAR(50),
    employee_id             VARCHAR(50),
    incident_date           DATE,
    injury_type             VARCHAR(50),
    body_part_injured       VARCHAR(100),
    claim_amount            FLOAT,
    paid_amount             FLOAT DEFAULT 0,
    days_lost               INT,
    claim_status            VARCHAR(30) DEFAULT 'PENDING',
    fraud_flag              BOOLEAN DEFAULT FALSE,
    treating_physician_id   VARCHAR(50),
    incident_description    VARCHAR(10000),
    incident_description_embedding VECTOR(FLOAT, 768),
    medical_report          VARCHAR(500),
    employer_statement      VARCHAR(10000),
    return_to_work_plan     VARCHAR(500),
    submitted_by            VARCHAR(100),
    submission_date         TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_wc_claims PRIMARY KEY (claim_id)
);

DEFINE TABLE INSURANCE_DB.RAW.WORKERS_COMP_POLICY_APPLICATIONS (
    application_id          VARCHAR(50) DEFAULT UUID_STRING(),
    employer_name           VARCHAR(200),
    industry_code           VARCHAR(20),
    employee_count          INT,
    payroll_amount          FLOAT,
    experience_modification_rate FLOAT,
    annual_premium          FLOAT,
    policy_start_date       DATE,
    renewal_date            DATE,
    prior_claims_3yr        INT DEFAULT 0,
    safety_program_flag     BOOLEAN DEFAULT FALSE,
    osha_violations_count   INT DEFAULT 0,
    workplace_safety_audit  VARCHAR(500),
    submitted_by            VARCHAR(100),
    submission_date         TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    status                  VARCHAR(20) DEFAULT 'PENDING',
    CONSTRAINT pk_wc_apps PRIMARY KEY (application_id)
);

DEFINE TABLE INSURANCE_DB.RAW.POLICE_REPORTS (
    report_id               VARCHAR(50) DEFAULT UUID_STRING(),
    claim_id                VARCHAR(50),
    report_number           VARCHAR(50),
    incident_location       VARCHAR(500),
    fault_determination     VARCHAR(30),
    parties_involved_count  INT,
    officer_narrative       VARCHAR(10000),
    accident_diagram_photos VARCHAR(500),
    submission_date         TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

DEFINE TABLE INSURANCE_DB.RAW.GEOGRAPHIC_RISK (
    zipcode                 VARCHAR(10) PRIMARY KEY,
    flood_risk_score        FLOAT,
    fire_risk_score         FLOAT,
    crime_rate_index        FLOAT,
    weather_zone            VARCHAR(50)
);

DEFINE TABLE INSURANCE_DB.RAW.CREDIT_BUREAU (
    customer_id             VARCHAR(50),
    credit_score            INT,
    credit_history_length   INT,
    delinquencies_count     INT DEFAULT 0,
    bankruptcies_count      INT DEFAULT 0,
    pulled_date             DATE DEFAULT CURRENT_DATE()
);

DEFINE TABLE INSURANCE_DB.RAW.DOCUMENT_REGISTRY (
    document_id             VARCHAR(50) DEFAULT UUID_STRING(),
    claim_id                VARCHAR(50),
    application_id          VARCHAR(50),
    customer_id             VARCHAR(50),
    lob_type                VARCHAR(30),
    document_type           VARCHAR(50),
    file_name               VARCHAR(200),
    stage_path              VARCHAR(500),
    file_size_bytes         INT,
    upload_date             TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    uploaded_by             VARCHAR(100),
    extraction_status       VARCHAR(20) DEFAULT 'PENDING',
    extracted_text          VARCHAR(100000),
    text_embedding          VECTOR(FLOAT, 768),
    extraction_date         TIMESTAMP_NTZ,
    CONSTRAINT pk_doc_registry PRIMARY KEY (document_id)
);

-- ======================== PROCESSED SCHEMA ========================

DEFINE TABLE INSURANCE_DB.PROCESSED.CLAIM_STATE (
    claim_id            VARCHAR(50) NOT NULL,
    current_state       VARCHAR(30),
    intake_output       VARIANT,
    validation_output   VARIANT,
    fraud_output        VARIANT,
    assessment_output   VARIANT,
    resolution_output   VARIANT,
    started_at          TIMESTAMP_NTZ,
    completed_at        TIMESTAMP_NTZ,
    error_message       VARCHAR(2000),
    retry_count         INT DEFAULT 0,
    CONSTRAINT pk_claim_state PRIMARY KEY (claim_id)
);

DEFINE TABLE INSURANCE_DB.PROCESSED.FCT_CUSTOMER_360 (
    customer_id                 VARCHAR(50) NOT NULL,
    customer_segment            VARCHAR(20),
    lifetime_value_score        FLOAT,
    tenure_months               INT,
    active_policy_count         INT,
    total_annual_premium        FLOAT,
    lob_diversity               INT,
    days_to_nearest_renewal     INT,
    coverage_adequacy_ratio     FLOAT,
    lapse_count_historical      INT,
    policy_ids_array            VARIANT,
    claim_count_12m             INT,
    claim_count_lifetime        INT,
    claims_approved_ratio       FLOAT,
    avg_claim_amount            FLOAT,
    max_claim_amount            FLOAT,
    total_amount_paid           FLOAT,
    avg_resolution_time_days    FLOAT,
    open_claims_count           INT,
    fraud_flag_count            INT,
    loss_ratio                  FLOAT,
    claim_acceleration_ratio    FLOAT,
    payment_delay_avg_days      FLOAT,
    missed_payments_12m         INT,
    payment_regularity_score    FLOAT,
    last_payment_days_ago       INT,
    auto_pay_enrolled           BOOLEAN,
    sentiment_score_last_30d    FLOAT,
    sentiment_trend             FLOAT,
    frustration_level           FLOAT,
    escalation_flag             BOOLEAN,
    complaint_count_90d         INT,
    nps_score_latest            INT,
    intent_cancel_detected      BOOLEAN,
    competitor_mentions_count   INT,
    channel_preference          VARCHAR(20),
    last_interaction_days_ago   INT,
    digital_engagement_trend    FLOAT,
    emotional_manipulation_flag BOOLEAN,
    inconsistency_score         FLOAT,
    vagueness_score             FLOAT,
    fraud_similarity_score      FLOAT,
    claim_cluster_id            INT,
    provider_anomaly_score      FLOAT,
    renewal_risk_signal         BOOLEAN,
    complaint_rate_per_claim    FLOAT,
    lifetime_loss_ratio         FLOAT,
    high_value_at_risk          BOOLEAN,
    geographic_risk_score       FLOAT,
    churn_propensity_score      FLOAT,
    churn_time_to_event_days    INT,
    fraud_propensity_score      FLOAT,
    underwriting_risk_tier      VARCHAR(20),
    expected_loss_ratio         FLOAT,
    cross_sell_propensity       FLOAT,
    recommended_lob             VARCHAR(30),
    next_best_action            VARCHAR(50),
    nba_rationale               VARCHAR(2000),
    nba_priority                INT,
    last_refreshed_at           TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_customer_360 PRIMARY KEY (customer_id)
);

DEFINE TABLE INSURANCE_DB.PROCESSED.CHURN_ALERTS (
    alert_id            VARCHAR(50) DEFAULT UUID_STRING(),
    customer_id         VARCHAR(50),
    alert_date          DATE DEFAULT CURRENT_DATE(),
    churn_propensity    FLOAT,
    sentiment_score     FLOAT,
    complaint_count     INT,
    trigger_reason      VARCHAR(200),
    priority            INT,
    status              VARCHAR(20) DEFAULT 'NEW',
    root_cause          VARCHAR(100),
    root_cause_confidence FLOAT,
    created_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

DEFINE TABLE INSURANCE_DB.PROCESSED.NEXT_BEST_ACTIONS (
    nba_id              VARCHAR(50) DEFAULT UUID_STRING(),
    customer_id         VARCHAR(50),
    action_type         VARCHAR(50),
    offer_details       VARCHAR(2000),
    channel             VARCHAR(20),
    timing              VARCHAR(50),
    priority            INT,
    expected_success_rate FLOAT,
    root_cause          VARCHAR(100),
    rationale           VARCHAR(2000),
    status              VARCHAR(20) DEFAULT 'PENDING',
    created_date        DATE DEFAULT CURRENT_DATE(),
    expiry_date         DATE,
    outcome             VARCHAR(20),
    created_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- ======================== RESULTS SCHEMA ========================

DEFINE TABLE INSURANCE_DB.RESULTS.RESOLUTIONS (
    resolution_id       VARCHAR(50) DEFAULT UUID_STRING(),
    claim_id            VARCHAR(50),
    customer_id         VARCHAR(50),
    policy_id           VARCHAR(50),
    lob_type            VARCHAR(30),
    decision            VARCHAR(30),
    settlement_amount   FLOAT,
    claimed_amount      FLOAT,
    fraud_risk_level    VARCHAR(20),
    fraud_score         FLOAT,
    reasoning_summary   VARCHAR(5000),
    confidence_score    FLOAT,
    next_steps          VARCHAR(2000),
    processing_time_ms  INT,
    decided_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

DEFINE TABLE INSURANCE_DB.RESULTS.UNDERWRITING_DECISIONS (
    decision_id         VARCHAR(50) DEFAULT UUID_STRING(),
    application_id      VARCHAR(50),
    customer_id         VARCHAR(50),
    lob_type            VARCHAR(30),
    risk_tier           VARCHAR(20),
    confidence          FLOAT,
    recommended_premium FLOAT,
    exclusions          VARIANT,
    terms_text          VARCHAR(5000),
    auto_approved       BOOLEAN,
    rationale           VARCHAR(2000),
    decided_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

DEFINE TABLE INSURANCE_DB.RESULTS.AUDIT_LOG (
    audit_id            VARCHAR(50) DEFAULT UUID_STRING(),
    flow_type           VARCHAR(30),
    reference_id        VARCHAR(50),
    agent_name          VARCHAR(50),
    step_number         INT,
    input_payload       VARIANT,
    output_payload      VARIANT,
    cortex_module_used  VARCHAR(50),
    model_used          VARCHAR(50),
    tokens_input        INT,
    tokens_output       INT,
    latency_ms          INT,
    status              VARCHAR(20),
    error_message       VARCHAR(2000),
    created_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- ======================== VECTORS SCHEMA ========================

DEFINE TABLE INSURANCE_DB.VECTORS.DOCUMENT_CHUNKS (
    chunk_id            VARCHAR(50) DEFAULT UUID_STRING(),
    document_id         VARCHAR(50),
    claim_id            VARCHAR(50),
    chunk_index         INT,
    chunk_text          VARCHAR(8000),
    chunk_embedding     VECTOR(FLOAT, 768),
    document_type       VARCHAR(50),
    lob_type            VARCHAR(30),
    metadata            VARIANT,
    created_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

DEFINE TABLE INSURANCE_DB.VECTORS.FRAUD_PATTERN_EMBEDDINGS (
    pattern_id          VARCHAR(50),
    pattern_type        VARCHAR(100),
    pattern_description VARCHAR(5000),
    pattern_embedding   VECTOR(FLOAT, 768),
    severity            VARCHAR(20),
    lob_type            VARCHAR(30),
    created_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);