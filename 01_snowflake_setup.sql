-- ============================================================================
-- SNOWFLAKE SAAS ANALYTICS PLATFORM - DDL
-- Medallion Architecture: Bronze → Silver → Gold
-- ============================================================================

-- Create Database
CREATE DATABASE IF NOT EXISTS saas_analytics;

-- Create Schemas
CREATE SCHEMA IF NOT EXISTS saas_analytics.bronze;
CREATE SCHEMA IF NOT EXISTS saas_analytics.silver;
CREATE SCHEMA IF NOT EXISTS saas_analytics.gold;
CREATE SCHEMA IF NOT EXISTS saas_analytics.ml;

-- Create File Format for CSV staging
CREATE FILE FORMAT IF NOT EXISTS saas_analytics.bronze.csv_format
TYPE = CSV
FIELD_DELIMITER = ','
SKIP_HEADER = 1
NULL_IF = ('NULL', 'null');

-- ============================================================================
-- BRONZE LAYER - Raw Events (No transformation)
-- ============================================================================

CREATE TABLE IF NOT EXISTS saas_analytics.bronze.events (
    event_id STRING NOT NULL,
    event_type STRING NOT NULL,  -- signup, login, feature_used, purchase, churn
    user_id STRING NOT NULL,
    timestamp TIMESTAMP NOT NULL,
    session_id STRING,
    metadata VARIANT,  -- JSON-rich event data
    ingestion_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    _file_name STRING,
    _row_number NUMBER
);

-- Create Iceberg table for performance
ALTER TABLE saas_analytics.bronze.events SET ICEBERG_TABLE = TRUE;

-- ============================================================================
-- SILVER LAYER - Conformed Dimensions & Cleaned Facts
-- ============================================================================

-- Dimension: Users (with SCD Type 2)
CREATE TABLE IF NOT EXISTS saas_analytics.silver.dim_users (
    user_id STRING NOT NULL,
    user_natural_key STRING NOT NULL,
    email STRING,
    company_name STRING,
    plan_type STRING,  -- free, pro, enterprise
    subscription_status STRING,  -- active, churned, paused
    signup_date DATE,
    last_active_date DATE,
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    -- SCD Type 2
    scd_effective_date DATE,
    scd_end_date DATE,
    is_current BOOLEAN,
    PRIMARY KEY (user_id)
);

-- Dimension: Products/Features
CREATE TABLE IF NOT EXISTS saas_analytics.silver.dim_features (
    feature_id STRING NOT NULL,
    feature_name STRING,
    feature_category STRING,  -- core, premium, enterprise
    release_date DATE,
    is_active BOOLEAN,
    created_at TIMESTAMP,
    PRIMARY KEY (feature_id)
);

-- Dimension: Date (conformed)
CREATE TABLE IF NOT EXISTS saas_analytics.silver.dim_date (
    date_id INT NOT NULL,
    calendar_date DATE NOT NULL,
    year INT,
    quarter INT,
    month INT,
    week INT,
    day_of_week INT,
    is_weekend BOOLEAN,
    PRIMARY KEY (date_id)
);

-- Fact Table: Usage Events
CREATE TABLE IF NOT EXISTS saas_analytics.silver.fct_events (
    event_key STRING NOT NULL,
    user_key STRING,
    feature_key STRING,
    event_date DATE,
    event_time TIME,
    event_type STRING,
    session_duration_seconds INT,
    revenue_impact DECIMAL(10, 2),
    created_at TIMESTAMP,
    PRIMARY KEY (event_key),
    FOREIGN KEY (user_key) REFERENCES saas_analytics.silver.dim_users(user_id),
    FOREIGN KEY (feature_key) REFERENCES saas_analytics.silver.dim_features(feature_id)
);

-- ============================================================================
-- GOLD LAYER - Business Metrics & Aggregations
-- ============================================================================

-- User Metrics (Daily aggregation)
CREATE TABLE IF NOT EXISTS saas_analytics.gold.user_daily_metrics (
    user_id STRING NOT NULL,
    metric_date DATE NOT NULL,
    plan_type STRING,
    -- Usage metrics
    login_count INT,
    feature_usage_count INT,
    features_used INT,
    session_count INT,
    total_session_duration_minutes INT,
    -- Revenue metrics
    daily_revenue DECIMAL(10, 2),
    monthly_recurring_revenue DECIMAL(10, 2),
    -- Health metrics
    days_since_active INT,
    engagement_score DECIMAL(5, 2),
    -- AI predictions (populated by Cortex)
    churn_risk_score DECIMAL(5, 2),
    churn_risk_category STRING,
    sentiment_score DECIMAL(5, 2),
    -- Metadata
    loaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (user_id, metric_date)
);

-- Create dynamic table for real-time metrics
CREATE DYNAMIC TABLE IF NOT EXISTS saas_analytics.gold.active_users_realtime
TARGET LAG = '5 minute'
WAREHOUSE = compute_wh
AS
SELECT 
    user_id,
    MAX(timestamp) AS last_active,
    COUNT(*) AS events_last_hour,
    COUNT(DISTINCT session_id) AS sessions_last_hour
FROM saas_analytics.bronze.events
WHERE timestamp >= DATEADD(hour, -1, CURRENT_TIMESTAMP())
GROUP BY user_id;

-- Company-Level Metrics (Monthly)
CREATE TABLE IF NOT EXISTS saas_analytics.gold.company_monthly_metrics (
    company_id STRING NOT NULL,
    company_name STRING,
    metric_month DATE NOT NULL,
    total_users INT,
    active_users INT,
    monthly_recurring_revenue DECIMAL(12, 2),
    revenue_growth_pct DECIMAL(5, 2),
    churn_rate_pct DECIMAL(5, 2),
    nps_score INT,
    avg_engagement_score DECIMAL(5, 2),
    plan_mix VARIANT,  -- JSON breakdown of free/pro/enterprise
    loaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (company_id, metric_month)
);

-- Cohort Analysis (Monthly Cohorts)
CREATE TABLE IF NOT EXISTS saas_analytics.gold.user_cohort_analysis (
    cohort_month DATE NOT NULL,
    months_since_signup INT NOT NULL,
    cohort_size INT,
    retained_users INT,
    retention_rate DECIMAL(5, 2),
    revenue_per_user DECIMAL(10, 2),
    avg_engagement_score DECIMAL(5, 2),
    loaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (cohort_month, months_since_signup)
);

-- ============================================================================
-- ML LAYER - AI Features & Predictions
-- ============================================================================

CREATE TABLE IF NOT EXISTS saas_analytics.ml.churn_predictions (
    prediction_id STRING NOT NULL,
    user_id STRING NOT NULL,
    prediction_date DATE,
    days_inactive INT,
    monthly_revenue DECIMAL(10, 2),
    support_tickets INT,
    feature_adoption_count INT,
    engagement_score DECIMAL(5, 2),
    churn_probability DECIMAL(5, 2),
    churn_category STRING,  -- high_risk, medium_risk, low_risk
    recommendation STRING,  -- contact, monitor, nurture
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (prediction_id)
);

CREATE TABLE IF NOT EXISTS saas_analytics.ml.sentiment_analysis (
    feedback_id STRING NOT NULL,
    user_id STRING,
    feedback_text STRING,
    feedback_date DATE,
    sentiment_score DECIMAL(5, 2),
    sentiment_category STRING,  -- positive, neutral, negative
    key_topics ARRAY,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (feedback_id)
);

CREATE TABLE IF NOT EXISTS saas_analytics.ml.anomalies (
    anomaly_id STRING NOT NULL,
    metric_name STRING,
    metric_date DATE,
    expected_value DECIMAL(12, 2),
    actual_value DECIMAL(12, 2),
    deviation_pct DECIMAL(5, 2),
    anomaly_score DECIMAL(5, 2),
    severity STRING,  -- low, medium, high
    flagged_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (anomaly_id)
);

-- ============================================================================
-- MATERIALIZED VIEWS FOR PERFORMANCE
-- ============================================================================

-- Performance optimization: Clustering key on user_id
ALTER TABLE saas_analytics.bronze.events CLUSTER BY (user_id, timestamp);
ALTER TABLE saas_analytics.silver.fct_events CLUSTER BY (user_key, event_date);
ALTER TABLE saas_analytics.gold.user_daily_metrics CLUSTER BY (user_id, metric_date);

-- Create indexes (Snowflake uses search optimization)
ALTER TABLE saas_analytics.gold.user_daily_metrics ADD SEARCH OPTIMIZATION ON EQUALITY(user_id, metric_date), RANGE(metric_date);

-- ============================================================================
-- WAREHOUSE & ROLES
-- ============================================================================

-- Create warehouse for analytics
CREATE WAREHOUSE IF NOT EXISTS compute_wh
WAREHOUSE_SIZE = 'XSMALL'
AUTO_SUSPEND = 60
AUTO_RESUME = TRUE;

-- Create role for BI users
CREATE ROLE IF NOT EXISTS bi_analyst;
GRANT USAGE ON WAREHOUSE compute_wh TO ROLE bi_analyst;
GRANT USAGE ON DATABASE saas_analytics TO ROLE bi_analyst;
GRANT USAGE ON SCHEMA saas_analytics.silver TO ROLE bi_analyst;
GRANT USAGE ON SCHEMA saas_analytics.gold TO ROLE bi_analyst;
GRANT SELECT ON ALL TABLES IN SCHEMA saas_analytics.silver TO ROLE bi_analyst;
GRANT SELECT ON ALL TABLES IN SCHEMA saas_analytics.gold TO ROLE bi_analyst;

-- ============================================================================
-- SAMPLE DATA LOAD (Optional - for testing)
-- ============================================================================

-- Populate dim_date with last 2 years
INSERT INTO saas_analytics.silver.dim_date
WITH date_range AS (
    SELECT DATE_TRUNC('day', DATEADD(day, ROW_NUMBER() OVER (ORDER BY SEQ4()), '2023-01-01')) as d
    FROM TABLE(GENERATOR(ROWCOUNT => 730))
)
SELECT 
    TO_NUMBER(TO_CHAR(d, 'YYYYMMDD')) as date_id,
    d as calendar_date,
    YEAR(d) as year,
    QUARTER(d) as quarter,
    MONTH(d) as month,
    WEEK(d) as week,
    DAYOFWEEK(d) as day_of_week,
    DAYOFWEEK(d) IN (1, 7) as is_weekend
FROM date_range;

-- Create sample features
INSERT INTO saas_analytics.silver.dim_features VALUES
('feat_001', 'Dashboard', 'core', '2023-01-01', TRUE, CURRENT_TIMESTAMP()),
('feat_002', 'Reports', 'core', '2023-01-01', TRUE, CURRENT_TIMESTAMP()),
('feat_003', 'API Access', 'premium', '2023-06-01', TRUE, CURRENT_TIMESTAMP()),
('feat_004', 'Advanced Analytics', 'premium', '2023-08-15', TRUE, CURRENT_TIMESTAMP()),
('feat_005', 'Custom Integrations', 'enterprise', '2024-01-01', TRUE, CURRENT_TIMESTAMP());

COMMIT;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

SELECT 'Bronze Layer' as layer, COUNT(*) as row_count FROM saas_analytics.bronze.events
UNION ALL
SELECT 'Silver - Users', COUNT(*) FROM saas_analytics.silver.dim_users
UNION ALL
SELECT 'Silver - Events', COUNT(*) FROM saas_analytics.silver.fct_events
UNION ALL
SELECT 'Gold - Daily Metrics', COUNT(*) FROM saas_analytics.gold.user_daily_metrics;
