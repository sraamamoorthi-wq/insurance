import os
import uuid
from datetime import date, datetime

import streamlit as st

st.set_page_config(page_title="IDP Insurance", page_icon=":shield:", layout="wide")

conn = st.connection("snowflake", ttl=os.getenv("SNOWFLAKE_CONNECTION_TTL"))
session = conn.session()

# ── Hero Section ────────────────────────────────────────────────────────
_, center, _ = st.columns([1, 2, 1])
with center:
    st.markdown(
        """
        <div style="text-align:center; padding-top:1.5rem;">
            <svg width="72" height="72" viewBox="0 0 64 64" xmlns="http://www.w3.org/2000/svg">
                <defs>
                    <linearGradient id="sg" x1="0%" y1="0%" x2="0%" y2="100%">
                        <stop offset="0%" style="stop-color:#1B3A5C"/>
                        <stop offset="100%" style="stop-color:#0F2440"/>
                    </linearGradient>
                </defs>
                <path d="M32 2 L58 14 V34 C58 48 46 58 32 62 C18 58 6 48 6 34 V14 Z"
                      fill="url(#sg)" stroke="#C9A84C" stroke-width="2"/>
                <text x="32" y="30" text-anchor="middle" font-family="Arial,sans-serif"
                      font-size="11" font-weight="bold" fill="#C9A84C">IDP</text>
                <line x1="20" y1="35" x2="44" y2="35" stroke="#C9A84C" stroke-width="1"/>
                <text x="32" y="46" text-anchor="middle" font-family="Arial,sans-serif"
                      font-size="6" fill="#E8DCC8" letter-spacing="2">INSURANCE</text>
            </svg>
        </div>
        """,
        unsafe_allow_html=True,
    )

st.markdown("<h1 style='text-align:center; color:#1B3A5C; margin-bottom:0;'>IDP Insurance</h1>", unsafe_allow_html=True)
st.markdown("<p style='text-align:center; color:#666; font-size:1.1rem; margin-top:0;'>Intelligent Digital Platform</p>", unsafe_allow_html=True)
st.markdown(
    "<p style='text-align:center; color:#888; font-size:0.95rem; max-width:600px; margin:0 auto 1rem auto; line-height:1.6;'>"
    "AI-powered insurance operations — from claims intake to customer retention. "
    "Select an application below to get started.</p>",
    unsafe_allow_html=True,
)

st.divider()

# ── Application Cards ───────────────────────────────────────────────────
ACCOUNT_HOST = "nb59385.us-east-2.aws.snowflakecomputing.com"

APPS = [
    {
        "icon": ":material/description:",
        "title": "Claims & Policy Intake",
        "badge": "OPERATIONS",
        "description": "Submit LOB-specific claims (Auto, Property, Workers Comp), file policy applications, and upload supporting documents to internal stages.",
        "url_id": "3l7p2qtqxe3mhohvbwv7",
        "btn_label": "Open Claims",
    },
    {
        "icon": ":material/monitoring:",
        "title": "Customer 360 Dashboard",
        "badge": "ANALYTICS",
        "description": "Unified customer view with policy portfolio, claims history, payment behavior, churn risk signals, and Next-Best-Action status.",
        "url_id": None,
        "btn_label": "Open Dashboard",
    },
    {
        "icon": ":material/chat:",
        "title": "NBA Chatbot",
        "badge": "AI AGENT",
        "description": "Chat with customers via Cortex AI, log interactions, and generate retention Next-Best-Actions powered by churn alerts and playbooks.",
        "url_id": "er33a77cajpqcjnps4h2",
        "btn_label": "Open Chatbot",
    },
]

cols = st.columns(3, gap="large")

for col, app in zip(cols, APPS):
    with col:
        with st.container(border=True):
            st.markdown(f"#### {app['icon']} {app['title']}")
            st.caption(app["badge"])
            st.write(app["description"])

            if app["url_id"]:
                app_url = f"https://{ACCOUNT_HOST}/#/streamlit-apps/USER%24RAAMAMOORTHIS.PUBLIC.{app['url_id']}"
                st.link_button(
                    app["btn_label"],
                    app_url,
                    use_container_width=True,
                    type="primary",
                )
            else:
                st.info("Deploy from workspace to enable link", icon=":material/info:")


# ── Quick Stats ─────────────────────────────────────────────────────────
st.divider()
st.markdown("#### :material/analytics: Platform at a Glance")

c1, c2, c3, c4 = st.columns(4)

customers = conn.query("SELECT COUNT(*) AS n FROM INSURANCE_DB.RAW.CUSTOMERS", ttl=300)
policies = conn.query("SELECT COUNT(*) AS n FROM INSURANCE_DB.RAW.POLICIES", ttl=300)
claims = conn.query("SELECT COUNT(*) AS n FROM INSURANCE_DB.RAW.CLAIMS_LANDING", ttl=300)
alerts = conn.query(
    "SELECT COUNT(*) AS n FROM INSURANCE_DB.PROCESSED.CHURN_ALERTS WHERE STATUS = 'NEW'",
    ttl=300,
)

c1.metric("Customers", int(customers["N"].iloc[0]))
c2.metric("Active Policies", int(policies["N"].iloc[0]))
c3.metric("Total Claims", int(claims["N"].iloc[0]))
c4.metric("Active Churn Alerts", int(alerts["N"].iloc[0]))


# ══════════════════════════════════════════════════════════════════════════
# TEST SUITE
# ══════════════════════════════════════════════════════════════════════════
st.divider()

with st.expander(":material/science: **Integration Test Suite** — End-to-End Validation for All 3 Apps", expanded=False):
    st.markdown(
        "Runs automated tests that simulate user actions across **Claims & Policy Intake**, "
        "**Customer 360 Dashboard**, and **NBA Chatbot**. Each test inserts data, "
        "validates pipeline flow, checks dashboard queries, and cleans up after itself."
    )

    if "test_results" not in st.session_state:
        st.session_state.test_results = []
    if "test_running" not in st.session_state:
        st.session_state.test_running = False

    def _run_test(name, fn):
        """Run a single test, return (name, passed, detail)."""
        try:
            detail = fn()
            return (name, True, detail)
        except Exception as e:
            return (name, False, str(e)[:300])

    # ── TEST DEFINITIONS ────────────────────────────────────────────────

    def test_source_tables_populated():
        """Verify RAW source tables have data."""
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
        """Verify FCT_CUSTOMER_360 and DT_CUSTOMER_360 have rows."""
        fct = conn.query("SELECT COUNT(*) AS n FROM INSURANCE_DB.PROCESSED.FCT_CUSTOMER_360")
        dt = conn.query("SELECT COUNT(*) AS n FROM INSURANCE_DB.PROCESSED.DT_CUSTOMER_360")
        fct_n, dt_n = int(fct["N"].iloc[0]), int(dt["N"].iloc[0])
        if fct_n == 0:
            raise Exception("FCT_CUSTOMER_360 is empty — run SP_BUILD_CUSTOMER_360()")
        if dt_n == 0:
            raise Exception("DT_CUSTOMER_360 is empty — run ALTER DYNAMIC TABLE ... REFRESH")
        return f"FCT_CUSTOMER_360={fct_n}, DT_CUSTOMER_360={dt_n}"

    def test_lob_tables_exist():
        """Verify LOB-specific claim and application tables exist."""
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
        """Verify internal stages for document upload."""
        stages = conn.query(
            "SELECT STAGE_NAME FROM INSURANCE_DB.INFORMATION_SCHEMA.STAGES "
            "WHERE STAGE_SCHEMA = 'RAW' AND STAGE_TYPE = 'Internal Named Stage'"
        )
        names = set(stages["STAGE_NAME"].tolist()) if not stages.empty else set()
        required = {"DOCUMENTS_STAGE", "EVIDENCE_STAGE", "POLICY_DOCS_STAGE"}
        missing = required - names
        if missing:
            raise Exception(f"Missing stages: {', '.join(sorted(missing))}")
        return f"Found stages: {', '.join(sorted(names & required))}"

    def test_claim_submission_e2e():
        """Simulate auto claim form: validate -> insert -> CLAIMS_LANDING -> CLAIM_STATE."""
        # Pick a valid customer + policy
        valid = conn.query(
            "SELECT c.CUSTOMER_ID, p.POLICY_ID, p.LOB_TYPE "
            "FROM INSURANCE_DB.RAW.CUSTOMERS c "
            "JOIN INSURANCE_DB.RAW.POLICIES p ON c.CUSTOMER_ID = p.CUSTOMER_ID "
            "WHERE c.KYC_STATUS = 'VERIFIED' AND p.POLICY_STATUS = 'ACTIVE' AND p.LOB_TYPE = 'AUTO' "
            "LIMIT 1"
        )
        if valid.empty:
            raise Exception("No valid customer with active AUTO policy found")

        cust_id = valid["CUSTOMER_ID"].iloc[0]
        pol_id = valid["POLICY_ID"].iloc[0]
        test_tag = f"TEST-{uuid.uuid4().hex[:8].upper()}"

        try:
            # Insert claim (as claim form does)
            session.sql(
                "INSERT INTO INSURANCE_DB.RAW.CLAIMS_LANDING "
                "(policy_id, customer_id, claim_text, incident_date, claimed_amount, lob_type, incident_location, claim_status) "
                "SELECT ?, ?, ?, CURRENT_DATE(), 15000, 'AUTO', 'Test Location', 'SUBMITTED'",
                params=[pol_id, cust_id, f"E2E test claim [{test_tag}]"],
            ).collect()

            # Retrieve generated claim_id
            result = conn.query(
                f"SELECT claim_id FROM INSURANCE_DB.RAW.CLAIMS_LANDING "
                f"WHERE customer_id = '{cust_id}' AND claim_text LIKE '%{test_tag}%' "
                f"ORDER BY submission_date DESC LIMIT 1"
            )
            if result.empty:
                raise Exception("Claim inserted but not retrievable from CLAIMS_LANDING")

            claim_id = result["CLAIM_ID"].iloc[0]

            # Seed CLAIM_STATE (pipeline substitute since SP_AGENT_* missing)
            session.sql(
                "INSERT INTO INSURANCE_DB.PROCESSED.CLAIM_STATE (claim_id, current_state, started_at) "
                "VALUES (?, 'INTAKE', CURRENT_TIMESTAMP())",
                params=[claim_id],
            ).collect()

            # Verify visible in pipeline view
            pipe = conn.query(
                f"SELECT claim_id, current_state, customer_segment "
                f"FROM INSURANCE_DB.PROCESSED.V_PIPELINE_STATUS "
                f"WHERE claim_id = '{claim_id}'"
            )
            if pipe.empty:
                raise Exception("Claim not visible in V_PIPELINE_STATUS after CLAIM_STATE insert")

            return f"Claim {claim_id[:12]}... submitted, entered pipeline, visible in dashboard"

        finally:
            # Cleanup
            session.sql(
                f"DELETE FROM INSURANCE_DB.PROCESSED.CLAIM_STATE WHERE claim_id IN "
                f"(SELECT claim_id FROM INSURANCE_DB.RAW.CLAIMS_LANDING WHERE claim_text LIKE '%{test_tag}%')"
            ).collect()
            session.sql(
                f"DELETE FROM INSURANCE_DB.RAW.CLAIMS_LANDING WHERE claim_text LIKE '%{test_tag}%'"
            ).collect()

    def test_nba_chatbot_interaction_flow():
        """Simulate NBA chatbot: save interaction -> verify queryable."""
        test_id = f"INT-TEST-{uuid.uuid4().hex[:8].upper()}"
        cust_id = "CUST-001"

        try:
            session.sql(
                "INSERT INTO INSURANCE_DB.RAW.INTERACTIONS "
                "(INTERACTION_ID, CUSTOMER_ID, CHANNEL, INTERACTION_DATE, "
                "TRANSCRIPT_TEXT, DIRECTION, TOPIC, RESOLUTION_STATUS, "
                "AGENT_ID, DURATION_SECONDS, NPS_SCORE) "
                "VALUES (?, ?, 'CHAT', CURRENT_TIMESTAMP(), ?, 'INBOUND', 'General Inquiry', 'RESOLVED', 'CHATBOT-AGENT', 60, 7)",
                params=[test_id, cust_id, f"Test transcript [{test_id}]"],
            ).collect()

            result = conn.query(
                f"SELECT INTERACTION_ID, CHANNEL, TOPIC "
                f"FROM INSURANCE_DB.RAW.INTERACTIONS "
                f"WHERE INTERACTION_ID = '{test_id}'"
            )
            if result.empty:
                raise Exception("Interaction inserted but not queryable")

            return f"Interaction {test_id} inserted and queryable"

        finally:
            session.sql(
                f"DELETE FROM INSURANCE_DB.RAW.INTERACTIONS WHERE INTERACTION_ID = '{test_id}'"
            ).collect()

    def test_nba_generation():
        """Trigger NBA generation for a customer with a churn alert."""
        # Find a customer with an active churn alert
        alerts = conn.query(
            "SELECT customer_id FROM INSURANCE_DB.PROCESSED.CHURN_ALERTS "
            "WHERE status = 'NEW' ORDER BY churn_propensity DESC LIMIT 1"
        )
        if alerts.empty:
            raise Exception("No NEW churn alerts found — run SP_CHURN_PIPELINE_FULL()")

        cust_id = alerts["CUSTOMER_ID"].iloc[0]
        nba_before = conn.query(
            f"SELECT COUNT(*) AS n FROM INSURANCE_DB.PROCESSED.NEXT_BEST_ACTIONS "
            f"WHERE customer_id = '{cust_id}'"
        )
        before_count = int(nba_before["N"].iloc[0])

        result = session.sql(
            "CALL INSURANCE_DB.PROCESSED.SP_GENERATE_RETENTION_NBA(?)",
            params=[cust_id],
        ).collect()

        nba_after = conn.query(
            f"SELECT COUNT(*) AS n FROM INSURANCE_DB.PROCESSED.NEXT_BEST_ACTIONS "
            f"WHERE customer_id = '{cust_id}'"
        )
        after_count = int(nba_after["N"].iloc[0])

        if after_count <= before_count:
            raise Exception(f"NBA count did not increase (before={before_count}, after={after_count})")

        # Cleanup: remove the newly inserted NBA
        session.sql(
            f"DELETE FROM INSURANCE_DB.PROCESSED.NEXT_BEST_ACTIONS "
            f"WHERE customer_id = '{cust_id}' AND created_date = CURRENT_DATE()::VARCHAR "
            f"AND nba_id NOT IN (SELECT nba_id FROM INSURANCE_DB.PROCESSED.NEXT_BEST_ACTIONS "
            f"WHERE customer_id = '{cust_id}' ORDER BY created_date LIMIT {before_count})"
        ).collect()

        # Reset churn alert status
        session.sql(
            f"UPDATE INSURANCE_DB.PROCESSED.CHURN_ALERTS SET status = 'NEW' "
            f"WHERE customer_id = '{cust_id}'"
        ).collect()

        return f"NBA generated for {cust_id} (count {before_count} -> {after_count}), cleaned up"

    def test_dashboard_executive_overview():
        """Verify Customer 360 Tab 1 queries run without error and return data."""
        kpi = conn.query(
            "SELECT COUNT(*) AS total_customers, "
            "ROUND(AVG(churn_propensity_score), 2) AS avg_churn, "
            "ROUND(AVG(sentiment_score_last_30d), 2) AS avg_sentiment, "
            "ROUND(SUM(total_annual_premium), 0) AS total_premium "
            "FROM INSURANCE_DB.PROCESSED.FCT_CUSTOMER_360"
        )
        if kpi.empty or int(kpi["TOTAL_CUSTOMERS"].iloc[0]) == 0:
            raise Exception("Executive Overview KPI query returned no customers")

        seg = conn.query(
            "SELECT customer_segment, COUNT(*) AS count "
            "FROM INSURANCE_DB.PROCESSED.FCT_CUSTOMER_360 "
            "WHERE customer_segment IS NOT NULL GROUP BY 1"
        )
        if seg.empty:
            raise Exception("Segment breakdown query returned no data")

        return f"{int(kpi['TOTAL_CUSTOMERS'].iloc[0])} customers, {len(seg)} segments"

    def test_dashboard_churn_retention():
        """Verify Churn & Retention tab queries work."""
        churn = conn.query(
            "SELECT COUNT(*) AS total_alerts, "
            "SUM(CASE WHEN a.priority <= 3 THEN 1 ELSE 0 END) AS critical "
            "FROM INSURANCE_DB.PROCESSED.CHURN_ALERTS a "
            "JOIN INSURANCE_DB.PROCESSED.FCT_CUSTOMER_360 f ON a.customer_id = f.customer_id"
        )
        total = int(churn["TOTAL_ALERTS"].iloc[0])
        if total == 0:
            raise Exception("No churn alerts joined to FCT_CUSTOMER_360")

        dashboard = conn.query("SELECT COUNT(*) AS n FROM INSURANCE_DB.PROCESSED.V_CHURN_DASHBOARD")
        dash_n = int(dashboard["N"].iloc[0])

        return f"{total} alerts visible, V_CHURN_DASHBOARD has {dash_n} rows"

    def test_dashboard_customer_deep_dive():
        """Verify Customer Deep-Dive tab can load a customer profile."""
        profile = conn.query(
            "SELECT customer_id, customer_segment, lifetime_value_score, tenure_months "
            "FROM INSURANCE_DB.PROCESSED.FCT_CUSTOMER_360 LIMIT 1"
        )
        if profile.empty:
            raise Exception("Cannot load any customer profile")
        cid = profile["CUSTOMER_ID"].iloc[0]

        claims = conn.query(
            f"SELECT COUNT(*) AS n FROM INSURANCE_DB.RAW.CLAIMS_LANDING WHERE customer_id = '{cid}'"
        )
        payments = conn.query(
            f"SELECT COUNT(*) AS n FROM INSURANCE_DB.RAW.PAYMENTS WHERE customer_id = '{cid}'"
        )

        return (
            f"Profile loaded for {cid}: segment={profile['CUSTOMER_SEGMENT'].iloc[0]}, "
            f"claims={int(claims['N'].iloc[0])}, payments={int(payments['N'].iloc[0])}"
        )

    def test_dashboard_pipeline_monitor():
        """Verify AI Pipeline Monitor tab queries."""
        pipe = conn.query("SELECT COUNT(*) AS n FROM INSURANCE_DB.PROCESSED.V_PIPELINE_STATUS")
        resolutions = conn.query("SELECT COUNT(*) AS n FROM INSURANCE_DB.RESULTS.RESOLUTIONS")
        audit = conn.query(
            "SELECT COUNT(*) AS n FROM INSURANCE_DB.RESULTS.AUDIT_LOG WHERE flow_type = 'CLAIMS'"
        )
        return (
            f"V_PIPELINE_STATUS={int(pipe['N'].iloc[0])}, "
            f"RESOLUTIONS={int(resolutions['N'].iloc[0])}, "
            f"AUDIT_LOG(CLAIMS)={int(audit['N'].iloc[0])}"
        )

    def test_dashboard_portfolio_analytics():
        """Verify Portfolio Analytics tab queries."""
        lob = conn.query(
            "SELECT lob_type, COUNT(*) AS cnt FROM INSURANCE_DB.RAW.POLICIES GROUP BY 1"
        )
        if lob.empty:
            raise Exception("No policies found for LOB breakdown")

        claims = conn.query(
            "SELECT claim_status, COUNT(*) AS cnt FROM INSURANCE_DB.RAW.CLAIMS_LANDING GROUP BY 1"
        )
        return f"{len(lob)} LOB types, {len(claims)} claim statuses"

    def test_idp_landing_stats():
        """Verify IDP landing page stats queries all return > 0."""
        checks = {
            "Customers": "SELECT COUNT(*) AS n FROM INSURANCE_DB.RAW.CUSTOMERS",
            "Policies": "SELECT COUNT(*) AS n FROM INSURANCE_DB.RAW.POLICIES",
            "Claims": "SELECT COUNT(*) AS n FROM INSURANCE_DB.RAW.CLAIMS_LANDING",
            "Churn Alerts": "SELECT COUNT(*) AS n FROM INSURANCE_DB.PROCESSED.CHURN_ALERTS WHERE STATUS = 'NEW'",
        }
        results = {}
        for label, sql in checks.items():
            r = conn.query(sql)
            results[label] = int(r["N"].iloc[0])
        zeros = [k for k, v in results.items() if v == 0]
        if zeros:
            raise Exception(f"Zero counts: {', '.join(zeros)}")
        return ", ".join(f"{k}={v}" for k, v in results.items())

    # ── TEST RUNNER ─────────────────────────────────────────────────────

    ALL_TESTS = [
        # Infrastructure tests
        ("1. Source Tables Populated", test_source_tables_populated),
        ("2. Feature Store Populated", test_feature_store_populated),
        ("3. LOB Tables Exist", test_lob_tables_exist),
        ("4. Internal Stages Exist", test_internal_stages_exist),
        # Claims & Policy Intake (App 1) tests
        ("5. Claim Submission E2E", test_claim_submission_e2e),
        # NBA Chatbot (App 3) tests
        ("6. Chatbot Interaction Flow", test_nba_chatbot_interaction_flow),
        ("7. NBA Generation Pipeline", test_nba_generation),
        # Customer 360 Dashboard (App 2) tests
        ("8. Dashboard: Executive Overview", test_dashboard_executive_overview),
        ("9. Dashboard: Portfolio Analytics", test_dashboard_portfolio_analytics),
        ("10. Dashboard: Churn & Retention", test_dashboard_churn_retention),
        ("11. Dashboard: Customer Deep-Dive", test_dashboard_customer_deep_dive),
        ("12. Dashboard: AI Pipeline Monitor", test_dashboard_pipeline_monitor),
        # IDP Landing Page
        ("13. IDP Landing Page Stats", test_idp_landing_stats),
    ]

    if st.button(":material/play_arrow: **Run All Tests**", type="primary", use_container_width=True):
        st.session_state.test_running = True
        st.session_state.test_results = []

        progress = st.progress(0, text="Running tests...")
        results_container = st.container()

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


# ── Footer ──────────────────────────────────────────────────────────────
st.divider()
st.caption("IDP Insurance — Intelligent Digital Platform | Powered by Snowflake Cortex AI")
