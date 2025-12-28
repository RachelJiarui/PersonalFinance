"""
Firestore Service for BudgetInsight
Handles all database operations with Google Cloud Firestore
"""

import os
from datetime import datetime

from google.cloud import firestore


class FirestoreService:
    def __init__(self):
        """Initialize Firestore client"""
        # Firestore uses GOOGLE_APPLICATION_CREDENTIALS env variable automatically
        self.db = firestore.Client()
        print("✅ Connected to Firestore")

    # ========================================================================
    # USER MANAGEMENT
    # ========================================================================

    def create_user(self, user_data):
        """Create a new user"""
        user_id = user_data["user_id"]
        user_data["created_at"] = firestore.SERVER_TIMESTAMP
        user_data["updated_at"] = firestore.SERVER_TIMESTAMP
        self.db.collection("users").document(user_id).set(user_data)
        return user_id

    def get_user_by_email(self, email):
        """Get user by email"""
        users = (
            self.db.collection("users").where("email", "==", email).limit(1).stream()
        )
        for user in users:
            return user.to_dict()
        return None

    def get_user_by_id(self, user_id):
        """Get user by user_id"""
        doc = self.db.collection("users").document(user_id).get()
        if doc.exists:
            return doc.to_dict()
        return None

    def update_user_history_id(self, user_id, history_id):
        """Update user's last processed history ID"""
        self.db.collection("users").document(user_id).update(
            {"last_history_id": history_id, "updated_at": firestore.SERVER_TIMESTAMP}
        )

    def add_device_token(self, user_id, device_token):
        """Add device token to user (for push notifications)"""
        self.db.collection("users").document(user_id).update(
            {
                "device_tokens": firestore.ArrayUnion([device_token]),
                "updated_at": firestore.SERVER_TIMESTAMP,
            }
        )

    # ========================================================================
    # TRANSACTION ALERTS
    # ========================================================================

    def save_transaction_alert(self, user_id, alert):
        """Save a transaction alert from email"""
        alert["user_id"] = user_id
        alert["created_at"] = firestore.SERVER_TIMESTAMP
        alert["is_linked"] = False

        # Use email_id as document ID to prevent duplicates
        doc_id = alert.get("email_id", None)
        if doc_id:
            self.db.collection("transaction_alerts").document(doc_id).set(alert)
            return doc_id
        else:
            doc_ref = self.db.collection("transaction_alerts").add(alert)
            return doc_ref[1].id

    def get_unlinked_alerts(self, user_id):
        """Get all unlinked transaction alerts for a user"""
        alerts = (
            self.db.collection("transaction_alerts")
            .where("user_id", "==", user_id)
            .where("is_linked", "==", False)
            .order_by("created_at", direction=firestore.Query.DESCENDING)
            .stream()
        )
        return [{"id": alert.id, **alert.to_dict()} for alert in alerts]

    def get_all_transaction_alerts(self, user_id, limit=1000):
        """Get all transaction alerts for a user (linked + unlinked)"""
        alerts = (
            self.db.collection("transaction_alerts")
            .where("user_id", "==", user_id)
            .order_by("created_at", direction=firestore.Query.DESCENDING)
            .limit(limit)
            .stream()
        )
        return [{"id": alert.id, **alert.to_dict()} for alert in alerts]

    def get_transaction_alert_by_id(self, alert_id):
        """Get a single transaction alert by ID"""
        doc = self.db.collection("transaction_alerts").document(alert_id).get()
        if doc.exists:
            return {"id": doc.id, **doc.to_dict()}
        return None

    def link_alert(self, alert_id, transaction_id):
        """Link an alert to a transaction"""
        # Validate alert exists and is unlinked
        alert = self.get_transaction_alert_by_id(alert_id)
        if not alert:
            raise ValueError(f"Alert {alert_id} not found")
        if alert.get("is_linked"):
            raise ValueError(f"Alert {alert_id} is already linked")

        self.db.collection("transaction_alerts").document(alert_id).update(
            {
                "is_linked": True,
                "linked_transaction_id": transaction_id,
                "linked_at": firestore.SERVER_TIMESTAMP,
            }
        )

    def unlink_alert(self, alert_id):
        """Unlink an alert from its transaction"""
        self.db.collection("transaction_alerts").document(alert_id).update(
            {
                "is_linked": False,
                "linked_transaction_id": None,
                "unlinked_at": firestore.SERVER_TIMESTAMP,
            }
        )

    def delete_transaction_alert(self, alert_id):
        """Delete a transaction alert"""
        self.db.collection("transaction_alerts").document(alert_id).delete()

    # ========================================================================
    # TRANSACTIONS
    # ========================================================================

    def save_transaction(self, transaction):
        """Save a transaction"""
        transaction["created_at"] = firestore.SERVER_TIMESTAMP
        transaction["updated_at"] = firestore.SERVER_TIMESTAMP

        # Ensure linked_email_alert_id field exists (can be None)
        if "linked_email_alert_id" not in transaction:
            transaction["linked_email_alert_id"] = None

        # Use transaction_id as document ID if provided
        doc_id = transaction.get("transaction_id", None)
        if doc_id:
            self.db.collection("transactions").document(doc_id).set(transaction)
            return doc_id
        else:
            doc_ref = self.db.collection("transactions").add(transaction)
            return doc_ref[1].id

    def get_user_transactions(self, user_id, limit=1000):
        """Get all transactions for a user"""
        transactions = (
            self.db.collection("transactions")
            .where("user_id", "==", user_id)
            .order_by("date", direction=firestore.Query.DESCENDING)
            .limit(limit)
            .stream()
        )
        return [{"id": tx.id, **tx.to_dict()} for tx in transactions]

    def get_transaction_by_id(self, transaction_id):
        """Get a single transaction by ID"""
        doc = self.db.collection("transactions").document(transaction_id).get()
        if doc.exists:
            return {"id": doc.id, **doc.to_dict()}
        return None

    def update_transaction(self, transaction_id, update_data):
        """Update a transaction"""
        update_data["updated_at"] = firestore.SERVER_TIMESTAMP
        self.db.collection("transactions").document(transaction_id).update(update_data)

    def link_transaction_to_alert(self, transaction_id, alert_id):
        """Link a transaction to an alert (bidirectional)"""
        # Update transaction
        self.db.collection("transactions").document(transaction_id).update(
            {
                "linked_email_alert_id": alert_id,
                "updated_at": firestore.SERVER_TIMESTAMP,
            }
        )
        # Update alert
        self.link_alert(alert_id, transaction_id)

    def unlink_transaction_from_alert(self, transaction_id, alert_id):
        """Unlink a transaction from an alert (bidirectional)"""
        # Update transaction
        self.db.collection("transactions").document(transaction_id).update(
            {
                "linked_email_alert_id": None,
                "updated_at": firestore.SERVER_TIMESTAMP,
            }
        )
        # Update alert
        self.unlink_alert(alert_id)

    def delete_transaction(self, transaction_id):
        """Delete a transaction"""
        self.db.collection("transactions").document(transaction_id).delete()

    def delete_transaction_with_cascade(self, transaction_id):
        """
        Delete a transaction and handle alert unlinking

        If transaction is linked to an alert:
        1. Unlink the alert (set is_linked=False)
        2. Delete the transaction

        This preserves the alert for potential future matching.
        """
        # Get transaction to check if linked
        transaction = self.get_transaction_by_id(transaction_id)
        if not transaction:
            raise ValueError(f"Transaction {transaction_id} not found")

        # If linked to an alert, unlink it
        linked_alert_id = transaction.get("linked_email_alert_id")
        if linked_alert_id:
            self.unlink_alert(linked_alert_id)

        # Delete the transaction
        self.db.collection("transactions").document(transaction_id).delete()

    # ========================================================================
    # BUDGET DATA (Simplified - just two documents per user)
    # ========================================================================

    def save_user_budget(self, user_id, budget_data):
        """Save or update user's budget allocation and income"""
        budget_data["user_id"] = user_id
        budget_data["updated_at"] = firestore.SERVER_TIMESTAMP

        # Store in users/{user_id}/data/budget
        self.db.collection("users").document(user_id).collection("data").document(
            "budget"
        ).set(budget_data, merge=True)

    def get_user_budget(self, user_id):
        """Get user's budget allocation and income"""
        doc = (
            self.db.collection("users")
            .document(user_id)
            .collection("data")
            .document("budget")
            .get()
        )
        if doc.exists:
            return doc.to_dict()
        return {}

    def delete_user_budget(self, user_id):
        """Delete user's entire budget"""
        self.db.collection("users").document(user_id).collection("data").document(
            "budget"
        ).delete()

    def update_budget_categories(self, user_id, categories):
        """Update only the budget categories"""
        self.db.collection("users").document(user_id).collection("data").document(
            "budget"
        ).update({"categories": categories, "updated_at": firestore.SERVER_TIMESTAMP})

    def update_budget_income(self, user_id, income_data):
        """Update only the income fields"""
        update_dict = {"updated_at": firestore.SERVER_TIMESTAMP}

        # Add income fields if provided
        if "annual_salary" in income_data:
            update_dict["annual_salary"] = income_data["annual_salary"]
        if "contribution_401k" in income_data:
            update_dict["contribution_401k"] = income_data["contribution_401k"]
        if "monthly_take_home" in income_data:
            update_dict["monthly_take_home"] = income_data["monthly_take_home"]

        self.db.collection("users").document(user_id).collection("data").document(
            "budget"
        ).update(update_dict)

    # ========================================================================
    # SNAPSHOTS (HISTORICAL DATA) - Optional for your use case
    # ========================================================================

    def save_snapshot(self, user_id, snapshot):
        """Save a monthly or yearly snapshot"""
        snapshot["user_id"] = user_id
        snapshot["created_at"] = firestore.SERVER_TIMESTAMP

        # Create unique ID: user_id_year_month (or user_id_year for yearly)
        if snapshot.get("month"):
            doc_id = f"{user_id}_{snapshot['year']}_{snapshot['month']:02d}"
        else:
            doc_id = f"{user_id}_{snapshot['year']}"

        self.db.collection("snapshots").document(doc_id).set(snapshot, merge=True)
        return doc_id

    def get_snapshots(self, user_id, period_type="monthly", limit=100):
        """Get snapshots for a user"""
        snapshots = (
            self.db.collection("snapshots")
            .where("user_id", "==", user_id)
            .where("period_type", "==", period_type)
            .order_by("year", direction=firestore.Query.DESCENDING)
            .limit(limit)
            .stream()
        )
        return [{"id": snap.id, **snap.to_dict()} for snap in snapshots]

    def get_snapshot_by_period(self, user_id, year, month=None):
        """Get a specific snapshot by period"""
        if month:
            doc_id = f"{user_id}_{year}_{month:02d}"
        else:
            doc_id = f"{user_id}_{year}"

        doc = self.db.collection("snapshots").document(doc_id).get()
        if doc.exists:
            return doc.to_dict()
        return None

    # ========================================================================
    # CLEANUP
    # ========================================================================

    def close(self):
        """Close Firestore connection (not needed, but kept for compatibility)"""
        print("✅ Firestore connection closed")
