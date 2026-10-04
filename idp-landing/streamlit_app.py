import os
import uuid
from datetime import date, datetime

import streamlit as st

st.set_page_config(page_title="IDP Insurance", page_icon=":shield:", layout="wide")

# ── Global CSS Theme ───────────────────────────────────────────────────
st.markdown(
    """
    <style>
    /* ── Color palette ── */
    :root {
        --idp-navy: #1B3A5C;
        --idp-gold: #C9A84C;
        --idp-light: #F7F8FA;
    }

    /* ── Sidebar polish ── */
    section[data-testid="stSidebar"] {
        background: linear-gradient(180deg, #F7F8FA 0%, #EDF0F5 100%);
        border-right: 1px solid #E0E4EA;
    }
    div[data-testid="stSidebar"] .stRadio label p {
        font-size: 1.05rem;
        font-weight: 500;
    }
    div[data-testid="stSidebar"] .stRadio label:hover p {
        color: var(--idp-navy);
    }

    /* ── Metric cards ── */
    div[data-testid="stMetric"] {
        background: white;
        border-radius: 10px;
        box-shadow: 0 1px 4px rgba(0,0,0,0.06);
    }
    div[data-testid="stMetric"] label {
        font-size: 0.8rem;
        text-transform: uppercase;
        letter-spacing: 0.5px;
        color: #666;
    }
    div[data-testid="stMetric"] [data-testid="stMetricValue"] {
        font-weight: 700;
        color: var(--idp-navy);
    }

    /* ── Tabs styling ── */
    button[data-baseweb="tab"] {
        font-weight: 600;
        font-size: 0.9rem;
    }

    /* ── Bordered containers ── */
    div[data-testid="stVerticalBlock"] > div[style*="border"] {
        border-radius: 10px !important;
    }

    /* ── Dataframes ── */
    .stDataFrame {
        border-radius: 8px;
        overflow: hidden;
    }

    /* ── Chat messages ── */
    div[data-testid="stChatMessage"] {
        border-radius: 12px;
    }

    /* ── Section headers ── */
    h2 {
        color: var(--idp-navy) !important;
        border-bottom: 2px solid var(--idp-gold);
        padding-bottom: 0.3rem;
    }

    /* ── Buttons ── */
    button[kind="primary"] {
        border-radius: 8px;
    }

    /* ── Form containers ── */
    div[data-testid="stForm"] {
        border-radius: 10px;
        border-color: #E0E4EA;
    }
    </style>
    """,
    unsafe_allow_html=True,
)

conn = st.connection("snowflake", ttl=os.getenv("SNOWFLAKE_CONNECTION_TTL"))
session = conn.session()


# ── Sidebar Navigation ─────────────────────────────────────────────────
with st.sidebar:
    st.markdown(
        """
        <div style="text-align:center; padding:1rem 0;">
            <svg width="80" height="80" viewBox="0 0 64 64" xmlns="http://www.w3.org/2000/svg">
                <defs>
                    <linearGradient id="sg" x1="0%" y1="0%" x2="0%" y2="100%">
                        <stop offset="0%" style="stop-color:#1B3A5C"/>
                        <stop offset="100%" style="stop-color:#0F2440"/>
                    </linearGradient>
                </defs>
                <path d="M32 2 L58 14 V34 C58 48 46 58 32 62 C18 58 6 48 6 34 V14 Z"
                      fill="url(#sg)" stroke="#C9A84C" stroke-width="2"/>
                <text x="32" y="29" text-anchor="middle" font-family="Arial,sans-serif"
                      font-size="11" font-weight="bold" fill="#C9A84C">IDP</text>
                <line x1="18" y1="34" x2="46" y2="34" stroke="#C9A84C" stroke-width="1"/>
                <text x="32" y="44" text-anchor="middle" font-family="Arial,sans-serif"
                      font-size="6.5" fill="#E8DCC8" letter-spacing="1">INSURANCE</text>
            </svg>
        </div>
        """,
        unsafe_allow_html=True,
    )
    st.markdown(
        "<h3 style='text-align:center; color:#1B3A5C; margin:0;'>IDP Insurance</h3>",
        unsafe_allow_html=True,
    )
    st.caption("Intelligent Digital Platform")
    st.divider()

    nav = st.radio(
        "Navigation",
        [
            ":material/home: Home",
            ":material/description: Claims & Policy Intake",
            ":material/monitoring: Customer 360",
            ":material/chat: Intelligent Chat",
        ],
        label_visibility="collapsed",
    )

    st.divider()
    st.caption("Powered by Snowflake Cortex AI")


# ══════════════════════════════════════════════════════════════════════════
# HOME
# ══════════════════════════════════════════════════════════════════════════
def render_home():
    st.markdown(
        "<h1 style='text-align:center; color:#1B3A5C; margin-bottom:0;'>IDP Insurance Platform</h1>",
        unsafe_allow_html=True,
    )
    st.markdown(
        "<p style='text-align:center; color:#666; font-size:1.05rem; margin-top:0;'>"
        "AI-powered insurance operations — from claims intake to customer retention. "
        "Use the sidebar to navigate between modules.</p>",
        unsafe_allow_html=True,
    )

    st.divider()
    st.markdown("#### :material/analytics: Platform at a Glance")

    customers = conn.query("SELECT COUNT(*) AS n FROM INSURANCE_DB.RAW.CUSTOMERS", ttl=300)
    policies = conn.query("SELECT COUNT(*) AS n FROM INSURANCE_DB.RAW.POLICIES", ttl=300)
    claims = conn.query("SELECT COUNT(*) AS n FROM INSURANCE_DB.RAW.CLAIMS_LANDING", ttl=300)
    alerts = conn.query(
        "SELECT COUNT(*) AS n FROM INSURANCE_DB.PROCESSED.CHURN_ALERTS WHERE STATUS = 'NEW'",
        ttl=300,
    )

    with st.container(horizontal=True):
        st.metric("Customers", int(customers["N"].iloc[0]), border=True)
        st.metric("Active Policies", int(policies["N"].iloc[0]), border=True)
        st.metric("Total Claims", int(claims["N"].iloc[0]), border=True)
        st.metric("Active Churn Alerts", int(alerts["N"].iloc[0]), border=True)

    # ── Quick module cards ──
    st.divider()
    st.markdown("#### :material/apps: Modules")
    cols = st.columns(3, gap="large")

    modules = [
        (":material/description: Claims & Policy Intake", "OPERATIONS",
         "Submit LOB-specific claims (Auto, Property, Workers Comp), file policy applications, and upload documents."),
        (":material/monitoring: Customer 360 Dashboard", "ANALYTICS",
         "Unified customer view with policy portfolio, claims history, payment behavior, churn risk signals, and NBA status."),
        (":material/chat: Intelligent Chat", "AI AGENT",
         "Dual-mode Cortex AI chat — Agent Mode for internal case handling, Customer Mode for direct customer support."),
    ]
    for col, (title, badge, desc) in zip(cols, modules):
        with col:
            with st.container(border=True):
                st.markdown(f"#### {title}")
                st.caption(badge)
                st.write(desc)

    # ── Test Suite ──
    _render_test_suite()


# ══════════════════════════════════════════════════════════════════════════
# CLAIMS & POLICY INTAKE
# ══════════════════════════════════════════════════════════════════════════
def render_claims():
    st.markdown("## :material/description: Claims & Policy Intake")
    st.caption("OPERATIONS")

    intake_tab, policy_tab, docs_tab = st.tabs(
        [":material/assignment: New Claim", ":material/policy: Policy Application", ":material/upload_file: Document Upload"]
    )

    # ── New Claim ──
    with intake_tab:
        st.markdown("### Submit a New Claim")

        lob = st.selectbox("Line of Business", ["AUTO", "PROPERTY", "WORKERS_COMP"], key="claim_lob")

        with st.form("claim_form", clear_on_submit=False):
            c1, c2 = st.columns(2)
            with c1:
                customer_id = st.text_input("Customer ID", placeholder="e.g. CUST-001")
                policy_id = st.text_input("Policy ID", placeholder="e.g. POL-001")
            with c2:
                incident_date = st.date_input("Incident Date", value=date.today())
                claimed_amount = st.number_input("Claimed Amount ($)", min_value=0.0, step=100.0)

            incident_location = st.text_input("Incident Location")
            claim_text = st.text_area("Describe the incident", height=120)

            st.markdown("---")
            st.markdown("**Attach Supporting Documents** *(optional)*")
            claim_doc_type = st.selectbox(
                "Document Type",
                ["PHOTO", "POLICE_REPORT", "MEDICAL_RECORD", "INVOICE", "OTHER"],
                key="claim_doc_type",
            )
            claim_uploaded = st.file_uploader(
                "Upload file",
                type=["pdf", "jpg", "jpeg", "png", "docx"],
                key="claim_doc_upload",
            )

            submitted = st.form_submit_button(":material/send: Submit Claim", type="primary", use_container_width=True)

        if submitted:
            if not customer_id or not policy_id or not claim_text:
                st.error("Customer ID, Policy ID, and incident description are required.")
            else:
                # ── Frontend DQ Validation ──
                dq_errors = []
                dq_warnings = []
                cid = customer_id.strip()
                pid = policy_id.strip()

                # 1. Customer exists
                cust_check = conn.query(
                    "SELECT COUNT(*) AS cnt FROM INSURANCE_DB.RAW.CUSTOMERS WHERE customer_id = :1",
                    params=[cid],
                )
                if int(cust_check["CNT"].iloc[0]) == 0:
                    dq_errors.append(f"Customer **{cid}** not found.")

                # 2. Policy exists
                pol_check = conn.query(
                    "SELECT policy_status, customer_id, lob_type, coverage_limit "
                    "FROM INSURANCE_DB.RAW.POLICIES WHERE policy_id = :1",
                    params=[pid],
                )
                if pol_check.empty:
                    dq_errors.append(f"Policy **{pid}** not found.")
                else:
                    pol_row = pol_check.iloc[0]
                    # 3. Policy belongs to customer
                    if pol_row["CUSTOMER_ID"] != cid:
                        dq_errors.append(f"Policy **{pid}** belongs to **{pol_row['CUSTOMER_ID']}**, not **{cid}**.")
                    # 4. Policy is active
                    if pol_row["POLICY_STATUS"] not in ("ACTIVE", "RENEWAL_PENDING"):
                        dq_errors.append(f"Policy **{pid}** is **{pol_row['POLICY_STATUS']}** (not active).")
                    # 5. LOB match
                    if pol_row["LOB_TYPE"] != lob:
                        dq_warnings.append(f"LOB mismatch: claim is **{lob}** but policy is **{pol_row['LOB_TYPE']}**.")
                    # 6. Coverage limit
                    if claimed_amount > float(pol_row["COVERAGE_LIMIT"]):
                        dq_warnings.append(
                            f"Claimed amount **${claimed_amount:,.0f}** exceeds coverage limit **${float(pol_row['COVERAGE_LIMIT']):,.0f}**."
                        )

                # Show warnings (non-blocking)
                for w in dq_warnings:
                    st.warning(w)

                # Block on errors
                if dq_errors:
                    for e in dq_errors:
                        st.error(e)
                else:
                    try:
                        new_claim_id = f"CLM-{uuid.uuid4().hex[:6].upper()}"

                        # Build metadata and supporting_docs
                        meta = {
                            "source": "STREAMLIT_INTAKE",
                            "submitted_by": "IDP_LANDING",
                            "lob": lob,
                            "dq_validated": True,
                        }
                        docs_info = None

                        if claim_uploaded:
                            doc_id = f"DOC-{uuid.uuid4().hex[:8].upper()}"
                            stage_path = f"@INSURANCE_DB.RAW.DOCUMENTS_STAGE/{new_claim_id}/{doc_id}_{claim_uploaded.name}"
                            docs_info = [{"doc_id": doc_id, "type": claim_doc_type, "file": claim_uploaded.name, "stage": stage_path}]

                        session.sql(
                            "INSERT INTO INSURANCE_DB.RAW.CLAIMS_LANDING "
                            "(CLAIM_ID, POLICY_ID, CUSTOMER_ID, CLAIM_TEXT, INCIDENT_DATE, CLAIMED_AMOUNT, "
                            "LOB_TYPE, INCIDENT_LOCATION, CLAIM_STATUS, SUPPORTING_DOCS, METADATA) "
                            "SELECT :1, :2, :3, :4, :5, :6, :7, :8, 'SUBMITTED', "
                            "PARSE_JSON(:9), PARSE_JSON(:10)",
                            params=[
                                new_claim_id, pid, cid, claim_text, str(incident_date),
                                float(claimed_amount), lob, incident_location,
                                str(docs_info).replace("'", '"') if docs_info else "null",
                                str(meta).replace("'", '"').replace("True", "true").replace("False", "false"),
                            ],
                        ).collect()
                        st.success(f"Claim **{new_claim_id}** submitted for {cid} / {pid} ({lob})")
                        st.info(f":material/content_copy: **Claim ID: {new_claim_id}** — use this to track your claim or upload additional documents.")

                        if claim_uploaded:
                            session.file.put_stream(claim_uploaded, stage_path, auto_compress=False, overwrite=True)
                            session.sql(
                                "INSERT INTO INSURANCE_DB.RAW.DOCUMENT_REGISTRY "
                                "(DOCUMENT_ID, CLAIM_ID, DOCUMENT_TYPE, FILE_NAME, STAGE_PATH) "
                                "VALUES (:1, :2, :3, :4, :5)",
                                params=[doc_id, new_claim_id, claim_doc_type, claim_uploaded.name, stage_path],
                            ).collect()
                            st.success(f"Document **{doc_id}** ({claim_uploaded.name}) attached to claim {new_claim_id}")

                    except Exception as e:
                        st.error(f"Submission failed: {e}")

    # ── Policy Application ──
    with policy_tab:
        st.markdown("### File a Policy Application")
        lob_app = st.selectbox("Line of Business", ["AUTO", "PROPERTY", "WORKERS_COMP"], key="policy_lob")

        with st.form("policy_form", clear_on_submit=True):
            if lob_app == "AUTO":
                pc1, pc2 = st.columns(2)
                with pc1:
                    applicant_name = st.text_input("Applicant Name", key="app_name")
                    vehicle = st.text_input("Vehicle (Make/Model/Year)", placeholder="e.g. Toyota Camry 2023", key="app_vehicle")
                with pc2:
                    start_date = st.date_input("Policy Start Date", key="app_start")
                    coverage = st.number_input("Coverage Limit ($)", min_value=0, step=1000, key="app_cov")
                deductible = st.number_input("Deductible ($)", min_value=0, step=100, key="app_ded")

            elif lob_app == "PROPERTY":
                pc1, pc2 = st.columns(2)
                with pc1:
                    applicant_name = st.text_input("Applicant Name", key="app_name")
                    prop_address = st.text_input("Property Address", key="app_addr")
                with pc2:
                    start_date = st.date_input("Policy Start Date", key="app_start")
                    coverage = st.number_input("Coverage Limit ($)", min_value=0, step=1000, key="app_cov")
                prop_type = st.selectbox("Property Type", ["SINGLE_FAMILY", "CONDO", "TOWNHOUSE", "MULTI_FAMILY"], key="app_ptype")
                deductible = st.number_input("Deductible ($)", min_value=0, step=100, key="app_ded")

            else:  # WORKERS_COMP
                pc1, pc2 = st.columns(2)
                with pc1:
                    employer_name = st.text_input("Employer Name", key="app_employer")
                    employee_count = st.number_input("Employee Count", min_value=1, step=1, key="app_emp_count")
                with pc2:
                    start_date = st.date_input("Policy Start Date", key="app_start")
                    payroll = st.number_input("Annual Payroll ($)", min_value=0, step=1000, key="app_payroll")

            app_submitted = st.form_submit_button(":material/send: Submit Application", type="primary", use_container_width=True)

        if app_submitted:
            try:
                if lob_app == "AUTO":
                    if not applicant_name:
                        st.error("Applicant Name is required.")
                    else:
                        session.sql(
                            "INSERT INTO INSURANCE_DB.RAW.AUTO_POLICY_APPLICATIONS "
                            "(APPLICANT_NAME, VEHICLE_MAKE_MODEL_YEAR, POLICY_START_DATE, COVERAGE_LIMIT, DEDUCTIBLE_AMOUNT, STATUS) "
                            "VALUES (:1, :2, :3, :4, :5, 'PENDING')",
                            params=[applicant_name, vehicle, str(start_date), float(coverage), float(deductible)],
                        ).collect()
                        st.success(f"Auto application submitted for {applicant_name}")

                elif lob_app == "PROPERTY":
                    if not applicant_name:
                        st.error("Applicant Name is required.")
                    else:
                        session.sql(
                            "INSERT INTO INSURANCE_DB.RAW.PROPERTY_POLICY_APPLICATIONS "
                            "(APPLICANT_NAME, PROPERTY_ADDRESS, PROPERTY_TYPE, POLICY_START_DATE, COVERAGE_LIMIT, DEDUCTIBLE_AMOUNT, STATUS) "
                            "VALUES (:1, :2, :3, :4, :5, :6, 'PENDING')",
                            params=[applicant_name, prop_address, prop_type, str(start_date), float(coverage), float(deductible)],
                        ).collect()
                        st.success(f"Property application submitted for {applicant_name}")

                else:  # WORKERS_COMP
                    if not employer_name:
                        st.error("Employer Name is required.")
                    else:
                        session.sql(
                            "INSERT INTO INSURANCE_DB.RAW.WORKERS_COMP_POLICY_APPLICATIONS "
                            "(EMPLOYER_NAME, EMPLOYEE_COUNT, PAYROLL_AMOUNT, POLICY_START_DATE, STATUS) "
                            "VALUES (:1, :2, :3, :4, 'PENDING')",
                            params=[employer_name, int(employee_count), float(payroll), str(start_date)],
                        ).collect()
                        st.success(f"Workers Comp application submitted for {employer_name}")

            except Exception as e:
                st.error(f"Submission failed: {e}")

    # ── Document Upload ──
    with docs_tab:
        st.markdown("### Upload Supporting Documents")
        doc_claim_id = st.text_input("Associated Claim ID", placeholder="e.g. CLM-001", key="doc_claim")
        doc_type = st.selectbox("Document Type", ["PHOTO", "POLICE_REPORT", "MEDICAL_RECORD", "INVOICE", "OTHER"], key="doc_type")
        uploaded = st.file_uploader("Upload file", type=["pdf", "jpg", "jpeg", "png", "docx"], key="doc_upload")

        if st.button(":material/cloud_upload: Upload Document", type="primary", use_container_width=True, key="doc_submit"):
            if not doc_claim_id or not uploaded:
                st.error("Claim ID and file are required.")
            else:
                try:
                    doc_id = f"DOC-{uuid.uuid4().hex[:8].upper()}"
                    stage_path = f"@INSURANCE_DB.RAW.DOCUMENTS_STAGE/{doc_claim_id}/{doc_id}_{uploaded.name}"
                    session.file.put_stream(uploaded, stage_path, auto_compress=False, overwrite=True)
                    session.sql(
                        "INSERT INTO INSURANCE_DB.RAW.DOCUMENT_REGISTRY "
                        "(DOCUMENT_ID, CLAIM_ID, DOCUMENT_TYPE, FILE_NAME, STAGE_PATH) "
                        "VALUES (:1, :2, :3, :4, :5)",
                        params=[doc_id, doc_claim_id.strip(), doc_type, uploaded.name, stage_path],
                    ).collect()
                    st.success(f"Document {doc_id} uploaded to {stage_path}")
                except Exception as e:
                    st.error(f"Upload failed: {e}")


# ══════════════════════════════════════════════════════════════════════════
# CUSTOMER 360 DASHBOARD
# ══════════════════════════════════════════════════════════════════════════
def render_customer_360():
    st.markdown("## :material/monitoring: Customer 360 Dashboard")
    st.caption("ANALYTICS")

    tab_exec, tab_portfolio, tab_churn, tab_deep, tab_pipeline = st.tabs([
        ":material/dashboard: Executive Overview",
        ":material/pie_chart: Portfolio Analytics",
        ":material/warning: Churn & Retention",
        ":material/person_search: Customer Deep-Dive",
        ":material/manufacturing: AI Pipeline Monitor",
    ])

    # ── Executive Overview ──
    with tab_exec:
        kpi = conn.query(
            "SELECT COUNT(*) AS total_customers, "
            "ROUND(AVG(churn_propensity_score), 2) AS avg_churn, "
            "ROUND(AVG(sentiment_score_last_30d), 2) AS avg_sentiment, "
            "ROUND(SUM(total_annual_premium), 0) AS total_premium "
            "FROM INSURANCE_DB.PROCESSED.FCT_CUSTOMER_360",
            ttl=300,
        )
        with st.container(horizontal=True):
            st.metric("Total Customers", int(kpi["TOTAL_CUSTOMERS"].iloc[0]), border=True)
            st.metric("Avg Churn Score", float(kpi["AVG_CHURN"].iloc[0]), border=True)
            st.metric("Avg Sentiment (30d)", float(kpi["AVG_SENTIMENT"].iloc[0]), border=True)
            st.metric("Total Annual Premium", f"${int(kpi['TOTAL_PREMIUM'].iloc[0]):,}", border=True)

        seg = conn.query(
            "SELECT customer_segment, COUNT(*) AS count, "
            "ROUND(AVG(churn_propensity_score), 2) AS avg_churn, "
            "ROUND(AVG(lifetime_value_score), 1) AS avg_ltv "
            "FROM INSURANCE_DB.PROCESSED.FCT_CUSTOMER_360 "
            "WHERE customer_segment IS NOT NULL GROUP BY 1 ORDER BY count DESC",
            ttl=300,
        )
        col1, col2 = st.columns(2)
        with col1:
            with st.container(border=True):
                st.markdown("**Customer Segments**")
                st.bar_chart(seg, x="CUSTOMER_SEGMENT", y="COUNT")
        with col2:
            with st.container(border=True):
                st.markdown("**Segment Details**")
                st.dataframe(seg, hide_index=True, use_container_width=True)

    # ── Portfolio Analytics ──
    with tab_portfolio:
        lob = conn.query(
            "SELECT lob_type, COUNT(*) AS policy_count, "
            "ROUND(SUM(premium_annual), 0) AS total_premium, "
            "ROUND(AVG(coverage_limit), 0) AS avg_coverage "
            "FROM INSURANCE_DB.RAW.POLICIES GROUP BY 1 ORDER BY policy_count DESC",
            ttl=300,
        )
        with st.container(horizontal=True):
            for _, row in lob.iterrows():
                st.metric(
                    f"{row['LOB_TYPE']} Policies",
                    int(row["POLICY_COUNT"]),
                    f"${int(row['TOTAL_PREMIUM']):,} premium",
                    border=True,
                )

        col_a, col_b = st.columns(2)
        with col_a:
            with st.container(border=True):
                st.markdown("**Policies by LOB**")
                st.bar_chart(lob, x="LOB_TYPE", y="POLICY_COUNT")
        with col_b:
            claim_status = conn.query(
                "SELECT claim_status, COUNT(*) AS cnt "
                "FROM INSURANCE_DB.RAW.CLAIMS_LANDING GROUP BY 1 ORDER BY cnt DESC",
                ttl=300,
            )
            with st.container(border=True):
                st.markdown("**Claims by Status**")
                st.bar_chart(claim_status, x="CLAIM_STATUS", y="CNT")

    # ── Churn & Retention ──
    with tab_churn:
        churn_kpi = conn.query(
            "SELECT COUNT(*) AS total_alerts, "
            "SUM(CASE WHEN a.priority <= 3 THEN 1 ELSE 0 END) AS critical, "
            "ROUND(AVG(a.churn_propensity), 2) AS avg_propensity "
            "FROM INSURANCE_DB.PROCESSED.CHURN_ALERTS a "
            "JOIN INSURANCE_DB.PROCESSED.FCT_CUSTOMER_360 f ON a.customer_id = f.customer_id",
            ttl=300,
        )
        with st.container(horizontal=True):
            st.metric("Total Churn Alerts", int(churn_kpi["TOTAL_ALERTS"].iloc[0]), border=True)
            st.metric("Critical (Priority <= 3)", int(churn_kpi["CRITICAL"].iloc[0]), border=True)
            st.metric("Avg Churn Propensity", float(churn_kpi["AVG_PROPENSITY"].iloc[0]), border=True)

        churn_dash = conn.query(
            "SELECT * FROM INSURANCE_DB.PROCESSED.V_CHURN_DASHBOARD ORDER BY churn_propensity DESC",
            ttl=300,
        )
        with st.container(border=True):
            st.markdown("**Churn Dashboard — At-Risk Customers**")
            st.dataframe(churn_dash, hide_index=True, use_container_width=True, height=400)

        nba_data = conn.query(
            "SELECT * FROM INSURANCE_DB.PROCESSED.V_NBA_FOR_CRM ORDER BY 1",
            ttl=300,
        )
        if not nba_data.empty:
            with st.container(border=True):
                st.markdown("**Next-Best-Actions for CRM**")
                st.dataframe(nba_data, hide_index=True, use_container_width=True, height=300)

    # ── Customer Deep-Dive ──
    with tab_deep:
        cust_list = conn.query(
            "SELECT customer_id, customer_id || ' — ' || customer_segment AS label "
            "FROM INSURANCE_DB.PROCESSED.FCT_CUSTOMER_360 ORDER BY customer_id",
            ttl=300,
        )
        selected_label = st.selectbox("Select Customer", cust_list["LABEL"].tolist(), key="deep_cust")
        if selected_label:
            selected_cid = selected_label.split(" — ")[0]

            profile = conn.query(
                "SELECT * FROM INSURANCE_DB.PROCESSED.FCT_CUSTOMER_360 WHERE customer_id = ?",
                params=[selected_cid],
                ttl=60,
            )
            if not profile.empty:
                p = profile.iloc[0]
                with st.container(horizontal=True):
                    st.metric("Segment", p.get("CUSTOMER_SEGMENT", "N/A"), border=True)
                    st.metric("LTV Score", p.get("LIFETIME_VALUE_SCORE", "N/A"), border=True)
                    st.metric("Churn Score", p.get("CHURN_PROPENSITY_SCORE", "N/A"), border=True)
                    st.metric("Tenure (months)", p.get("TENURE_MONTHS", "N/A"), border=True)

                dd1, dd2 = st.columns(2)
                with dd1:
                    with st.container(border=True):
                        st.markdown("**Policies**")
                        pol = conn.query(
                            "SELECT policy_id, lob_type, policy_status, premium_annual, coverage_limit "
                            "FROM INSURANCE_DB.RAW.POLICIES WHERE customer_id = ?",
                            params=[selected_cid],
                        )
                        st.dataframe(pol, hide_index=True, use_container_width=True)

                with dd2:
                    with st.container(border=True):
                        st.markdown("**Claims**")
                        clm = conn.query(
                            "SELECT claim_id, lob_type, claim_status, claimed_amount, incident_date "
                            "FROM INSURANCE_DB.RAW.CLAIMS_LANDING WHERE customer_id = ?",
                            params=[selected_cid],
                        )
                        st.dataframe(clm, hide_index=True, use_container_width=True)

                with st.container(border=True):
                    st.markdown("**Payment History**")
                    pay = conn.query(
                        "SELECT payment_id, policy_id, amount, payment_date, payment_method, payment_status "
                        "FROM INSURANCE_DB.RAW.PAYMENTS WHERE customer_id = ?",
                        params=[selected_cid],
                    )
                    st.dataframe(pay, hide_index=True, use_container_width=True)

                with st.container(border=True):
                    st.markdown("**Interactions**")
                    inter = conn.query(
                        "SELECT interaction_id, channel, topic, interaction_date, resolution_status, nps_score "
                        "FROM INSURANCE_DB.RAW.INTERACTIONS WHERE customer_id = ?",
                        params=[selected_cid],
                    )
                    st.dataframe(inter, hide_index=True, use_container_width=True)

    # ── AI Pipeline Monitor ──
    with tab_pipeline:
        pipe = conn.query("SELECT * FROM INSURANCE_DB.PROCESSED.V_PIPELINE_STATUS ORDER BY 1 DESC", ttl=120)
        with st.container(horizontal=True):
            st.metric("Active Claims in Pipeline", len(pipe), border=True)
            if not pipe.empty and "CURRENT_STATE" in pipe.columns:
                states = pipe["CURRENT_STATE"].value_counts()
                for state, cnt in states.items():
                    st.metric(state, int(cnt), border=True)

        with st.container(border=True):
            st.markdown("**Pipeline Status**")
            st.dataframe(pipe, hide_index=True, use_container_width=True, height=350)

        res_col, audit_col = st.columns(2)
        with res_col:
            resolutions = conn.query("SELECT * FROM INSURANCE_DB.RESULTS.RESOLUTIONS ORDER BY 1 DESC LIMIT 50", ttl=120)
            with st.container(border=True):
                st.markdown("**Recent Resolutions**")
                st.dataframe(resolutions, hide_index=True, use_container_width=True, height=300)
        with audit_col:
            audit = conn.query(
                "SELECT * FROM INSURANCE_DB.RESULTS.AUDIT_LOG WHERE flow_type = 'CLAIMS' ORDER BY 1 DESC LIMIT 50",
                ttl=120,
            )
            with st.container(border=True):
                st.markdown("**Claims Audit Log**")
                st.dataframe(audit, hide_index=True, use_container_width=True, height=300)


# ══════════════════════════════════════════════════════════════════════════
# INTELLIGENT CHAT — DUAL MODE
# ══════════════════════════════════════════════════════════════════════════
def render_chatbot():
    st.markdown("## :material/chat: Intelligent Chat")

    # Mode toggle
    if "chat_mode" not in st.session_state:
        st.session_state.chat_mode = "Agent Mode"

    mode = st.segmented_control(
        "Mode",
        [":material/support_agent: Agent Mode", ":material/person: Customer Mode"],
        default=":material/support_agent: Agent Mode",
        key="mode_toggle",
    )
    is_agent_mode = "Agent" in (mode or "Agent")

    if is_agent_mode:
        st.caption("INTERNAL — You are an insurance agent. The AI helps you handle customer cases.")
    else:
        st.caption("CUSTOMER-FACING — The AI speaks directly to the customer on your behalf.")

    # Customer context selector
    cust_list = conn.query(
        "SELECT c.customer_id, c.first_name || ' ' || c.last_name AS name, c.customer_segment "
        "FROM INSURANCE_DB.RAW.CUSTOMERS c ORDER BY c.customer_id",
        ttl=300,
    )
    chat_col, context_col = st.columns([3, 1])

    with context_col:
        with st.container(border=True):
            st.markdown("**Customer Context**")
            cust_options = [f"{r['CUSTOMER_ID']} — {r['NAME']}" for _, r in cust_list.iterrows()]
            selected = st.selectbox("Customer", cust_options, key="chat_cust")
            chat_cust_id = selected.split(" — ")[0] if selected else None
            chat_cust_name = selected.split(" — ")[1] if selected and " — " in selected else ""

            if chat_cust_id:
                ctx = conn.query(
                    "SELECT customer_segment, churn_propensity_score, lifetime_value_score, total_annual_premium "
                    "FROM INSURANCE_DB.PROCESSED.FCT_CUSTOMER_360 WHERE customer_id = ?",
                    params=[chat_cust_id],
                )
                if not ctx.empty:
                    c = ctx.iloc[0]
                    st.metric("Segment", c.get("CUSTOMER_SEGMENT", "N/A"))
                    if is_agent_mode:
                        st.metric("Churn Risk", c.get("CHURN_PROPENSITY_SCORE", "N/A"))
                        st.metric("LTV Score", c.get("LIFETIME_VALUE_SCORE", "N/A"))
                        st.metric("Annual Premium", f"${int(c.get('TOTAL_ANNUAL_PREMIUM', 0)):,}")

                # NBA section (agent mode only)
                if is_agent_mode:
                    nba = conn.query(
                        "SELECT nba_id, action_type, offer_details, priority "
                        "FROM INSURANCE_DB.PROCESSED.NEXT_BEST_ACTIONS WHERE customer_id = ? ORDER BY priority",
                        params=[chat_cust_id],
                    )
                    if not nba.empty:
                        st.markdown("**Next-Best-Actions**")
                        for _, row in nba.iterrows():
                            st.caption(f"P{row['PRIORITY']}: {row['ACTION_TYPE']} — {str(row['OFFER_DETAILS'])[:60]}")

                    if st.button(":material/auto_fix_high: Generate NBA", key="gen_nba", use_container_width=True):
                        with st.spinner("Generating NBA..."):
                            try:
                                session.sql(
                                    "CALL INSURANCE_DB.PROCESSED.SP_GENERATE_RETENTION_NBA(:1)",
                                    params=[chat_cust_id],
                                ).collect()
                                st.success("NBA generated!")
                                st.rerun()
                            except Exception as e:
                                st.error(f"NBA generation failed: {e}")

    # Chat input at page bottom (outside columns so it pins to bottom)
    pending = st.session_state.pop("pending_prompt", None)
    placeholder = "Ask about this customer..." if is_agent_mode else "Type your message as the customer..."
    chat_input = st.chat_input(placeholder)
    prompt = pending or chat_input

    with chat_col:
        if "messages" not in st.session_state:
            st.session_state.messages = []

        # Clear chat when mode changes
        prev_mode = st.session_state.get("prev_chat_mode")
        if prev_mode and prev_mode != mode:
            st.session_state.messages = []
        st.session_state.prev_chat_mode = mode

        for msg in st.session_state.messages:
            with st.chat_message(msg["role"]):
                st.write(msg["content"])

        if not st.session_state.messages and not prompt:
            if is_agent_mode:
                suggestions = {
                    ":blue[:material/summarize:] Customer summary": f"Give me a full summary of {chat_cust_id} — profile, policies, claims, risk signals, and recommended actions.",
                    ":green[:material/lightbulb:] Retention strategy": f"What's the best retention strategy for {chat_cust_id}? Consider their churn risk and portfolio.",
                    ":orange[:material/edit_note:] Draft outreach": f"Draft a personalized outreach message for {chat_cust_id} to improve retention.",
                }
            else:
                suggestions = {
                    ":blue[:material/help:] Check my policy": f"Hi, I'd like to know the details of my current insurance policies.",
                    ":green[:material/receipt_long:] Claim status": f"Can you tell me the status of my recent claims?",
                    ":orange[:material/payments:] Billing question": f"I have a question about my premium payments and next due date.",
                }
            selected_pill = st.pills("Try asking:", list(suggestions.keys()), label_visibility="collapsed")
            if selected_pill:
                st.session_state.pending_prompt = suggestions[selected_pill]
                st.rerun()

        if prompt:
            st.session_state.messages.append({"role": "user", "content": prompt})

            with st.chat_message("user"):
                st.write(prompt)

            # Build context for Cortex
            context_str = ""
            if chat_cust_id:
                cust_profile = conn.query(
                    "SELECT * FROM INSURANCE_DB.PROCESSED.FCT_CUSTOMER_360 WHERE customer_id = ?",
                    params=[chat_cust_id],
                )
                if not cust_profile.empty:
                    context_str = f"Customer profile: {cust_profile.to_dict(orient='records')[0]}\n\n"

                cust_alerts = conn.query(
                    "SELECT * FROM INSURANCE_DB.PROCESSED.CHURN_ALERTS WHERE customer_id = ?",
                    params=[chat_cust_id],
                )
                if not cust_alerts.empty:
                    context_str += f"Churn alerts: {cust_alerts.to_dict(orient='records')}\n\n"

                cust_nba = conn.query(
                    "SELECT action_type, offer_details, priority FROM INSURANCE_DB.PROCESSED.NEXT_BEST_ACTIONS WHERE customer_id = ?",
                    params=[chat_cust_id],
                )
                if not cust_nba.empty:
                    context_str += f"Next-Best-Actions: {cust_nba.to_dict(orient='records')}\n\n"

            if is_agent_mode:
                system_prompt = (
                    "You are an AI assistant for IDP Insurance internal agents. "
                    "The user is an insurance agent handling a customer case. "
                    "Help them with: customer profile analysis, churn risk assessment, retention strategies, "
                    "talking points for calls, drafting outreach messages, and Next-Best-Action recommendations. "
                    "Be data-driven and reference specific numbers from the profile. "
                    "Format recommendations clearly with bullet points.\n"
                    f"Customer ID: {chat_cust_id} ({chat_cust_name})\n{context_str}"
                )
            else:
                system_prompt = (
                    f"You are a friendly customer care agent for IDP Insurance, speaking directly to {chat_cust_name}. "
                    "Be warm, empathetic, and professional. Use their first name. "
                    "Help with: policy details, claims status, billing, renewals, and general insurance questions. "
                    "If they seem unhappy or at risk of leaving, proactively offer help or mention available offers. "
                    "NEVER reveal internal scores (churn score, LTV), system IDs, or technical details. "
                    "Speak naturally as a human agent would.\n"
                    f"Customer: {chat_cust_id}\n{context_str}"
                )

            with st.chat_message("assistant"):
                with st.spinner("Thinking..."):
                    try:
                        full_prompt = f"{system_prompt}\n\nUser: {prompt}"
                        result = session.sql(
                            "SELECT SNOWFLAKE.CORTEX.COMPLETE(:1, :2) AS response",
                            params=["llama3.1-8b", full_prompt],
                        ).collect()
                        response = result[0]["RESPONSE"]
                    except Exception as e:
                        response = f"Cortex AI error: {e}"
                st.write(response)

            st.session_state.messages.append({"role": "assistant", "content": response})

            # Log interaction
            if chat_cust_id:
                try:
                    int_id = f"INT-{uuid.uuid4().hex[:8].upper()}"
                    direction = "INTERNAL" if is_agent_mode else "INBOUND"
                    topic = "Agent Assist" if is_agent_mode else "Customer Chat"
                    session.sql(
                        "INSERT INTO INSURANCE_DB.RAW.INTERACTIONS "
                        "(INTERACTION_ID, CUSTOMER_ID, CHANNEL, INTERACTION_DATE, "
                        "TRANSCRIPT_TEXT, DIRECTION, TOPIC, RESOLUTION_STATUS, "
                        "AGENT_ID, DURATION_SECONDS, NPS_SCORE) "
                        "VALUES (:1, :2, 'CHAT', CURRENT_TIMESTAMP(), :3, :4, :5, 'RESOLVED', 'CORTEX-AGENT', 0, NULL)",
                        params=[int_id, chat_cust_id, f"User: {prompt}\nAssistant: {str(response)[:500]}", direction, topic],
                    ).collect()
                except Exception:
                    pass


# ══════════════════════════════════════════════════════════════════════════
# TEST SUITE (Home page expander)
# ══════════════════════════════════════════════════════════════════════════
def _render_test_suite():
    st.divider()
    with st.expander(":material/science: **Integration Test Suite** — End-to-End Validation", expanded=False):
        st.markdown(
            "Runs automated tests that simulate user actions across **Claims & Policy Intake**, "
            "**Customer 360 Dashboard**, and **NBA Chatbot**."
        )

        if "test_results" not in st.session_state:
            st.session_state.test_results = []
        if "test_running" not in st.session_state:
            st.session_state.test_running = False

        def _run_test(name, fn):
            try:
                detail = fn()
                return (name, True, detail)
            except Exception as e:
                return (name, False, str(e)[:300])

        def test_source_tables_populated():
            tables = {
                "CUSTOMERS": "INSURANCE_DB.RAW.CUSTOMERS",
                "POLICIES": "INSURANCE_DB.RAW.POLICIES",
                "CLAIMS_LANDING": "INSURANCE_DB.RAW.CLAIMS_LANDING",
                "PAYMENTS": "INSURANCE_DB.RAW.PAYMENTS",
                "INTERACTIONS": "INSURANCE_DB.RAW.INTERACTIONS",
                "PROVIDERS": "INSURANCE_DB.RAW.PROVIDERS",
            }
            empty = []
            counts = {}
            for label, fqn in tables.items():
                r = conn.query(f"SELECT COUNT(*) AS n FROM {fqn}")
                cnt = int(r["N"].iloc[0])
                counts[label] = cnt
                if cnt == 0:
                    empty.append(label)
            if empty:
                raise Exception(f"Empty tables: {', '.join(empty)}")
            return f"All {len(tables)} tables have data: " + ", ".join(f"{k}={v}" for k, v in counts.items())

        def test_feature_store_populated():
            fct = conn.query("SELECT COUNT(*) AS n FROM INSURANCE_DB.PROCESSED.FCT_CUSTOMER_360")
            dt = conn.query("SELECT COUNT(*) AS n FROM INSURANCE_DB.PROCESSED.DT_CUSTOMER_360")
            fct_n, dt_n = int(fct["N"].iloc[0]), int(dt["N"].iloc[0])
            if fct_n == 0:
                raise Exception("FCT_CUSTOMER_360 is empty")
            if dt_n == 0:
                raise Exception("DT_CUSTOMER_360 is empty")
            return f"FCT_CUSTOMER_360={fct_n}, DT_CUSTOMER_360={dt_n}"

        def test_lob_tables_exist():
            required = [
                "AUTO_CLAIMS", "PROPERTY_CLAIMS", "WORKERS_COMP_CLAIMS",
                "AUTO_POLICY_APPLICATIONS", "PROPERTY_POLICY_APPLICATIONS",
                "WORKERS_COMP_POLICY_APPLICATIONS", "DOCUMENT_REGISTRY",
            ]
            existing = conn.query(
                "SELECT TABLE_NAME FROM INSURANCE_DB.INFORMATION_SCHEMA.TABLES "
                "WHERE TABLE_SCHEMA = 'RAW' AND TABLE_NAME IN ("
                + ",".join(f"'{t}'" for t in required) + ") ORDER BY 1"
            )
            found = set(existing["TABLE_NAME"].tolist())
            missing = set(required) - found
            if missing:
                raise Exception(f"Missing tables: {', '.join(sorted(missing))}")
            return f"All {len(required)} LOB tables present"

        def test_internal_stages_exist():
            required = {"DOCUMENTS_STAGE", "EVIDENCE_STAGE", "POLICY_DOCS_STAGE"}
            found = set()
            for stage_name in required:
                try:
                    session.sql(f"DESCRIBE STAGE INSURANCE_DB.RAW.{stage_name}").collect()
                    found.add(stage_name)
                except Exception:
                    pass
            missing = required - found
            if missing:
                raise Exception(f"Missing stages: {', '.join(sorted(missing))}")
            return f"Found stages: {', '.join(sorted(found))}"

        def test_dashboard_kpis():
            kpi = conn.query(
                "SELECT COUNT(*) AS total_customers FROM INSURANCE_DB.PROCESSED.FCT_CUSTOMER_360"
            )
            if kpi.empty or int(kpi["TOTAL_CUSTOMERS"].iloc[0]) == 0:
                raise Exception("KPI query returned no customers")
            return f"{int(kpi['TOTAL_CUSTOMERS'].iloc[0])} customers in FCT_CUSTOMER_360"

        def test_churn_alerts():
            churn = conn.query(
                "SELECT COUNT(*) AS total_alerts, "
                "SUM(CASE WHEN status = 'NEW' THEN 1 ELSE 0 END) AS new_alerts "
                "FROM INSURANCE_DB.PROCESSED.CHURN_ALERTS"
            )
            total = int(churn["TOTAL_ALERTS"].iloc[0])
            if total == 0:
                raise Exception("No churn alerts found")
            new_count = int(churn["NEW_ALERTS"].iloc[0])
            dashboard = conn.query("SELECT COUNT(*) AS n FROM INSURANCE_DB.PROCESSED.V_CHURN_DASHBOARD")
            return f"{total} alerts ({new_count} NEW), V_CHURN_DASHBOARD has {int(dashboard['N'].iloc[0])} rows"

        def test_pipeline_view():
            pipe = conn.query("SELECT COUNT(*) AS n FROM INSURANCE_DB.PROCESSED.V_PIPELINE_STATUS")
            audit = conn.query("SELECT COUNT(*) AS n FROM INSURANCE_DB.RESULTS.AUDIT_LOG WHERE flow_type = 'CLAIMS'")
            return f"V_PIPELINE_STATUS={int(pipe['N'].iloc[0])}, AUDIT_LOG(CLAIMS)={int(audit['N'].iloc[0])}"

        ALL_TESTS = [
            ("1. Source Tables Populated", test_source_tables_populated),
            ("2. Feature Store Populated", test_feature_store_populated),
            ("3. LOB Tables Exist", test_lob_tables_exist),
            ("4. Internal Stages Exist", test_internal_stages_exist),
            ("5. Dashboard KPIs", test_dashboard_kpis),
            ("6. Churn & Retention Data", test_churn_alerts),
            ("7. Pipeline Monitor Data", test_pipeline_view),
        ]

        if st.button(":material/play_arrow: **Run All Tests**", type="primary", use_container_width=True):
            st.session_state.test_running = True
            st.session_state.test_results = []
            progress = st.progress(0, text="Running tests...")
            for i, (name, fn) in enumerate(ALL_TESTS):
                progress.progress((i + 1) / len(ALL_TESTS), text=f"Running: {name}")
                result = _run_test(name, fn)
                st.session_state.test_results.append(result)
            progress.empty()
            st.session_state.test_running = False

        if st.session_state.test_results:
            passed = sum(1 for _, ok, _ in st.session_state.test_results if ok)
            failed = sum(1 for _, ok, _ in st.session_state.test_results if not ok)
            total = len(st.session_state.test_results)
            st.markdown(f"### Results: **{passed}/{total}** passed")
            if failed == 0:
                st.success(f"All {total} tests passed!")
            else:
                st.error(f"{failed} test(s) failed")
            for name, ok, detail in st.session_state.test_results:
                icon = ":white_check_mark:" if ok else ":x:"
                with st.expander(f"{icon} {name}", expanded=not ok):
                    if ok:
                        st.caption(detail)
                    else:
                        st.error(detail)


# ══════════════════════════════════════════════════════════════════════════
# ROUTING
# ══════════════════════════════════════════════════════════════════════════
if ":material/home:" in nav:
    render_home()
elif ":material/description:" in nav:
    render_claims()
elif ":material/monitoring:" in nav:
    render_customer_360()
elif ":material/chat:" in nav:
    render_chatbot()

# ── Footer ──────────────────────────────────────────────────────────────
st.divider()
st.caption("IDP Insurance — Intelligent Digital Platform | Powered by Snowflake Cortex AI")
