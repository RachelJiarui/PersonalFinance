"""
BudgetInsight Backend Server (Single-User Refactored)
Flask API for rachel.j.chen@gmail.com
"""

import os
from datetime import datetime

from dotenv import load_dotenv
from flask import Flask, jsonify, redirect, request
from flask_cors import CORS
from services.firestore_service import FirestoreService
from services.gmail_service import GmailService
from services.pubsub_handler import PubSubHandler

# Load environment variables
load_dotenv()

# Initialize Flask app
app = Flask(__name__)
CORS(app)
app.config["SECRET_KEY"] = os.getenv("SECRET_KEY", "dev-secret-key")

# Initialize services
db = FirestoreService()
gmail_service = GmailService(db.db)
pubsub_handler = PubSubHandler(gmail_service, db)

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
    """Get the active budget plan (end_date = null)"""
    try:
        plan = db.get_active_budget_plan()
        if not plan:
            return jsonify({"error": "No active budget plan found"}), 404
        return jsonify(plan), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/budget-plans", methods=["POST"])
def create_budget_plan():
    """
    Create a budget plan

    Validates all 4 invariants before creation
    """
    try:
        plan_data = request.get_json()
        print(f"📥 [API] Received budget plan data: {plan_data}")
        plan_id = db.create_budget_plan(plan_data)
        return jsonify({"success": True, "id": plan_id}), 201
    except ValueError as e:
        print(f"❌ [API] ValueError creating budget plan: {e}")
        return jsonify({"error": str(e)}), 400
    except Exception as e:
        import traceback

        print(f"❌ [API] Exception creating budget plan: {e}")
        print(f"❌ [API] Traceback: {traceback.format_exc()}")
        return jsonify({"error": str(e)}), 500


@app.route("/api/budget-plans/<plan_id>", methods=["PUT"])
def update_budget_plan(plan_id):
    """
    Update a budget plan

    Note: Typically used to set end_date when creating new plan
    """
    try:
        updates = request.get_json()
        db.update_budget_plan(plan_id, updates)
        return jsonify({"success": True}), 200
    except ValueError as e:
        return jsonify({"error": str(e)}), 400
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


@app.route("/api/budget-plans/<plan_id>", methods=["GET"])
def get_budget_plan(plan_id):
    """Get a specific budget plan by ID"""
    try:
        plan = db.get_budget_plan(plan_id)
        if not plan:
            return jsonify({"error": "Budget plan not found"}), 404
        return jsonify(plan), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/budget-plans/for-date/<date_str>", methods=["GET"])
def get_budget_plan_for_date(date_str):
    """
    Get the budget plan that covers a specific date

    Args:
        date_str: ISO8601 date (e.g., "2025-06-15T00:00:00Z")

    Returns:
        The budget plan covering that date
    """
    try:
        # Parse ISO8601 date string
        target_date = datetime.fromisoformat(date_str.replace("Z", "+00:00"))

        plan = db.get_budget_plan_for_date(target_date)
        if not plan:
            return jsonify({"error": "No budget plan found for date"}), 404

        return jsonify(plan), 200
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
        print(f"📥 [API] Received snapshot creation request: {snapshot_data}")
        snapshot_id = db.create_snapshot(snapshot_data)
        print(f"✅ [API] Created snapshot with ID: {snapshot_id}")
        return jsonify({"success": True, "id": snapshot_id}), 201
    except Exception as e:
        print(f"❌ [API] Error creating snapshot: {str(e)}")
        return jsonify({"error": str(e)}), 500


# ============================================================================
# GMAIL INTEGRATION
# ============================================================================


@app.route("/api/gmail/auth/status", methods=["GET"])
def gmail_auth_status():
    """Check if Gmail is authenticated"""
    try:
        is_authenticated = gmail_service.is_authenticated()
        return jsonify({"authenticated": is_authenticated}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/gmail/auth/start", methods=["GET"])
def gmail_auth_start():
    """Start Gmail OAuth flow"""
    try:
        auth_url = gmail_service.get_authorization_url()
        return jsonify({"auth_url": auth_url}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/gmail/watch/status", methods=["GET"])
def gmail_watch_status():
    """Get current Gmail watch status"""
    try:
        is_active, expiration_ms, seconds_remaining = gmail_service.get_watch_status()

        response = {
            "is_active": is_active,
            "expiration_ms": expiration_ms,
            "seconds_remaining": seconds_remaining,
            "hours_remaining": round(seconds_remaining / 3600, 1)
            if seconds_remaining
            else None,
        }
        return jsonify(response), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/gmail/watch/renew", methods=["POST"])
def gmail_watch_renew():
    """Manually renew Gmail watch (force renewal regardless of expiration)"""
    try:
        response = gmail_service.setup_push_notifications()
        return jsonify(
            {
                "success": True,
                "history_id": response.get("historyId"),
                "expiration": response.get("expiration"),
            }
        ), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/gmail/oauth/callback", methods=["GET"])
def gmail_oauth_callback():
    """Handle Gmail OAuth callback"""
    code = request.args.get("code")
    if not code:
        return redirect("budgetinsight://gmail-error?message=No+authorization+code")

    try:
        # Exchange code for token
        token_data = gmail_service.exchange_code_for_token(code)
        print(f"✅ [Gmail] OAuth successful, tokens stored")

        # Try to set up push notifications (non-blocking)
        try:
            watch_response = gmail_service.setup_push_notifications()
            print(f"✅ [Gmail] Watch set up: {watch_response}")
        except Exception as watch_error:
            # Log error but don't fail the OAuth flow
            print(f"⚠️ [Gmail] Watch setup failed (non-critical): {watch_error}")
            # User can still manually set up watch later

        # Always redirect back to app on success
        return redirect("budgetinsight://gmail-connected")

    except Exception as e:
        print(f"❌ [Gmail] OAuth callback error: {e}")
        error_message = str(e).replace(" ", "+")
        return redirect(f"budgetinsight://gmail-error?message={error_message}")


@app.route("/api/gmail/pubsub/webhook", methods=["POST"])
def gmail_pubsub_webhook():
    """
    Receive Gmail push notifications from Pub/Sub
    This endpoint is called by Google Cloud Pub/Sub
    """
    try:
        pubsub_message = request.get_json()

        if not pubsub_message:
            return jsonify({"error": "No message received"}), 400

        # Check and renew watch if needed (non-blocking)
        try:
            renewal_status = gmail_service.check_and_renew_watch(threshold_hours=24)
            if renewal_status.get("renewed"):
                print(f"🔄 [Gmail] Watch renewed: {renewal_status.get('reason')}")
        except Exception as renewal_error:
            print(f"⚠️ [Gmail] Watch renewal check failed: {renewal_error}")
            # Don't fail the webhook, just log the error

        # Process the notification
        result = pubsub_handler.process_notification(pubsub_message)

        print(f"📬 [Pub/Sub] Processed notification: {result}")

        # Always return 200 to acknowledge receipt
        return jsonify({"success": True, "result": result}), 200

    except Exception as e:
        print(f"❌ [Pub/Sub] Webhook error: {e}")
        # Still return 200 to avoid retries
        return jsonify({"error": str(e)}), 200


# ============================================================================
# TRANSACTION ALERTS
# ============================================================================


@app.route("/api/transaction-alerts", methods=["GET"])
def get_transaction_alerts():
    """Get transaction alerts (query param: ?is_resolved=true/false)"""
    try:
        is_resolved_str = request.args.get("is_resolved")
        is_resolved = None
        if is_resolved_str is not None:
            is_resolved = is_resolved_str.lower() == "true"

        alerts = db.get_transaction_alerts(is_resolved=is_resolved)
        return jsonify({"alerts": alerts}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/transaction-alerts/<alert_id>", methods=["GET"])
def get_transaction_alert(alert_id):
    """Get a specific transaction alert"""
    try:
        alert = db.get_transaction_alert(alert_id)
        if not alert:
            return jsonify({"error": "Alert not found"}), 404
        return jsonify(alert), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/transaction-alerts/<alert_id>", methods=["PUT"])
def update_transaction_alert(alert_id):
    """Update a transaction alert (e.g., mark as resolved)"""
    try:
        updates = request.get_json()
        db.update_transaction_alert(alert_id, updates)
        return jsonify({"success": True}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/transaction-alerts/<alert_id>", methods=["DELETE"])
def delete_transaction_alert(alert_id):
    """Delete a transaction alert"""
    try:
        db.delete_transaction_alert(alert_id)
        return jsonify({"success": True}), 200
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
