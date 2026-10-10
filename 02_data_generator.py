"""
SaaS Analytics Data Generator
Generates realistic SaaS events for streaming into Snowflake
"""

import os
import json
import uuid
import random
from datetime import datetime, timedelta
from typing import List, Dict, Any
import snowflake.connector
from snowflake.connector.pandas_tools import write_pandas
import pandas as pd
import numpy as np

# ============================================================================
# Configuration
# ============================================================================

SNOWFLAKE_CONFIG = {
    'user': os.getenv('SNOWFLAKE_USER', 'your_username'),
    'password': os.getenv('SNOWFLAKE_PASSWORD', 'your_password'),
    'account': os.getenv('SNOWFLAKE_ACCOUNT', 'xy12345.us-east-1'),  # e.g., ab12345.us-east-1
    'warehouse': 'compute_wh',
    'database': 'saas_analytics',
    'schema': 'bronze',
}

# SaaS configuration
PLANS = ['free', 'pro', 'enterprise']
FEATURES = ['Dashboard', 'Reports', 'API Access', 'Advanced Analytics', 'Custom Integrations']
EVENT_TYPES = ['signup', 'login', 'feature_used', 'purchase', 'churn', 'billing_update']
COMPANIES = ['Acme Corp', 'TechStart Inc', 'DataViz Pro', 'Analytics Hub', 'Cloud Metrics']

# ============================================================================
# User Cohorts (Simulate different user segments)
# ============================================================================

class UserCohort:
    """Represents a cohort of users with similar behavior patterns"""
    
    def __init__(self, cohort_id: str, signup_date: datetime, size: int, plan: str, churn_rate: float):
        self.cohort_id = cohort_id
        self.signup_date = signup_date
        self.size = size
        self.plan = plan
        self.churn_rate = churn_rate
        self.users = self._generate_users()
    
    def _generate_users(self) -> List[Dict[str, Any]]:
        """Generate users for this cohort"""
        users = []
        for i in range(self.size):
            user_id = f"usr_{self.cohort_id}_{i:04d}"
            
            # Determine if user churned
            is_churned = random.random() < self.churn_rate
            
            # Last active date logic
            if is_churned:
                last_active = self.signup_date + timedelta(
                    days=random.randint(7, 180)
                )
            else:
                last_active = datetime.now() - timedelta(
                    days=random.randint(0, 14)
                )
            
            users.append({
                'user_id': user_id,
                'email': f'{user_id}@{random.choice(COMPANIES).lower().replace(" ", "")}.com',
                'company': random.choice(COMPANIES),
                'plan': self.plan,
                'signup_date': self.signup_date,
                'last_active_date': last_active,
                'is_churned': is_churned,
                'churn_date': last_active if is_churned else None,
                'engagement_level': random.choice(['high', 'medium', 'low']),
            })
        return users


class EventGenerator:
    """Generates realistic SaaS events based on user behavior"""
    
    def __init__(self, cohorts: List[UserCohort]):
        self.cohorts = cohorts
        self.all_users = [user for cohort in cohorts for user in cohort.users]
        self.event_counter = 0
    
    def generate_events_for_user(self, user: Dict[str, Any], num_days: int = 30) -> List[Dict[str, Any]]:
        """Generate events for a single user over N days"""
        events = []
        
        # Generate events with different probability based on engagement
        engagement_probs = {
            'high': {'login': 0.8, 'feature': 0.6, 'purchase': 0.1},
            'medium': {'login': 0.4, 'feature': 0.2, 'purchase': 0.02},
            'low': {'login': 0.1, 'feature': 0.05, 'purchase': 0.005},
        }
        
        engagement = user['engagement_level']
        probs = engagement_probs[engagement]
        
        # Determine active date range
        if user['is_churned']:
            end_date = user['churn_date']
        else:
            end_date = datetime.now()
        
        start_date = max(user['signup_date'], end_date - timedelta(days=num_days))
        
        # Generate daily events
        current_date = start_date
        while current_date <= end_date:
            session_id = str(uuid.uuid4())
            
            # Signup event (only on signup date)
            if current_date.date() == user['signup_date'].date():
                events.append(self._create_event(
                    user_id=user['user_id'],
                    event_type='signup',
                    timestamp=user['signup_date'],
                    session_id=session_id,
                    metadata={'plan': user['plan'], 'company': user['company']}
                ))
            
            # Login event
            if random.random() < probs['login']:
                events.append(self._create_event(
                    user_id=user['user_id'],
                    event_type='login',
                    timestamp=current_date + timedelta(hours=random.randint(6, 22)),
                    session_id=session_id,
                    metadata={'login_time': datetime.now().isoformat()}
                ))
                
                # Feature usage events (if logged in)
                for _ in range(random.randint(1, 5)):
                    if random.random() < probs['feature']:
                        events.append(self._create_event(
                            user_id=user['user_id'],
                            event_type='feature_used',
                            timestamp=current_date + timedelta(
                                hours=random.randint(6, 22),
                                minutes=random.randint(0, 59)
                            ),
                            session_id=session_id,
                            metadata={
                                'feature': random.choice(FEATURES),
                                'duration_seconds': random.randint(30, 600)
                            }
                        ))
            
            # Purchase event (for paid plans)
            if user['plan'] != 'free' and random.random() < probs['purchase']:
                events.append(self._create_event(
                    user_id=user['user_id'],
                    event_type='purchase',
                    timestamp=current_date + timedelta(hours=random.randint(6, 22)),
                    session_id=session_id,
                    metadata={
                        'amount': {'pro': 99, 'enterprise': 999}[user['plan']],
                        'currency': 'USD',
                        'plan': user['plan']
                    }
                ))
            
            # Churn event (on last day if churned)
            if user['is_churned'] and current_date.date() == user['churn_date'].date():
                events.append(self._create_event(
                    user_id=user['user_id'],
                    event_type='churn',
                    timestamp=user['churn_date'],
                    session_id=session_id,
                    metadata={'reason': random.choice(['cost', 'unused', 'competitor', 'other'])}
                ))
            
            current_date += timedelta(days=1)
        
        return events
    
    def _create_event(self, user_id: str, event_type: str, timestamp: datetime,
                     session_id: str, metadata: Dict[str, Any]) -> Dict[str, Any]:
        """Create a single event"""
        self.event_counter += 1
        return {
            'event_id': f"evt_{self.event_counter:08d}",
            'event_type': event_type,
            'user_id': user_id,
            'timestamp': timestamp,
            'session_id': session_id,
            'metadata': json.dumps(metadata),
        }
    
    def generate_all_events(self, num_days: int = 90) -> List[Dict[str, Any]]:
        """Generate events for all users"""
        all_events = []
        for user in self.all_users:
            all_events.extend(self.generate_events_for_user(user, num_days))
        return all_events


# ============================================================================
# Snowflake Integration
# ============================================================================

class SnowflakeLoader:
    """Load events into Snowflake"""
    
    def __init__(self, config: Dict[str, str]):
        self.config = config
        self.conn = None
    
    def connect(self):
        """Connect to Snowflake"""
        try:
            self.conn = snowflake.connector.connect(**self.config)
            print("✓ Connected to Snowflake")
        except Exception as e:
            print(f"✗ Failed to connect to Snowflake: {e}")
            raise
    
    def load_events(self, events: List[Dict[str, Any]], table: str = 'EVENTS'):
        """Load events into Snowflake table"""
        if not self.conn:
            raise Exception("Not connected to Snowflake")
        
        try:
            # Convert to DataFrame
            df = pd.DataFrame(events)
            
            # Load into Snowflake
            write_pandas(
                self.conn,
                df,
                table,
                auto_create_table=False,
                overwrite=False
            )
            
            print(f"✓ Loaded {len(events)} events into {table}")
            
            # Verify load
            cursor = self.conn.cursor()
            cursor.execute(f"SELECT COUNT(*) FROM {table}")
            count = cursor.fetchone()[0]
            print(f"  Total rows in table: {count}")
            
        except Exception as e:
            print(f"✗ Failed to load events: {e}")
            raise
    
    def close(self):
        """Close connection"""
        if self.conn:
            self.conn.close()
            print("✓ Disconnected from Snowflake")


# ============================================================================
# Main Execution
# ============================================================================

def main():
    """Generate and load SaaS event data"""
    
    print("=" * 70)
    print("SaaS Analytics Data Generator")
    print("=" * 70)
    
    # Create cohorts (different user segments)
    print("\n📊 Generating user cohorts...")
    cohorts = [
        UserCohort('early_adopters', datetime(2023, 1, 1), 500, 'pro', 0.05),      # Low churn
        UserCohort('wave_2', datetime(2023, 6, 1), 800, 'free', 0.15),              # Medium churn
        UserCohort('recent', datetime(2024, 1, 1), 1200, 'free', 0.25),             # Higher churn
        UserCohort('enterprise', datetime(2023, 3, 1), 50, 'enterprise', 0.02),    # Enterprise, low churn
    ]
    
    total_users = sum(c.size for c in cohorts)
    print(f"✓ Created {len(cohorts)} cohorts with {total_users} total users")
    
    # Generate events
    print("\n📝 Generating events...")
    generator = EventGenerator(cohorts)
    events = generator.generate_all_events(num_days=90)
    print(f"✓ Generated {len(events)} events")
    
    # Show sample
    print("\n📋 Sample events:")
    for event in events[:5]:
        print(f"  {event['event_type']:15} | {event['user_id']} | {event['timestamp']}")
    
    # Statistics
    print("\n📈 Event statistics:")
    event_counts = {}
    for event in events:
        event_counts[event['event_type']] = event_counts.get(event['event_type'], 0) + 1
    
    for event_type, count in sorted(event_counts.items(), key=lambda x: x[1], reverse=True):
        print(f"  {event_type:20} {count:6} ({count/len(events)*100:5.1f}%)")
    
    # Load to Snowflake
    print("\n🚀 Loading to Snowflake...")
    loader = SnowflakeLoader(SNOWFLAKE_CONFIG)
    
    try:
        loader.connect()
        loader.load_events(events, 'EVENTS')
        loader.close()
        print("\n✓ Data generation complete!")
    except Exception as e:
        print(f"\n✗ Error: {e}")
        print("\nTo use this script:")
        print("1. Set environment variables:")
        print("   export SNOWFLAKE_USER='your_username'")
        print("   export SNOWFLAKE_PASSWORD='your_password'")
        print("   export SNOWFLAKE_ACCOUNT='xy12345.us-east-1'")
        print("\n2. Install dependencies:")
        print("   pip install snowflake-connector-python pandas numpy")
        print("\n3. Run this script")


if __name__ == '__main__':
    main()
