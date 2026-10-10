# ⚡ Quick Start Checklist

Complete these steps in order to deploy the SaaS Analytics Platform.

---

## ✅ PHASE 1: SNOWFLAKE SETUP (30 minutes)

- [ ] **Create Snowflake Account**
  - Go to: https://www.snowflake.com/en/sign-up/
  - Choose: Standard Edition, AWS, us-east-1
  - Verify email
  - Login to: https://app.snowflake.com

- [ ] **Save Your Credentials**
  - Account URL: From browser URL or account dropdown
  - Username: Your Snowflake username
  - Password: Your Snowflake password
  - Save these in a safe place

- [ ] **Create Warehouse**
  ```sql
  CREATE WAREHOUSE compute_wh WAREHOUSE_SIZE = 'XSMALL';
  ```

- [ ] **Create Database & Schemas**
  ```sql
  CREATE DATABASE saas_analytics;
  CREATE SCHEMA saas_analytics.bronze;
  CREATE SCHEMA saas_analytics.silver;
  CREATE SCHEMA saas_analytics.gold;
  CREATE SCHEMA saas_analytics.ml;
  ```

- [ ] **Run Full Setup SQL**
  - Copy all of `01_snowflake_setup.sql`
  - Paste into Snowflake SQL Editor
  - Execute (should complete without errors)

- [ ] **Verify Tables Created**
  ```sql
  SELECT * FROM information_schema.tables WHERE table_schema IN ('BRONZE', 'SILVER', 'GOLD');
  ```

---

## ✅ PHASE 2: DATA GENERATION (15 minutes)

- [ ] **Clone/Download Project Files**
  ```bash
  git clone https://github.com/your-username/saas-analytics.git
  cd saas-analytics
  ```

- [ ] **Set Environment Variables (macOS/Linux)**
  ```bash
  export SNOWFLAKE_USER="your_username"
  export SNOWFLAKE_PASSWORD="your_password"
  export SNOWFLAKE_ACCOUNT="xy12345.us-east-1"
  ```

- [ ] **Set Environment Variables (Windows)**
  ```powershell
  $env:SNOWFLAKE_USER="your_username"
  $env:SNOWFLAKE_PASSWORD="your_password"
  $env:SNOWFLAKE_ACCOUNT="xy12345.us-east-1"
  ```

- [ ] **Install Python Dependencies**
  ```bash
  pip install -r requirements.txt
  ```

- [ ] **Run Data Generator**
  ```bash
  python 02_data_generator.py
  ```
  Expected output:
  ```
  ✓ Created 4 cohorts with 2550 total users
  ✓ Generated 52,340 events
  ✓ Connected to Snowflake
  ✓ Loaded 52,340 events into EVENTS
  ```

- [ ] **Verify Data Loaded**
  ```sql
  SELECT COUNT(*) FROM saas_analytics.bronze.events;  -- Should see ~52,000
  SELECT COUNT(DISTINCT user_id) FROM saas_analytics.bronze.events;  -- Should see ~2,550
  ```

---

## ✅ PHASE 3: AI PREDICTIONS (10 minutes)

- [ ] **Load Cortex Predictions**
  - Copy and run first section of `03_cortex_predictions.sql`:
    ```sql
    -- Insert churn predictions
    INSERT INTO saas_analytics.ml.churn_predictions ...
    ```

- [ ] **Verify Predictions Loaded**
  ```sql
  SELECT COUNT(*) FROM saas_analytics.ml.churn_predictions;
  SELECT * FROM saas_analytics.ml.churn_predictions LIMIT 5;
  ```

- [ ] **Optional: Run Anomaly Detection**
  ```sql
  -- Run anomaly detection section
  INSERT INTO saas_analytics.ml.anomalies ...
  ```

---

## ✅ PHASE 4: LOCAL TESTING (15 minutes)

- [ ] **Set Flask Environment**
  ```bash
  cp .env.example .env
  # Edit .env with your credentials
  ```

- [ ] **Create Virtual Environment (Recommended)**
  ```bash
  python -m venv venv
  source venv/bin/activate  # macOS/Linux
  # OR
  venv\Scripts\activate  # Windows
  ```

- [ ] **Start Flask App**
  ```bash
  python 04_flask_app.py
  ```
  Expected output:
  ```
  * Running on http://127.0.0.1:5000
  * Debug mode: on
  ```

- [ ] **Test Dashboard**
  - Open browser: http://localhost:5000
  - Verify KPI cards load
  - Verify charts load
  - Check for any errors in console

- [ ] **Test API Endpoints**
  ```bash
  # In another terminal:
  curl http://localhost:5000/api/kpi-summary
  curl http://localhost:5000/api/daily-metrics
  curl http://localhost:5000/api/churn-segments
  ```

---

## ✅ PHASE 5: RENDER DEPLOYMENT (20 minutes)

### Option A: Deploy with GitHub (Recommended)

- [ ] **Create GitHub Repository**
  ```bash
  git init
  git add .
  git commit -m "Initial commit: SaaS Analytics Platform"
  git remote add origin https://github.com/your-username/saas-analytics.git
  git branch -M main
  git push -u origin main
  ```

- [ ] **Connect Render**
  - Go to: https://render.com
  - Sign up or login
  - Click "New +" → "Web Service"
  - Select "Deploy an existing repo"
  - Connect GitHub account (if not already)
  - Select `saas-analytics` repository

- [ ] **Configure Render Service**
  - **Name:** `saas-analytics`
  - **Environment:** `Docker`
  - **Region:** `us-east-1` (or your region)
  - **Plan:** Free (or Starter for reliability)

- [ ] **Add Environment Variables**
  Click "Advanced" and add:
  ```
  SNOWFLAKE_USER=your_username
  SNOWFLAKE_PASSWORD=your_password
  SNOWFLAKE_ACCOUNT=xy12345.us-east-1
  FLASK_ENV=production
  SECRET_KEY=generate_a_random_secure_key_here
  PORT=10000  # Render assigns this automatically
  ```

- [ ] **Deploy**
  - Click "Create Web Service"
  - Render builds Docker image (5-10 minutes)
  - Wait for "Live" status
  - Get public URL from dashboard

- [ ] **Test Live Dashboard**
  - Copy Render URL (e.g., `https://saas-analytics-xyz.onrender.com`)
  - Open in browser
  - Verify dashboard loads
  - Check all API endpoints work

### Option B: Manual Docker Build

- [ ] **Test Docker Locally**
  ```bash
  docker build -t saas-analytics .
  docker run -p 5000:5000 \
    -e SNOWFLAKE_USER=your_username \
    -e SNOWFLAKE_PASSWORD=your_password \
    -e SNOWFLAKE_ACCOUNT=xy12345.us-east-1 \
    saas-analytics
  ```

- [ ] **Push to Docker Registry**
  ```bash
  # Docker Hub
  docker tag saas-analytics your-username/saas-analytics:latest
  docker push your-username/saas-analytics:latest
  ```

- [ ] **Deploy from Registry**
  - In Render, select "Deploy from image"
  - Use your Docker Hub image URL

---

## ✅ PHASE 6: TABLEAU INTEGRATION (OPTIONAL, 30 minutes)

- [ ] **Create Tableau Account**
  - Option A: Tableau Public (free, data is public)
  - Option B: Tableau Online (paid, private)
  - Option C: Tableau Desktop (free trial)

- [ ] **Connect to Snowflake**
  - Server: `xy12345.us-east-1`
  - Database: `saas_analytics`
  - Username/Password: Your Snowflake creds

- [ ] **Create Sample Dashboard**
  - Create new worksheet
  - Drag `plan_type` to Rows
  - Drag `total_mrr` to Columns
  - Publish to Tableau Server/Online

- [ ] **Get Dashboard URL**
  - Copy public URL
  - Save for embedding

- [ ] **Update Flask App (Optional)**
  - Add `TABLEAU_DASHBOARD_URL` environment variable
  - Uncomment Tableau section in `templates/dashboard.html`
  - Redeploy

---

## ✅ PHASE 7: VERIFICATION & MONITORING

- [ ] **Health Check**
  ```bash
  curl https://your-render-url/health
  # Should return: {"status": "healthy", "timestamp": "..."}
  ```

- [ ] **Monitor Snowflake Usage**
  - Check Snowflake web UI for warehouse activity
  - Verify compute credits are reasonable
  - Set up alerts if needed

- [ ] **Monitor Render Logs**
  - Go to Render dashboard
  - View logs for any errors
  - Check response times

- [ ] **Performance Test**
  - Open dashboard
  - Verify KPIs load in <2 seconds
  - Verify charts render smoothly
  - Test all filter options

---

## ✅ PHASE 8: CUSTOMIZATION & SCALING

- [ ] **Load Your Own Data** (Optional)
  - Modify `02_data_generator.py` to use your data
  - Upload CSV to Snowflake via `COPY` command
  - Update SQL views/tables

- [ ] **Customize Dashboards**
  - Modify `templates/dashboard.html`
  - Add new charts/tables
  - Update colors/branding
  - Redeploy to Render

- [ ] **Add More AI Predictions**
  - Expand `03_cortex_predictions.sql`
  - Add more Cortex functions
  - Create new ML tables

- [ ] **Scale Up**
  - Increase Render plan for higher traffic
  - Increase Snowflake warehouse size if needed
  - Set up caching for dashboards

---

## 🔧 Troubleshooting

### Snowflake Connection Issues
```
Error: "Cannot connect to Snowflake"
→ Verify account ID (format: xy12345.us-east-1)
→ Check username/password
→ Ensure warehouse is running
→ Check IP whitelist (if enabled)
```

### Data Not Loading
```
Error: "Table does not exist"
→ Run 01_snowflake_setup.sql again
→ Verify database/schema names
→ Check GRANT permissions
```

### Render Deployment Failed
```
Error: "Build failed"
→ Check Dockerfile syntax
→ Verify requirements.txt
→ View Render logs for details
→ Ensure Docker image builds locally first
```

### Dashboard Not Loading
```
Error: "Cannot fetch data" or blank dashboard
→ Check Flask logs
→ Verify Snowflake connection
→ Test API endpoints directly
→ Check browser console for JS errors
```

### Slow Queries
```
Issue: Queries take >5 seconds
→ Check Snowflake warehouse size
→ Verify clustering keys are set
→ Review query performance in Snowflake
→ Consider materialized views
```

---

## 📊 After Deployment

### Daily Operations
- ✅ Monitor dashboard alerts
- ✅ Check Snowflake query performance
- ✅ Review ML predictions for accuracy
- ✅ Watch for anomalies in revenue/engagement

### Weekly Tasks
- ✅ Review churn predictions
- ✅ Analyze cohort retention trends
- ✅ Optimize Snowflake queries if needed
- ✅ Update company metrics

### Monthly Tasks
- ✅ Review total cost (Snowflake + Render)
- ✅ Archive old data (optional)
- ✅ Update ML models with new data
- ✅ Gather stakeholder feedback

---

## 🚀 Success Indicators

You'll know it's working when:

- ✅ Dashboard loads in <2 seconds
- ✅ KPI cards show live data
- ✅ Charts display 30-day trends
- ✅ Churn predictions populated
- ✅ Anomalies detected correctly
- ✅ All API endpoints responding
- ✅ Zero errors in logs

---

## 📞 Getting Help

1. **Check README.md** - Full documentation
2. **Review ARCHITECTURE.md** - System design details
3. **Check logs:**
   - Flask: Terminal output
   - Snowflake: Web UI → Query History
   - Render: Dashboard → Logs

4. **Verify setup:**
   - Run health check: `curl /health`
   - Test each API endpoint
   - Check Snowflake data counts

---

## 📝 Next Steps

After deployment:
1. Share dashboard with team
2. Set up data refresh schedule
3. Configure alerts for anomalies
4. Customize for your business metrics
5. Add your own data sources
6. Implement additional ML models

---

**🎉 Congratulations! Your SaaS Analytics Platform is live!**

**Dashboard URL:** `https://your-render-url`
**Snowflake DB:** `saas_analytics`
**Data Warehouse:** `compute_wh`

Share the dashboard link with your team to start exploring insights! 📊
