"""
Migration Script: Budget Plan Rework
Transform Budget Plans from yearly versioning to monthly time-range model
Merge UserIncome into BudgetPlan

Run this script ONCE to migrate existing data.
BACKUP YOUR DATA BEFORE RUNNING!
"""

import os
import sys
from datetime import datetime
from typing import Dict, List, Optional

# Add parent directory to path to import services
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from services.firestore_service import FirestoreService


class BudgetPlanMigration:
    def __init__(self):
        self.db = FirestoreService()
        self.stats = {
            "budget_plans_processed": 0,
            "budget_plans_migrated": 0,
            "user_incomes_processed": 0,
            "errors": [],
        }

    def backup_collections(self):
        """Create backup of budget_plans and user_incomes collections"""
        print("=" * 80)
        print("STEP 1: Creating backups")
        print("=" * 80)

        try:
            # Backup budget_plans
            budget_plans = self.db.db.collection("budget_plans").stream()
            for plan in budget_plans:
                plan_data = plan.to_dict()
                self.db.db.collection("budget_plans_backup").document(plan.id).set(
                    plan_data
                )
            print("✅ Backed up budget_plans collection")

            # Backup user_incomes
            user_incomes = self.db.db.collection("user_incomes").stream()
            for income in user_incomes:
                income_data = income.to_dict()
                self.db.db.collection("user_incomes_backup").document(income.id).set(
                    income_data
                )
            print("✅ Backed up user_incomes collection")

            print("\n")
        except Exception as e:
            print(f"❌ Backup failed: {e}")
            raise

    def get_user_income_for_plan(self, user_income_id: str) -> Optional[Dict]:
        """Fetch UserIncome by ID"""
        try:
            doc = self.db.db.collection("user_incomes").document(user_income_id).get()
            if doc.exists:
                return {"id": doc.id, **doc.to_dict()}
            return None
        except Exception as e:
            print(f"⚠️ Error fetching user income {user_income_id}: {e}")
            return None

    def migrate_plan(self, old_plan: Dict) -> Optional[Dict]:
        """
        Transform old budget plan to new schema

        Old schema:
        - year, annualSalaryGross, userIncomeId, categoryIds
        - isActive, effectiveDate, endDate, versionNumber, changeReason, supersededByPlanId

        New schema:
        - createdAt (from effectiveDate), endDate, categoryIds
        - annualSalary, contribution401k, federalTax, socialSecurityTax, medicareTax, nyStateTax, nycTax
        """
        try:
            # Fetch associated UserIncome
            user_income_id = old_plan.get("user_income_id")
            if not user_income_id:
                self.stats["errors"].append(
                    f"Plan {old_plan['id']} missing user_income_id"
                )
                return None

            user_income = self.get_user_income_for_plan(user_income_id)
            if not user_income:
                self.stats["errors"].append(
                    f"Plan {old_plan['id']}: UserIncome {user_income_id} not found"
                )
                return None

            # Convert effectiveDate to createdAt (normalize to first of month)
            effective_date_str = old_plan.get("effective_date")
            if not effective_date_str:
                self.stats["errors"].append(
                    f"Plan {old_plan['id']} missing effective_date"
                )
                return None

            effective_date = datetime.fromisoformat(
                effective_date_str.replace("Z", "+00:00")
            )
            # Normalize to first day of month
            created_at = datetime(effective_date.year, effective_date.month, 1)

            # Convert endDate (keep as-is if exists, else None)
            end_date = None
            if old_plan.get("end_date"):
                end_date_parsed = datetime.fromisoformat(
                    old_plan["end_date"].replace("Z", "+00:00")
                )
                # Normalize to first day of month
                end_date = datetime(end_date_parsed.year, end_date_parsed.month, 1)

            # Build new plan data
            new_plan = {
                "created_at": created_at.isoformat(),
                "end_date": end_date.isoformat() if end_date else None,
                "annual_salary": user_income.get("annual_salary", 0.0),
                "contribution_401k": user_income.get("contribution_401k", 0.0),
                "federal_tax": user_income.get("federal_tax", 0.0),
                "social_security_tax": user_income.get("social_security_tax", 0.0),
                "medicare_tax": user_income.get("medicare_tax", 0.0),
                "ny_state_tax": user_income.get("ny_state_tax", 0.0),
                "nyc_tax": user_income.get("nyc_tax", 0.0),
                "category_ids": old_plan.get("category_ids", []),
            }

            return new_plan

        except Exception as e:
            self.stats["errors"].append(f"Error migrating plan {old_plan['id']}: {e}")
            return None

    def validate_migration(self, new_plans: List[Dict]) -> bool:
        """
        Validate that migrated plans satisfy all invariants
        """
        print("=" * 80)
        print("STEP 3: Validating migration")
        print("=" * 80)

        active_count = 0
        for plan in new_plans:
            if plan.get("end_date") is None:
                active_count += 1

        # Invariant 1: Only one active plan
        if active_count > 1:
            print(f"❌ Invariant 1 failed: {active_count} active plans found")
            return False
        print(f"✅ Invariant 1: Only {active_count} active plan(s)")

        # Check for overlapping ranges
        for i, plan1 in enumerate(new_plans):
            for j, plan2 in enumerate(new_plans):
                if i >= j:
                    continue

                # Check overlap
                start1 = datetime.fromisoformat(
                    plan1["created_at"].replace("Z", "+00:00")
                )
                end1 = (
                    datetime.fromisoformat(plan1["end_date"].replace("Z", "+00:00"))
                    if plan1.get("end_date")
                    else None
                )

                start2 = datetime.fromisoformat(
                    plan2["created_at"].replace("Z", "+00:00")
                )
                end2 = (
                    datetime.fromisoformat(plan2["end_date"].replace("Z", "+00:00"))
                    if plan2.get("end_date")
                    else None
                )

                if self.db._ranges_overlap(start1, end1, start2, end2):
                    print(f"❌ Invariant 3 failed: Plans overlap")
                    print(f"   Plan 1: {start1} - {end1}")
                    print(f"   Plan 2: {start2} - {end2}")
                    return False

        print("✅ Invariant 3: No overlapping ranges")

        # Validate dates
        for plan in new_plans:
            created_at = datetime.fromisoformat(
                plan["created_at"].replace("Z", "+00:00")
            )
            if plan.get("end_date"):
                end_date = datetime.fromisoformat(
                    plan["end_date"].replace("Z", "+00:00")
                )

                # Invariant 2: created_at != end_date
                if self.db._same_month_year(created_at, end_date):
                    print(f"❌ Invariant 2 failed: same month/year")
                    return False

                # Invariant 4: created_at < end_date
                if created_at >= end_date:
                    print(f"❌ Invariant 4 failed: created_at >= end_date")
                    return False

        print("✅ Invariant 2 & 4: Date validation passed")
        print("\n")
        return True

    def verify_snapshot_references(self):
        """Verify all snapshots still reference valid budget plan IDs"""
        print("=" * 80)
        print("STEP 4: Verifying snapshot references")
        print("=" * 80)

        try:
            # Get all migrated plan IDs
            migrated_plans = self.db.db.collection("budget_plans").stream()
            valid_plan_ids = {plan.id for plan in migrated_plans}

            # Check all snapshots
            snapshots = self.db.db.collection("snapshots").stream()
            invalid_refs = []

            for snapshot in snapshots:
                snapshot_data = snapshot.to_dict()
                budget_plan_id = snapshot_data.get("budget_plan_id")

                if budget_plan_id and budget_plan_id not in valid_plan_ids:
                    invalid_refs.append(snapshot.id)

            if invalid_refs:
                print(
                    f"⚠️ Warning: {len(invalid_refs)} snapshots reference non-existent plans"
                )
                print(f"   Snapshot IDs: {invalid_refs[:5]}...")
            else:
                print("✅ All snapshot references are valid")

            print("\n")
        except Exception as e:
            print(f"❌ Error verifying snapshots: {e}")

    def run_migration(self):
        """Execute the migration"""
        print("\n")
        print("=" * 80)
        print("BUDGET PLAN MIGRATION - Yearly Versioning → Monthly Time-Range")
        print("=" * 80)
        print("\n")

        # Step 1: Backup
        self.backup_collections()

        # Step 2: Migrate plans
        print("=" * 80)
        print("STEP 2: Migrating budget plans")
        print("=" * 80)

        old_plans = list(self.db.db.collection("budget_plans").stream())
        self.stats["budget_plans_processed"] = len(old_plans)

        print(f"Found {len(old_plans)} budget plans to migrate\n")

        new_plans_to_create = []
        plan_id_mapping = {}  # old_id -> new_id for reference updates

        for old_plan_doc in old_plans:
            old_plan = {"id": old_plan_doc.id, **old_plan_doc.to_dict()}
            print(f"Processing plan {old_plan['id']}...")

            new_plan = self.migrate_plan(old_plan)
            if new_plan:
                # Keep the same Firestore ID for continuity
                new_plans_to_create.append((old_plan["id"], new_plan))
                plan_id_mapping[old_plan["id"]] = old_plan["id"]
                print(f"  ✅ Migrated successfully")
            else:
                print(f"  ❌ Migration failed (see errors)")

        print(f"\nMigrated {len(new_plans_to_create)} / {len(old_plans)} plans\n")

        # Step 3: Validate
        if not self.validate_migration([p[1] for p in new_plans_to_create]):
            print("❌ Validation failed! Migration aborted.")
            print("   Data has NOT been modified (backups preserved)")
            return False

        # Step 4: Write to Firestore
        print("=" * 80)
        print("STEP 5: Writing to Firestore")
        print("=" * 80)

        try:
            # Delete old plans first
            for old_plan_doc in old_plans:
                self.db.db.collection("budget_plans").document(old_plan_doc.id).delete()
            print(f"✅ Deleted {len(old_plans)} old plans")

            # Create new plans with same IDs
            for plan_id, new_plan_data in new_plans_to_create:
                self.db.db.collection("budget_plans").document(plan_id).set(
                    new_plan_data
                )
                self.stats["budget_plans_migrated"] += 1

            print(f"✅ Created {len(new_plans_to_create)} migrated plans")
            print("\n")

        except Exception as e:
            print(f"❌ Error writing to Firestore: {e}")
            print("   ROLLING BACK...")
            self.rollback()
            return False

        # Step 5: Verify snapshots
        self.verify_snapshot_references()

        # Step 6: Summary
        self.print_summary()

        return True

    def rollback(self):
        """Restore from backup"""
        print("\n")
        print("=" * 80)
        print("ROLLBACK: Restoring from backup")
        print("=" * 80)

        try:
            # Restore budget_plans
            backup_plans = self.db.db.collection("budget_plans_backup").stream()
            for plan in backup_plans:
                plan_data = plan.to_dict()
                self.db.db.collection("budget_plans").document(plan.id).set(plan_data)
            print("✅ Restored budget_plans from backup")

            # Restore user_incomes
            backup_incomes = self.db.db.collection("user_incomes_backup").stream()
            for income in backup_incomes:
                income_data = income.to_dict()
                self.db.db.collection("user_incomes").document(income.id).set(
                    income_data
                )
            print("✅ Restored user_incomes from backup")

        except Exception as e:
            print(f"❌ Rollback failed: {e}")
            print("   MANUAL INTERVENTION REQUIRED!")

    def print_summary(self):
        """Print migration summary"""
        print("=" * 80)
        print("MIGRATION SUMMARY")
        print("=" * 80)
        print(f"Budget Plans Processed: {self.stats['budget_plans_processed']}")
        print(f"Budget Plans Migrated:  {self.stats['budget_plans_migrated']}")
        print(f"Errors:                 {len(self.stats['errors'])}")

        if self.stats["errors"]:
            print("\nErrors encountered:")
            for error in self.stats["errors"][:10]:
                print(f"  - {error}")
            if len(self.stats["errors"]) > 10:
                print(f"  ... and {len(self.stats['errors']) - 10} more")

        print("\n")
        print("=" * 80)
        print("NEXT STEPS:")
        print("=" * 80)
        print("1. Verify data in Firestore console")
        print("2. Test budget plan operations in the app")
        print("3. If everything works, you can delete backup collections:")
        print("   - budget_plans_backup")
        print("   - user_incomes_backup")
        print("   - user_incomes (original, no longer needed)")
        print("\n")


def main():
    print("\n⚠️  WARNING: This script will modify your Firestore data!")
    print("    Make sure you have backed up your data before proceeding.\n")

    response = input("Do you want to proceed with migration? (yes/no): ")

    if response.lower() != "yes":
        print("Migration aborted.")
        return

    migration = BudgetPlanMigration()
    success = migration.run_migration()

    if success:
        print("✅ Migration completed successfully!")
    else:
        print("❌ Migration failed. Check errors above.")


if __name__ == "__main__":
    main()
