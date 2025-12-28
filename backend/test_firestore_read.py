"""
Test Firestore Read Operations
Tests reading from all three main collections: users, transactions, transaction_alerts
"""

import os
import sys

from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Add parent directory to path to import services
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from services.firestore_service import FirestoreService


def test_firestore_reads():
    print("🧪 Testing Firestore Read Operations\n")

    # Initialize Firestore
    db = FirestoreService()

    # Test data (should match what was created in test_firestore_write.py)
    test_user_id = "test_user_001"
    test_email = "rachel.j.chen+test@gmail.com"

    print("=" * 60)
    print("TEST 1: Read User by ID")
    print("=" * 60)

    try:
        user = db.get_user_by_id(test_user_id)
        if user:
            print(f"✅ Successfully read user: {test_user_id}")
            print(f"   Email: {user.get('email')}")
            print(f"   Device tokens: {user.get('device_tokens')}")
            print(f"   Last history ID: {user.get('last_history_id')}")
            print(f"   Created at: {user.get('created_at')}")
        else:
            print(f"❌ User not found: {test_user_id}")
    except Exception as e:
        print(f"❌ Failed to read user: {e}")

    print("\n" + "=" * 60)
    print("TEST 2: Read User by Email")
    print("=" * 60)

    try:
        user = db.get_user_by_email(test_email)
        if user:
            print(f"✅ Successfully read user by email: {test_email}")
            print(f"   User ID: {user.get('user_id')}")
            print(f"   Device tokens: {user.get('device_tokens')}")
        else:
            print(f"❌ User not found with email: {test_email}")
    except Exception as e:
        print(f"❌ Failed to read user by email: {e}")

    print("\n" + "=" * 60)
    print("TEST 3: Read User Budget")
    print("=" * 60)

    try:
        budget = db.get_user_budget(test_user_id)
        if budget:
            print(f"✅ Successfully read budget for user: {test_user_id}")
            print(f"   Annual salary: ${budget.get('annual_salary', 0):,}")
            print(f"   401k contribution: ${budget.get('contribution_401k', 0):,}")
            print(f"   Monthly take home: ${budget.get('monthly_take_home', 0):,}")
            print(f"   Categories: {len(budget.get('categories', []))}")

            if budget.get("categories"):
                print("\n   Budget Categories:")
                for cat in budget.get("categories", []):
                    print(
                        f"      - {cat.get('name')}: {cat.get('percentage')}% ({cat.get('icon')})"
                    )
        else:
            print(f"❌ Budget not found for user: {test_user_id}")
    except Exception as e:
        print(f"❌ Failed to read budget: {e}")

    print("\n" + "=" * 60)
    print("TEST 4: Read All Transactions for User")
    print("=" * 60)

    try:
        transactions = db.get_user_transactions(test_user_id)
        print(f"✅ Successfully read transactions for user: {test_user_id}")
        print(f"   Total transactions: {len(transactions)}")

        if transactions:
            print("\n   Recent Transactions:")
            for tx in transactions[:5]:  # Show first 5
                linked = tx.get("linked_email_alert_id")
                source = f"(linked to {linked})" if linked else "(manual)"
                print(f"      - {tx.get('merchant')}: ${tx.get('amount'):.2f} {source}")
    except Exception as e:
        print(f"❌ Failed to read transactions: {e}")

    print("\n" + "=" * 60)
    print("TEST 5: Read Transaction by ID")
    print("=" * 60)

    try:
        tx = db.get_transaction_by_id("test_tx_001")
        if tx:
            print(f"✅ Successfully read transaction: test_tx_001")
            print(f"   Merchant: {tx.get('merchant')}")
            print(f"   Amount: ${tx.get('amount'):.2f}")
            print(f"   Category: {tx.get('category')}")
            print(f"   Date: {tx.get('date')}")
            print(f"   Linked alert: {tx.get('linked_email_alert_id')}")
        else:
            print(f"❌ Transaction not found: test_tx_001")
    except Exception as e:
        print(f"❌ Failed to read transaction: {e}")

    print("\n" + "=" * 60)
    print("TEST 6: Read All Transaction Alerts for User")
    print("=" * 60)

    try:
        alerts = db.get_all_transaction_alerts(test_user_id)
        print(f"✅ Successfully read transaction alerts for user: {test_user_id}")
        print(f"   Total alerts: {len(alerts)}")

        if alerts:
            print("\n   Transaction Alerts:")
            for alert in alerts:
                status = "linked" if alert.get("is_linked") else "unlinked"
                print(
                    f"      - {alert.get('merchant')}: ${alert.get('amount'):.2f} ({status})"
                )
    except Exception as e:
        print(f"❌ Failed to read transaction alerts: {e}")

    print("\n" + "=" * 60)
    print("TEST 7: Read Unlinked Transaction Alerts")
    print("=" * 60)

    try:
        unlinked_alerts = db.get_unlinked_alerts(test_user_id)
        print(f"✅ Successfully read unlinked alerts for user: {test_user_id}")
        print(f"   Unlinked alerts: {len(unlinked_alerts)}")

        if unlinked_alerts:
            print("\n   Unlinked Alerts (need user action):")
            for alert in unlinked_alerts:
                print(f"      - {alert.get('merchant')}: ${alert.get('amount'):.2f}")
                print(f"        Email ID: {alert.get('email_id')}")
    except Exception as e:
        print(f"❌ Failed to read unlinked alerts: {e}")

    print("\n" + "=" * 60)
    print("TEST 8: Read Transaction Alert by ID")
    print("=" * 60)

    try:
        alert = db.get_transaction_alert_by_id("test_email_msg_001")
        if alert:
            print(f"✅ Successfully read alert: test_email_msg_001")
            print(f"   Merchant: {alert.get('merchant')}")
            print(f"   Amount: ${alert.get('amount'):.2f}")
            print(f"   Is linked: {alert.get('is_linked')}")
            print(f"   Linked to transaction: {alert.get('linked_transaction_id')}")
        else:
            print(f"❌ Alert not found: test_email_msg_001")
    except Exception as e:
        print(f"❌ Failed to read alert: {e}")

    print("\n" + "=" * 60)
    print("✅ ALL READ TESTS COMPLETED!")
    print("=" * 60)
    print(f"\nTest user ID: {test_user_id}")
    print("\nCheck the Firestore Console to verify data:")
    print(
        "https://console.cloud.google.com/firestore/databases/-default-/data/panel?project=personal-finance-482417"
    )


if __name__ == "__main__":
    test_firestore_reads()
