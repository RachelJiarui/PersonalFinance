"""
BudgetInsight Backend Server (Single-User Refactored)
Flask API for rachel.j.chen@gmail.com
"""

import base64
import json
import os
from datetime import datetime

from dotenv import load_dotenv
from flask import Flask, jsonify, request
from flask_cors import CORS
from services.firestore_service import FirestoreService
from services.gmail_service import GmailService
from services.pubsub_service import PubSubService
from services.transaction_parser import TransactionParser

# Try to import APNs service (optional)
try:
    from services.apns_service import APNsService

    APNS_AVAILABLE = True
except ImportError:
    print("⚠️ APNs service not available - push notifications disabled")
    APNS_AVAILABLE = False

# Load environment variables
load_dotenv()

# Initialize Flask app
app = Flask(__name__)
CORS(app)
app.config["SECRET_KEY"] = os.getenv("SECRET_KEY", "dev-secret-key")

# Initialize services
db = FirestoreService()
gmail_service = GmailService()
pubsub_service = PubSubService()
apns_service = APNsService() if APNS_AVAILABLE else None
transaction_parser = TransactionParser()

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
                "pubsub": pubsub_service.is_connected(),
            },
        }
    )


# ============================================================================
# GMAIL WEBHOOK (unchanged - still needed for email processing)
# ============================================================================


@app.route("/webhooks/gmail", methods=["POST"])
def gmail_webhook():
    """Receives Gmail push notifications from Google Cloud Pub/Sub"""
    try:
        if not pubsub_service.verify_push_request(request):
            return jsonify({"error": "Unauthorized"}), 401

        envelope = request.get_json()
        if not envelope:
            return jsonify({"error": "No Pub/Sub message received"}), 400

        pubsub_message = envelope.get("message", {})
        if not pubsub_message:
            return jsonify({"error": "Invalid Pub/Sub message"}), 400

        data = base64.b64decode(pubsub_message.get("data", "")).decode("utf-8")
        notification = json.loads(data)

        email_address = notification.get("emailAddress")
        history_id = notification.get("historyId")

        if email_address != db.user_email:
            return jsonify({"error": "Unauthorized email"}), 403

        process_gmail_notification(email_address, history_id)
        return jsonify({"success": True}), 200

    except Exception as e:
        print(f"❌ Error processing Gmail webhook: {str(e)}")
        return jsonify({"error": str(e)}), 500


def process_gmail_notification(email_address, history_id):
    """Process Gmail notification - parse emails and create alerts"""
    try:
        settings = db.get_settings()
        last_history_id = settings.get("last_history_id", history_id)

        messages = gmail_service.get_message_history(
            user_id=email_address, start_history_id=last_history_id
        )

        print(f"📬 Found {len(messages)} new messages")

        discover_filter = os.getenv(
            "EMAIL_FROM_FILTER", "discover@services.discover.com"
        )
        transaction_alerts = []

        for message in messages:
            if gmail_service.is_from_sender(message, discover_filter):
                alert = transaction_parser.parse_discover_email(message)
                if alert:
                    transaction_alerts.append(alert)
                    db.create_transaction_alert(alert)

        print(f"💰 Parsed {len(transaction_alerts)} transaction alerts")

        # Send push notifications
        if transaction_alerts and apns_service:
            device_tokens = db.get_device_tokens()
            for token in device_tokens:
                if len(transaction_alerts) == 1:
                    alert = transaction_alerts[0]
                    body = f"${alert.get('amount', 0):.2f} at {alert.get('merchant', 'Unknown')}"
                else:
                    total = sum(alert.get("amount", 0) for alert in transaction_alerts)
                    body = (
                        f"${total:.2f} total - {len(transaction_alerts)} transactions"
                    )

                apns_service.send_notification(
                    device_token=token,
                    title="New Transaction Alert",
                    body=body,
                    badge=len(transaction_alerts),
                    data={
                        "type": "transaction_alert",
                        "alert_count": len(transaction_alerts),
                    },
                )

        db.update_history_id(history_id)

    except Exception as e:
        print(f"❌ Error processing notification: {str(e)}")
        raise


# ============================================================================
# APP SETTINGS
# ============================================================================


@app.route("/api/settings", methods=["GET"])
def get_settings():
    """Get app settings"""
    try:
        settings = db.get_settings()
        return jsonify(settings), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/settings/device-token", methods=["POST"])
def update_device_token():
    """Register device token for push notifications"""
    try:
        data = request.get_json()
        device_token = data.get("device_token")

        if not device_token:
            return jsonify({"error": "device_token required"}), 400

        db.update_device_token(device_token)
        return jsonify({"success": True}), 200

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


@app.route("/api/transactions/<transaction_id>/link-alert", methods=["PUT"])
def link_transaction_to_alert(transaction_id):
    """Link a transaction to an alert"""
    try:
        data = request.get_json()
        alert_id = data.get("alert_id")

        if not alert_id:
            return jsonify({"error": "alert_id required"}), 400

        db.link_transaction_to_alert(transaction_id, alert_id)
        return jsonify({"success": True}), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500


# ============================================================================
# TRANSACTION ALERTS
# ============================================================================


@app.route("/api/transaction-alerts", methods=["GET"])
def get_transaction_alerts():
    """Get transaction alerts (query param: ?status=all|linked|unlinked)"""
    try:
        status = request.args.get("status", "all")
        alerts = db.get_transaction_alerts(status=status)
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


@app.route("/api/transaction-alerts/<alert_id>/unlink", methods=["PUT"])
def unlink_alert(alert_id):
    """Unlink an alert from its transaction"""
    try:
        db.unlink_alert(alert_id)
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
