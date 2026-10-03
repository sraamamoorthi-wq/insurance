import os
import uuid
from datetime import datetime

import streamlit as st
from snowflake.cortex import complete

st.set_page_config(page_title="Insurance Customer Chat", page_icon=":shield:", layout="wide")

conn = st.connection("snowflake", ttl=os.getenv("SNOWFLAKE_CONNECTION_TTL"))
session = conn.session()

# --- Sidebar: customer selection ---
st.sidebar.header("Customer Context")

customers = conn.query(
    "SELECT CUSTOMER_ID, FIRST_NAME || ' ' || LAST_NAME AS FULL_NAME FROM INSURANCE_DB.RAW.CUSTOMERS ORDER BY FULL_NAME",
    ttl=600,
)

if customers.empty:
    st.sidebar.warning("No customers found. Seed the CUSTOMERS table first.")
    st.stop()

customer_map = dict(zip(customers["FULL_NAME"], customers["CUSTOMER_ID"]))
selected_name = st.sidebar.selectbox("Select Customer", list(customer_map.keys()))
customer_id = customer_map[selected_name]

st.sidebar.markdown(f"**Customer ID:** `{customer_id}`")

channel = st.sidebar.selectbox("Channel", ["CHAT", "CALL", "EMAIL", "SMS"])
topic = st.sidebar.selectbox(
    "Topic",
    ["Billing", "Claim Status", "Policy Change", "Renewal", "Complaint", "General Inquiry"],
)

# Show recent interactions for this customer
with st.sidebar.expander("Recent Interactions"):
    recent = conn.query(
        "SELECT INTERACTION_DATE, CHANNEL, TOPIC, RESOLUTION_STATUS "
        "FROM INSURANCE_DB.RAW.INTERACTIONS "
        "WHERE CUSTOMER_ID = ? ORDER BY INTERACTION_DATE DESC LIMIT 5",
        params=[customer_id],
    )
    if recent.empty:
        st.caption("No prior interactions.")
    else:
        st.dataframe(recent, use_container_width=True, hide_index=True)

# --- Main area ---
st.title(":shield: Insurance Customer Interaction Hub")
st.caption("Chat with a customer, log interactions, and trigger Next-Best-Action recommendations.")

# Session state
if "messages" not in st.session_state:
    st.session_state.messages = []
if "interaction_saved" not in st.session_state:
    st.session_state.interaction_saved = False

# Display chat history
for msg in st.session_state.messages:
    with st.chat_message(msg["role"]):
        st.write(msg["content"])

# Suggestion chips before first message
SUGGESTIONS = {
    ":blue[:material/help:] Ask about claim status": f"Hi, I'm calling to check on my recent claim. My customer ID is {customer_id}.",
    ":green[:material/receipt_long:] Billing question": f"I have a question about my last bill. Can you help?",
    ":orange[:material/autorenew:] Policy renewal": f"My policy is coming up for renewal. What are my options?",
}

if not st.session_state.messages:
    selected = st.pills("Suggested prompts:", list(SUGGESTIONS.keys()), label_visibility="collapsed")
    if selected:
        prompt = SUGGESTIONS[selected]
        st.session_state.messages.append({"role": "user", "content": prompt})
        st.rerun()

# Chat input
if prompt := st.chat_input("Type customer message..."):
    st.session_state.messages.append({"role": "user", "content": prompt})
    st.session_state.interaction_saved = False

    with st.chat_message("user"):
        st.write(prompt)

    # Build context for the assistant
    system_prompt = (
        "You are an experienced insurance customer service agent. "
        f"You are speaking with customer {selected_name} (ID: {customer_id}). "
        f"Channel: {channel}. Topic: {topic}. "
        "Be empathetic, professional, and helpful. Provide clear next steps. "
        "If the customer seems frustrated or at risk of churning, note it clearly."
    )
    conversation = system_prompt + "\n\n"
    for m in st.session_state.messages:
        role_label = "Customer" if m["role"] == "user" else "Agent"
        conversation += f"{role_label}: {m['content']}\n"
    conversation += "Agent:"

    with st.chat_message("assistant"):
        response = st.write_stream(
            complete(
                "llama3.1-70b",
                conversation,
                session=session,
                stream=True,
            )
        )

    st.session_state.messages.append({"role": "assistant", "content": response})

# --- Save interaction & trigger NBA ---
if len(st.session_state.messages) >= 2 and not st.session_state.interaction_saved:
    st.divider()
    col1, col2 = st.columns(2)

    resolution = col1.selectbox(
        "Resolution Status",
        ["RESOLVED", "PENDING", "ESCALATED", "FOLLOW_UP"],
    )
    nps = col2.slider("Customer NPS Score (if collected)", 0, 10, 7)

    def _save_interaction():
        transcript = "\n".join(
            f"{'Customer' if m['role'] == 'user' else 'Agent'}: {m['content']}"
            for m in st.session_state.messages
        )
        interaction_id = f"INT-{uuid.uuid4().hex[:12].upper()}"
        duration = len(st.session_state.messages) * 45

        session.sql(
            """
            INSERT INTO INSURANCE_DB.RAW.INTERACTIONS
                (INTERACTION_ID, CUSTOMER_ID, CHANNEL, INTERACTION_DATE,
                 TRANSCRIPT_TEXT, DIRECTION, TOPIC, RESOLUTION_STATUS,
                 AGENT_ID, DURATION_SECONDS, NPS_SCORE)
            VALUES
                (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            params=[
                interaction_id,
                customer_id,
                channel,
                datetime.now().isoformat(),
                transcript[:50000],
                "INBOUND",
                topic,
                resolution,
                "CHATBOT-AGENT",
                duration,
                nps,
            ],
        ).collect()

        st.session_state.interaction_saved = True
        st.session_state.last_interaction_id = interaction_id

    if st.button(":floppy_disk: Save Interaction & Log to NBA Pipeline", type="primary", on_click=_save_interaction):
        st.success(
            f"Interaction **{st.session_state.get('last_interaction_id', '')}** saved to "
            "`INSURANCE_DB.RAW.INTERACTIONS`. The INTERACTIONS_STREAM will pick this up "
            "for downstream NBA processing."
        )

# --- Trigger NBA manually ---
if st.session_state.interaction_saved:
    st.divider()
    st.subheader("Generate Next-Best-Action")
    st.caption(
        "Trigger the retention NBA procedure for this customer. "
        "It reads churn alerts, retention playbooks, and uses Cortex AI to recommend an action."
    )
    if st.button(":rocket: Generate NBA for this Customer"):
        with st.spinner("Running SP_GENERATE_RETENTION_NBA..."):
            result = session.sql(
                "CALL INSURANCE_DB.PROCESSED.SP_GENERATE_RETENTION_NBA(?)",
                params=[customer_id],
            ).collect()
        if result and len(result) > 0:
            st.success("NBA generated successfully!")
            st.json(str(result[0][0]))
        else:
            st.info("No NBA result returned. The customer may not have active churn alerts.")

    # Show existing NBAs
    with st.expander("Existing NBAs for this customer"):
        nbas = conn.query(
            "SELECT ACTION_TYPE, OFFER_DETAILS, CHANNEL, TIMING, STATUS, CREATED_DATE "
            "FROM INSURANCE_DB.PROCESSED.NEXT_BEST_ACTIONS "
            "WHERE CUSTOMER_ID = ? ORDER BY CREATED_DATE DESC LIMIT 10",
            params=[customer_id],
        )
        if nbas.empty:
            st.caption("No NBAs found for this customer.")
        else:
            st.dataframe(nbas, use_container_width=True, hide_index=True)
