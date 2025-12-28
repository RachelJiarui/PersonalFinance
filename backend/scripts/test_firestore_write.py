"""
Test Firestore Write Operations
Tests writing to all three main collections: users, transactions, transaction_alerts
"""

import os
import sys
from datetime import datetime

from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Add parent directory to path to import services
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from services.firestore_service import FirestoreService


def test_firestore_writes():
    print("🧪 Testing Firestore Write Operations\n")

    # Initialize Firestore
    db = FirestoreService()

    # Test data
    test_user_id = "test_user_001"
    test_email = "rachel.j.chen+test@gmail.com"

    print("=" * 60)
    print("TEST 1: Write to Users Collection")
    print("=" * 60)

    try:
        user_data = {
            "user_id": test_user_id,
            "email": test_email,
            "device_tokens": ["test_apns_token_123"],
            "last_history_id": "12345",
        }

        user_id = db.create_user(user_data)
        print(f"✅ Successfully created user: {user_id}")
        print(f"   Email: {test_email}")
        print(f"   Device tokens: {user_data['device_tokens']}")
    except Exception as e:
        print(f"❌ Failed to create user: {e}")
        return

    print("\n" + "=" * 60)
    print("TEST 2: Write to Users Budget Subcollection")
    print("=" * 60)

    try:
        budget_data = {
            "annual_salary": 85000,
            "contribution_401k": 5000,
            "monthly_take_home": 5200,
            "categories": [
                {
                    "name": "Food & Dining",
                    "percentage": 15.0,
                    "icon": "fork.knife",
                    "color": "blue",
                },
                {
                    "name": "Transportation",
                    "percentage": 10.0,
                    "icon": "car.fill",
                    "color": "green",
                },
                {
                    "name": "Shopping",
                    "percentage": 20.0,
                    "icon": "bag.fill",
                    "color": "purple",
                },
            ],
        }

        db.save_user_budget(test_user_id, budget_data)
        print(f"✅ Successfully saved budget for user: {test_user_id}")
        print(f"   Annual salary: ${budget_data['annual_salary']:,}")
        print(f"   Monthly take home: ${budget_data['monthly_take_home']:,}")
        print(f"   Categories: {len(budget_data['categories'])}")
    except Exception as e:
        print(f"❌ Failed to save budget: {e}")

    print("\n" + "=" * 60)
    print("TEST 3: Write to Transaction Alerts Collection")
    print("=" * 60)

    try:
        alert_data = {
            "email_id": "test_email_msg_001",
            "amount": 45.67,
            "merchant": "Whole Foods Market",
            "date": datetime.now().isoformat(),
        }

        alert_id = db.save_transaction_alert(test_user_id, alert_data)
        print(f"✅ Successfully created transaction alert: {alert_id}")
        print(f"   Merchant: {alert_data['merchant']}")
        print(f"   Amount: ${alert_data['amount']:.2f}")
        print(f"   Email ID: {alert_data['email_id']}")
    except Exception as e:
        print(f"❌ Failed to create transaction alert: {e}")

    print("\n" + "=" * 60)
    print("TEST 4: Write to Transactions Collection")
    print("=" * 60)

    try:
        transaction_data = {
            "transaction_id": "test_tx_001",
            "user_id": test_user_id,
            "amount": 89.99,
            "merchant": "Amazon",
            "category": "Shopping",
            "date": datetime.now().isoformat(),
            "linked_email_alert_id": None,  # Manually created
        }

        tx_id = db.save_transaction(transaction_data)
        print(f"✅ Successfully created transaction: {tx_id}")
        print(f"   Merchant: {transaction_data['merchant']}")
        print(f"   Amount: ${transaction_data['amount']:.2f}")
        print(f"   Category: {transaction_data['category']}")
        print(f"   Linked to alert: {transaction_data['linked_email_alert_id']}")
    except Exception as e:
        print(f"❌ Failed to create transaction: {e}")

    print("\n" + "=" * 60)
    print("TEST 5: Write Transaction Linked to Alert")
    print("=" * 60)

    try:
        # Create another alert first
        alert_data_2 = {
            "email_id": "test_email_msg_002",
            "amount": 12.50,
            "merchant": "Starbucks",
            "date": datetime.now().isoformat(),
        }

        alert_id_2 = db.save_transaction_alert(test_user_id, alert_data_2)
        print(f"✅ Created alert: {alert_id_2}")

        # Create transaction linked to this alert
        transaction_data_2 = {
            "transaction_id": "test_tx_002",
            "user_id": test_user_id,
            "amount": 12.50,
            "merchant": "Starbucks",
            "category": "Food & Dining",
            "date": datetime.now().isoformat(),
            "linked_email_alert_id": alert_id_2,
        }

        tx_id_2 = db.save_transaction(transaction_data_2)
        print(f"✅ Created transaction: {tx_id_2}")

        # Link them together
        db.link_transaction_to_alert(tx_id_2, alert_id_2)
        print(f"✅ Successfully linked transaction to alert")
        print(f"   Transaction: {tx_id_2}")
        print(f"   Alert: {alert_id_2}")
    except Exception as e:
        print(f"❌ Failed to create linked transaction: {e}")

    print("\n" + "=" * 60)
    print("✅ ALL WRITE TESTS COMPLETED!")
    print("=" * 60)
    print(f"\nTest user ID: {test_user_id}")
    print("You can now run test_firestore_read.py to verify the data")


if __name__ == "__main__":
    test_firestore_writes()
