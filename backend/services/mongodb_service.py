"""
MongoDB Service for BudgetInsight
Handles all database operations
"""

import os
from datetime import datetime

from pymongo import MongoClient
from pymongo.errors import ConnectionFailure


class MongoDBService:
    def __init__(self):
        self.uri = os.getenv("MONGODB_URI", "mongodb://localhost:27017/")
        self.db_name = os.getenv("MONGODB_DATABASE", "budgetinsight")
        self.client = None
        self.db = None
        self.connect()

    def connect(self):
        """Connect to MongoDB"""
        try:
            self.client = MongoClient(self.uri)
            self.db = self.client[self.db_name]
            # Test connection
            self.client.admin.command("ping")
            print("✅ Connected to MongoDB")
        except ConnectionFailure as e:
            print(f"❌ MongoDB connection failed: {str(e)}")
            raise

    def is_connected(self):
        """Check if MongoDB is connected"""
        try:
            self.client.admin.command("ping")
            return True
        except:
            return False

    # ========================================================================
    # USER MANAGEMENT
    # ========================================================================

    def create_user(self, user_data):
        """Create a new user"""
        return self.db.users.insert_one(user_data).inserted_id

    def get_user_by_email(self, email):
        """Get user by email"""
        return self.db.users.find_one({"email": email})

    def get_user_by_id(self, user_id):
        """Get user by user_id"""
        return self.db.users.find_one({"user_id": user_id})

    def update_user_history_id(self, user_id, history_id):
        """Update user's last processed history ID"""
        self.db.users.update_one(
            {"user_id": user_id},
            {"$set": {"last_history_id": history_id, "updated_at": datetime.utcnow()}},
        )

    def add_device_token(self, user_id, device_token):
        """Add device token to user (for push notifications)"""
        self.db.users.update_one(
            {"user_id": user_id},
            {
                "$addToSet": {"device_tokens": device_token},
                "$set": {"updated_at": datetime.utcnow()},
            },
        )

    # ========================================================================
    # TRANSACTION ALERTS
    # ========================================================================

    def save_transaction_alert(self, user_id, alert):
        """Save a transaction alert from email"""
        alert["user_id"] = user_id
        alert["created_at"] = datetime.utcnow()
        alert["is_linked"] = False
        return self.db.transaction_alerts.insert_one(alert).inserted_id

    def get_unlinked_alerts(self, user_id):
        """Get all unlinked transaction alerts for a user"""
        return list(
            self.db.transaction_alerts.find(
                {"user_id": user_id, "is_linked": False}
            ).sort("created_at", -1)
        )

    def link_alert(self, alert_id, transaction_id):
        """Link an alert to a transaction"""
        self.db.transaction_alerts.update_one(
            {"_id": alert_id},
            {
                "$set": {
                    "is_linked": True,
                    "linked_transaction_id": transaction_id,
                    "linked_at": datetime.utcnow(),
                }
            },
        )

    # ========================================================================
    # TRANSACTIONS
    # ========================================================================

    def save_transaction(self, transaction):
        """Save a transaction"""
        transaction["created_at"] = datetime.utcnow()
        return self.db.transactions.insert_one(transaction).inserted_id

    def get_user_transactions(self, user_id, limit=1000):
        """Get all transactions for a user"""
        return list(
            self.db.transactions.find({"user_id": user_id})
            .sort("date", -1)
            .limit(limit)
        )

    def delete_transaction(self, transaction_id):
        """Delete a transaction"""
        self.db.transactions.delete_one({"_id": transaction_id})

    # ========================================================================
    # BUDGET DATA
    # ========================================================================

    def save_user_budget(self, budget_data):
        """Save or update user's budget allocation and income"""
        self.db.budgets.update_one(
            {"user_id": budget_data["user_id"]}, {"$set": budget_data}, upsert=True
        )

    def get_user_budget(self, user_id):
        """Get user's budget allocation and income"""
        budget = self.db.budgets.find_one({"user_id": user_id})
        if budget:
            budget["_id"] = str(budget["_id"])
        return budget or {}

    # ========================================================================
    # SNAPSHOTS (HISTORICAL DATA)
    # ========================================================================

    def save_snapshot(self, snapshot):
        """Save a monthly or yearly snapshot"""
        snapshot["created_at"] = datetime.utcnow()
        return self.db.snapshots.insert_one(snapshot).inserted_id

    def get_snapshots(self, user_id, period_type="monthly", limit=100):
        """Get snapshots for a user"""
        query = {"user_id": user_id, "period_type": period_type}
        return list(self.db.snapshots.find(query).sort("year", -1).limit(limit))

    def get_snapshot_by_period(self, user_id, year, month=None):
        """Get a specific snapshot by period"""
        query = {"user_id": user_id, "year": year}
        if month:
            query["month"] = month
            query["period_type"] = "monthly"
        else:
            query["period_type"] = "yearly"

        return self.db.snapshots.find_one(query)

    # ========================================================================
    # CLEANUP
    # ========================================================================

    def close(self):
        """Close MongoDB connection"""
        if self.client:
            self.client.close()
            print("✅ MongoDB connection closed")
