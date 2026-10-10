-- ============================================================================
-- SNOWFLAKE CORTEX AI PREDICTIONS
-- Uses LLM and built-in functions for ML analytics
-- ============================================================================

-- ============================================================================
-- 1. CHURN RISK PREDICTION (Using LLM)
-- ============================================================================

-- Insert churn predictions
INSERT INTO saas_analytics.ml.churn_predictions
SELECT 
    MD5(CONCAT(user_id, CURRENT_TIMESTAMP())) AS prediction_id,
    user_id,
    CURRENT_DATE() AS prediction_date,
    days_since_active,
    monthly_recurring_revenue,
    0 AS support_tickets,  -- Would join from support table in real scenario
    features_used AS feature_adoption_count,
    engagement_score,
    -- LLM-based churn probability
    TRY_CAST(
        REGEXP_SUBSTR(
            SNOWFLAKE.CORTEX.COMPLETE(
                'mistral-large',
                CONCAT(
                    'Based on these SaaS user metrics, predict churn probability (0.0-1.0): ',
                    'Days inactive: ', days_since_active, '. ',
                    'Monthly revenue: $', monthly_recurring_revenue::STRING, '. ',
                    'Features used: ', features_used, '. ',
                    'Engagement score: ', engagement_score::STRING, '. ',
                    'Plan: ', plan_type, '. ',
                    'Status: ', subscription_status, '. ',
                    'Respond with ONLY a decimal number between 0.0 and 1.0.'
                )
            ),
            '[0-9]+\.[0-9]+'
        ) AS DECIMAL(5,2)
    ) * 0.01 AS churn_probability,  -- Scale to 0-100
    CASE 
        WHEN churn_probability >= 0.7 THEN 'high_risk'
        WHEN churn_probability >= 0.4 THEN 'medium_risk'
        ELSE 'low_risk'
    END AS churn_category,
    -- Recommendation based on risk
    CASE 
        WHEN churn_probability >= 0.7 THEN 'Immediate outreach required'
        WHEN churn_probability >= 0.4 THEN 'Monitor and nurture'
        ELSE 'Maintain engagement'
    END AS recommendation,
    CURRENT_TIMESTAMP()
FROM saas_analytics.gold.user_daily_metrics
WHERE DATEDIFF(day, metric_date, CURRENT_DATE()) = 0  -- Only today's data
AND subscription_status = 'active';

-- Verify churn predictions
SELECT 
    churn_category,
    COUNT(*) AS user_count,
    ROUND(AVG(churn_probability), 3) AS avg_probability,
    MAX(churn_probability) AS max_probability
FROM saas_analytics.ml.churn_predictions
WHERE prediction_date = CURRENT_DATE()
GROUP BY churn_category
ORDER BY avg_probability DESC;

-- ============================================================================
-- 2. SENTIMENT ANALYSIS (Customer Feedback)
-- ============================================================================

-- Create sample feedback table (in real world, from support system)
CREATE TABLE IF NOT EXISTS saas_analytics.bronze.customer_feedback (
    feedback_id STRING,
    user_id STRING,
    feedback_text STRING,
    feedback_date DATE,
    feedback_source STRING  -- email, survey, chat
);

-- Insert sentiment analysis
INSERT INTO saas_analytics.ml.sentiment_analysis
SELECT 
    feedback_id,
    user_id,
    feedback_text,
    feedback_date,
    -- Sentiment score using Cortex
    CASE 
        WHEN SNOWFLAKE.CORTEX.SENTIMENT_ANALYSIS(feedback_text) LIKE '%positive%' THEN 0.8
        WHEN SNOWFLAKE.CORTEX.SENTIMENT_ANALYSIS(feedback_text) LIKE '%neutral%' THEN 0.5
        WHEN SNOWFLAKE.CORTEX.SENTIMENT_ANALYSIS(feedback_text) LIKE '%negative%' THEN 0.2
        ELSE 0.5
    END AS sentiment_score,
    SNOWFLAKE.CORTEX.SENTIMENT_ANALYSIS(feedback_text) AS sentiment_category,
    SNOWFLAKE.CORTEX.EXTRACT_ANSWER(
        'Extract 3 main topics from this feedback: ' || feedback_text,
        'What are the main topics?'
    ) AS key_topics,
    CURRENT_TIMESTAMP()
FROM saas_analytics.bronze.customer_feedback
WHERE feedback_date >= DATEADD(day, -30, CURRENT_DATE());

-- Sentiment summary
SELECT 
    sentiment_category,
    COUNT(*) AS feedback_count,
    ROUND(AVG(sentiment_score), 3) AS avg_sentiment
FROM saas_analytics.ml.sentiment_analysis
WHERE feedback_date >= DATEADD(day, -30, CURRENT_DATE())
GROUP BY sentiment_category;

-- ============================================================================
-- 3. ANOMALY DETECTION (Revenue & Metrics)
-- ============================================================================

-- Calculate rolling statistics for anomaly detection
CREATE OR REPLACE VIEW saas_analytics.ml.revenue_metrics_v AS
SELECT 
    metric_date,
    SUM(daily_revenue) AS total_daily_revenue,
    SUM(monthly_recurring_revenue) AS total_mrr,
    COUNT(DISTINCT user_id) AS active_user_count,
    AVG(engagement_score) AS avg_engagement
FROM saas_analytics.gold.user_daily_metrics
WHERE metric_date >= DATEADD(day, -90, CURRENT_DATE())
GROUP BY metric_date;

-- Detect anomalies using statistical methods
INSERT INTO saas_analytics.ml.anomalies
WITH revenue_stats AS (
    SELECT 
        metric_date,
        total_daily_revenue,
        AVG(total_daily_revenue) OVER (
            ORDER BY metric_date 
            ROWS BETWEEN 30 PRECEDING AND 1 PRECEDING
        ) AS revenue_30d_avg,
        STDDEV(total_daily_revenue) OVER (
            ORDER BY metric_date 
            ROWS BETWEEN 30 PRECEDING AND 1 PRECEDING
        ) AS revenue_30d_stddev
    FROM saas_analytics.ml.revenue_metrics_v
)
SELECT 
    MD5(CONCAT(metric_date, CURRENT_TIMESTAMP())) AS anomaly_id,
    'Daily Revenue' AS metric_name,
    metric_date,
    revenue_30d_avg AS expected_value,
    total_daily_revenue AS actual_value,
    ROUND((ABS(total_daily_revenue - revenue_30d_avg) / revenue_30d_avg) * 100, 2) AS deviation_pct,
    -- Anomaly score (standard deviations from mean)
    CASE 
        WHEN ABS(total_daily_revenue - revenue_30d_avg) > (3 * revenue_30d_stddev) THEN 0.95
        WHEN ABS(total_daily_revenue - revenue_30d_avg) > (2 * revenue_30d_stddev) THEN 0.75
        WHEN ABS(total_daily_revenue - revenue_30d_avg) > (1.5 * revenue_30d_stddev) THEN 0.50
        ELSE 0.10
    END AS anomaly_score,
    -- Severity classification
    CASE 
        WHEN ABS(total_daily_revenue - revenue_30d_avg) > (3 * revenue_30d_stddev) THEN 'high'
        WHEN ABS(total_daily_revenue - revenue_30d_avg) > (2 * revenue_30d_stddev) THEN 'medium'
        ELSE 'low'
    END AS severity,
    CURRENT_TIMESTAMP()
FROM revenue_stats
WHERE revenue_30d_stddev > 0  -- Avoid division issues
AND metric_date >= DATEADD(day, -7, CURRENT_DATE());  -- Last 7 days

-- View anomalies
SELECT 
    metric_date,
    metric_name,
    expected_value::INT AS expected,
    actual_value::INT AS actual,
    deviation_pct,
    anomaly_score,
    severity
FROM saas_analytics.ml.anomalies
WHERE anomaly_score > 0.5
ORDER BY anomaly_date DESC;

-- ============================================================================
-- 4. PREDICTIVE METRICS - LTV PREDICTION
-- ============================================================================

-- Customer Lifetime Value estimation using LLM
CREATE OR REPLACE VIEW saas_analytics.ml.ltv_predictions_v AS
SELECT 
    user_id,
    plan_type,
    signup_date,
    monthly_recurring_revenue,
    engagement_score,
    SNOWFLAKE.CORTEX.COMPLETE(
        'mistral-large',
        CONCAT(
            'Estimate the lifetime value (LTV) in USD for this SaaS customer. ',
            'Plan: ', plan_type, '. ',
            'Monthly revenue: $', monthly_recurring_revenue::STRING, '. ',
            'Engagement score (0-10): ', engagement_score::STRING, '. ',
            'Assume 3-year avg lifetime. Respond with ONLY a number (e.g., 3600).'
        )
    ) AS ltv_prediction_text,
    TRY_CAST(
        REGEXP_SUBSTR(ltv_prediction_text, '[0-9]+')
    AS INT
    ) AS estimated_ltv
FROM saas_analytics.gold.user_daily_metrics
WHERE metric_date = CURRENT_DATE()
AND subscription_status = 'active';

-- LTV Summary
SELECT 
    plan_type,
    COUNT(*) AS user_count,
    ROUND(AVG(estimated_ltv), 2) AS avg_ltv,
    ROUND(MAX(estimated_ltv), 2) AS max_ltv,
    ROUND(MIN(estimated_ltv), 2) AS min_ltv,
    ROUND(SUM(estimated_ltv), 2) AS total_ltv
FROM saas_analytics.ml.ltv_predictions_v
GROUP BY plan_type;

-- ============================================================================
-- 5. DASHBOARD METRICS - READY FOR TABLEAU
-- ============================================================================

-- Unified view for Tableau: User Insights with AI Predictions
CREATE OR REPLACE VIEW saas_analytics.gold.user_insights_with_ai_v AS
SELECT 
    udm.user_id,
    udm.metric_date,
    udm.plan_type,
    udm.subscription_status,
    udm.login_count,
    udm.feature_usage_count,
    udm.features_used,
    udm.total_session_duration_minutes,
    udm.daily_revenue,
    udm.monthly_recurring_revenue,
    udm.engagement_score,
    -- AI Predictions (from ML layer)
    cp.churn_probability,
    cp.churn_category,
    cp.recommendation AS churn_recommendation,
    sa.sentiment_score,
    sa.sentiment_category,
    -- Anomaly indicators
    CASE WHEN anom.anomaly_id IS NOT NULL THEN TRUE ELSE FALSE END AS has_revenue_anomaly
FROM saas_analytics.gold.user_daily_metrics udm
LEFT JOIN saas_analytics.ml.churn_predictions cp 
    ON udm.user_id = cp.user_id AND cp.prediction_date = CURRENT_DATE()
LEFT JOIN saas_analytics.ml.sentiment_analysis sa 
    ON udm.user_id = sa.user_id AND sa.feedback_date >= DATEADD(day, -30, CURRENT_DATE())
LEFT JOIN saas_analytics.ml.anomalies anom 
    ON udm.metric_date = anom.metric_date AND anom.severity = 'high'
WHERE udm.metric_date >= DATEADD(day, -30, CURRENT_DATE());

-- Test view
SELECT * FROM saas_analytics.gold.user_insights_with_ai_v LIMIT 10;

-- ============================================================================
-- 6. CORTEX COMPLETE - NATURAL LANGUAGE QUERIES
-- ============================================================================

-- Example: Ask a question about your data in natural language
-- Note: Requires Cortex Analytics enabled
SELECT 
    SNOWFLAKE.CORTEX.COMPLETE(
        'mistral-large',
        'Based on SaaS user data with high engagement and low churn risk, '
        || 'what are the top 3 characteristics of ideal customers? '
        || 'Respond concisely in 2-3 sentences.'
    ) AS insights;
