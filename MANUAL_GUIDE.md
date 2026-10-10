# 📚 Complete Manual Build Guide
## SaaS Analytics Platform - Step by Step

This guide walks you through **building the entire project manually** so you understand each component deeply and can explain it to others.

---

# 🔷 STAGE 1: FOUNDATION & PLANNING

## What We're Building
A **real-time SaaS analytics platform** that:
1. Ingests SaaS event data (simulated)
2. Transforms it through medallion architecture
3. Applies AI predictions
4. Serves dashboards + APIs

## Why This Architecture?
- **Medallion (Bronze/Silver/Gold)** = Industry standard, separates concerns
- **Snowflake** = Best-in-class data warehouse, native AI
- **Star Schema** = Optimized for BI queries
- **Cortex AI** = ML without data movement
- **Render + Flask** = Minimal ops, scalable

## Key Decisions to Make
1. **Data Volume**: 2,500 users × 30 days ≈ 50K events
2. **Refresh Cadence**: Daily batch (can scale to real-time)
3. **Fact Grain**: One row per event (atomic)
4. **Dimensions**: User (SCD Type 2), Features, Date
5. **Aggregations**: Daily user metrics, monthly company metrics

---

# 🔷 STAGE 2: SNOWFLAKE ACCOUNT & SETUP

## 2.1: Create Snowflake Account

**What:** Register for Snowflake free trial

**Steps:**
1. Go to https://www.snowflake.com/en/sign-up/
2. Fill form:
   - Email: your@email.com
   - Name: Your Name
   - Company: Your Company
3. Select Edition: **Standard** (most versatile)
4. Cloud Provider: **AWS**
5. Region: **us-east-1** (cheapest, lowest latency for demos)
6. Create account
7. Check email for verification link
8. Login to https://app.snowflake.com

**Why these choices?**
- Standard Edition: Good balance of features & cost
- AWS us-east-1: Cheapest region, fast
- Free trial: $400 credits (~20 hours compute)

**Verify:**
- You can log in
- You see "My Company" database
- Worksheets tab is available

---

## 2.2: Understand Snowflake Concepts

Before building, understand the hierarchy:

```
Snowflake Account (xy12345.us-east-1)
├── Database (saas_analytics)
│   ├── Schema (bronze, silver, gold, ml)
│   │   ├── Table (events, dim_users, fct_events)
│   │   ├── View (aggregations, virtual tables)
│   │   └── Dynamic Table (auto-refresh)
│   └── Role (bi_analyst, data_engineer)
└── Warehouse (compute_wh - the compute engine)
```

**Key Concepts:**
- **Database**: Logical container for data
- **Schema**: Organize tables by layer (bronze/silver/gold)
- **Warehouse**: Compute resources (like EC2 instances)
- **Role**: Access control (who can do what)
- **Table**: Physical data storage (Iceberg format = ACID transactions)

---

## 2.3: Create Warehouse (Compute Engine)

**What:** A warehouse is Snowflake's compute engine. It runs queries and costs credits.

**In Snowflake UI:**
1. Click **Admin** (left sidebar)
2. Click **Warehouses**
3. Click **+ Warehouse** button

**Configure:**
```
Name: compute_wh
Size: X-Small (1 credit/hour = $4/hour)
Max Cluster Count: 1
Min Cluster Count: 1
Auto Suspend: 60 minutes (pause after 1 hour of inactivity)
Auto Resume: Yes (resume when queries arrive)
```

**Why these settings?**
- XSMALL: Good for dev/demo, scales up for production
- Auto-suspend: Saves money (no idle compute)
- Auto-resume: Transparent to users

**Verify:**
- Warehouse shows "RUNNING" status
- You can see it in the dropdown at top-left

---

## 2.4: Create Database & Schemas

**What:** Database is a container. Schemas organize tables by layer.

**In Snowflake UI:**
1. Click **Data** (left sidebar)
2. Click **Databases**
3. Click **+ Database**

**Create Database:**
```
Name: saas_analytics
Comment: SaaS Analytics Platform - Medallion Architecture
```

**Create Schemas:**
After database created, click on it and create 4 schemas:

1. **bronze** (raw data layer)
   - Comment: Raw events, no transformation
   
2. **silver** (cleaned data layer)
   - Comment: Conformed dimensions and facts
   
3. **gold** (analytics layer)
   - Comment: Business metrics and aggregations
   
4. **ml** (machine learning layer)
   - Comment: AI predictions and features

**Why this structure?**
```
Bronze: events (raw) → ~50K rows
   ↓ (transform)
Silver: dim_users, dim_features, dim_date, fct_events
   ↓ (aggregate)
Gold: user_daily_metrics, company_monthly_metrics, cohort_analysis
   ↓ (enrich with AI)
ML: churn_predictions, sentiment_analysis, anomalies
```

**Verify:**
- All 4 schemas exist
- They're empty (no tables yet)

---

# 🔷 STAGE 3: DIMENSIONAL MODELING

## 3.1: Understand Star Schema

**What:** A star schema has:
- **Fact table** (center) - measures, events, transactions
- **Dimension tables** (points) - attributes, descriptors

**Example:**
```
        dim_date
          |
          |
dim_user--fct_events--dim_features
          |
          |
```

**Why Star Schema?**
- ✅ Fast joins (pre-identified relationships)
- ✅ Easy aggregations (summarize by any dimension)
- ✅ Business logic in one place (dimension tables)
- ✅ Denormalized dimensions = fewer joins

---

## 3.2: Design Dimensions

### Dimension 1: dim_users

**Purpose:** Who are our users? What plan? Are they active?

**Grain:** One row per user (with history via SCD Type 2)

**Attributes:**
```sql
user_id (PK)              -- Unique identifier
email                      -- Contact info
company_name               -- Which company
plan_type                  -- free, pro, enterprise
subscription_status        -- active, churned, paused
signup_date                -- When they joined
last_active_date           -- Last activity timestamp
-- SCD Type 2 (track changes)
scd_effective_date         -- When this version started
scd_end_date               -- When this version ended
is_current                 -- Is this the latest?
```

**Why SCD Type 2?**
When a user changes plans, we need history for analysis:
- "What was the churn rate for users who downgraded?"
- "How long did they stay before churning?"

**Example data:**
```
user_id | email            | plan_type | scd_effective | scd_end    | is_current
usr_001 | john@acme.com    | free      | 2023-01-01    | 2023-06-01 | FALSE
usr_001 | john@acme.com    | pro       | 2023-06-01    | NULL       | TRUE
usr_002 | jane@acme.com    | pro       | 2023-02-15    | NULL       | TRUE
```

### Dimension 2: dim_features

**Purpose:** What features does your product have?

**Grain:** One row per feature

**Attributes:**
```sql
feature_id (PK)           -- Unique ID
feature_name              -- Human-readable name
feature_category          -- core, premium, enterprise
release_date              -- When launched
is_active                 -- Still available?
```

**Why separate?**
- Product team manages feature list
- Track feature adoption over time
- Analyze which features drive retention/churn

### Dimension 3: dim_date

**Purpose:** Time dimension for aggregations

**Grain:** One row per day (pre-populated)

**Attributes:**
```sql
date_id (PK)              -- 20240101 format
calendar_date             -- Actual date
year, quarter, month      -- For aggregation
week, day_of_week         -- 1=Monday, 7=Sunday
is_weekend                -- Flag for weekend
```

**Why pre-populate?**
- Joins are faster than calculations
- Can add fiscal year, holidays, etc.
- Standard approach in enterprise BI

---

## 3.3: Design Fact Table

### Fact Table: fct_events

**Purpose:** Every event a user takes (login, feature used, purchase, etc.)

**Grain:** One row per event (atomic, no aggregation)

**Why atomic?**
- Most flexible for analysis
- Can aggregate to any level
- Maintains all detail for drilling down

**Attributes:**
```sql
event_key (PK)            -- Unique surrogate key
user_key (FK)             -- Link to dim_users
feature_key (FK)          -- Link to dim_features
date_key (FK)             -- Link to dim_date
event_type                -- signup, login, feature_used, purchase, churn
event_timestamp           -- Exact time
session_id                -- Which session?
session_duration_seconds  -- How long on platform?
revenue_impact            -- $ from purchase events
```

**Why these fields?**
- Foreign keys → Join to dimensions
- Additive measures → Can SUM(revenue_impact)
- Grain clarity → One row = one event

**Example data:**
```
event_id | user_key | feature_key | date_key | event_type   | revenue_impact
evt_0001 | usr_001  | feat_002    | 20240115 | login        | 0.00
evt_0002 | usr_001  | feat_003    | 20240115 | feature_used | 0.00
evt_0003 | usr_001  | NULL        | 20240115 | purchase     | 99.00
```

---

## 3.4: Design Gold Layer Aggregations

### Aggregation 1: user_daily_metrics

**Purpose:** Summarize user activity per day

**Grain:** One row per user per day

**Why aggregate?**
- Dashboard queries are fast (already pre-aggregated)
- No need to re-aggregate millions of events

**Attributes:**
```sql
user_id (PK)              
metric_date (PK)          
plan_type                 -- For filtering
-- Activity metrics
login_count               -- How many logins?
feature_usage_count       -- How many features used?
features_used             -- Which features used?
session_count             -- How many sessions?
total_session_duration    -- Total time on platform
-- Revenue metrics
daily_revenue             -- $ earned from this user
monthly_recurring_revenue -- Annualized MRR
-- Health metrics
days_since_active         -- How long inactive?
engagement_score          -- Calculated 0-10
-- AI predictions (joined from ML layer)
churn_risk_score          -- From Cortex
sentiment_score           -- From NLP
```

**SQL Pattern:**
```sql
SELECT 
    user_id,
    DATE(event_timestamp) as metric_date,
    COUNT(*) as total_events,
    COUNTIF(event_type = 'login') as login_count,
    SUM(revenue_impact) as daily_revenue,
    ...
FROM fct_events
GROUP BY 1, 2
```

### Aggregation 2: user_cohort_analysis

**Purpose:** Track retention by signup cohort

**Grain:** One row per cohort × months since signup

**Why cohorts?**
- Compare user cohorts (early vs late adopters)
- Track retention trends (are new users stickier?)
- Benchmark retention metrics

**Example:**
```
cohort_month | months_since_signup | cohort_size | retained_users | retention_rate
2023-01      | 0                   | 500         | 500            | 100%
2023-01      | 1                   | 500         | 475            | 95%
2023-01      | 2                   | 500         | 450            | 90%
2023-06      | 0                   | 800         | 800            | 100%
2023-06      | 1                   | 800         | 760            | 95%
```

---

# 🔷 STAGE 4: CREATE TABLES IN SNOWFLAKE

## 4.1: Create Bronze Layer Table

**What:** Raw events table. No transformation, just append.

**In Snowflake Worksheets:**

```sql
-- First, select warehouse and database
USE WAREHOUSE compute_wh;
USE DATABASE saas_analytics;

-- Create EVENTS table
CREATE TABLE IF NOT EXISTS bronze.events (
    event_id STRING NOT NULL,
    event_type STRING NOT NULL,
    user_id STRING NOT NULL,
    timestamp TIMESTAMP NOT NULL,
    session_id STRING,
    metadata VARIANT,  -- JSON field for flexibility
    ingestion_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (event_id)
);

-- Optimize with clustering (tells Snowflake how to physically arrange data)
ALTER TABLE bronze.events 
CLUSTER BY (user_id, timestamp);

-- Enable time-travel (can query historical versions)
ALTER TABLE bronze.events SET DATA_RETENTION_TIME_IN_DAYS = 7;
```

**Explain each part:**
- `STRING NOT NULL`: Text field, required
- `VARIANT`: JSON - flexible schema for metadata
- `PRIMARY KEY`: Uniqueness constraint
- `CLUSTER BY`: Physically group data (10-100x faster for user queries)
- `DATA_RETENTION_TIME_IN_DAYS`: Can undo deletes for 7 days

**Verify:**
```sql
DESC TABLE bronze.events;  -- Shows column names, types
SHOW TABLES IN schema bronze;  -- Lists all tables
```

---

## 4.2: Create Silver Layer - Dimensions

```sql
-- Dimension: Users
CREATE TABLE IF NOT EXISTS silver.dim_users (
    user_id STRING NOT NULL,
    email STRING,
    company_name STRING,
    plan_type STRING,
    subscription_status STRING,
    signup_date DATE,
    last_active_date DATE,
    -- SCD Type 2
    scd_effective_date DATE,
    scd_end_date DATE,
    is_current BOOLEAN,
    created_at TIMESTAMP,
    PRIMARY KEY (user_id, scd_effective_date)
);

ALTER TABLE silver.dim_users 
CLUSTER BY (user_id);

-- Dimension: Features
CREATE TABLE IF NOT EXISTS silver.dim_features (
    feature_id STRING NOT NULL,
    feature_name STRING,
    feature_category STRING,
    release_date DATE,
    is_active BOOLEAN,
    PRIMARY KEY (feature_id)
);

-- Dimension: Date
CREATE TABLE IF NOT EXISTS silver.dim_date (
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

ALTER TABLE silver.dim_date 
CLUSTER BY (calendar_date);
```

**Why separate tables?**
- Each dimension can be managed independently
- Reusable across multiple fact tables
- Business logic lives in dimensions (e.g., plan categories)

---

## 4.3: Create Silver Layer - Fact Table

```sql
CREATE TABLE IF NOT EXISTS silver.fct_events (
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
    FOREIGN KEY (user_key) REFERENCES silver.dim_users(user_id),
    FOREIGN KEY (feature_key) REFERENCES silver.dim_features(feature_id)
);

ALTER TABLE silver.fct_events 
CLUSTER BY (user_key, event_date);

ALTER TABLE silver.fct_events 
ADD SEARCH OPTIMIZATION ON EQUALITY(user_key), RANGE(event_date);
```

**Explain:**
- `FOREIGN KEY`: Enforces referential integrity
- `SEARCH OPTIMIZATION`: Index-like acceleration (Snowflake proprietary)
- Why cluster by user_key: Most queries filter by user

---

## 4.4: Create Gold Layer - Metrics

```sql
CREATE TABLE IF NOT EXISTS gold.user_daily_metrics (
    user_id STRING NOT NULL,
    metric_date DATE NOT NULL,
    plan_type STRING,
    login_count INT,
    feature_usage_count INT,
    features_used INT,
    session_count INT,
    total_session_duration_minutes INT,
    daily_revenue DECIMAL(10, 2),
    monthly_recurring_revenue DECIMAL(10, 2),
    days_since_active INT,
    engagement_score DECIMAL(5, 2),
    churn_risk_score DECIMAL(5, 2),
    churn_risk_category STRING,
    sentiment_score DECIMAL(5, 2),
    loaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (user_id, metric_date)
);

ALTER TABLE gold.user_daily_metrics 
CLUSTER BY (user_id, metric_date);

-- Create Cohort Retention Table
CREATE TABLE IF NOT EXISTS gold.user_cohort_analysis (
    cohort_month DATE NOT NULL,
    months_since_signup INT NOT NULL,
    cohort_size INT,
    retained_users INT,
    retention_rate DECIMAL(5, 2),
    revenue_per_user DECIMAL(10, 2),
    PRIMARY KEY (cohort_month, months_since_signup)
);
```

---

## 4.5: Create ML Layer - Predictions

```sql
CREATE TABLE IF NOT EXISTS ml.churn_predictions (
    prediction_id STRING NOT NULL,
    user_id STRING NOT NULL,
    prediction_date DATE,
    days_inactive INT,
    monthly_revenue DECIMAL(10, 2),
    support_tickets INT,
    feature_adoption_count INT,
    engagement_score DECIMAL(5, 2),
    churn_probability DECIMAL(5, 2),
    churn_category STRING,
    recommendation STRING,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (prediction_id)
);

CREATE TABLE IF NOT EXISTS ml.sentiment_analysis (
    feedback_id STRING NOT NULL,
    user_id STRING,
    feedback_text STRING,
    feedback_date DATE,
    sentiment_score DECIMAL(5, 2),
    sentiment_category STRING,
    key_topics ARRAY,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (feedback_id)
);

CREATE TABLE IF NOT EXISTS ml.anomalies (
    anomaly_id STRING NOT NULL,
    metric_name STRING,
    metric_date DATE,
    expected_value DECIMAL(12, 2),
    actual_value DECIMAL(12, 2),
    deviation_pct DECIMAL(5, 2),
    anomaly_score DECIMAL(5, 2),
    severity STRING,
    flagged_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (anomaly_id)
);
```

**Verify all tables created:**
```sql
SHOW TABLES IN database saas_analytics;
```

---

# 🔷 STAGE 5: POPULATE DIMENSIONS

## 5.1: Populate dim_date (Calendar)

**Why:** Need a 2-year calendar for fast date lookups

```sql
INSERT INTO silver.dim_date
WITH date_range AS (
    SELECT DATE_TRUNC('day', DATEADD(day, ROW_NUMBER() OVER (ORDER BY SEQ4()), '2023-01-01')) as d
    FROM TABLE(GENERATOR(ROWCOUNT => 730))  -- 730 days = 2 years
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
```

**Verify:**
```sql
SELECT COUNT(*) FROM silver.dim_date;  -- Should see 730
SELECT MIN(calendar_date), MAX(calendar_date) FROM silver.dim_date;
```

---

## 5.2: Populate dim_features

```sql
INSERT INTO silver.dim_features VALUES
('feat_001', 'Dashboard', 'core', '2023-01-01', TRUE),
('feat_002', 'Reports', 'core', '2023-01-01', TRUE),
('feat_003', 'API Access', 'premium', '2023-06-01', TRUE),
('feat_004', 'Advanced Analytics', 'premium', '2023-08-15', TRUE),
('feat_005', 'Custom Integrations', 'enterprise', '2024-01-01', TRUE);
```

**Verify:**
```sql
SELECT * FROM silver.dim_features;
```

---

# 🔷 STAGE 6: DATA GENERATION (MANUAL APPROACH)

## 6.1: Understand Data Generation Strategy

**What:** We need realistic SaaS events to populate bronze.events

**Why not just load random data?**
- Random data doesn't tell stories
- We need realistic patterns:
  - New users do more activities
  - Churned users go inactive
  - Premium users engage more

**Strategy:** Create user cohorts with different behaviors

```
Cohort 1: Early Adopters (2023-01)
├─ 500 users
├─ 5% churn rate (good product-market fit)
├─ High engagement (8/10)
└─ Mostly pro/enterprise plans

Cohort 2: Wave 2 (2023-06)
├─ 800 users
├─ 15% churn rate (moderate adoption)
├─ Medium engagement (5/10)
└─ Mix of free/pro

Cohort 3: Recent (2024-01)
├─ 1,200 users
├─ 25% churn rate (still evaluating)
├─ Low engagement (3/10)
└─ Mostly free tier

Cohort 4: Enterprise (2023-03)
├─ 50 users
├─ 2% churn rate (sticky)
├─ Very high engagement (9/10)
└─ Enterprise tier
```

---

## 6.2: Manual Data Generation in SQL

**Approach 1: SQL-based (no Python needed)**

```sql
-- Generate users
INSERT INTO silver.dim_users
WITH cohorts AS (
    SELECT 'early' as cohort, 500 as size, '2023-01-01'::DATE as signup_date, 'pro' as plan, 0.05 as churn_rate
    UNION ALL
    SELECT 'wave2', 800, '2023-06-01'::DATE, 'free', 0.15
    UNION ALL
    SELECT 'recent', 1200, '2024-01-01'::DATE, 'free', 0.25
    UNION ALL
    SELECT 'enterprise', 50, '2023-03-01'::DATE, 'enterprise', 0.02
)
SELECT 
    CONCAT('usr_', cohort, '_', ROW_NUMBER() OVER (PARTITION BY cohort ORDER BY RANDOM())) as user_id,
    CONCAT('user_', RANDOM(), '@company.com') as email,
    CASE WHEN ROW_NUMBER() OVER (PARTITION BY cohort ORDER BY RANDOM()) % 5 = 0 THEN 'Acme' 
         WHEN ROW_NUMBER() OVER (PARTITION BY cohort ORDER BY RANDOM()) % 5 = 1 THEN 'TechStart'
         ELSE 'DataCorp' END as company_name,
    plan,
    CASE WHEN RANDOM() > churn_rate THEN 'active' ELSE 'churned' END as subscription_status,
    signup_date,
    DATEADD(day, RANDOM() * 30, signup_date) as last_active_date,
    signup_date as scd_effective_date,
    NULL as scd_end_date,
    TRUE as is_current,
    CURRENT_TIMESTAMP() as created_at
FROM cohorts
CROSS JOIN TABLE(GENERATOR(ROWCOUNT => 1000));  -- Generate 1000 rows per cohort
```

**Verify:**
```sql
SELECT 
    COUNT(*) as total_users,
    COUNT(DISTINCT user_id) as unique_users,
    plan_type,
    subscription_status,
    COUNT(*) as count
FROM silver.dim_users
GROUP BY plan_type, subscription_status;
```

---

## 6.3: Generate Events (Manual)

```sql
-- Generate events (simplified - one event per user per day for 30 days)
INSERT INTO silver.fct_events
WITH daily_events AS (
    SELECT 
        du.user_id,
        ddate.calendar_date,
        CASE 
            WHEN RANDOM() < 0.8 THEN 'login'
            WHEN RANDOM() < 0.5 THEN 'feature_used'
            WHEN du.plan_type != 'free' AND RANDOM() < 0.1 THEN 'purchase'
            WHEN du.subscription_status = 'churned' AND ddate.calendar_date > du.last_active_date THEN 'churn'
            ELSE NULL
        END as event_type,
        CASE WHEN RANDOM() < 0.7 THEN 'feat_001' 
             WHEN RANDOM() < 0.5 THEN 'feat_003' 
             ELSE NULL END as feature_id,
        CASE 
            WHEN du.plan_type = 'pro' THEN 99.00
            WHEN du.plan_type = 'enterprise' THEN 999.00
            ELSE 0.00
        END as revenue,
        FLOOR(RANDOM() * 600) as session_seconds
    FROM silver.dim_users du
    CROSS JOIN silver.dim_date ddate
    WHERE ddate.calendar_date BETWEEN du.signup_date AND DATEADD(day, 30, du.signup_date)
    AND event_type IS NOT NULL
)
SELECT 
    MD5(CONCAT(user_id, calendar_date, event_type)) as event_key,
    user_id as user_key,
    feature_id as feature_key,
    calendar_date as event_date,
    CAST(DATEADD(minute, FLOOR(RANDOM() * 1440), calendar_date) as TIME) as event_time,
    event_type,
    session_seconds as session_duration_seconds,
    revenue as revenue_impact,
    CURRENT_TIMESTAMP() as created_at
FROM daily_events;
```

**Verify:**
```sql
SELECT COUNT(*) as event_count FROM silver.fct_events;  -- Should be 20K-50K
SELECT event_type, COUNT(*) FROM silver.fct_events GROUP BY event_type;
```

---

# 🔷 STAGE 7: TRANSFORMATIONS & AGGREGATIONS

## 7.1: Create Views (Silver to Gold)

**What:** Views are virtual tables that run SQL each time you query them

**Why not materialized views yet?**
- Start simple with views
- Understand the logic
- Materialize when you need performance

```sql
-- View: User Daily Metrics
CREATE OR REPLACE VIEW gold.user_daily_metrics_v AS
SELECT 
    fe.user_key as user_id,
    fe.event_date as metric_date,
    du.plan_type,
    du.subscription_status,
    DATEDIFF(day, fe.event_date, CURRENT_DATE()) as days_since_active,
    -- Activity metrics
    COUNT(*) as total_events,
    COUNTIF(fe.event_type = 'login') as login_count,
    COUNTIF(fe.event_type = 'feature_used') as feature_usage_count,
    COUNT(DISTINCT fe.feature_key) as features_used,
    COUNT(DISTINCT fe.session_id) as session_count,
    SUM(fe.session_duration_seconds) / 60 as total_session_duration_minutes,
    -- Revenue
    SUM(CASE WHEN fe.event_type = 'purchase' THEN fe.revenue_impact ELSE 0 END) as daily_revenue,
    SUM(CASE WHEN fe.event_type = 'purchase' THEN fe.revenue_impact ELSE 0 END) * 12 / 365 as monthly_recurring_revenue,
    -- Engagement score (0-10)
    LEAST(
        10.0,
        (COUNTIF(fe.event_type = 'login') * 0.5 + COUNTIF(fe.event_type = 'feature_used') * 0.3) / 10.0
    ) as engagement_score
FROM silver.fct_events fe
LEFT JOIN silver.dim_users du ON fe.user_key = du.user_id
WHERE fe.event_date >= DATEADD(day, -90, CURRENT_DATE())
GROUP BY 1, 2, 3, 4, 5;

-- Test the view
SELECT * FROM gold.user_daily_metrics_v WHERE metric_date = CURRENT_DATE() LIMIT 10;
```

---

## 7.2: Create Cohort Analysis View

```sql
CREATE OR REPLACE VIEW gold.user_cohort_analysis_v AS
WITH user_cohorts AS (
    SELECT 
        user_id,
        DATEADD(day, -DAYOFMONTH(signup_date) + 1, signup_date) as cohort_month,
        signup_date
    FROM silver.dim_users
),
cohort_activity AS (
    SELECT 
        uc.cohort_month,
        FLOOR(DATEDIFF(day, uc.signup_date, fe.event_date) / 30) as months_since_signup,
        fe.user_key
    FROM user_cohorts uc
    INNER JOIN silver.fct_events fe ON uc.user_id = fe.user_key
    WHERE fe.event_date >= uc.signup_date
)
SELECT 
    cohort_month,
    months_since_signup,
    COUNT(DISTINCT fe.user_key) as retained_users,
    (SELECT COUNT(DISTINCT user_id) FROM user_cohorts WHERE cohort_month = ca.cohort_month) as cohort_size,
    ROUND(retained_users / cohort_size * 100, 2) as retention_rate
FROM cohort_activity ca
INNER JOIN silver.fct_events fe ON ca.user_key = fe.user_key
GROUP BY 1, 2
ORDER BY 1 DESC, 2 ASC;

-- Test
SELECT * FROM gold.user_cohort_analysis_v LIMIT 20;
```

---

# 🔷 STAGE 8: SNOWFLAKE CORTEX AI PREDICTIONS

## 8.1: Understand Cortex

**What:** Snowflake's native AI capabilities (no data movement)

**Available Functions:**
1. `SNOWFLAKE.CORTEX.COMPLETE()` - LLM (Mistral Large)
2. `SNOWFLAKE.CORTEX.SENTIMENT_ANALYSIS()` - NLP
3. Statistical methods - z-score, standard deviation

**Why use Cortex?**
- ✅ Data stays in Snowflake
- ✅ No API calls, no latency
- ✅ Integrated with Snowflake data
- ✅ Cost-effective (included in compute)

---

## 8.2: Churn Prediction with LLM

**What:** Use Mistral LLM to predict churn probability

**Logic:**
```
Input: days_inactive, MRR, engagement, support_tickets
↓
LLM: "Predict if this user will churn (Yes/No)"
↓
Output: Probability score 0.0-1.0
```

**SQL Implementation:**

```sql
INSERT INTO ml.churn_predictions
SELECT 
    MD5(CONCAT(user_id, CURRENT_TIMESTAMP())) as prediction_id,
    user_id,
    CURRENT_DATE() as prediction_date,
    days_since_active,
    monthly_recurring_revenue,
    0 as support_tickets,  -- Would join from support table
    features_used as feature_adoption_count,
    engagement_score,
    -- LLM-based churn prediction
    TRY_CAST(
        REGEXP_SUBSTR(
            SNOWFLAKE.CORTEX.COMPLETE(
                'mistral-large',
                CONCAT(
                    'Based on these metrics, predict churn probability (0.0-1.0): ',
                    'Days inactive: ', days_since_active::STRING, '. ',
                    'Monthly revenue: $', monthly_recurring_revenue::STRING, '. ',
                    'Features used: ', features_used::STRING, '. ',
                    'Engagement: ', engagement_score::STRING, '. ',
                    'Respond with ONLY a decimal (e.g., 0.75)'
                )
            ),
            '[0-9]+\.[0-9]+'
        ) AS DECIMAL(5,2)
    ) / 100 as churn_probability,
    CASE 
        WHEN churn_probability >= 0.7 THEN 'high_risk'
        WHEN churn_probability >= 0.4 THEN 'medium_risk'
        ELSE 'low_risk'
    END as churn_category,
    CASE 
        WHEN churn_probability >= 0.7 THEN 'Immediate outreach needed'
        WHEN churn_probability >= 0.4 THEN 'Monitor and nurture'
        ELSE 'Maintain engagement'
    END as recommendation
FROM gold.user_daily_metrics_v
WHERE metric_date = CURRENT_DATE()
AND subscription_status = 'active';
```

**Verify:**
```sql
SELECT 
    churn_category,
    COUNT(*) as user_count,
    ROUND(AVG(churn_probability), 3) as avg_probability
FROM ml.churn_predictions
GROUP BY churn_category
ORDER BY avg_probability DESC;
```

---

## 8.3: Sentiment Analysis

**What:** Analyze customer feedback sentiment

**First, create feedback table:**
```sql
CREATE TABLE bronze.customer_feedback (
    feedback_id STRING,
    user_id STRING,
    feedback_text STRING,
    feedback_date DATE,
    feedback_source STRING
);

-- Sample feedback
INSERT INTO bronze.customer_feedback VALUES
('fb_001', 'usr_early_001', 'Love this product! Makes my workflow so much easier.', CURRENT_DATE(), 'survey'),
('fb_002', 'usr_wave2_100', 'Too expensive and limited features.', CURRENT_DATE(), 'email'),
('fb_003', 'usr_recent_500', 'OK product but needs better documentation.', CURRENT_DATE(), 'chat');
```

**Then analyze sentiment:**
```sql
INSERT INTO ml.sentiment_analysis
SELECT 
    feedback_id,
    user_id,
    feedback_text,
    feedback_date,
    CASE 
        WHEN SNOWFLAKE.CORTEX.SENTIMENT_ANALYSIS(feedback_text) LIKE '%positive%' THEN 0.8
        WHEN SNOWFLAKE.CORTEX.SENTIMENT_ANALYSIS(feedback_text) LIKE '%neutral%' THEN 0.5
        WHEN SNOWFLAKE.CORTEX.SENTIMENT_ANALYSIS(feedback_text) LIKE '%negative%' THEN 0.2
        ELSE 0.5
    END as sentiment_score,
    SNOWFLAKE.CORTEX.SENTIMENT_ANALYSIS(feedback_text) as sentiment_category,
    ARRAY_CONSTRUCT('sentiment', 'feedback') as key_topics,  -- Simplified
    CURRENT_TIMESTAMP()
FROM bronze.customer_feedback;
```

---

## 8.4: Anomaly Detection

**What:** Detect unusual patterns in metrics

**Using statistical method (z-score):**
```sql
INSERT INTO ml.anomalies
WITH daily_revenue AS (
    SELECT 
        metric_date,
        SUM(daily_revenue) as total_revenue
    FROM gold.user_daily_metrics_v
    GROUP BY metric_date
),
revenue_with_stats AS (
    SELECT 
        metric_date,
        total_revenue,
        AVG(total_revenue) OVER (ORDER BY metric_date ROWS BETWEEN 30 PRECEDING AND 1 PRECEDING) as avg_revenue,
        STDDEV(total_revenue) OVER (ORDER BY metric_date ROWS BETWEEN 30 PRECEDING AND 1 PRECEDING) as stddev_revenue
    FROM daily_revenue
)
SELECT 
    MD5(CONCAT(metric_date, CURRENT_TIMESTAMP())) as anomaly_id,
    'Daily Revenue' as metric_name,
    metric_date,
    ROUND(avg_revenue, 2) as expected_value,
    ROUND(total_revenue, 2) as actual_value,
    ROUND(ABS(total_revenue - avg_revenue) / avg_revenue * 100, 2) as deviation_pct,
    -- Anomaly score based on standard deviations
    CASE 
        WHEN ABS(total_revenue - avg_revenue) > (3 * stddev_revenue) THEN 0.95
        WHEN ABS(total_revenue - avg_revenue) > (2 * stddev_revenue) THEN 0.75
        WHEN ABS(total_revenue - avg_revenue) > (1.5 * stddev_revenue) THEN 0.50
        ELSE 0.10
    END as anomaly_score,
    CASE 
        WHEN ABS(total_revenue - avg_revenue) > (3 * stddev_revenue) THEN 'high'
        WHEN ABS(total_revenue - avg_revenue) > (2 * stddev_revenue) THEN 'medium'
        ELSE 'low'
    END as severity,
    CURRENT_TIMESTAMP()
FROM revenue_with_stats
WHERE stddev_revenue > 0
AND metric_date >= DATEADD(day, -7, CURRENT_DATE());
```

---

# 🔷 STAGE 9: FLASK WEB APPLICATION

## 9.1: Understand Flask Architecture

```
User Browser
    ↓ (HTTP Request)
Flask App (04_flask_app.py)
    ├─ Route: /api/kpi-summary
    ├─ Route: /api/daily-metrics
    ├─ Route: /api/churn-segments
    └─ All routes query Snowflake via pandas
        ↓ (SQL Query)
Snowflake
    ├─ Query Gold layer (fast)
    ├─ Query ML layer (predictions)
    └─ Return results
        ↓ (JSON Response)
Frontend (dashboard.html)
    └─ Render charts with Chart.js
```

---

## 9.2: Create Flask App Structure

**Create file: `app.py`**

```python
from flask import Flask, render_template, jsonify
import snowflake.connector
import pandas as pd
import os

app = Flask(__name__)

# Snowflake Configuration
SF_CONFIG = {
    'user': os.getenv('SNOWFLAKE_USER'),
    'password': os.getenv('SNOWFLAKE_PASSWORD'),
    'account': os.getenv('SNOWFLAKE_ACCOUNT'),
    'warehouse': 'compute_wh',
    'database': 'saas_analytics'
}

# ============================================================================
# FUNCTIONS: Database Connection
# ============================================================================

def get_snowflake_data(sql_query):
    """Execute SQL query and return as pandas DataFrame"""
    try:
        conn = snowflake.connector.connect(**SF_CONFIG)
        df = pd.read_sql(sql_query, conn)
        conn.close()
        return df
    except Exception as e:
        print(f"Database error: {e}")
        return None

# ============================================================================
# ROUTES: Pages
# ============================================================================

@app.route('/')
def index():
    """Main dashboard page"""
    return render_template('dashboard.html')

@app.route('/health')
def health():
    """Health check for monitoring"""
    return jsonify({'status': 'healthy'})

# ============================================================================
# ROUTES: API Endpoints
# ============================================================================

@app.route('/api/kpi-summary')
def kpi_summary():
    """
    Return: Total users, active users, revenue, churn, engagement
    Why: KPI cards on dashboard
    """
    sql = """
    SELECT 
        COUNT(DISTINCT user_id) AS total_users,
        COUNT(DISTINCT CASE WHEN subscription_status = 'active' THEN user_id END) AS active_users,
        ROUND(SUM(daily_revenue), 2) AS total_revenue,
        ROUND(AVG(engagement_score), 2) AS avg_engagement
    FROM gold.user_daily_metrics_v
    WHERE metric_date = CURRENT_DATE();
    """
    df = get_snowflake_data(sql)
    return jsonify(df.to_dict(orient='records')[0] if len(df) > 0 else {})

@app.route('/api/daily-metrics')
def daily_metrics():
    """
    Return: Last 30 days of trends
    Why: Line chart showing growth/decline
    """
    sql = """
    SELECT 
        metric_date,
        COUNT(DISTINCT user_id) AS active_users,
        SUM(login_count) AS total_logins,
        SUM(daily_revenue) AS daily_revenue
    FROM gold.user_daily_metrics_v
    WHERE metric_date >= DATEADD(day, -30, CURRENT_DATE())
    GROUP BY metric_date
    ORDER BY metric_date DESC;
    """
    df = get_snowflake_data(sql)
    df['metric_date'] = df['metric_date'].astype(str)  # Convert to string for JSON
    return jsonify(df.to_dict(orient='records'))

@app.route('/api/churn-segments')
def churn_segments():
    """
    Return: Users segmented by churn risk
    Why: Identify high-risk users for outreach
    """
    sql = """
    SELECT 
        churn_category,
        COUNT(*) AS user_count,
        ROUND(AVG(churn_probability), 3) AS avg_churn_prob,
        ROUND(SUM(monthly_recurring_revenue), 2) AS total_mrr
    FROM ml.churn_predictions
    GROUP BY churn_category
    ORDER BY avg_churn_prob DESC;
    """
    df = get_snowflake_data(sql)
    return jsonify(df.to_dict(orient='records'))

@app.route('/api/plan-analysis')
def plan_analysis():
    """
    Return: Metrics broken down by plan type
    Why: Understand which plans are most valuable
    """
    sql = """
    SELECT 
        plan_type,
        COUNT(DISTINCT user_id) AS user_count,
        ROUND(SUM(monthly_recurring_revenue), 2) AS total_mrr,
        ROUND(AVG(engagement_score), 2) AS avg_engagement
    FROM gold.user_daily_metrics_v
    WHERE metric_date = CURRENT_DATE()
    GROUP BY plan_type
    ORDER BY total_mrr DESC;
    """
    df = get_snowflake_data(sql)
    return jsonify(df.to_dict(orient='records'))

# ============================================================================
# ERROR HANDLERS
# ============================================================================

@app.errorhandler(500)
def internal_error(error):
    return jsonify({'error': 'Server error'}), 500

# ============================================================================
# RUN APP
# ============================================================================

if __name__ == '__main__':
    port = int(os.getenv('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=False)
```

---

## 9.3: Create HTML Dashboard

**Create file: `templates/dashboard.html`**

```html
<!DOCTYPE html>
<html>
<head>
    <title>SaaS Analytics Dashboard</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js@3.9.1/dist/chart.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/axios/dist/axios.min.js"></script>
    <style>
        * { margin: 0; padding: 0; }
        body { font-family: Arial; background: #f0f0f0; padding: 20px; }
        .container { max-width: 1200px; margin: 0 auto; }
        
        .kpi-cards {
            display: grid;
            grid-template-columns: repeat(4, 1fr);
            gap: 20px;
            margin-bottom: 30px;
        }
        
        .card {
            background: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        
        .kpi-label { color: #666; font-size: 12px; text-transform: uppercase; }
        .kpi-value { font-size: 28px; font-weight: bold; margin: 10px 0; }
        
        .charts {
            display: grid;
            grid-template-columns: repeat(2, 1fr);
            gap: 20px;
        }
        
        .chart-container { height: 300px; position: relative; }
        
        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 20px;
        }
        
        th, td {
            padding: 10px;
            text-align: left;
            border-bottom: 1px solid #ddd;
        }
        
        th { background: #f8f8f8; font-weight: bold; }
    </style>
</head>
<body>
    <div class="container">
        <h1>📊 SaaS Analytics Dashboard</h1>
        
        <!-- KPI Cards -->
        <div class="kpi-cards" id="kpi-container"></div>
        
        <!-- Charts -->
        <div class="charts">
            <div class="card">
                <h2>Daily Trends</h2>
                <div class="chart-container">
                    <canvas id="daily-chart"></canvas>
                </div>
            </div>
            
            <div class="card">
                <h2>Churn Risk</h2>
                <div class="chart-container">
                    <canvas id="churn-chart"></canvas>
                </div>
            </div>
        </div>
        
        <!-- Tables -->
        <div class="card" style="margin-top: 30px;">
            <h2>Plan Analysis</h2>
            <table id="plan-table">
                <thead>
                    <tr>
                        <th>Plan Type</th>
                        <th>Users</th>
                        <th>Total MRR</th>
                        <th>Avg Engagement</th>
                    </tr>
                </thead>
                <tbody></tbody>
            </table>
        </div>
    </div>

    <script>
        // Load KPIs
        async function loadKPIs() {
            const response = await axios.get('/api/kpi-summary');
            const data = response.data;
            
            document.getElementById('kpi-container').innerHTML = `
                <div class="card">
                    <div class="kpi-label">Active Users</div>
                    <div class="kpi-value">${data.active_users}</div>
                </div>
                <div class="card">
                    <div class="kpi-label">Total Revenue</div>
                    <div class="kpi-value">$${data.total_revenue}</div>
                </div>
                <div class="card">
                    <div class="kpi-label">Avg Engagement</div>
                    <div class="kpi-value">${data.avg_engagement}</div>
                </div>
                <div class="card">
                    <div class="kpi-label">Total Users</div>
                    <div class="kpi-value">${data.total_users}</div>
                </div>
            `;
        }
        
        // Load Charts
        async function loadCharts() {
            // Daily trends chart
            const dailyResponse = await axios.get('/api/daily-metrics');
            const dailyData = dailyResponse.data.reverse();
            
            new Chart(document.getElementById('daily-chart'), {
                type: 'line',
                data: {
                    labels: dailyData.map(d => d.metric_date),
                    datasets: [{
                        label: 'Active Users',
                        data: dailyData.map(d => d.active_users),
                        borderColor: '#667eea'
                    }]
                }
            });
            
            // Churn segmentation chart
            const churnResponse = await axios.get('/api/churn-segments');
            const churnData = churnResponse.data;
            
            new Chart(document.getElementById('churn-chart'), {
                type: 'pie',
                data: {
                    labels: churnData.map(d => d.churn_category),
                    datasets: [{
                        data: churnData.map(d => d.user_count),
                        backgroundColor: ['#e74c3c', '#f39c12', '#27ae60']
                    }]
                }
            });
        }
        
        // Load Tables
        async function loadTables() {
            const response = await axios.get('/api/plan-analysis');
            const tbody = document.querySelector('#plan-table tbody');
            
            response.data.forEach(row => {
                tbody.innerHTML += `
                    <tr>
                        <td>${row.plan_type}</td>
                        <td>${row.user_count}</td>
                        <td>$${row.total_mrr}</td>
                        <td>${row.avg_engagement}</td>
                    </tr>
                `;
            });
        }
        
        // Initialize
        document.addEventListener('DOMContentLoaded', () => {
            loadKPIs();
            loadCharts();
            loadTables();
        });
    </script>
</body>
</html>
```

---

# 🔷 STAGE 10: DEPLOYMENT (RENDER)

## 10.1: Create Docker Container

**Why Docker?**
- Package your app with all dependencies
- Same app runs on dev laptop + Render + AWS
- Easy to scale

**Create file: `Dockerfile`**

```dockerfile
# Start from Python 3.11
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Copy requirements
COPY requirements.txt .

# Install dependencies
RUN pip install -r requirements.txt

# Copy app code
COPY . .

# Expose port
EXPOSE 5000

# Run app
CMD ["python", "app.py"]
```

**Create file: `requirements.txt`**

```
Flask==2.3.2
pandas==2.0.3
numpy==1.24.3
snowflake-connector-python==3.2.1
gunicorn==21.2.0
```

---

## 10.2: Prepare for Render Deployment

**Create `.env.example`:**
```
SNOWFLAKE_USER=your_username
SNOWFLAKE_PASSWORD=your_password
SNOWFLAKE_ACCOUNT=xy12345.us-east-1
FLASK_ENV=production
PORT=5000
```

**Create GitHub repository:**
```bash
git init
git add .
git commit -m "Initial: SaaS Analytics Platform"
git remote add origin https://github.com/YOUR-USERNAME/saas-analytics.git
git push -u origin main
```

---

## 10.3: Deploy to Render

1. **Go to render.com**
2. **Sign up → Connect GitHub**
3. **Click "New +" → "Web Service"**
4. **Select your repository**
5. **Configure:**
   - Name: `saas-analytics`
   - Environment: `Docker`
   - Region: `us-east-1`

6. **Add Environment Variables:**
   ```
   SNOWFLAKE_USER=your_username
   SNOWFLAKE_PASSWORD=your_password
   SNOWFLAKE_ACCOUNT=xy12345.us-east-1
   FLASK_ENV=production
   ```

7. **Deploy!** (5-10 minutes to build)

---

# 🔷 STAGE 11: TESTING & VERIFICATION

## 11.1: Test Each Component

**Verify Snowflake Tables:**
```sql
-- Check row counts
SELECT 
    'dim_users' as table_name, COUNT(*) as rows FROM silver.dim_users
UNION ALL
SELECT 'fct_events', COUNT(*) FROM silver.fct_events
UNION ALL
SELECT 'user_daily_metrics_v', COUNT(*) FROM gold.user_daily_metrics_v
UNION ALL
SELECT 'churn_predictions', COUNT(*) FROM ml.churn_predictions;
```

**Verify Flask API:**
```bash
# In terminal
curl http://localhost:5000/api/kpi-summary
curl http://localhost:5000/api/daily-metrics
curl http://localhost:5000/health
```

**Verify Dashboard:**
- Open http://localhost:5000
- Check KPI cards load
- Check charts render
- Check tables populate

---

## 11.2: Performance Testing

**Check query performance:**
```sql
-- Enable query profiling
SELECT * FROM gold.user_daily_metrics_v LIMIT 10;

-- Check execution time (shown in Snowflake UI)
-- Should be <1 second for well-clustered data
```

**Monitor Snowflake usage:**
- Go to Admin → Usage → Warehouse
- Check credit consumption
- Typical demo: 1-5 credits/hour

---

# 🔷 STAGE 12: OPTIMIZATION

## 12.1: Materialize Views for Performance

**Why:** Views recalculate every query. For dashboards, pre-compute.

```sql
-- Create materialized view (physical table)
CREATE MATERIALIZED TABLE IF NOT EXISTS gold.user_daily_metrics AS
SELECT * FROM gold.user_daily_metrics_v;

-- Refresh daily (via schedule)
ALTER MATERIALIZED TABLE gold.user_daily_metrics REFRESH;
```

---

## 12.2: Add Indexes/Search Optimization

```sql
-- Already done via clustering, but can add:
ALTER TABLE gold.user_daily_metrics 
ADD SEARCH OPTIMIZATION ON EQUALITY(user_id), RANGE(metric_date);

-- For queries like:
-- WHERE user_id = 'usr_001' AND metric_date BETWEEN '2024-01' AND '2024-02'
```

---

# 🔷 STAGE 13: TABLEAU INTEGRATION (OPTIONAL)

## 13.1: Connect Tableau to Snowflake

1. **In Tableau Desktop:**
   - Connect to Data → Snowflake
   - Server: `xy12345.us-east-1`
   - Database: `saas_analytics`
   - Username/Password: Your Snowflake creds

2. **Query Gold Layer:**
   - Select `user_daily_metrics` table
   - Tableau shows all columns

3. **Build Dashboard:**
   - Drag `plan_type` to Rows
   - Drag `monthly_recurring_revenue` to Columns
   - Get bar chart instantly

4. **Publish:**
   - File → Publish as
   - Choose Tableau Online
   - Set sharing permissions

---

# 🔷 STAGE 14: DOCUMENTATION & KNOWLEDGE TRANSFER

## 14.1: Document Your Decisions

**Create ARCHITECTURE.md with:**
- Why medallion pattern?
- Why these fact/dimension grains?
- Why Cortex predictions?
- Performance optimization decisions

**Create README.md with:**
- How to run locally
- How to deploy
- API documentation
- Troubleshooting guide

---

## 14.2: Create Runbooks

**Operations Runbook:**
- How to refresh data
- How to add new metrics
- How to troubleshoot slowness
- How to monitor costs

**Development Runbook:**
- How to add new table
- How to modify transformation
- How to add new API endpoint
- How to deploy changes

---

# 📊 SUMMARY: WHAT YOU'VE BUILT

```
Stage 1:  📋 Planning & Architecture
Stage 2:  ❄️  Snowflake Setup (account, warehouse, database)
Stage 3:  🎯 Dimensional Modeling (star schema design)
Stage 4:  🗄️  Create Tables (bronze/silver/gold/ml)
Stage 5:  📤 Populate Dimensions (date, features, users)
Stage 6:  📊 Generate Events (realistic SaaS data)
Stage 7:  🔄 Create Transformations (views, aggregations)
Stage 8:  🤖 Add AI Predictions (Cortex churn, sentiment)
Stage 9:  🌐 Build Flask API (routes, endpoints)
Stage 10: 🎨 Create Dashboard (HTML, JavaScript, charts)
Stage 11: 🐳 Docker Container (for deployment)
Stage 12: 🚀 Deploy to Render (live at URL)
Stage 13: 📈 Optional: Tableau Integration
Stage 14: 📚 Document Everything
```

---

# 🎓 KEY LEARNINGS

**Architecture:**
- ✅ Medallion pattern (Bronze → Silver → Gold)
- ✅ Star schema (facts + dimensions)
- ✅ Conformed dimensions (business logic)
- ✅ SCD Type 2 (history tracking)

**Data Engineering:**
- ✅ Clustering keys (performance)
- ✅ Grain design (what should aggregate?)
- ✅ Views vs Materialized tables (tradeoffs)
- ✅ Data quality (PII, null handling)

**AI/ML:**
- ✅ Cortex integration (LLM, NLP)
- ✅ Churn prediction (business case)
- ✅ Anomaly detection (statistical)
- ✅ ML in SQL (no Python needed)

**Applications:**
- ✅ Flask API (database → JSON)
- ✅ Frontend (charts, tables)
- ✅ Deployment (Docker, Render)
- ✅ Monitoring (logs, health checks)

---

# ✨ READY TO BUILD?

Start with **Stage 2** and work through sequentially. Each stage builds on previous ones.

**Timeline:**
- Stages 2-5: 2 hours (Snowflake setup)
- Stages 6-8: 2 hours (Data generation & AI)
- Stages 9-11: 2 hours (Flask & deployment)
- Stages 12-14: 1 hour (Optimization & docs)

**Total: ~7 hours hands-on work**

Now you can **explain each component** to stakeholders, architects, and your team! 🚀
