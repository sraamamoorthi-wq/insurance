# IDP Insurance — CoCo Demo Narration Script

> Voiceover script for the CoCo-driven demo recording.
> Mix of CoCo chat prompts + Streamlit app walkthroughs.
> Paste prompts from the cheat sheet. CoCo runs the SQL and narrates.
> Total duration: ~6 minutes (compressible to 5).

---

## SCENE 1: Platform Overview (0:00 - 0:40)

*[Show: Snowsight workspace with CoCo chat panel open]*

"Hi, I'm Raamamoorthi. This is IDP Insurance — an AI-powered insurance platform built 100% on Snowflake.

I'll walk you through the full lifecycle — starting with a claim submission through our Streamlit portal, then using Cortex Code — Snowflake's AI coding agent — to orchestrate the backend. CoCo will trigger the AI pipeline, pull results step by step, and run churn detection — all from natural language prompts."

*[Paste Prompt 1 — platform overview]*

"CoCo just queried the metadata. 32 tables, 9 views, 21 stored procedures, 4 UDFs, 8 tasks, 5 streams — across 4 schemas. 8 customers, 13 policies, 3 LOBs: Auto, Property, Workers Comp. All managed through DCM — database change management as code."

---

## SCENE 2: Claims Intake (0:40 - 1:30)

*[Switch to Streamlit app — pre-opened]*

"Let me file a real claim. Ananya Sharma had a rear-end collision in Mumbai. I'll use our Streamlit intake portal."

*[Fill form: CUST-001, POL-001, AUTO, incident description, $4500]*
*[Attach garage estimate document in the form]*
*[Submit — note the Claim ID and document confirmation displayed]*

"The portal generated a Claim ID, validated the customer and policy in real-time, and uploaded the supporting document to a Snowflake internal stage — all in one step."

*[Switch back to CoCo chat]*
*[Paste Prompt 2 — verify claim]*

"Let me verify with CoCo — there it is. Status SUBMITTED, sitting in our raw landing table. Now for the fun part."

---

## SCENE 3: AI Pipeline via CoCo (1:30 - 3:15)

*[Stay in CoCo chat]*

"This is the core of the demo. I'm going to ask CoCo to process this claim through our 5-agent AI pipeline and show me every step."

*[Paste Prompt 3]*

*[Wait for CoCo to run SP_PROCESS_CLAIM and show results...]*

"Watch what CoCo just did. One prompt — and it triggered 5 AI agents in sequence.

Agent 1, Intake, used Cortex CLASSIFY_TEXT to tag the severity as medium.

Agent 2, Validation, checked the policy is active and the amount is within coverage — $4,500 against a $50,000 limit.

Agent 3, Fraud Detection — this is where it gets interesting. It computed vector similarity against our fraud pattern embeddings using EMBED_TEXT_768, ran sentiment analysis with CORTEX.SENTIMENT, retrieved matching fraud indicators via Cortex Search, and then passed everything to an LLM via CORTEX.COMPLETE for a grounded fraud assessment.

Agent 4, Assessment, used Cortex Search again to pull underwriting guidelines for the Auto LOB, then recommended a settlement amount.

Agent 5, Resolution, made the final call — and deducted the settlement from the policy's remaining coverage. You can see the coverage balance updated.

And look at the audit trail — every agent logged its Cortex module, model, latency in milliseconds, and status. Full production-grade observability. The entire pipeline ran in about 14 seconds."

---

## SCENE 4: Customer 360 Dashboard (3:15 - 4:15)

*[Switch to Streamlit app → Customer 360 Dashboard in sidebar]*

"Now let me show you the analytics layer — the Customer 360 Dashboard."

*[Tab 1 — Executive Overview]*
"Executive KPIs at a glance — total customers, total premium, active claims in the pipeline, churn alerts."

*[Tab 2 — Portfolio Analytics]*
"Portfolio breakdown by LOB, premium distribution across customer segments."

*[Tab 3 — Churn & Retention]*
"The churn dashboard shows our 4 at-risk customers with propensity scores and trigger reasons. And here are the AI-generated Next-Best-Actions ready for the CRM team."

*[Tab 4 — Customer Deep-Dive]*
*[Select CUST-001 — Ananya Sharma]*
"Ananya's deep-dive — Segment PREMIUM, LTV score 92.5, tenure 88 months. Her policies, claims, payment history, and interactions all in one view."

*[Switch to CUST-004 — James Wilson]*
"Now James Wilson — our highest churn risk. Late payments, low NPS, escalated billing complaint. This is who needs attention."

*[Tab 5 — AI Pipeline Monitor]*
"And the pipeline monitor — every claim's current state, resolutions, and the full audit log with per-agent latency."

"Everything here is powered by the 60-feature Customer 360 fact table and 5 aggregation views we built."

---

## SCENE 5: Churn + NBA via CoCo (4:15 - 5:00)

*[Switch back to CoCo chat]*

"Let me ask CoCo to run the churn pipeline and generate a retention offer."

*[Paste Prompt 4]*

*[Wait for CoCo to run CHURN_SCAN and NBA generation...]*

"CoCo ran the churn scanner, identified 4 at-risk customers, and generated a personalized retention offer for James Wilson — the highest priority.

The NBA includes a specific action, recommended channel, timing, talking points, and expected success rate. This was generated by Cortex COMPLETE using llama3.3-70b, grounded in our retention playbooks via RAG."

---

## SCENE 6: NBA Chatbot (5:00 - 5:45)

*[Switch to Streamlit app → Intelligent Chat in sidebar]*

"The platform includes a dual-mode AI chatbot."

*[Agent Mode — select CUST-004]*
"In Agent Mode, I'm an insurance agent handling James's case. The context panel shows his segment, churn risk, LTV score, and active NBAs."

*[Click "Retention strategy" suggestion pill]*
"The AI generates a data-driven retention strategy — referencing James's actual payment history, NPS scores, and escalation record. These are real numbers from the Customer 360."

*[Toggle to Customer Mode]*
"Now Customer Mode. Same customer, but now the AI speaks directly to James as a friendly care agent."

*[Click "Check my policy" suggestion pill]*
"Notice the tone shift — warm, empathetic, uses his first name. And critically, it never reveals internal scores like churn risk or LTV. That separation is built into the system prompt."

*[Toggle back to Agent Mode, click "Generate NBA" button]*
"And agents can generate new retention offers with one click — SP_GENERATE_RETENTION_NBA runs in the background and the NBA appears right in the sidebar."

---

## SCENE 7: Wrap-up (5:45 - 6:00)

*[Switch back to CoCo chat]*

*[Paste Prompt 5]*

"Let me ask CoCo to summarize."

*[CoCo lists all components]*

"8 Cortex AI functions. 5 AI agents. 60-feature Customer 360. Customer 360 Dashboard with 5 analytics tabs. Dual-mode AI chatbot. Churn prediction with AI-generated retention offers. Document intelligence. Coverage balance tracking. Event-driven automation with 8 tasks and 5 streams. Full audit trail.

And we orchestrated the entire thing through natural language prompts to Cortex Code.

From raw data to AI-powered decisions — entirely within Snowflake. Thank you."

*[End]*
