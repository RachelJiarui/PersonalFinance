"""
Firestore Service for BudgetInsight (Single-User Refactored)
Handles all database operations for rachel.j.chen@gmail.com
"""

import os
from datetime import datetime
from typing import Dict, List, Optional

from google.cloud import firestore


class FirestoreService:
    """Single-user Firestore service - all data belongs to rachel.j.chen@gmail.com"""

    def __init__(self):
        """Initialize Firestore client"""
        # Get project ID from environment or use default
        project_id = os.getenv("GOOGLE_CLOUD_PROJECT", "personal-finance-482417")

        # Initialize Firestore client with explicit project
        # This will use Application Default Credentials (ADC) which works both locally and on Cloud Run
        self.db = firestore.Client(project=project_id)
        self.user_email = "rachel.j.chen@gmail.com"
        print(
            f"✅ Connected to Firestore (single-user mode: {self.user_email}, project: {project_id})"
        )

    # ========================================================================
    # APP SETTINGS
    # ========================================================================

    def get_settings(self) -> Dict:
        """Get app settings including user profile"""
        doc = self.db.collection("app_settings").document("user_profile").get()
        if doc.exists:
            return doc.to_dict()
        return {
            "email": self.user_email,
            "device_tokens": [],
            "last_history_id": None,
        }

    def update_device_token(self, device_token: str):
        """Add device token for push notifications"""
        self.db.collection("app_settings").document("user_profile").set(
            {
                "email": self.user_email,
                "device_tokens": firestore.ArrayUnion([device_token]),
                "updated_at": firestore.SERVER_TIMESTAMP,
            },
            merge=True,
        )

    def update_history_id(self, history_id: str):
        """Update Gmail last processed history ID"""
        self.db.collection("app_settings").document("user_profile").update(
            {"last_history_id": history_id, "updated_at": firestore.SERVER_TIMESTAMP}
        )

    def get_device_tokens(self) -> List[str]:
        """Get all device tokens for push notifications"""
        settings = self.get_settings()
        return settings.get("device_tokens", [])

    # ========================================================================
    # BUDGET CATEGORIES
    # ========================================================================

    def get_budget_categories(self, include_inactive: bool = False) -> List[Dict]:
        """
        Get budget categories

        Args:
            include_inactive: If True, returns all categories. If False, only active ones.
        """
        query = self.db.collection("budget_categories")

        if not include_inactive:
            query = query.where("is_active", "==", True)

        categories = query.stream()
        return [{"id": cat.id, **cat.to_dict()} for cat in categories]

    def get_budget_category(self, category_id: str) -> Optional[Dict]:
        """Get a specific budget category"""
        doc = self.db.collection("budget_categories").document(category_id).get()
        if doc.exists:
            return {"id": doc.id, **doc.to_dict()}
        return None

    def create_budget_category(self, category_data: Dict) -> str:
        """
        Create a new budget category - Firestore auto-generates ID

        Expected fields:
        - name: str
        - percentage: float (0-100)
        - icon: str (SF Symbol name)
        - is_active: bool (default True)
        """
        category_data["created_at"] = firestore.SERVER_TIMESTAMP
        category_data["updated_at"] = firestore.SERVER_TIMESTAMP
        category_data["is_active"] = category_data.get("is_active", True)

        # Remove id if present - let Firestore generate it
        category_data.pop("id", None)

        # Firestore auto-generates ID
        _, doc_ref = self.db.collection("budget_categories").add(category_data)
        return doc_ref.id

    def update_budget_category(self, category_id: str, updates: Dict):
        """
        Update a budget category (only if is_active = True)
        Once is_active = False, category becomes immutable for historical data integrity
        """
        # Check if category is active
        category = self.get_budget_category(category_id)
        if not category:
            raise ValueError(f"Category {category_id} not found")

        if not category.get("is_active", True):
            raise ValueError(
                f"Cannot update inactive category {category_id}. Inactive categories are immutable."
            )

        updates["updated_at"] = firestore.SERVER_TIMESTAMP
        self.db.collection("budget_categories").document(category_id).update(updates)

    def deactivate_budget_category(self, category_id: str):
        """
        Deactivate a budget category (makes it immutable)
        Historical transactions will still reference this category by UUID
        """
        self.db.collection("budget_categories").document(category_id).update(
            {"is_active": False, "updated_at": firestore.SERVER_TIMESTAMP}
        )

    def delete_budget_category(self, category_id: str):
        """
        Delete a budget category (use with caution - prefer deactivation)
        This should only be used if category has no associated transactions
        """
        self.db.collection("budget_categories").document(category_id).delete()

    # ========================================================================
    # TRANSACTIONS
    # ========================================================================

    def get_transactions(
        self,
        category_id: Optional[str] = None,
        start_date: Optional[str] = None,
        end_date: Optional[str] = None,
        limit: int = 1000,
    ) -> List[Dict]:
        """
        Get transactions with optional filtering

        Args:
            category_id: Filter by budget category UUID
            start_date: ISO8601 date string (inclusive)
            end_date: ISO8601 date string (inclusive)
            limit: Maximum number of transactions
        """
        query = self.db.collection("transactions")

        if category_id:
            query = query.where("category_id", "==", category_id)

        if start_date:
            query = query.where("date", ">=", start_date)

        if end_date:
            query = query.where("date", "<=", end_date)

        transactions = (
            query.order_by("date", direction=firestore.Query.DESCENDING)
            .limit(limit)
            .stream()
        )
        return [{"id": tx.id, **tx.to_dict()} for tx in transactions]

    def get_transaction(self, transaction_id: str) -> Optional[Dict]:
        """Get a specific transaction"""
        doc = self.db.collection("transactions").document(transaction_id).get()
        if doc.exists:
            return {"id": doc.id, **doc.to_dict()}
        return None

    def create_transaction(self, transaction_data: Dict) -> str:
        """
        Create a new transaction

        Expected fields:
        - id: str (UUID)
        - amount: float
        - date: str (ISO8601)
        - title: str
        - category_id: str (BudgetCategory UUID)
        - is_expense: bool
        - timestamp: str (ISO8601, defaults to now)
        - linked_email_alert_id: str | null (optional)
        """
        transaction_data["created_at"] = firestore.SERVER_TIMESTAMP
        transaction_data["updated_at"] = firestore.SERVER_TIMESTAMP

        # Set timestamp if not provided
        if "timestamp" not in transaction_data:
            transaction_data["timestamp"] = datetime.now().isoformat()

        # Remove id if present - let Firestore generate it
        transaction_data.pop("id", None)

        # Firestore auto-generates ID
        _, doc_ref = self.db.collection("transactions").add(transaction_data)
        return doc_ref.id

    def update_transaction(self, transaction_id: str, updates: Dict):
        """Update a transaction"""
        updates["updated_at"] = firestore.SERVER_TIMESTAMP
        self.db.collection("transactions").document(transaction_id).update(updates)

    def delete_transaction(self, transaction_id: str):
        """Delete a transaction and unlink any associated alert"""
        # Get transaction to check for linked alert
        transaction = self.get_transaction(transaction_id)
        if transaction and transaction.get("linked_email_alert_id"):
            # Unlink the alert
            self.unlink_alert_from_transaction(transaction["linked_email_alert_id"])

        # Delete the transaction
        self.db.collection("transactions").document(transaction_id).delete()

    def link_transaction_to_alert(self, transaction_id: str, alert_id: str):
        """
        Link a transaction to an alert (bidirectional)
        Updates both Transaction.linkedEmailAlertId and TransactionAlert.linkedTransactionId
        """
        # Update transaction
        self.db.collection("transactions").document(transaction_id).update(
            {
                "linked_email_alert_id": alert_id,
                "updated_at": firestore.SERVER_TIMESTAMP,
            }
        )

        # Update alert
        self.db.collection("transaction_alerts").document(alert_id).update(
            {
                "linked_transaction_id": transaction_id,
                "updated_at": firestore.SERVER_TIMESTAMP,
            }
        )

    # ========================================================================
    # TRANSACTION ALERTS
    # ========================================================================

    def get_transaction_alerts(
        self, resolved: Optional[bool] = None, limit: int = 1000
    ) -> List[Dict]:
        """
        Get transaction alerts

        Args:
            resolved: If True, get only resolved alerts. If False, only unresolved. If None, get all.
            limit: Maximum number of alerts to return
        """
        query = self.db.collection("transaction_alerts")

        # Filter by resolved status (computed from linked_transaction_id)
        if resolved is True:
            query = query.where("linked_transaction_id", "!=", None)
        elif resolved is False:
            query = query.where("linked_transaction_id", "==", None)

        alerts = (
            query.order_by("received_at", direction=firestore.Query.DESCENDING)
            .limit(limit)
            .stream()
        )

        return [{"id": alert.id, **alert.to_dict()} for alert in alerts]

    def get_transaction_alert(self, alert_id: str) -> Optional[Dict]:
        """Get a specific transaction alert"""
        doc = self.db.collection("transaction_alerts").document(alert_id).get()
        if doc.exists:
            return {"id": doc.id, **doc.to_dict()}
        return None

    def create_transaction_alert(self, alert_data: Dict) -> str:
        """
        Create a transaction alert from email

        Expected fields:
        - id: str (UUID)
        - email_id: str (Gmail message ID)
        - merchant: str
        - date: str (ISO8601)
        - amount: float
        - raw_email_body: str
        - received_at: str (ISO8601, defaults to now)
        - linked_transaction_id: str | null (optional)
        """
        alert_data["created_at"] = firestore.SERVER_TIMESTAMP
        alert_data["updated_at"] = firestore.SERVER_TIMESTAMP
        alert_data["linked_transaction_id"] = alert_data.get(
            "linked_transaction_id", None
        )

        # Set received_at if not provided
        if "received_at" not in alert_data:
            alert_data["received_at"] = datetime.now().isoformat()

        # Remove id if present - let Firestore generate it
        alert_data.pop("id", None)

        # Firestore auto-generates ID
        _, doc_ref = self.db.collection("transaction_alerts").add(alert_data)
        return doc_ref.id

    def unlink_alert_from_transaction(self, alert_id: str):
        """Unlink an alert from its transaction (bidirectional)"""
        alert = self.get_transaction_alert(alert_id)
        if alert and alert.get("linked_transaction_id"):
            # Remove link from transaction
            self.db.collection("transactions").document(
                alert["linked_transaction_id"]
            ).update(
                {
                    "linked_email_alert_id": None,
                    "updated_at": firestore.SERVER_TIMESTAMP,
                }
            )

        # Remove link from alert
        self.db.collection("transaction_alerts").document(alert_id).update(
            {
                "linked_transaction_id": None,
                "updated_at": firestore.SERVER_TIMESTAMP,
            }
        )

    def delete_transaction_alert(self, alert_id: str):
        """Delete a transaction alert and unlink from any transaction"""
        # Get alert to check if it's linked
        alert = self.get_transaction_alert(alert_id)
        if alert and alert.get("linked_transaction_id"):
            # Unlink from transaction first
            self.db.collection("transactions").document(
                alert["linked_transaction_id"]
            ).update(
                {
                    "linked_email_alert_id": None,
                    "updated_at": firestore.SERVER_TIMESTAMP,
                }
            )

        # Delete the alert
        self.db.collection("transaction_alerts").document(alert_id).delete()

    # ========================================================================
    # BUDGET PLANS
    # ========================================================================

    def get_budget_plans(self, year: Optional[int] = None) -> List[Dict]:
        """
        Get budget plans

        Args:
            year: Filter by specific year. If None, returns all budget plans.
        """
        query = self.db.collection("budget_plans")

        if year:
            query = query.where("year", "==", year)

        plans = query.order_by("year", direction=firestore.Query.DESCENDING).stream()
        return [{"id": plan.id, **plan.to_dict()} for plan in plans]

    def get_active_budget_plan(self) -> Optional[Dict]:
        """Get the active budget plan (current year)"""
        current_year = datetime.now().year
        plans = self.get_budget_plans(year=current_year)
        return plans[0] if plans else None

    def get_budget_plan(self, plan_id: str) -> Optional[Dict]:
        """Get a specific budget plan"""
        doc = self.db.collection("budget_plans").document(plan_id).get()
        if doc.exists:
            return {"id": doc.id, **doc.to_dict()}
        return None

    def create_budget_plan(self, plan_data: Dict) -> str:
        """
        Create a budget plan

        Expected fields:
        - id: str (UUID)
        - year: int
        - annual_salary_gross: float
        - user_income_id: str (UUID linking to UserIncome)
        - category_ids: [str] (list of active BudgetCategory UUIDs)
        """
        plan_data["created_at"] = firestore.SERVER_TIMESTAMP
        plan_data["updated_at"] = firestore.SERVER_TIMESTAMP

        # Remove id if present - let Firestore generate it
        plan_data.pop("id", None)

        # Firestore auto-generates ID
        _, doc_ref = self.db.collection("budget_plans").add(plan_data)
        return doc_ref.id

    def update_budget_plan(self, plan_id: str, updates: Dict):
        """Update a budget plan"""
        updates["updated_at"] = firestore.SERVER_TIMESTAMP
        self.db.collection("budget_plans").document(plan_id).update(updates)

    def delete_budget_plan(self, plan_id: str):
        """Delete a budget plan"""
        self.db.collection("budget_plans").document(plan_id).delete()

    # ========================================================================
    # USER INCOME
    # ========================================================================

    def get_user_incomes(self, year: Optional[int] = None) -> List[Dict]:
        """
        Get user income records

        Args:
            year: Filter by specific year. If None, returns all records.
        """
        query = self.db.collection("user_incomes")

        if year:
            query = query.where("year", "==", year)

        incomes = query.order_by("year", direction=firestore.Query.DESCENDING).stream()
        return [{"id": income.id, **income.to_dict()} for income in incomes]

    def get_user_income(self, income_id: str) -> Optional[Dict]:
        """Get a specific user income record"""
        doc = self.db.collection("user_incomes").document(income_id).get()
        if doc.exists:
            return {"id": doc.id, **doc.to_dict()}
        return None

    def create_user_income(self, income_data: Dict) -> str:
        """
        Create a user income record

        Expected fields:
        - id: str (UUID)
        - year: int
        - annual_salary: float
        - contribution_401k: float
        - federal_tax: float
        - social_security_tax: float
        - medicare_tax: float
        - ny_state_tax: float
        - nyc_tax: float
        """
        income_data["created_at"] = firestore.SERVER_TIMESTAMP
        income_data["updated_at"] = firestore.SERVER_TIMESTAMP

        # Remove id if present - let Firestore generate it
        income_data.pop("id", None)

        # Firestore auto-generates ID
        _, doc_ref = self.db.collection("user_incomes").add(income_data)
        return doc_ref.id

    def update_user_income(self, income_id: str, updates: Dict):
        """Update a user income record"""
        updates["updated_at"] = firestore.SERVER_TIMESTAMP
        self.db.collection("user_incomes").document(income_id).update(updates)

    def delete_user_income(self, income_id: str):
        """Delete a user income record"""
        self.db.collection("user_incomes").document(income_id).delete()

    # ========================================================================
    # FUNDS
    # ========================================================================

    def get_funds(self, include_inactive: bool = False) -> List[Dict]:
        """
        Get funds

        Args:
            include_inactive: If True, returns all funds. If False, only active ones.
        """
        print(
            f"🔍 [FirestoreService] Fetching funds (include_inactive={include_inactive})"
        )
        query = self.db.collection("funds")

        if not include_inactive:
            query = query.where("is_active", "==", True)

        funds = query.stream()
        funds_list = [{"id": fund.id, **fund.to_dict()} for fund in funds]
        print(f"✅ [FirestoreService] Found {len(funds_list)} funds")
        for fund in funds_list:
            print(
                f"   - {fund.get('name', 'N/A')}: active={fund.get('is_active', 'N/A')}, balance={fund.get('balance', 'N/A')}"
            )
        return funds_list

    def get_fund(self, fund_id: str) -> Optional[Dict]:
        """Get a specific fund"""
        doc = self.db.collection("funds").document(fund_id).get()
        if doc.exists:
            return {"id": doc.id, **doc.to_dict()}
        return None

    def create_fund(self, fund_data: Dict) -> str:
        """
        Create a new fund

        Expected fields:
        - name: str
        - icon: str (SF Symbol name)
        - description: str
        - balance: float
        - goal: float | null (optional)
        - deadline: str | null (ISO8601, optional)
        - is_active: bool (default True)
        """
        fund_data["created_at"] = firestore.SERVER_TIMESTAMP
        fund_data["updated_at"] = firestore.SERVER_TIMESTAMP
        fund_data["is_active"] = fund_data.get("is_active", True)

        # Remove id if present - let Firestore generate it
        fund_data.pop("id", None)

        # Firestore auto-generates ID
        _, doc_ref = self.db.collection("funds").add(fund_data)
        return doc_ref.id

    def update_fund(self, fund_id: str, updates: Dict):
        """Update a fund"""
        updates["updated_at"] = firestore.SERVER_TIMESTAMP
        self.db.collection("funds").document(fund_id).update(updates)

    def delete_fund(self, fund_id: str):
        """Soft delete a fund (set is_active to False)"""
        self.db.collection("funds").document(fund_id).update(
            {"is_active": False, "updated_at": firestore.SERVER_TIMESTAMP}
        )

    # ========================================================================
    # DEBTS
    # ========================================================================

    def get_debts(self, include_inactive: bool = False) -> List[Dict]:
        """
        Get debts

        Args:
            include_inactive: If True, returns all debts. If False, only active ones.
        """
        print(
            f"🔍 [FirestoreService] Fetching debts (include_inactive={include_inactive})"
        )
        query = self.db.collection("debts")

        if not include_inactive:
            query = query.where("is_active", "==", True)

        debts = query.stream()
        debts_list = [{"id": debt.id, **debt.to_dict()} for debt in debts]
        print(f"✅ [FirestoreService] Found {len(debts_list)} debts")
        for debt in debts_list:
            print(
                f"   - {debt.get('name', 'N/A')}: active={debt.get('is_active', 'N/A')}, balance={debt.get('balance', 'N/A')}"
            )
        return debts_list

    def get_debt(self, debt_id: str) -> Optional[Dict]:
        """Get a specific debt"""
        doc = self.db.collection("debts").document(debt_id).get()
        if doc.exists:
            return {"id": doc.id, **doc.to_dict()}
        return None

    def create_debt(self, debt_data: Dict) -> str:
        """
        Create a new debt

        Expected fields:
        - name: str
        - icon: str (SF Symbol name)
        - description: str
        - balance: float
        - goal: float (REQUIRED)
        - deadline: str | null (ISO8601, optional)
        - is_active: bool (default True)
        """
        debt_data["created_at"] = firestore.SERVER_TIMESTAMP
        debt_data["updated_at"] = firestore.SERVER_TIMESTAMP
        debt_data["is_active"] = debt_data.get("is_active", True)

        # Remove id if present - let Firestore generate it
        debt_data.pop("id", None)

        # Firestore auto-generates ID
        _, doc_ref = self.db.collection("debts").add(debt_data)
        return doc_ref.id

    def update_debt(self, debt_id: str, updates: Dict):
        """Update a debt"""
        updates["updated_at"] = firestore.SERVER_TIMESTAMP
        self.db.collection("debts").document(debt_id).update(updates)

    def delete_debt(self, debt_id: str):
        """Soft delete a debt (set is_active to False)"""
        self.db.collection("debts").document(debt_id).update(
            {"is_active": False, "updated_at": firestore.SERVER_TIMESTAMP}
        )

    # ========================================================================
    # TRANSACTION ALLOCATIONS
    # ========================================================================

    def get_allocations(
        self,
        transaction_id: Optional[str] = None,
        destination_type: Optional[str] = None,
        destination_id: Optional[str] = None,
        limit: int = 1000,
    ) -> List[Dict]:
        """
        Get transaction allocations with optional filtering

        Args:
            transaction_id: Filter by transaction ID
            destination_type: Filter by destination type ('category', 'fund', 'debt')
            destination_id: Filter by destination ID
            limit: Maximum number of allocations
        """
        query = self.db.collection("transaction_allocations")

        if transaction_id:
            query = query.where("transaction_id", "==", transaction_id)

        if destination_type:
            query = query.where("destination_type", "==", destination_type)

        if destination_id:
            query = query.where("destination_id", "==", destination_id)

        allocations = (
            query.order_by("allocated_at", direction=firestore.Query.DESCENDING)
            .limit(limit)
            .stream()
        )

        return [{"id": alloc.id, **alloc.to_dict()} for alloc in allocations]

    def get_allocation(self, allocation_id: str) -> Optional[Dict]:
        """Get a specific allocation"""
        doc = (
            self.db.collection("transaction_allocations").document(allocation_id).get()
        )
        if doc.exists:
            return {"id": doc.id, **doc.to_dict()}
        return None

    def create_allocation(self, allocation_data: Dict) -> str:
        """
        Create a new allocation

        Expected fields:
        - transaction_id: str
        - destination_type: str ('category', 'fund', 'debt')
        - destination_id: str
        - amount: float
        - allocated_at: str (ISO8601, defaults to now)
        """
        allocation_data["created_at"] = firestore.SERVER_TIMESTAMP
        allocation_data["updated_at"] = firestore.SERVER_TIMESTAMP

        # Set allocated_at if not provided
        if "allocated_at" not in allocation_data:
            allocation_data["allocated_at"] = datetime.now().isoformat()

        # Remove id if present - let Firestore generate it
        allocation_data.pop("id", None)

        # Firestore auto-generates ID
        _, doc_ref = self.db.collection("transaction_allocations").add(allocation_data)
        return doc_ref.id

    def update_allocation(self, allocation_id: str, updates: Dict):
        """Update an allocation"""
        updates["updated_at"] = firestore.SERVER_TIMESTAMP
        self.db.collection("transaction_allocations").document(allocation_id).update(
            updates
        )

    def delete_allocation(self, allocation_id: str):
        """Delete an allocation"""
        self.db.collection("transaction_allocations").document(allocation_id).delete()

    # ========================================================================
    # SNAPSHOTS
    # ========================================================================

    def get_snapshots(
        self, period_type: str = "monthly", limit: int = 100
    ) -> List[Dict]:
        """
        Get historical snapshots

        Args:
            period_type: 'monthly' or 'yearly'
            limit: Maximum number of snapshots
        """
        query = self.db.collection("snapshots")

        if period_type == "monthly":
            query = query.where("month", "!=", None)
        elif period_type == "yearly":
            query = query.where("month", "==", None)

        snapshots = (
            query.order_by("year", direction=firestore.Query.DESCENDING)
            .order_by("month", direction=firestore.Query.DESCENDING)
            .limit(limit)
            .stream()
        )

        return [{"id": snap.id, **snap.to_dict()} for snap in snapshots]

    def create_snapshot(self, snapshot_data: Dict) -> str:
        """
        Create a snapshot

        Expected fields:
        - id: str (UUID)
        - year: int
        - month: int | null
        - monthly_take_home: float
        - total_spending: float
        - savings: float
        - transaction_count: int
        - created_at: str (ISO8601)
        """
        snapshot_data["created_at"] = firestore.SERVER_TIMESTAMP
        snapshot_data["updated_at"] = firestore.SERVER_TIMESTAMP

        # Remove id if present - let Firestore generate it
        snapshot_data.pop("id", None)

        # Firestore auto-generates ID
        _, doc_ref = self.db.collection("snapshots").add(snapshot_data)
        return doc_ref.id
