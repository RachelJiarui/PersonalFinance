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
        """Delete a transaction"""
        self.db.collection("transactions").document(transaction_id).delete()

    # ========================================================================
    # BUDGET PLANS
    # ========================================================================

    def _same_month_year(self, date1: datetime, date2: datetime) -> bool:
        """
        Check if two dates are in the same month and year

        Args:
            date1: First date
            date2: Second date

        Returns:
            True if same month/year, False otherwise
        """
        return date1.year == date2.year and date1.month == date2.month

    def _ranges_overlap(
        self,
        start1: datetime,
        end1: Optional[datetime],
        start2: datetime,
        end2: Optional[datetime],
    ) -> bool:
        """
        Check if two date ranges overlap (exclusive end dates)

        Args:
            start1: Start of first range (created_at)
            end1: End of first range (end_date, None if active)
            start2: Start of second range (created_at)
            end2: End of second range (end_date, None if active)

        Returns:
            True if ranges overlap, False otherwise
        """
        # Convert to month precision (first day of month)
        s1 = datetime(start1.year, start1.month, 1)
        s2 = datetime(start2.year, start2.month, 1)

        e1 = datetime(end1.year, end1.month, 1) if end1 else None
        e2 = datetime(end2.year, end2.month, 1) if end2 else None

        # If both ranges are infinite (no end), they overlap
        if e1 is None and e2 is None:
            return True

        # If one range is infinite
        if e1 is None:
            return s1 < e2
        if e2 is None:
            return s2 < e1

        # Both ranges are finite: overlap if start1 < end2 AND start2 < end1
        return s1 < e2 and s2 < e1

    def _validate_budget_plan_invariants(
        self, plan_data: Dict, plan_id: Optional[str] = None
    ) -> bool:
        """
        Enforce 4 budget plan invariants:
        1. Only ONE active plan (end_date = null) at any time
        2. created_at != end_date (must cover at least one month)
        3. No overlapping ranges
        4. created_at < end_date (chronological)

        Args:
            plan_data: Budget plan data to validate
            plan_id: ID of plan being updated (None for new plans)

        Returns:
            True if all invariants pass, False otherwise
        """
        # Parse dates
        try:
            created_at_str = plan_data.get("created_at")
            if not created_at_str:
                return False

            created_at = datetime.fromisoformat(created_at_str.replace("Z", "+00:00"))
        except Exception:
            return False

        end_date = None
        if plan_data.get("end_date"):
            try:
                end_date = datetime.fromisoformat(
                    plan_data["end_date"].replace("Z", "+00:00")
                )
            except Exception:
                return False

        # Invariant 2 & 4: Date validation
        if end_date:
            # Invariant 2: Must cover at least one month
            if self._same_month_year(created_at, end_date):
                return False

            # Invariant 4: Chronological order
            if created_at >= end_date:
                return False

        # Invariant 1: Only one active plan
        if end_date is None:
            active_plans = self.get_active_budget_plans()
            # If updating existing plan, allow it
            for active_plan in active_plans:
                if plan_id and active_plan["id"] == plan_id:
                    continue  # Skip self
                return False

        # Invariant 3: No overlapping ranges
        all_plans = self.get_budget_plans()
        for existing_plan in all_plans:
            # Skip self when updating
            if plan_id and existing_plan["id"] == plan_id:
                continue

            # Skip old schema plans that don't have created_at
            if "created_at" not in existing_plan:
                continue

            try:
                existing_start = datetime.fromisoformat(
                    existing_plan["created_at"].replace("Z", "+00:00")
                )
                existing_end = None
                if existing_plan.get("end_date"):
                    existing_end = datetime.fromisoformat(
                        existing_plan["end_date"].replace("Z", "+00:00")
                    )

                if self._ranges_overlap(
                    created_at, end_date, existing_start, existing_end
                ):
                    return False
            except Exception:
                continue

        return True

    def get_budget_plans(self, year: Optional[int] = None) -> List[Dict]:
        """
        Get all budget plans

        Args:
            year: DEPRECATED - kept for backward compatibility during migration
                  Returns all plans regardless of year in new schema

        Returns:
            List of all budget plans ordered by created_at descending
        """
        query = self.db.collection("budget_plans")
        plans = query.order_by(
            "created_at", direction=firestore.Query.DESCENDING
        ).stream()
        return [{"id": plan.id, **plan.to_dict()} for plan in plans]

    def get_active_budget_plans(self) -> List[Dict]:
        """
        Get all active budget plans (end_date = null)

        Note: Should only return ONE plan due to invariant enforcement

        Returns:
            List of active budget plans (should be length 0 or 1)
        """
        query = self.db.collection("budget_plans").where("end_date", "==", None)
        plans = query.stream()
        return [{"id": plan.id, **plan.to_dict()} for plan in plans]

    def get_active_budget_plan(self) -> Optional[Dict]:
        """
        Get the single active budget plan (end_date = null)

        Returns:
            The active budget plan, or None if no active plan exists
        """
        active_plans = self.get_active_budget_plans()

        if len(active_plans) == 0:
            return None

        if len(active_plans) > 1:
            print(f"⚠️ [WARNING] Multiple active budget plans found - data corruption!")
            # Return the most recent one
            active_plans.sort(key=lambda p: p.get("created_at", ""), reverse=True)

        return active_plans[0]

    def get_budget_plan(self, plan_id: str) -> Optional[Dict]:
        """Get a specific budget plan"""
        doc = self.db.collection("budget_plans").document(plan_id).get()
        if doc.exists:
            return {"id": doc.id, **doc.to_dict()}
        return None

    def get_budget_plan_for_date(self, target_date: datetime) -> Optional[Dict]:
        """
        Get the budget plan that covers a specific date

        Returns the plan where:
        created_at <= target_date < end_date (or end_date is null)

        Args:
            target_date: The date to check

        Returns:
            The budget plan covering that date, or None
        """
        # Normalize to month precision
        target_month = datetime(target_date.year, target_date.month, 1)

        # Fetch all plans (we need to filter in Python due to Firestore range query limitations)
        all_plans = self.get_budget_plans()

        for plan in all_plans:
            try:
                created_at = datetime.fromisoformat(
                    plan["created_at"].replace("Z", "+00:00")
                )
                created_month = datetime(created_at.year, created_at.month, 1)

                end_month = None
                if plan.get("end_date"):
                    end_date = datetime.fromisoformat(
                        plan["end_date"].replace("Z", "+00:00")
                    )
                    end_month = datetime(end_date.year, end_date.month, 1)

                # Check if target falls within range [created_month, end_month)
                if created_month <= target_month:
                    if end_month is None or target_month < end_month:
                        return plan
            except Exception as e:
                print(
                    f"⚠️ [BudgetPlan] Error parsing dates for plan {plan.get('id')}: {e}"
                )
                continue

        return None

    def create_budget_plan(self, plan_data: Dict) -> str:
        """
        Create a budget plan with monthly time-range model

        Expected fields:
        - created_at: str (ISO8601 month/year - e.g., "2025-03-01T00:00:00Z")
        - end_date: str | null (ISO8601 month/year, exclusive, null = active)
        - annual_salary: float
        - contribution_401k: float
        - federal_tax: float
        - social_security_tax: float
        - medicare_tax: float
        - ny_state_tax: float
        - nyc_tax: float
        - category_ids: [str] (list of active BudgetCategory UUIDs)

        Returns:
            Firestore-generated document ID

        Raises:
            ValueError: If budget plan violates invariants
        """
        # Validation: Check invariants before creation
        if not self._validate_budget_plan_invariants(plan_data):
            raise ValueError("Budget plan violates invariants")

        # Add Firestore timestamps
        plan_data["created_at_firestore"] = firestore.SERVER_TIMESTAMP
        plan_data["updated_at"] = firestore.SERVER_TIMESTAMP

        # Remove id if present - let Firestore generate it
        plan_data.pop("id", None)

        # Firestore auto-generates ID
        _, doc_ref = self.db.collection("budget_plans").add(plan_data)
        print(f"✅ [BudgetPlan] Created budget plan with ID: {doc_ref.id}")
        return doc_ref.id

    def update_budget_plan(self, plan_id: str, updates: Dict):
        """
        Update a budget plan

        Note: Typically used to set end_date when creating new plan.
        Updates are validated against invariants.

        Args:
            plan_id: ID of plan to update
            updates: Fields to update

        Raises:
            ValueError: If updates would violate invariants
        """
        # Get existing plan
        existing_plan = self.get_budget_plan(plan_id)
        if not existing_plan:
            raise ValueError(f"Budget plan {plan_id} not found")

        # Merge updates with existing data for validation
        updated_plan = {**existing_plan, **updates}

        # Validate if critical fields are being changed
        if "created_at" in updates or "end_date" in updates:
            if not self._validate_budget_plan_invariants(updated_plan, plan_id):
                raise ValueError("Budget plan update violates invariants")

        updates["updated_at"] = firestore.SERVER_TIMESTAMP
        self.db.collection("budget_plans").document(plan_id).update(updates)
        print(f"✅ [BudgetPlan] Updated budget plan {plan_id}")

    def delete_budget_plan(self, plan_id: str):
        """Delete a budget plan"""
        self.db.collection("budget_plans").document(plan_id).delete()

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
        try:
            query = self.db.collection("snapshots")

            # Simplified query to avoid composite index requirement
            # Filter in Python instead of Firestore for now
            all_snapshots = query.limit(limit * 2).stream()

            results = []
            for snap in all_snapshots:
                data = snap.to_dict()
                if period_type == "monthly":
                    if data.get("month") is not None:
                        results.append({"id": snap.id, **data})
                elif period_type == "yearly":
                    if data.get("month") is None:
                        results.append({"id": snap.id, **data})
                else:
                    results.append({"id": snap.id, **data})

            # Sort in Python
            results.sort(
                key=lambda x: (x.get("year", 0), x.get("month") or 0), reverse=True
            )

            return results[:limit]
        except Exception as e:
            print(f"Error fetching snapshots: {e}")
            return []

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

    # ========================================================================
    # TRANSACTION ALERTS
    # ========================================================================

    def get_transaction_alerts(
        self, is_resolved: Optional[bool] = None, limit: int = 100
    ) -> List[Dict]:
        """
        Get transaction alerts

        Args:
            is_resolved: Filter by resolution status (None = all)
            limit: Maximum number of alerts
        """
        query = self.db.collection("transaction_alerts")

        if is_resolved is not None:
            query = query.where("is_resolved", "==", is_resolved)

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

    def get_transaction_alert_by_email_id(self, email_id: str) -> Optional[Dict]:
        """Get transaction alert by Gmail message ID (prevents duplicates)"""
        query = (
            self.db.collection("transaction_alerts")
            .where("email_id", "==", email_id)
            .limit(1)
        )
        results = list(query.stream())
        if results:
            doc = results[0]
            return {"id": doc.id, **doc.to_dict()}
        return None

    def create_transaction_alert(self, alert_data: Dict) -> str:
        """
        Create a new transaction alert

        Expected fields:
        - email_id: str (Gmail message ID, unique)
        - merchant: str
        - transaction_date: str (ISO8601)
        - amount: float
        - raw_email_body: str
        - card_last4: str | null (optional)
        - received_at: str (ISO8601, defaults to now)
        - is_resolved: bool (default False)
        - resolved_transaction_id: str | null (optional)
        """
        # Check for duplicate email_id
        existing = self.get_transaction_alert_by_email_id(alert_data.get("email_id"))
        if existing:
            print(
                f"⚠️ [TransactionAlert] Duplicate email_id {alert_data.get('email_id')}, skipping"
            )
            return existing["id"]

        alert_data["created_at"] = firestore.SERVER_TIMESTAMP
        alert_data["updated_at"] = firestore.SERVER_TIMESTAMP

        # Set defaults
        if "received_at" not in alert_data:
            alert_data["received_at"] = datetime.now().isoformat()

        if "is_resolved" not in alert_data:
            alert_data["is_resolved"] = False

        # Remove id if present - let Firestore generate it
        alert_data.pop("id", None)

        # Firestore auto-generates ID
        _, doc_ref = self.db.collection("transaction_alerts").add(alert_data)
        print(f"✅ [TransactionAlert] Created alert with ID: {doc_ref.id}")
        return doc_ref.id

    def update_transaction_alert(self, alert_id: str, updates: Dict):
        """Update a transaction alert"""
        updates["updated_at"] = firestore.SERVER_TIMESTAMP
        self.db.collection("transaction_alerts").document(alert_id).update(updates)

    def delete_transaction_alert(self, alert_id: str):
        """Delete a transaction alert"""
        self.db.collection("transaction_alerts").document(alert_id).delete()
