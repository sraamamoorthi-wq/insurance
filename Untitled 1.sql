create or replace view V_AGG_INTERACTION_SIGNALS(
	CUSTOMER_ID,
	SENTIMENT_SCORE_LAST_30D,
	SENTIMENT_TREND,
	COMPLAINT_COUNT_90D,
	NPS_SCORE_LATEST,
	CHANNEL_PREFERENCE,
	LAST_INTERACTION_DAYS_AGO,
	ESCALATION_FLAG
) as
SELECT
    customer_id,
    AVG(CASE WHEN interaction_date >= DATEADD(day, -30, CURRENT_TIMESTAMP())
        THEN SNOWFLAKE.CORTEX.SENTIMENT(transcript_text) END) AS sentiment_score_last_30d,
    AVG(CASE WHEN interaction_date >= DATEADD(day, -30, CURRENT_TIMESTAMP())
        THEN SNOWFLAKE.CORTEX.SENTIMENT(transcript_text) END)
    - COALESCE(AVG(CASE WHEN interaction_date BETWEEN DATEADD(day, -60, CURRENT_TIMESTAMP()) AND DATEADD(day, -30, CURRENT_TIMESTAMP())
        THEN SNOWFLAKE.CORTEX.SENTIMENT(transcript_text) END), 0)
    AS sentiment_trend,
    COUNT_IF(resolution_status = 'ESCALATED'
        AND interaction_date >= DATEADD(day, -90, CURRENT_TIMESTAMP())) AS complaint_count_90d,
    MAX(nps_score) AS nps_score_latest,
    MODE(channel) AS channel_preference,
    DATEDIFF(day, MAX(interaction_date), CURRENT_TIMESTAMP()) AS last_interaction_days_ago,
    MAX(CASE WHEN resolution_status = 'ESCALATED'
        AND interaction_date >= DATEADD(day, -30, CURRENT_TIMESTAMP()) THEN TRUE ELSE FALSE END) AS escalation_flag
FROM INSURANCE_DB.RAW.INTERACTIONS
GROUP BY customer_id;