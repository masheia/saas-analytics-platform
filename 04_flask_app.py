"""
SaaS Analytics Dashboard - Flask Application
Render-deployable web app with Tableau embedded dashboard
"""

import os
import json
from datetime import datetime, timedelta
from flask import Flask, render_template, jsonify, request
import snowflake.connector
import pandas as pd
from dotenv import load_dotenv
import logging

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ============================================================================
# Flask App Initialization
# ============================================================================

app = Flask(__name__)
app.config['SECRET_KEY'] = os.getenv('SECRET_KEY', 'dev-secret-key')

# ============================================================================
# Snowflake Connection Configuration
# ============================================================================

SNOWFLAKE_CONFIG = {
    'user': os.getenv('SNOWFLAKE_USER'),
    'password': os.getenv('SNOWFLAKE_PASSWORD'),
    'account': os.getenv('SNOWFLAKE_ACCOUNT'),
    'warehouse': 'compute_wh',
    'database': 'saas_analytics',
}

TABLEAU_CONFIG = {
    'server_url': os.getenv('TABLEAU_SERVER_URL', 'https://online.tableau.com'),
    'site_id': os.getenv('TABLEAU_SITE_ID', ''),
    'client_id': os.getenv('TABLEAU_CLIENT_ID', ''),
    'client_secret': os.getenv('TABLEAU_CLIENT_SECRET', ''),
    'workbook_name': os.getenv('TABLEAU_WORKBOOK_NAME', 'SaaS-Analytics'),
    'dashboard_name': os.getenv('TABLEAU_DASHBOARD_NAME', 'Executive-Summary'),
}

# ============================================================================
# Database Connection Pool
# ============================================================================

class SnowflakeConnector:
    """Manages Snowflake connections"""
    
    @staticmethod
    def get_connection():
        """Get a Snowflake connection"""
        try:
            conn = snowflake.connector.connect(**SNOWFLAKE_CONFIG)
            return conn
        except Exception as e:
            logger.error(f"Failed to connect to Snowflake: {e}")
            raise

    @staticmethod
    def query_to_dataframe(sql):
        """Execute query and return pandas DataFrame"""
        try:
            conn = SnowflakeConnector.get_connection()
            df = pd.read_sql(sql, conn)
            conn.close()
            return df
        except Exception as e:
            logger.error(f"Query failed: {e}")
            raise


# ============================================================================
# Queries (Pre-defined, parameterized)
# ============================================================================

QUERIES = {
    'kpi_summary': """
        SELECT 
            COUNT(DISTINCT user_id) AS total_users,
            COUNT(DISTINCT CASE WHEN subscription_status = 'active' THEN user_id END) AS active_users,
            COUNT(DISTINCT CASE WHEN subscription_status = 'churned' THEN user_id END) AS churned_users,
            SUM(daily_revenue) AS total_revenue,
            ROUND(AVG(engagement_score), 2) AS avg_engagement,
            COUNT(DISTINCT CASE WHEN churn_risk_category = 'high_risk' THEN user_id END) AS high_risk_users
        FROM saas_analytics.gold.user_insights_with_ai_v
        WHERE metric_date = CURRENT_DATE()
    """,
    
    'daily_metrics_trend': """
        SELECT 
            metric_date,
            COUNT(DISTINCT user_id) AS active_users,
            SUM(login_count) AS total_logins,
            SUM(feature_usage_count) AS total_features_used,
            SUM(daily_revenue) AS daily_revenue,
            ROUND(AVG(engagement_score), 2) AS avg_engagement
        FROM saas_analytics.gold.user_daily_metrics
        WHERE metric_date >= DATEADD(day, -30, CURRENT_DATE())
        GROUP BY metric_date
        ORDER BY metric_date DESC
    """,
    
    'churn_risk_segmentation': """
        SELECT 
            churn_risk_category,
            COUNT(*) AS user_count,
            ROUND(AVG(churn_probability), 3) AS avg_churn_prob,
            ROUND(SUM(monthly_recurring_revenue), 2) AS total_mrr,
            ROUND(AVG(engagement_score), 2) AS avg_engagement,
            ROUND(AVG(days_since_active), 0) AS avg_days_inactive
        FROM saas_analytics.gold.user_insights_with_ai_v
        WHERE metric_date = CURRENT_DATE()
        GROUP BY churn_risk_category
        ORDER BY avg_churn_prob DESC
    """,
    
    'plan_analysis': """
        SELECT 
            plan_type,
            COUNT(DISTINCT user_id) AS user_count,
            ROUND(SUM(monthly_recurring_revenue), 2) AS total_mrr,
            ROUND(AVG(engagement_score), 2) AS avg_engagement,
            ROUND(COUNT(CASE WHEN subscription_status = 'churned' THEN 1 END) / 
                  COUNT(DISTINCT user_id) * 100, 2) AS churn_rate_pct,
            COUNT(CASE WHEN churn_risk_category = 'high_risk' THEN 1 END) AS high_risk_users
        FROM saas_analytics.gold.user_insights_with_ai_v
        WHERE metric_date = CURRENT_DATE()
        GROUP BY plan_type
        ORDER BY total_mrr DESC
    """,
    
    'cohort_retention': """
        SELECT 
            cohort_month,
            months_since_signup,
            retention_rate,
            cohort_size,
            retained_users,
            revenue_per_user
        FROM saas_analytics.gold.user_cohort_analysis
        ORDER BY cohort_month DESC, months_since_signup ASC
        LIMIT 60
    """,
    
    'real_time_anomalies': """
        SELECT 
            metric_date,
            metric_name,
            expected_value::INT,
            actual_value::INT,
            deviation_pct,
            anomaly_score,
            severity
        FROM saas_analytics.ml.anomalies
        WHERE anomaly_score > 0.5
        ORDER BY anomaly_date DESC
        LIMIT 20
    """
}


# ============================================================================
# Routes - Pages
# ============================================================================

@app.route('/')
def index():
    """Home/Dashboard page"""
    return render_template('dashboard.html', tableau_config=TABLEAU_CONFIG)

@app.route('/health')
def health():
    """Health check endpoint"""
    return jsonify({'status': 'healthy', 'timestamp': datetime.now().isoformat()})

@app.route('/documentation')
def documentation():
    """API documentation"""
    return render_template('documentation.html')


# ============================================================================
# Routes - API Endpoints
# ============================================================================

@app.route('/api/kpi-summary', methods=['GET'])
def get_kpi_summary():
    """Get KPI summary data"""
    try:
        df = SnowflakeConnector.query_to_dataframe(QUERIES['kpi_summary'])
        return jsonify(df.to_dict(orient='records')[0] if len(df) > 0 else {})
    except Exception as e:
        logger.error(f"Error in get_kpi_summary: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/daily-metrics', methods=['GET'])
def get_daily_metrics():
    """Get daily metrics trend"""
    try:
        df = SnowflakeConnector.query_to_dataframe(QUERIES['daily_metrics_trend'])
        df['metric_date'] = pd.to_datetime(df['metric_date']).dt.strftime('%Y-%m-%d')
        return jsonify(df.to_dict(orient='records'))
    except Exception as e:
        logger.error(f"Error in get_daily_metrics: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/churn-segments', methods=['GET'])
def get_churn_segments():
    """Get churn risk segmentation"""
    try:
        df = SnowflakeConnector.query_to_dataframe(QUERIES['churn_risk_segmentation'])
        return jsonify(df.to_dict(orient='records'))
    except Exception as e:
        logger.error(f"Error in get_churn_segments: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/plan-analysis', methods=['GET'])
def get_plan_analysis():
    """Get plan-level analysis"""
    try:
        df = SnowflakeConnector.query_to_dataframe(QUERIES['plan_analysis'])
        return jsonify(df.to_dict(orient='records'))
    except Exception as e:
        logger.error(f"Error in get_plan_analysis: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/cohort-retention', methods=['GET'])
def get_cohort_retention():
    """Get cohort retention analysis"""
    try:
        df = SnowflakeConnector.query_to_dataframe(QUERIES['cohort_retention'])
        df['cohort_month'] = pd.to_datetime(df['cohort_month']).dt.strftime('%Y-%m')
        return jsonify(df.to_dict(orient='records'))
    except Exception as e:
        logger.error(f"Error in get_cohort_retention: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/anomalies', methods=['GET'])
def get_anomalies():
    """Get real-time anomalies"""
    try:
        df = SnowflakeConnector.query_to_dataframe(QUERIES['real_time_anomalies'])
        df['metric_date'] = pd.to_datetime(df['metric_date']).dt.strftime('%Y-%m-%d')
        return jsonify(df.to_dict(orient='records'))
    except Exception as e:
        logger.error(f"Error in get_anomalies: {e}")
        return jsonify({'error': str(e)}), 500


# ============================================================================
# Routes - Data Export
# ============================================================================

@app.route('/api/export/<metric_type>', methods=['GET'])
def export_data(metric_type):
    """Export data as CSV"""
    try:
        if metric_type not in QUERIES:
            return jsonify({'error': f'Unknown metric type: {metric_type}'}), 400
        
        df = SnowflakeConnector.query_to_dataframe(QUERIES[metric_type])
        
        # Return CSV
        csv_string = df.to_csv(index=False)
        return app.response_class(
            response=csv_string,
            mimetype='text/csv',
            headers={'Content-Disposition': f'attachment;filename={metric_type}.csv'}
        )
    except Exception as e:
        logger.error(f"Error in export_data: {e}")
        return jsonify({'error': str(e)}), 500


# ============================================================================
# Error Handlers
# ============================================================================

@app.errorhandler(404)
def not_found(error):
    return jsonify({'error': 'Not found'}), 404

@app.errorhandler(500)
def internal_error(error):
    return jsonify({'error': 'Internal server error'}), 500


# ============================================================================
# CLI Commands
# ============================================================================

@app.cli.command()
def init_db():
    """Initialize database (run setup SQL)"""
    print("Initializing Snowflake database...")
    # This would run the DDL from 01_snowflake_setup.sql
    print("Done!")

@app.cli.command()
def load_data():
    """Load sample data"""
    print("Loading sample data...")
    os.system('python 02_data_generator.py')
    print("Done!")


# ============================================================================
# Main
# ============================================================================

if __name__ == '__main__':
    port = int(os.getenv('PORT', 5000))
    debug = os.getenv('FLASK_ENV') == 'development'
    app.run(host='0.0.0.0', port=port, debug=debug)
