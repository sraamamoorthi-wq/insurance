import streamlit as st
import os
from datetime import date, timedelta

st.set_page_config(page_title="Customer 360 Dashboard", page_icon=":bar_chart:", layout="wide")

conn = st.connection("snowflake", ttl=os.getenv("SNOWFLAKE_CONNECTION_TTL"))
session = conn.session()
session.sql("USE DATABASE INSURANCE_DB").collect()


@st.cache_data(ttl=300)
def run_query(sql):
    return conn.query(sql)


def safe_int(val, default=0):
    import math
    if val is None:
        return default
    try:
        if math.isnan(val):
            return default
    except (TypeError, ValueError):
        pass
    try:
        return int(val)
    except (TypeError, ValueError):
        return default


# ── Sidebar filters ──
with st.sidebar:
    st.title("Filters")
    today = date.today()
    default_start = date(2024, 1, 1)
    date_range = st.date_input("Date range", value=(default_start, today), key="dr")
    if isinstance(date_range, tuple) and len(date_range) == 2:
        start_dt, end_dt = date_range
    else:
        start_dt, end_dt = default_start, today

    segments = run_query("SELECT DISTINCT customer_segment FROM INSURANCE_DB.PROCESSED.FCT_CUSTOMER_360 WHERE customer_segment IS NOT NULL ORDER BY 1")
    seg_options = segments["CUSTOMER_SEGMENT"].tolist()
    sel_segments = st.multiselect("Customer Segment", seg_options, default=seg_options, key="seg")

    lobs = run_query("SELECT DISTINCT lob_type FROM INSURANCE_DB.RAW.POLICIES WHERE lob_type IS NOT NULL ORDER BY 1")
    lob_options = lobs["LOB_TYPE"].tolist()
    sel_lobs = st.multiselect("Line of Business", lob_options, default=lob_options, key="lob")

    if st.button("Refresh data", key="refresh"):
        run_query.clear()

seg_filter = ",".join([f"'{s}'" for s in sel_segments]) if sel_segments else "''"
lob_filter = ",".join([f"'{l}'" for l in sel_lobs]) if sel_lobs else "''"

st.title("Customer 360 Dashboard")

tab1, tab2, tab3, tab4, tab5 = st.tabs(
    ["Executive Overview", "Portfolio Analytics", "Churn & Retention", "Customer Deep-Dive", "AI Pipeline Monitor"]
)

# ════════════════════════════════════════════════════════════
# TAB 1: EXECUTIVE OVERVIEW
# ════════════════════════════════════════════════════════════
with tab1:
    kpi = run_query(f"""
        SELECT COUNT(*) AS total_customers,
               ROUND(AVG(churn_propensity_score), 2) AS avg_churn,
               ROUND(AVG(sentiment_score_last_30d), 2) AS avg_sentiment,
               ROUND(SUM(total_annual_premium), 0) AS total_premium,
               SUM(CASE WHEN churn_propensity_score > 0.7 THEN 1 ELSE 0 END) AS high_risk_count
        FROM INSURANCE_DB.PROCESSED.FCT_CUSTOMER_360
        WHERE customer_segment IN ({seg_filter})
    """)
    r = kpi.iloc[0]

    with st.container(horizontal=True):
        st.metric("Total Customers", f"{safe_int(r['TOTAL_CUSTOMERS']):,}", border=True)
        st.metric("Avg Churn Risk", f"{r['AVG_CHURN']:.0%}" if r['AVG_CHURN'] else "N/A", border=True)
        st.metric("Avg Sentiment", f"{r['AVG_SENTIMENT']:.2f}" if r['AVG_SENTIMENT'] else "N/A", border=True)
        st.metric("Total Premium", f"Rs {safe_int(r['TOTAL_PREMIUM']):,}", border=True)
        st.metric("High Risk", f"{safe_int(r['HIGH_RISK_COUNT'])}", border=True)

    col1, col2 = st.columns(2)
    with col1:
        with st.container(border=True):
            st.subheader("Customers by Segment")
            seg_df = run_query(f"""
                SELECT customer_segment, COUNT(*) AS count
                FROM INSURANCE_DB.PROCESSED.FCT_CUSTOMER_360
                WHERE customer_segment IN ({seg_filter})
                GROUP BY 1 ORDER BY count DESC
            """)
            if not seg_df.empty:
                st.bar_chart(seg_df, x="CUSTOMER_SEGMENT", y="COUNT", horizontal=True)

    with col2:
        with st.container(border=True):
            st.subheader("Churn Risk Distribution")
            churn_df = run_query(f"""
                SELECT
                    CASE WHEN churn_propensity_score > 0.7 THEN 'High (>0.7)'
                         WHEN churn_propensity_score > 0.4 THEN 'Medium (0.4-0.7)'
                         ELSE 'Low (<0.4)' END AS risk_band,
                    COUNT(*) AS count
                FROM INSURANCE_DB.PROCESSED.FCT_CUSTOMER_360
                WHERE customer_segment IN ({seg_filter}) AND churn_propensity_score IS NOT NULL
                GROUP BY 1
            """)
            if not churn_df.empty:
                st.bar_chart(churn_df, x="RISK_BAND", y="COUNT")

    with st.container(border=True):
        st.subheader("Sentiment by Segment")
        sent_df = run_query(f"""
            SELECT customer_segment,
                   ROUND(AVG(sentiment_score_last_30d), 2) AS avg_sentiment,
                   ROUND(AVG(churn_propensity_score), 2) AS avg_churn,
                   ROUND(AVG(total_annual_premium), 0) AS avg_premium
            FROM INSURANCE_DB.PROCESSED.FCT_CUSTOMER_360
            WHERE customer_segment IN ({seg_filter})
            GROUP BY 1 ORDER BY avg_sentiment
        """)
        if not sent_df.empty:
            st.dataframe(sent_df, use_container_width=True, hide_index=True)

# ════════════════════════════════════════════════════════════
# TAB 2: PORTFOLIO ANALYTICS
# ════════════════════════════════════════════════════════════
with tab2:
    col1, col2 = st.columns(2)
    with col1:
        with st.container(border=True):
            st.subheader("Policies by LOB")
            lob_df = run_query(f"""
                SELECT lob_type, COUNT(*) AS policy_count, ROUND(SUM(premium_annual),0) AS total_premium
                FROM INSURANCE_DB.RAW.POLICIES
                WHERE lob_type IN ({lob_filter})
                GROUP BY 1 ORDER BY policy_count DESC
            """)
            if not lob_df.empty:
                st.bar_chart(lob_df, x="LOB_TYPE", y=["POLICY_COUNT", "TOTAL_PREMIUM"], stack=False)

    with col2:
        with st.container(border=True):
            st.subheader("Claims by Status")
            cs_df = run_query(f"""
                SELECT claim_status, COUNT(*) AS count
                FROM INSURANCE_DB.RAW.CLAIMS_LANDING
                WHERE lob_type IN ({lob_filter})
                  AND incident_date BETWEEN '{start_dt}' AND '{end_dt}'
                GROUP BY 1 ORDER BY count DESC
            """)
            if not cs_df.empty:
                st.bar_chart(cs_df, x="CLAIM_STATUS", y="COUNT")

    with st.container(border=True):
        st.subheader("Monthly Claims Trend")
        trend_df = run_query(f"""
            SELECT DATE_TRUNC('month', incident_date)::DATE AS month, lob_type, COUNT(*) AS claims
            FROM INSURANCE_DB.RAW.CLAIMS_LANDING
            WHERE lob_type IN ({lob_filter})
              AND incident_date BETWEEN '{start_dt}' AND '{end_dt}'
            GROUP BY 1, 2 ORDER BY 1
        """)
        if not trend_df.empty:
            pivot = trend_df.pivot_table(index="MONTH", columns="LOB_TYPE", values="CLAIMS", fill_value=0).reset_index()
            st.line_chart(pivot, x="MONTH")

    with st.container(border=True):
        st.subheader("Payment Health")
        pay_df = run_query(f"""
            SELECT DATE_TRUNC('month', due_date)::DATE AS month, payment_status, COUNT(*) AS count
            FROM INSURANCE_DB.RAW.PAYMENTS
            WHERE due_date BETWEEN '{start_dt}' AND '{end_dt}'
            GROUP BY 1, 2 ORDER BY 1
        """)
        if not pay_df.empty:
            pivot_pay = pay_df.pivot_table(index="MONTH", columns="PAYMENT_STATUS", values="COUNT", fill_value=0).reset_index()
            st.bar_chart(pivot_pay, x="MONTH")

# ════════════════════════════════════════════════════════════
# TAB 3: CHURN & RETENTION
# ════════════════════════════════════════════════════════════
with tab3:
    churn_kpi = run_query(f"""
        SELECT
            COUNT(*) AS total_alerts,
            SUM(CASE WHEN priority <= 3 THEN 1 ELSE 0 END) AS critical,
            SUM(CASE WHEN priority > 3 AND priority <= 10 THEN 1 ELSE 0 END) AS high,
            (SELECT ROUND(SUM(f.total_annual_premium), 0) FROM INSURANCE_DB.PROCESSED.FCT_CUSTOMER_360 f
             WHERE f.churn_propensity_score > 0.7 AND f.customer_segment IN ({seg_filter})) AS at_risk_premium
        FROM INSURANCE_DB.PROCESSED.CHURN_ALERTS a
        JOIN INSURANCE_DB.PROCESSED.FCT_CUSTOMER_360 f ON a.customer_id = f.customer_id
        WHERE f.customer_segment IN ({seg_filter})
    """)
    cr = churn_kpi.iloc[0]

    with st.container(horizontal=True):
        st.metric("Total Alerts", safe_int(cr['TOTAL_ALERTS']), border=True)
        st.metric("Critical", safe_int(cr['CRITICAL']), border=True)
        st.metric("High", safe_int(cr['HIGH']), border=True)
        st.metric("At-Risk Premium", f"Rs {safe_int(cr['AT_RISK_PREMIUM']):,}", border=True)

    col1, col2 = st.columns(2)
    with col1:
        with st.container(border=True):
            st.subheader("Alerts by Trigger")
            trig_df = run_query(f"""
                SELECT a.trigger_reason, COUNT(*) AS count
                FROM INSURANCE_DB.PROCESSED.CHURN_ALERTS a
                JOIN INSURANCE_DB.PROCESSED.FCT_CUSTOMER_360 f ON a.customer_id = f.customer_id
                WHERE f.customer_segment IN ({seg_filter})
                GROUP BY 1 ORDER BY count DESC
            """)
            if not trig_df.empty:
                st.bar_chart(trig_df, x="TRIGGER_REASON", y="COUNT")

    with col2:
        with st.container(border=True):
            st.subheader("Churn vs Sentiment")
            scatter_df = run_query(f"""
                SELECT customer_id, customer_segment,
                       ROUND(churn_propensity_score, 2) AS churn_score,
                       ROUND(sentiment_score_last_30d, 2) AS sentiment,
                       ROUND(total_annual_premium, 0) AS premium
                FROM INSURANCE_DB.PROCESSED.FCT_CUSTOMER_360
                WHERE customer_segment IN ({seg_filter})
                  AND churn_propensity_score IS NOT NULL
            """)
            if not scatter_df.empty:
                st.scatter_chart(scatter_df, x="CHURN_SCORE", y="SENTIMENT", color="CUSTOMER_SEGMENT", size="PREMIUM")

    with st.container(border=True):
        st.subheader("High-Risk Customers (Churn > 0.7)")
        risk_df = run_query(f"""
            SELECT f.customer_id, f.customer_segment,
                   ROUND(f.churn_propensity_score, 2) AS churn_score,
                   ROUND(f.sentiment_score_last_30d, 2) AS sentiment,
                   f.complaint_count_90d, f.total_annual_premium,
                   f.active_policy_count, f.intent_cancel_detected
            FROM INSURANCE_DB.PROCESSED.FCT_CUSTOMER_360 f
            WHERE f.churn_propensity_score > 0.7
              AND f.customer_segment IN ({seg_filter})
            ORDER BY f.churn_propensity_score DESC
            LIMIT 25
        """)
        if not risk_df.empty:
            st.dataframe(risk_df, use_container_width=True, hide_index=True)
        else:
            st.info("No high-risk customers found for selected filters.")

# ════════════════════════════════════════════════════════════
# TAB 4: CUSTOMER DEEP-DIVE
# ════════════════════════════════════════════════════════════
with tab4:
    cust_list = run_query(f"""
        SELECT customer_id || ' (' || customer_segment || ')' AS label, customer_id
        FROM INSURANCE_DB.PROCESSED.FCT_CUSTOMER_360
        WHERE customer_segment IN ({seg_filter})
        ORDER BY customer_id LIMIT 200
    """)
    if cust_list.empty:
        st.warning("No customers found for selected segment filters.")
    else:
        options = dict(zip(cust_list["LABEL"], cust_list["CUSTOMER_ID"]))
        selected_label = st.selectbox("Select Customer", list(options.keys()))
        cid = options[selected_label]

        profile = run_query(f"""
            SELECT * FROM INSURANCE_DB.PROCESSED.FCT_CUSTOMER_360 WHERE customer_id = '{cid}'
        """)
        if not profile.empty:
            p = profile.iloc[0]

            with st.container(horizontal=True):
                st.metric("Segment", p.get('CUSTOMER_SEGMENT', 'N/A'), border=True)
                st.metric("Tenure", f"{safe_int(p.get('TENURE_MONTHS'))} mo", border=True)
                st.metric("LTV Score", f"{p.get('LIFETIME_VALUE_SCORE', 0):.2f}", border=True)
                st.metric("Premium", f"Rs {safe_int(p.get('TOTAL_ANNUAL_PREMIUM')):,}", border=True)
                st.metric("Policies", safe_int(p.get('ACTIVE_POLICY_COUNT')), border=True)

            with st.container(horizontal=True):
                st.metric("Churn Risk", f"{(p.get('CHURN_PROPENSITY_SCORE') or 0):.0%}", border=True)
                st.metric("Sentiment", f"{(p.get('SENTIMENT_SCORE_LAST_30D') or 0):.2f}", border=True)
                st.metric("Fraud Score", f"{(p.get('FRAUD_SIMILARITY_SCORE') or 0):.2f}", border=True)
                st.metric("Complaints", safe_int(p.get('COMPLAINT_COUNT_90D')), border=True)
                st.metric("NPS", safe_int(p.get('NPS_SCORE_LATEST')), border=True)

            col1, col2 = st.columns(2)
            with col1:
                with st.container(border=True):
                    st.subheader("Claims History")
                    claims = run_query(f"""
                        SELECT claim_id, lob_type, claimed_amount, claim_status, incident_date
                        FROM INSURANCE_DB.RAW.CLAIMS_LANDING
                        WHERE customer_id = '{cid}'
                        ORDER BY incident_date DESC LIMIT 20
                    """)
                    if not claims.empty:
                        st.dataframe(claims, use_container_width=True, hide_index=True)
                    else:
                        st.caption("No claims found.")

            with col2:
                with st.container(border=True):
                    st.subheader("Payment History")
                    payments = run_query(f"""
                        SELECT due_date, amount, payment_status, days_delayed
                        FROM INSURANCE_DB.RAW.PAYMENTS
                        WHERE customer_id = '{cid}'
                        ORDER BY due_date DESC LIMIT 20
                    """)
                    if not payments.empty:
                        st.dataframe(payments, use_container_width=True, hide_index=True)
                    else:
                        st.caption("No payments found.")

            with st.container(border=True):
                st.subheader("Recent Interactions")
                ints = run_query(f"""
                    SELECT interaction_date, channel, topic, direction, transcript_text, nps_score
                    FROM INSURANCE_DB.RAW.INTERACTIONS
                    WHERE customer_id = '{cid}'
                    ORDER BY interaction_date DESC LIMIT 15
                """)
                if not ints.empty:
                    st.dataframe(ints, use_container_width=True, hide_index=True)
                else:
                    st.caption("No interactions found.")

            with st.container(border=True):
                st.subheader("Churn Alerts")
                alerts = run_query(f"""
                    SELECT alert_date, trigger_reason, priority, status,
                           ROUND(churn_propensity, 2) AS churn_score, root_cause
                    FROM INSURANCE_DB.PROCESSED.CHURN_ALERTS
                    WHERE customer_id = '{cid}'
                    ORDER BY alert_date DESC LIMIT 10
                """)
                if not alerts.empty:
                    st.dataframe(alerts, use_container_width=True, hide_index=True)
                else:
                    st.caption("No churn alerts.")

            nba = p.get('NEXT_BEST_ACTION')
            if nba:
                with st.container(border=True):
                    st.subheader("Next Best Action")
                    st.info(f"**{nba}**")
                    rationale = p.get('NBA_RATIONALE')
                    if rationale:
                        st.caption(rationale)

# ════════════════════════════════════════════════════════════
# TAB 5: AI PIPELINE MONITOR
# ════════════════════════════════════════════════════════════
with tab5:
    pipe_kpi = run_query(f"""
        SELECT COUNT(DISTINCT claim_id) AS total_resolved,
               ROUND(AVG(processing_time_ms), 0) AS avg_latency_ms,
               SUM(CASE WHEN decision = 'APPROVED' THEN 1 ELSE 0 END) AS approved,
               SUM(CASE WHEN decision = 'DENIED' THEN 1 ELSE 0 END) AS denied,
               SUM(CASE WHEN decision = 'PARTIALLY_APPROVED' THEN 1 ELSE 0 END) AS partial,
               SUM(CASE WHEN decision = 'REFERRED' THEN 1 ELSE 0 END) AS referred
        FROM INSURANCE_DB.RESULTS.RESOLUTIONS
        WHERE decided_at::DATE BETWEEN '{start_dt}' AND '{end_dt}'
    """)
    pr = pipe_kpi.iloc[0]

    with st.container(horizontal=True):
        st.metric("Total Resolved", safe_int(pr['TOTAL_RESOLVED']), border=True)
        st.metric("Avg Latency", f"{safe_int(pr['AVG_LATENCY_MS'])} ms", border=True)
        st.metric("Approved", safe_int(pr['APPROVED']), border=True)
        st.metric("Partially Approved", safe_int(pr['PARTIAL']), border=True)
        st.metric("Denied", safe_int(pr['DENIED']), border=True)
        st.metric("Referred", safe_int(pr['REFERRED']), border=True)

    col1, col2 = st.columns(2)
    with col1:
        with st.container(border=True):
            st.subheader("Decisions by LOB")
            dec_df = run_query(f"""
                SELECT lob_type, decision, COUNT(*) AS count
                FROM INSURANCE_DB.RESULTS.RESOLUTIONS
                WHERE decided_at::DATE BETWEEN '{start_dt}' AND '{end_dt}'
                GROUP BY 1, 2 ORDER BY 1, 2
            """)
            if not dec_df.empty:
                pivot_dec = dec_df.pivot_table(index="LOB_TYPE", columns="DECISION", values="COUNT", fill_value=0).reset_index()
                st.bar_chart(pivot_dec, x="LOB_TYPE")

    with col2:
        with st.container(border=True):
            st.subheader("Fraud Risk Distribution")
            fraud_df = run_query(f"""
                SELECT fraud_risk_level, COUNT(*) AS count, ROUND(AVG(fraud_score), 2) AS avg_score
                FROM INSURANCE_DB.RESULTS.RESOLUTIONS
                WHERE decided_at::DATE BETWEEN '{start_dt}' AND '{end_dt}'
                GROUP BY 1 ORDER BY avg_score DESC
            """)
            if not fraud_df.empty:
                st.bar_chart(fraud_df, x="FRAUD_RISK_LEVEL", y="COUNT")

    with st.container(border=True):
        st.subheader("Agent Latency by Step")
        lat_df = run_query(f"""
            SELECT agent_name, ROUND(AVG(latency_ms), 0) AS avg_ms, COUNT(*) AS runs
            FROM INSURANCE_DB.RESULTS.AUDIT_LOG
            WHERE flow_type = 'CLAIMS' AND status = 'SUCCESS'
            GROUP BY 1 ORDER BY avg_ms DESC
        """)
        if not lat_df.empty:
            st.bar_chart(lat_df, x="AGENT_NAME", y="AVG_MS")

    with st.container(border=True):
        st.subheader("Recent Resolutions")
        recent = run_query(f"""
            SELECT claim_id, customer_id, lob_type, decision, settlement_amount,
                   claimed_amount, fraud_risk_level, ROUND(confidence_score, 2) AS confidence,
                   decided_at
            FROM INSURANCE_DB.RESULTS.RESOLUTIONS
            WHERE decided_at::DATE BETWEEN '{start_dt}' AND '{end_dt}'
            ORDER BY decided_at DESC LIMIT 20
        """)
        if not recent.empty:
            st.dataframe(recent, use_container_width=True, hide_index=True)
