"""
BudgetInsight Backend Server (Single-User Refactored)
Flask API for rachel.j.chen@gmail.com
"""

import os
from datetime import datetime

from dotenv import load_dotenv
from flask import Flask, jsonify, request
from flask_cors import CORS
from services.firestore_service import FirestoreService

# Load environment variables
load_dotenv()

# Initialize Flask app
app = Flask(__name__)
CORS(app)
app.config["SECRET_KEY"] = os.getenv("SECRET_KEY", "dev-secret-key")

# Initialize services
db = FirestoreService()

# ============================================================================
# HEALTH CHECK
# ============================================================================


@app.route("/health", methods=["GET"])
def health_check():
    """Health check endpoint for monitoring"""
    return jsonify(
        {
            "status": "healthy",
            "timestamp": datetime.utcnow().isoformat(),
            "user": db.user_email,
            "services": {
                "firestore": True,
            },
        }
    )


# ============================================================================
# APP SETTINGS
# ============================================================================


@app.route("/api/settings", methods=["GET"])
def get_settings():
    """Get app settings"""
    try:
        return jsonify(
            {
                "email": db.user_email,
            }
        ), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


# ============================================================================
# BUDGET CATEGORIES
# ============================================================================


@app.route("/api/budget-categories", methods=["GET"])
def get_budget_categories():
    """Get all budget categories"""
    try:
        categories = db.get_budget_categories()
        return jsonify({"categories": categories}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/budget-categories", methods=["POST"])
def create_budget_category():
    """Create a new budget category"""
    try:
        category_data = request.get_json()
        category_id = db.create_budget_category(category_data)
        return jsonify({"success": True, "id": category_id}), 201
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/budget-categories/<category_id>", methods=["PUT"])
def update_budget_category(category_id):
    """Update a budget category"""
    try:
        updates = request.get_json()
        db.update_budget_category(category_id, updates)
        return jsonify({"success": True}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/budget-categories/<category_id>", methods=["DELETE"])
def delete_budget_category(category_id):
    """Delete a budget category"""
    try:
        db.delete_budget_category(category_id)
        return jsonify({"success": True}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


# ============================================================================
# TRANSACTIONS
# ============================================================================


@app.route("/api/transactions", methods=["GET"])
def get_transactions():
    """Get all transactions"""
    try:
        transactions = db.get_transactions()
        return jsonify({"transactions": transactions}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/transactions", methods=["POST"])
def create_transaction():
    """Create a new transaction"""
    try:
        transaction_data = request.get_json()
        transaction_id = db.create_transaction(transaction_data)
        return jsonify({"success": True, "id": transaction_id}), 201
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/transactions/<transaction_id>", methods=["GET"])
def get_transaction(transaction_id):
    """Get a specific transaction"""
    try:
        transaction = db.get_transaction(transaction_id)
        if not transaction:
            return jsonify({"error": "Transaction not found"}), 404
        return jsonify(transaction), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/transactions/<transaction_id>", methods=["PUT"])
def update_transaction(transaction_id):
    """Update a transaction"""
    try:
        updates = request.get_json()
        db.update_transaction(transaction_id, updates)
        return jsonify({"success": True}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/transactions/<transaction_id>", methods=["DELETE"])
def delete_transaction(transaction_id):
    """Delete a transaction"""
    try:
        db.delete_transaction(transaction_id)
        return jsonify({"success": True}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


# ============================================================================
# BUDGET PLANS
# ============================================================================


@app.route("/api/budget-plans", methods=["GET"])
def get_budget_plans():
    """Get budget plans (query param: ?year=YYYY)"""
    try:
        year = request.args.get("year")
        year = int(year) if year else None
        plans = db.get_budget_plans(year=year)
        return jsonify({"plans": plans}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/budget-plans/active", methods=["GET"])
def get_active_budget_plan():
    """Get the active budget plan (current year)"""
    try:
        plan = db.get_active_budget_plan()
        if not plan:
            return jsonify({"error": "No active budget plan found"}), 404
        return jsonify(plan), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/budget-plans", methods=["POST"])
def create_budget_plan():
    """Create a budget plan"""
    try:
        plan_data = request.get_json()
        plan_id = db.create_budget_plan(plan_data)
        return jsonify({"success": True, "id": plan_id}), 201
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/budget-plans/<plan_id>", methods=["PUT"])
def update_budget_plan(plan_id):
    """Update a budget plan"""
    try:
        updates = request.get_json()
        db.update_budget_plan(plan_id, updates)
        return jsonify({"success": True}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/budget-plans/<plan_id>", methods=["DELETE"])
def delete_budget_plan(plan_id):
    """Delete a budget plan"""
    try:
        db.delete_budget_plan(plan_id)
        return jsonify({"success": True}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


# ============================================================================
# USER INCOME
# ============================================================================


@app.route("/api/user-incomes", methods=["GET"])
def get_user_incomes():
    """Get user income records (query param: ?year=YYYY)"""
    try:
        year = request.args.get("year")
        year = int(year) if year else None
        incomes = db.get_user_incomes(year=year)
        return jsonify({"incomes": incomes}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/user-incomes/<income_id>", methods=["GET"])
def get_user_income(income_id):
    """Get a specific user income record"""
    try:
        income = db.get_user_income(income_id)
        if not income:
            return jsonify({"error": "Income record not found"}), 404
        return jsonify(income), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/user-incomes", methods=["POST"])
def create_user_income():
    """Create a user income record"""
    try:
        income_data = request.get_json()
        income_id = db.create_user_income(income_data)
        return jsonify({"success": True, "id": income_id}), 201
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/user-incomes/<income_id>", methods=["PUT"])
def update_user_income(income_id):
    """Update a user income record"""
    try:
        updates = request.get_json()
        db.update_user_income(income_id, updates)
        return jsonify({"success": True}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/user-incomes/<income_id>", methods=["DELETE"])
def delete_user_income(income_id):
    """Delete a user income record"""
    try:
        db.delete_user_income(income_id)
        return jsonify({"success": True}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


# ============================================================================
# FUNDS
# ============================================================================


@app.route("/api/funds", methods=["GET"])
def get_funds():
    """Get all funds"""
    try:
        funds = db.get_funds()
        return jsonify({"funds": funds}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/funds/<fund_id>", methods=["GET"])
def get_fund(fund_id):
    """Get a specific fund"""
    try:
        fund = db.get_fund(fund_id)
        if not fund:
            return jsonify({"error": "Fund not found"}), 404
        return jsonify(fund), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/funds", methods=["POST"])
def create_fund():
    """Create a new fund"""
    try:
        fund_data = request.get_json()
        fund_id = db.create_fund(fund_data)
        return jsonify({"success": True, "id": fund_id}), 201
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/funds/<fund_id>", methods=["PUT"])
def update_fund(fund_id):
    """Update a fund"""
    try:
        updates = request.get_json()
        db.update_fund(fund_id, updates)
        return jsonify({"success": True}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/funds/<fund_id>", methods=["DELETE"])
def delete_fund(fund_id):
    """Delete a fund (soft delete)"""
    try:
        db.delete_fund(fund_id)
        return jsonify({"success": True}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


# ============================================================================
# DEBTS
# ============================================================================


@app.route("/api/debts", methods=["GET"])
def get_debts():
    """Get all debts"""
    try:
        debts = db.get_debts()
        return jsonify({"debts": debts}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/debts/<debt_id>", methods=["GET"])
def get_debt(debt_id):
    """Get a specific debt"""
    try:
        debt = db.get_debt(debt_id)
        if not debt:
            return jsonify({"error": "Debt not found"}), 404
        return jsonify(debt), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/debts", methods=["POST"])
def create_debt():
    """Create a new debt"""
    try:
        debt_data = request.get_json()
        debt_id = db.create_debt(debt_data)
        return jsonify({"success": True, "id": debt_id}), 201
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/debts/<debt_id>", methods=["PUT"])
def update_debt(debt_id):
    """Update a debt"""
    try:
        updates = request.get_json()
        db.update_debt(debt_id, updates)
        return jsonify({"success": True}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/debts/<debt_id>", methods=["DELETE"])
def delete_debt(debt_id):
    """Delete a debt (soft delete)"""
    try:
        db.delete_debt(debt_id)
        return jsonify({"success": True}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


# ============================================================================
# TRANSACTION ALLOCATIONS
# ============================================================================


@app.route("/api/allocations", methods=["GET"])
def get_allocations():
    """Get allocations (query params: ?transaction_id=X&destination_type=Y&destination_id=Z)"""
    try:
        transaction_id = request.args.get("transaction_id")
        destination_type = request.args.get("destination_type")
        destination_id = request.args.get("destination_id")

        allocations = db.get_allocations(
            transaction_id=transaction_id,
            destination_type=destination_type,
            destination_id=destination_id,
        )
        return jsonify({"allocations": allocations}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/allocations/<allocation_id>", methods=["GET"])
def get_allocation(allocation_id):
    """Get a specific allocation"""
    try:
        allocation = db.get_allocation(allocation_id)
        if not allocation:
            return jsonify({"error": "Allocation not found"}), 404
        return jsonify(allocation), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/allocations", methods=["POST"])
def create_allocation():
    """Create a new allocation"""
    try:
        allocation_data = request.get_json()
        allocation_id = db.create_allocation(allocation_data)
        return jsonify({"success": True, "id": allocation_id}), 201
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/allocations/<allocation_id>", methods=["PUT"])
def update_allocation(allocation_id):
    """Update an allocation"""
    try:
        updates = request.get_json()
        db.update_allocation(allocation_id, updates)
        return jsonify({"success": True}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/allocations/<allocation_id>", methods=["DELETE"])
def delete_allocation(allocation_id):
    """Delete an allocation"""
    try:
        db.delete_allocation(allocation_id)
        return jsonify({"success": True}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


# ============================================================================
# SNAPSHOTS
# ============================================================================


@app.route("/api/snapshots", methods=["GET"])
def get_snapshots():
    """Get snapshots (query param: ?type=monthly|yearly)"""
    try:
        period_type = request.args.get("type", "monthly")
        snapshots = db.get_snapshots(period_type=period_type)
        return jsonify({"snapshots": snapshots}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/snapshots", methods=["POST"])
def create_snapshot():
    """Create a snapshot"""
    try:
        snapshot_data = request.get_json()
        snapshot_id = db.create_snapshot(snapshot_data)
        return jsonify({"success": True, "id": snapshot_id}), 201
    except Exception as e:
        return jsonify({"error": str(e)}), 500


# ============================================================================
# MAIN
# ============================================================================

if __name__ == "__main__":
    port = int(os.getenv("PORT", 8080))
    host = os.getenv("HOST", "0.0.0.0")
    debug = os.getenv("FLASK_ENV") == "development"

    print(f"🚀 Starting BudgetInsight Backend Server (Single-User)")
    print(f"   User: {db.user_email}")
    print(f"   Port: {port}")
    print(f"   Debug: {debug}")

    app.run(host=host, port=port, debug=debug)
