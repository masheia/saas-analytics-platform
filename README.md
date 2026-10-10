# 🚀 SaaS Analytics Platform
## Snowflake + Cortex AI + Tableau + Render

An enterprise-grade real-time analytics platform showcasing modern data stack capabilities with AI-powered insights.

**Stack:**
- **Data Warehouse:** Snowflake (Medallion architecture)
- **Transformations:** dbt (Bronze → Silver → Gold)
- **AI/ML:** Snowflake Cortex (LLM-based predictions)
- **BI:** Tableau (interactive dashboards)
- **Hosting:** Render (Python Flask web app)
- **Data Simulation:** Python (realistic SaaS events)

---

## 📋 Project Structure

```
.
├── 01_snowflake_setup.sql          # DDL: Bronze/Silver/Gold schemas
├── 02_data_generator.py            # Python: Generate SaaS events
├── 03_cortex_predictions.sql       # Snowflake: AI predictions
├── 04_flask_app.py                 # Flask: Web application
├── dbt_models/
│   ├── silver/
│   │   ├── dim_users.sql           # User dimension (SCD Type 2)
│   │   └── fct_events.sql          # Events fact table
│   └── gold/
│       └── user_daily_metrics.sql  # Daily metrics aggregation
├── templates/
│   ├── dashboard.html              # Dashboard frontend
│   └── documentation.html          # API docs
├── requirements.txt                # Python dependencies
├── Dockerfile                      # Container build
├── .env.example                    # Environment template
└── README.md                       # This file
```

---

## 🚀 Quick Start

### Prerequisites
- Snowflake account (free trial available at snowflake.com)
- Python 3.9+
- Git
- Render account (free at render.com)
- Tableau account (optional, for embedded dashboards)

### Step 1: Snowflake Setup

1. **Create Snowflake Account**
   - Go to [snowflake.com/en/sign-up](https://www.snowflake.com/en/sign-up/)
   - Choose "Standard" edition, "AWS", "us-east-1"
   - Verify email

2. **Create Warehouse & Database**
   ```sql
   -- Run in Snowflake SQL Editor
   CREATE WAREHOUSE compute_wh WAREHOUSE_SIZE = 'XSMALL';
   CREATE DATABASE saas_analytics;
   CREATE SCHEMA saas_analytics.bronze;
   CREATE SCHEMA saas_analytics.silver;
   CREATE SCHEMA saas_analytics.gold;
   CREATE SCHEMA saas_analytics.ml;
   ```

3. **Run Setup SQL**
   - Copy entire `01_snowflake_setup.sql`
   - Paste into Snowflake SQL Editor
   - Execute all statements

4. **Get Your Credentials**
   - Account URL: `https://xy12345.us-east-1.snowflakecomputing.com` → Save as `xy12345.us-east-1`
   - Username: Your Snowflake username
   - Password: Your Snowflake password

### Step 2: Generate Sample Data

1. **Set Environment Variables**
   ```bash
   export SNOWFLAKE_USER="your_username"
   export SNOWFLAKE_PASSWORD="your_password"
   export SNOWFLAKE_ACCOUNT="xy12345.us-east-1"
   ```

2. **Install Python Dependencies**
   ```bash
   pip install -r requirements.txt
   ```

3. **Run Data Generator**
   ```bash
   python 02_data_generator.py
   ```
   - Generates 2,500+ users across 4 cohorts
   - Creates 50,000+ realistic SaaS events
   - Loads into Bronze layer

4. **Verify Data Loaded**
   ```sql
   SELECT COUNT(*) FROM saas_analytics.bronze.events;  -- Should see ~50,000
   ```

### Step 3: Load AI Predictions

Run Cortex SQL queries to populate ML layer:
```bash
# In Snowflake SQL Editor, run:
```
Copy and execute `03_cortex_predictions.sql` in Snowflake

This will:
- Calculate churn probabilities
- Analyze sentiment from feedback
- Detect revenue anomalies

### Step 4: Deploy to Render

1. **Create GitHub Repository**
   ```bash
   git init
   git add .
   git commit -m "Initial commit: SaaS Analytics Platform"
   git remote add origin https://github.com/your-username/saas-analytics.git
   git push -u origin main
   ```

2. **Connect Render**
   - Go to [render.com](https://render.com)
   - Click "New +" → "Web Service"
   - Connect GitHub account
   - Select `saas-analytics` repository
   - Configure:
     - **Name:** `saas-analytics`
     - **Environment:** `Docker`
     - **Plan:** Free or Paid

3. **Set Environment Variables**
   Click "Advanced" and add:
   ```
   SNOWFLAKE_USER=your_username
   SNOWFLAKE_PASSWORD=your_password
   SNOWFLAKE_ACCOUNT=xy12345.us-east-1
   FLASK_ENV=production
   SECRET_KEY=generate_random_key_here
   ```

4. **Deploy**
   - Click "Create Web Service"
   - Render builds Docker image and deploys
   - Get public URL (e.g., `https://saas-analytics-abc123.onrender.com`)

### Step 5: View Dashboard

Visit your Render URL and explore:
- **KPI Cards:** Real-time metrics
- **Daily Trends:** 30-day historical data
- **Churn Segments:** Risk categorization
- **Plan Analysis:** Revenue by plan type
- **Anomalies:** Real-time alerts

---

## 📊 Data Architecture

### Medallion Pattern (Snowflake)

```
Bronze Layer (Raw)
├── events (all raw events)
└── customer_feedback (raw feedback)
        ↓
Silver Layer (Cleaned)
├── dim_users (conformed user dimension)
├── dim_features (product features)
├── dim_date (calendar dimension)
└── fct_events (normalized event facts)
        ↓
Gold Layer (Analytics-Ready)
├── user_daily_metrics (aggregated daily)
├── company_monthly_metrics (business metrics)
├── user_cohort_analysis (retention cohorts)
└── active_users_realtime (dynamic table)
        ↓
ML Layer (AI/Predictions)
├── churn_predictions (LLM-based)
├── sentiment_analysis (NLP)
└── anomalies (statistical detection)
```

### Key Design Decisions

**Dimensions (Star Schema)**
- `dim_users`: SCD Type 2 (track changes)
- `dim_features`: Product features catalog
- `dim_date`: Calendar dimension (pre-loaded)

**Facts (Grain)**
- `fct_events`: One row per event
- `user_daily_metrics`: One row per user per day

**Performance Optimizations**
- Clustering keys: `user_id`, `metric_date`
- Search optimization on: `user_id`, `metric_date`
- Materialized views for common aggregations
- Dynamic tables for real-time metrics

---

## 🤖 Cortex AI Features

### 1. Churn Risk Prediction
Uses Mistral LLM to predict likelihood user will churn:
```sql
SELECT 
    user_id,
    churn_probability,  -- 0.0-1.0
    churn_category,     -- high_risk, medium_risk, low_risk
    recommendation      -- Action to take
FROM saas_analytics.ml.churn_predictions;
```

### 2. Sentiment Analysis
NLP on customer feedback:
```sql
SELECT 
    feedback_id,
    feedback_text,
    sentiment_score,    -- 0.0-1.0
    sentiment_category, -- positive, neutral, negative
    key_topics          -- Extracted topics
FROM saas_analytics.ml.sentiment_analysis;
```

### 3. Anomaly Detection
Statistical outlier detection on revenue:
```sql
SELECT 
    metric_date,
    actual_value,
    expected_value,
    deviation_pct,
    anomaly_score,
    severity            -- high, medium, low
FROM saas_analytics.ml.anomalies;
```

---

## 📈 API Endpoints

### KPI Metrics
```
GET /api/kpi-summary
```
Returns: Total users, active users, revenue, churn, engagement

### Time Series Data
```
GET /api/daily-metrics
```
Returns: 30-day trend of logins, features used, revenue

### Segmentation
```
GET /api/churn-segments
GET /api/plan-analysis
```
Returns: Breakdown by risk category, plan type, etc.

### Anomalies
```
GET /api/anomalies
```
Returns: Real-time anomalies with severity

### Data Export
```
GET /api/export/<metric_type>
```
Downloads CSV file of specified metric

---

## 🎯 Tableau Integration

### Option A: Embed Published Dashboard
1. Create dashboard in Tableau Online
2. Publish to public Tableau Server
3. Get dashboard URL
4. Update `TABLEAU_DASHBOARD_URL` env var
5. Dashboard will embed in Render app

### Option B: Use Direct Tableau Link
1. In dashboard.html, add iframe:
   ```html
   <iframe src="https://online.tableau.com/..." style="width:100%; height:800px;"></iframe>
   ```

### Recommended Visualizations
- **Executive Summary:** KPIs, trends, churn distribution
- **User Insights:** Cohort retention, feature adoption
- **Revenue Analytics:** MRR, ARPU, plan mix
- **AI Predictions:** Churn risk heatmap, sentiment trends

---

## 🔧 Development

### Local Setup
```bash
# Clone repository
git clone https://github.com/your-username/saas-analytics.git
cd saas-analytics

# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Set environment variables
cp .env.example .env
# Edit .env with your Snowflake credentials

# Run Flask app
python 04_flask_app.py
```

Visit http://localhost:5000

### dbt Transformations (Optional)

If using dbt:
```bash
# Install dbt
pip install dbt-snowflake

# Initialize dbt project
dbt init saas_analytics_dbt
cd saas_analytics_dbt

# Copy models
cp ../dbt_models/silver/*.sql models/
cp ../dbt_models/gold/*.sql models/

# Run transformations
dbt run
dbt test
```

---

## 📚 Documentation

### SQL Queries
- `01_snowflake_setup.sql`: All DDL for tables, views, roles
- `03_cortex_predictions.sql`: AI/ML queries with examples

### Python Code
- `02_data_generator.py`: Event simulation with cohort logic
- `04_flask_app.py`: Flask API with Snowflake queries

### Frontend
- `dashboard.html`: Interactive visualizations with Chart.js

---

## 🚨 Troubleshooting

### Connection Issues
```
Error: "Cannot connect to Snowflake"
→ Check credentials in .env
→ Verify warehouse is running in Snowflake
→ Confirm network connectivity
```

### Data Not Loading
```
Error: "Table not found"
→ Run 01_snowflake_setup.sql first
→ Verify database/schema names
→ Check WAREHOUSE and DATABASE grants
```

### Render Deployment Failed
```
Error: "Build failed"
→ Check Dockerfile syntax
→ Verify requirements.txt is valid
→ Check environment variables set
→ View logs in Render dashboard
```

---

## 📊 Performance Tuning

### Snowflake Optimization
- **Clustering:** `ALTER TABLE ... CLUSTER BY (user_id, metric_date)`
- **Materialized Views:** Pre-compute expensive aggregations
- **Dynamic Tables:** Real-time refresh (5-minute lag)
- **Warehouse Sizing:** Start XSMALL, scale as needed

### Query Performance
```sql
-- Use EXPLAIN to analyze query plan
EXPLAIN SELECT * FROM saas_analytics.gold.user_daily_metrics;

-- Check table statistics
SELECT * FROM TABLE(INFORMATION_SCHEMA.TABLE_STORAGE_METRICS(...));
```

---

## 🔐 Security Best Practices

1. **Environment Variables**
   - Never commit `.env` to Git
   - Use Render environment variables for secrets

2. **Snowflake Role-Based Access**
   ```sql
   CREATE ROLE bi_analyst;
   GRANT SELECT ON SCHEMA saas_analytics.gold TO ROLE bi_analyst;
   ```

3. **Network Security**
   - Use Snowflake IP whitelisting
   - Enable multi-factor authentication

4. **Data Privacy**
   - Mask PII in production (emails, company names)
   - Implement data retention policies

---

## 📈 Scaling Considerations

**Snowflake**
- Start: XSMALL warehouse, 2-3 GB data
- Scale: Use auto-suspend/auto-resume
- Monitor: Query duration, warehouse credits

**Render**
- Free tier: Good for development/demo
- Paid: Recommended for production
- Scale: Use horizontal scaling if needed

**Data Volume**
- Bronze: Append-only, grows with events
- Silver/Gold: Can run daily refreshes
- ML: Batch predictions or real-time with Cortex

---

## 🎓 Learning Resources

- [Snowflake Documentation](https://docs.snowflake.com)
- [Snowflake Cortex Guide](https://docs.snowflake.com/en/user-guide/ml-powered-analytics)
- [dbt Best Practices](https://docs.getdbt.com)
- [Tableau Public](https://public.tableau.com)
- [Render Deployment](https://render.com/docs)

---

## 📝 Next Steps

1. ✅ Deploy to Render
2. 🎨 Customize Tableau dashboards
3. 📊 Load your own data (CSV upload)
4. 🤖 Enhance Cortex predictions
5. 📈 Implement ML model training
6. 🔄 Add scheduled refresh jobs

---

## 📧 Support

For issues or questions:
- Check `TROUBLESHOOTING` section above
- Review Snowflake/Render documentation
- Examine Flask logs: `tail -f render.log`

---

## 📄 License

This project is open source and available under the MIT License.

---

**Built with ❤️ by a Senior Analytics Engineer**

*An enterprise-grade example of modern data stack: Snowflake + dbt + Cortex AI + Tableau + Render*
