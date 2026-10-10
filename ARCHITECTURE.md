# 🏗️ SaaS Analytics Platform - Architecture

## System Design Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    SaaS Analytics Data Platform                          │
│                      (Enterprise Architecture)                            │
└─────────────────────────────────────────────────────────────────────────┘

LAYER 1: DATA SOURCES
┌──────────────────────────────────────────────────────────────────────────┐
│  Simulated SaaS Events (Python)                                          │
│  • User signups, logins, feature usage                                   │
│  • Transactions, churn events                                            │
│  • 4 user cohorts with realistic patterns                                │
└──────────────────────────────────────────────────────────────────────────┘
                              ↓
LAYER 2: INGESTION & STORAGE (Snowflake)
┌──────────────────────────────────────────────────────────────────────────┐
│  BRONZE LAYER (Raw)                                                      │
│  ├── events (all raw SaaS events, ~50K rows)                            │
│  └── customer_feedback (raw feedback text)                              │
│                                                                          │
│  Clustering: user_id, timestamp                                         │
│  Format: Iceberg table (ACID, time-travel)                              │
└──────────────────────────────────────────────────────────────────────────┘
                              ↓
LAYER 3: TRANSFORMATION (dbt or SQL)
┌──────────────────────────────────────────────────────────────────────────┐
│  SILVER LAYER (Cleaned, Conformed)                                      │
│                                                                          │
│  Dimensions (Conformed):                                                │
│  ├── dim_users (SCD Type 2)                                             │
│  │   • User ID, email, plan, status                                     │
│  │   • SCD effective/end dates for history tracking                     │
│  ├── dim_features (product catalog)                                     │
│  │   • Feature ID, name, category, release date                         │
│  └── dim_date (calendar)                                                │
│      • Pre-populated 2-year calendar                                    │
│                                                                          │
│  Facts:                                                                  │
│  └── fct_events (grain: one row per event)                              │
│      • Event ID, user, feature, timestamp, session                      │
│      • Revenue impact, session duration                                 │
│                                                                          │
│  Clustering: user_id, event_date                                        │
└──────────────────────────────────────────────────────────────────────────┘
                              ↓
LAYER 4: ANALYTICS AGGREGATION
┌──────────────────────────────────────────────────────────────────────────┐
│  GOLD LAYER (Analytics-Ready)                                           │
│                                                                          │
│  Business Metrics:                                                       │
│  ├── user_daily_metrics (grain: user × day)                             │
│  │   • Login count, feature usage, engagement score                     │
│  │   • Daily & monthly revenue, session duration                        │
│  │   • Days since active, plan type                                     │
│  │                                                                       │
│  ├── company_monthly_metrics (grain: company × month)                   │
│  │   • User count, active users, churn rate                             │
│  │   • MRR, growth %, NPS, engagement                                   │
│  │                                                                       │
│  ├── user_cohort_analysis (retention cohorts)                           │
│  │   • Cohort month × months since signup                               │
│  │   • Retention rate, revenue per user                                 │
│  │                                                                       │
│  └── active_users_realtime (dynamic table)                              │
│      • Real-time active users (5-min refresh)                           │
│      • Last active time, recent events                                  │
│                                                                          │
│  Clustering: user_id, metric_date                                       │
│  Optimization: Search acceleration, materialized views                  │
└──────────────────────────────────────────────────────────────────────────┘
                              ↓
LAYER 5: AI & MACHINE LEARNING (Snowflake Cortex)
┌──────────────────────────────────────────────────────────────────────────┐
│  ML LAYER (Predictions & Insights)                                      │
│                                                                          │
│  Churn Predictions:                                                      │
│  ├── Uses: Mistral LLM (Cortex.COMPLETE)                                │
│  ├── Inputs: Days inactive, MRR, engagement, support tickets            │
│  ├── Output: Churn probability (0-1), risk category, recommendation     │
│  └── Table: churn_predictions                                           │
│                                                                          │
│  Sentiment Analysis:                                                     │
│  ├── Uses: Cortex.SENTIMENT_ANALYSIS (NLP)                              │
│  ├── Inputs: Customer feedback text                                     │
│  ├── Output: Sentiment score, category, key topics                      │
│  └── Table: sentiment_analysis                                          │
│                                                                          │
│  Anomaly Detection:                                                      │
│  ├── Uses: Statistical z-score (standard deviations from mean)          │
│  ├── Inputs: Daily revenue, active users, engagement                    │
│  ├── Output: Anomaly score, severity, expected vs actual                │
│  └── Table: anomalies                                                   │
│                                                                          │
│  LTV Predictions:                                                        │
│  ├── Uses: Mistral LLM (Cortex.COMPLETE)                                │
│  ├── Inputs: Plan, MRR, engagement, signup date                         │
│  └── Output: Estimated lifetime value (USD)                             │
│                                                                          │
│  Refresh: Daily batch (can be real-time with Cortex functions)          │
└──────────────────────────────────────────────────────────────────────────┘
                              ↓
LAYER 6: VISUALIZATION & BI
┌──────────────────────────────────────────────────────────────────────────┐
│  TABLEAU (Optional - Professional BI Tool)                              │
│                                                                          │
│  Dashboards:                                                             │
│  ├── Executive Summary                                                  │
│  │   • KPIs (users, revenue, churn, engagement)                         │
│  │   • Trends over time                                                 │
│  ├── User Insights + AI                                                 │
│  │   • Churn risk segmentation (Cortex predictions)                     │
│  │   • Sentiment trends (NLP analysis)                                  │
│  │   • Feature adoption by segment                                      │
│  └── Real-Time Monitoring                                               │
│      • Live event stream                                                │
│      • Anomaly alerts (from ML layer)                                   │
│      • Active users heatmap                                             │
│                                                                          │
│  Connection: Live Snowflake (Gold layer)                                │
│  Interactivity: Filters, parameters, cross-dashboard actions            │
└──────────────────────────────────────────────────────────────────────────┘
                              ↓
LAYER 7: WEB APPLICATION & API
┌──────────────────────────────────────────────────────────────────────────┐
│  RENDER (Python Flask Web App)                                          │
│                                                                          │
│  Frontend (dashboard.html):                                              │
│  ├── KPI cards (real-time)                                              │
│  ├── Line charts (Chart.js - daily trends)                              │
│  ├── Tables (churn segments, plan analysis)                             │
│  └── Anomaly alerts                                                     │
│                                                                          │
│  Backend API (Flask):                                                    │
│  ├── /api/kpi-summary → KPI metrics                                     │
│  ├── /api/daily-metrics → Time series (last 30 days)                    │
│  ├── /api/churn-segments → Risk segmentation                            │
│  ├── /api/plan-analysis → Plan-level metrics                            │
│  ├── /api/anomalies → Real-time anomalies                               │
│  ├── /api/export/<type> → CSV download                                  │
│  └── /health → Health check                                             │
│                                                                          │
│  Database: Direct Snowflake connections (pandas)                        │
│  Caching: None (fresh on each request for real-time)                    │
│  Deployment: Docker container on Render                                 │
│  Scaling: Auto-scaling based on traffic                                 │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## Data Flow Diagram

```
DAILY WORKFLOW:
├─ 12:00 AM: Python script generates day's SaaS events (simulated)
│            └─ 4 cohorts × different activity patterns
├─ 01:00 AM: Load events → Snowflake Bronze (events table)
├─ 02:00 AM: dbt transforms Bronze → Silver (dim + fct tables)
├─ 03:00 AM: Gold layer aggregations (daily metrics, company metrics)
├─ 04:00 AM: Cortex predictions (churn, sentiment, anomalies)
├─ 05:00 AM: Tableau refreshes from Gold + ML tables
└─ 06:00 AM: Dashboard available to stakeholders

ON-DEMAND:
├─ User visits Render web app (dashboard.html)
├─ JavaScript makes API calls to Flask backend
├─ Flask queries Snowflake Gold + ML layers
├─ Returns JSON to frontend
└─ Charts + tables render in browser (real-time)
```

---

## Key Architectural Decisions

### 1. Medallion Architecture (Bronze → Silver → Gold)
**Why:** Industry standard for data lakehouses
- **Bronze:** Raw data capture (Iceberg table with ACID)
- **Silver:** Data quality & conformance (conformed dimensions)
- **Gold:** Analytics-ready aggregations (optimized for BI)

**Benefits:**
- Separation of concerns
- Easy auditing & debugging
- Reproducible transformations
- Time-travel capability

### 2. Star Schema (Conformed Dimensions)
**Why:** Optimized for analytical queries
- Central fact table (fct_events) with foreign keys
- Conformed dimensions (dim_users, dim_features, dim_date)
- SCD Type 2 on dim_users to track changes

**Benefits:**
- Fast joins on dimension tables
- Easy aggregations & drill-downs
- Consistent business logic

### 3. Snowflake Cortex AI Integration
**Why:** Native ML without data movement
- Churn predictions using LLM (Mistral)
- Sentiment analysis using NLP
- Anomaly detection using statistical methods

**Benefits:**
- No data egress/third-party services
- Real-time predictions at query time
- Cost-efficient (Snowflake-native)

### 4. Dynamic Tables for Real-Time
**Why:** Automated refreshes without manual scheduling
- `active_users_realtime`: 5-minute refresh lag
- Queries always get fresh data
- Handles incremental updates

**Benefits:**
- No cron jobs or orchestration needed
- Guaranteed freshness
- Built on Iceberg foundation

### 5. Clustering Keys for Performance
**Why:** Minimize scan size for common filter patterns
- Cluster on `user_id` + `timestamp` (Bronze)
- Cluster on `user_id` + `metric_date` (Silver/Gold)

**Benefits:**
- 10-100x faster queries on filtered datasets
- Automatic maintenance (Snowflake)
- Transparent to users

### 6. Flask API + Chart.js Frontend
**Why:** Lightweight, self-contained, easy to deploy
- No heavy BI licensing
- Custom visualizations
- Direct Snowflake connection
- Deployable on free tier (Render)

**Benefits:**
- Full control over UX
- Minimal infrastructure
- Scalable API pattern
- Easy to customize

---

## Semantic Layer

### Conformed Dimensions

**dim_users**
```sql
user_id (PK)
├── Natural keys: email, company
├── Attributes: plan_type, subscription_status
├── Dates: signup_date, last_active_date, scd_effective_date
└── SCD Type 2: scd_end_date, is_current (track plan changes)
```

**dim_features**
```sql
feature_id (PK)
├── Name, category (core/premium/enterprise)
├── Release date, is_active
└── Relationships: Many-to-many via fct_events
```

**dim_date**
```sql
date_id (PK)
├── Calendar: year, quarter, month, week, day_of_week
└── Flags: is_weekend
```

### Conformed Measures

**fct_events (Atomic facts)**
```sql
event_key (PK)
├── FKs: user_key, feature_key, date_key
├── Degenerate dimensions: event_type, session_id
├── Additive measures: session_duration, revenue_impact
└── Grain: One row per event (atomic, no aggregation)
```

**user_daily_metrics (Derived aggregates)**
```sql
user_id (PK)
├── Date (PK)
├── Activity measures: login_count, feature_usage_count
├── Engagement: engagement_score (calculated)
├── Revenue: daily_revenue, mrr
├── Health: days_since_active, churn_risk_score (from ML)
└── Grain: One row per user per day
```

---

## Performance Optimizations

| Optimization | Technique | Impact |
|---|---|---|
| **Clustering** | `user_id, timestamp` on Bronze | 50-100x faster user scans |
| **Materialized Views** | Pre-compute hourly aggregations | Instant dashboard queries |
| **Dynamic Tables** | Auto-refresh every 5 min | Real-time without scheduling |
| **Pruning** | Search optimization on key columns | Eliminate irrelevant data |
| **Query Result Cache** | Snowflake automatic caching | 0.01s for repeated queries |
| **Warehouse Sizing** | Auto-suspend, multi-cluster | Cost efficiency + performance |

---

## Security & Governance

### Role-Based Access Control
```sql
-- BI analysts can only see Gold + ML layers
CREATE ROLE bi_analyst;
GRANT SELECT ON SCHEMA saas_analytics.gold TO ROLE bi_analyst;
GRANT SELECT ON SCHEMA saas_analytics.ml TO ROLE bi_analyst;
GRANT USAGE ON WAREHOUSE compute_wh TO ROLE bi_analyst;

-- Data engineers have full access
CREATE ROLE data_engineer;
GRANT ALL ON DATABASE saas_analytics TO ROLE data_engineer;
```

### Data Lineage
- Bronze → Silver: Documented via dbt metadata
- Silver → Gold: Documented via dbt DAG
- Gold → Cortex: Documented via SQL comments

### PII Handling
- Customer names/emails masked in sample data
- Feedback text anonymized
- Production: Use Snowflake Dynamic Masking

---

## Scalability Path

### Current (Demo)
- Data: 50K events, 2.5K users
- Warehouse: XSMALL (1 credit/hour)
- Refresh: Daily batch

### Production (Phase 1)
- Data: 10M events, 50K users
- Warehouse: SMALL/MEDIUM (auto-suspend)
- Refresh: Hourly incremental

### Enterprise (Phase 2)
- Data: 100M+ events, 500K+ users
- Warehouse: LARGE (multi-cluster)
- Refresh: Real-time streaming (Snowpipe)
- ML: Cortex models in production workflows

---

## Cost Estimation

| Component | Usage | Cost/Month |
|---|---|---|
| Snowflake Compute | 100 credits/month | $20-40 |
| Render (Web App) | Free tier | $0 |
| Tableau Public | (Optional) | $0 |
| Tableau Online | (Optional) | $70+ |
| **Total (Base)** | | **$20-40** |

*Scale linearly with data volume. Enterprise deployments: $500-2000/month*

---

## Disaster Recovery

### Backup Strategy
- Bronze: Iceberg ACID guarantees + time-travel (7 days default)
- Silver/Gold: Recreate from Bronze + code (dbt version control)
- ML predictions: Recalculate as needed (no critical state)

### Recovery Procedures
1. Data corruption detected → Revert Iceberg table to point-in-time
2. Code bug → Run dbt for specific model
3. Complete failure → Recreate from DDL + re-run generator

---

## Future Enhancements

1. **Real-Time Streaming**
   - Replace batch with Kafka → Snowpipe
   - Sub-second latency for events

2. **Advanced ML**
   - Customer segmentation (clustering)
   - Propensity modeling (classification)
   - Time-series forecasting (MRR prediction)

3. **Self-Service BI**
   - Add Streamlit for self-service dashboards
   - Natural language queries (Cortex.COMPLETE)

4. **Data Sharing**
   - Secure Data Sharing for partners
   - Iceberg table format for data exchange

5. **Governance**
   - Implement data catalog (Collibra, Alation)
   - Audit logging & monitoring
   - Data quality framework (dbt tests)

---

## References

- [Snowflake Architecture Best Practices](https://docs.snowflake.com)
- [Kimball Dimensional Modeling](https://www.kimballgroup.com)
- [dbt Modeling Guide](https://docs.getdbt.com/guides)
- [Snowflake Cortex Documentation](https://docs.snowflake.com/en/user-guide/cortex)
