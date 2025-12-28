"""
BudgetInsight Backend Server
Flask API with Gmail Push Notifications, Firestore, and APNs
"""

import base64
import json
import os
from datetime import datetime

from dotenv import load_dotenv
from flask import Flask, jsonify, request
from flask_cors import CORS
from services.firestore_service import FirestoreService

# Import services
from services.gmail_service import GmailService
from services.gmail_watch_manager import GmailWatchManager
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
watch_manager = GmailWatchManager(db)


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
            "services": {
                "firestore": True,
                "pubsub": pubsub_service.is_connected(),
            },
        }
    )


# ============================================================================
# GMAIL PUSH NOTIFICATION WEBHOOK
# ============================================================================


@app.route("/webhooks/gmail", methods=["POST"])
def gmail_webhook():
    """
    Receives Gmail push notifications from Google Cloud Pub/Sub
    This is called when new emails arrive in the user's Gmail
    """
    try:
        # Verify the request is from Google
        if not pubsub_service.verify_push_request(request):
            return jsonify({"error": "Unauthorized"}), 401

        # Parse Pub/Sub message
        envelope = request.get_json()
        if not envelope:
            return jsonify({"error": "No Pub/Sub message received"}), 400

        pubsub_message = envelope.get("message", {})
        if not pubsub_message:
            return jsonify({"error": "Invalid Pub/Sub message"}), 400

        # Decode the message data
        data = base64.b64decode(pubsub_message.get("data", "")).decode("utf-8")
        notification = json.loads(data)

        print(f"📧 Received Gmail notification: {notification}")

        # Extract user email and history ID
        email_address = notification.get("emailAddress")
        history_id = notification.get("historyId")

        if not email_address or not history_id:
            return jsonify({"error": "Missing email or historyId"}), 400

        # Process the notification
        process_gmail_notification(email_address, history_id)

        return jsonify({"success": True}), 200

    except Exception as e:
        print(f"❌ Error processing Gmail webhook: {str(e)}")
        return jsonify({"error": str(e)}), 500


def process_gmail_notification(email_address, history_id):
    """
    Process Gmail notification by fetching new messages and parsing transactions
    """
    try:
        # Get user's last processed history ID from database
        user = db.get_user_by_email(email_address)
        if not user:
            print(f"⚠️ User not found: {email_address}")
            return

        last_history_id = user.get("last_history_id", history_id)

        # Fetch message history from Gmail
        messages = gmail_service.get_message_history(
            user_id=email_address, start_history_id=last_history_id
        )

        print(f"📬 Found {len(messages)} new messages")

        # Filter for Discover transaction alerts
        discover_filter = os.getenv(
            "EMAIL_FROM_FILTER", "discover@services.discover.com"
        )
        transaction_alerts = []

        for message in messages:
            if gmail_service.is_from_sender(message, discover_filter):
                # Parse transaction from email
                alert = transaction_parser.parse_discover_email(message)
                if alert:
                    transaction_alerts.append(alert)
                    # Save to Firestore
                    db.save_transaction_alert(user["user_id"], alert)

        print(f"💰 Parsed {len(transaction_alerts)} transaction alerts")

        # Send push notifications to iOS app
        if transaction_alerts:
            device_tokens = user.get("device_tokens", [])
            for token in device_tokens:
                # Prepare alert data for notification
                alert_summaries = [
                    {
                        "id": alert.get("email_id"),
                        "merchant": alert.get("merchant"),
                        "amount": alert.get("amount"),
                        "date": alert.get("date"),
                    }
                    for alert in transaction_alerts
                ]

                # Create descriptive body text
                if len(transaction_alerts) == 1:
                    alert = transaction_alerts[0]
                    body = f"${alert.get('amount', 0):.2f} at {alert.get('merchant', 'Unknown')}"
                else:
                    total = sum(alert.get("amount", 0) for alert in transaction_alerts)
                    body = (
                        f"${total:.2f} total - {len(transaction_alerts)} transactions"
                    )

                if apns_service:
                    apns_service.send_notification(
                        device_token=token,
                        title="New Transaction Alert",
                        body=body,
                        badge=len(transaction_alerts),
                        data={
                            "type": "transaction_alert",
                            "alert_count": len(transaction_alerts),
                            "alerts": alert_summaries,
                        },
                    )
                else:
                    print("⚠️ APNs not available - skipping push notification")

        # Update user's last history ID
        db.update_user_history_id(user["user_id"], history_id)

    except Exception as e:
        print(f"❌ Error processing notification: {str(e)}")
        raise


# ============================================================================
# USER MANAGEMENT API
# ============================================================================


@app.route("/api/users/register", methods=["POST"])
def register_user():
    """Register a new user and set up Gmail watch"""
    try:
        data = request.get_json()
        user_id = data.get("user_id")
        email = data.get("email")
        device_token = data.get("device_token")
        gmail_access_token = data.get("gmail_access_token")

        if not all([user_id, email, device_token, gmail_access_token]):
            return jsonify({"error": "Missing required fields"}), 400

        # Save user to database
        user_data = {
            "user_id": user_id,
            "email": email,
            "device_tokens": [device_token],
            "gmail_access_token": gmail_access_token,
            "last_history_id": None,
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow(),
        }
        db.create_user(user_data)

        # Set up Gmail watch (push notifications)
        watch_response = gmail_service.setup_watch(
            user_id=email, access_token=gmail_access_token
        )

        return jsonify(
            {
                "success": True,
                "user_id": user_id,
                "watch_expiration": watch_response.get("expiration"),
            }
        ), 201

    except Exception as e:
        print(f"❌ Error registering user: {str(e)}")
        return jsonify({"error": str(e)}), 500


@app.route("/api/users/<user_id>/device-token", methods=["PUT"])
def update_device_token(user_id):
    """Update user's device token for push notifications"""
    try:
        data = request.get_json()
        device_token = data.get("device_token")

        if not device_token:
            return jsonify({"error": "Missing device_token"}), 400

        db.add_device_token(user_id, device_token)

        return jsonify({"success": True}), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500


# ============================================================================
# TRANSACTION ALERTS API
# ============================================================================


@app.route("/api/users/<user_id>/transaction-alerts", methods=["GET"])
def get_transaction_alerts(user_id):
    """Get all transaction alerts for a user"""
    try:
        # Query param: ?status=unlinked|linked|all (default: all)
        status = request.args.get("status", "all")

        if status == "unlinked":
            alerts = db.get_unlinked_alerts(user_id)
        elif status == "linked":
            all_alerts = db.get_all_transaction_alerts(user_id)
            alerts = [a for a in all_alerts if a.get("is_linked")]
        else:
            alerts = db.get_all_transaction_alerts(user_id)

        return jsonify({"alerts": alerts}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/users/<user_id>/transaction-alerts/<alert_id>", methods=["GET"])
def get_transaction_alert(user_id, alert_id):
    """Get a single transaction alert"""
    try:
        alert = db.get_transaction_alert_by_id(alert_id)
        if not alert:
            return jsonify({"error": "Alert not found"}), 404

        # Verify alert belongs to user
        if alert.get("user_id") != user_id:
            return jsonify({"error": "Unauthorized"}), 403

        return jsonify(alert), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/users/<user_id>/transaction-alerts/<alert_id>", methods=["DELETE"])
def delete_transaction_alert(user_id, alert_id):
    """Delete a transaction alert"""
    try:
        # Get alert and verify ownership
        alert = db.get_transaction_alert_by_id(alert_id)
        if not alert:
            return jsonify({"error": "Alert not found"}), 404

        if alert.get("user_id") != user_id:
            return jsonify({"error": "Unauthorized"}), 403

        # If linked to a transaction, unlink it first
        if alert.get("is_linked") and alert.get("linked_transaction_id"):
            transaction_id = alert["linked_transaction_id"]
            # Remove the reverse link from transaction
            try:
                db.update_transaction(transaction_id, {"linked_email_alert_id": None})
            except:
                pass  # Transaction might have been deleted already

        # Delete the alert
        db.delete_transaction_alert(alert_id)

        return jsonify({"success": True}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/users/<user_id>/transaction-alerts/<alert_id>/unlink", methods=["PUT"])
def unlink_transaction_alert(user_id, alert_id):
    """Unlink an alert from its transaction"""
    try:
        alert = db.get_transaction_alert_by_id(alert_id)
        if not alert:
            return jsonify({"error": "Alert not found"}), 404

        if alert.get("user_id") != user_id:
            return jsonify({"error": "Unauthorized"}), 403

        if not alert.get("is_linked"):
            return jsonify({"error": "Alert is not linked"}), 400

        transaction_id = alert.get("linked_transaction_id")

        # Unlink bidirectionally
        if transaction_id:
            db.unlink_transaction_from_alert(transaction_id, alert_id)
        else:
            # Fallback: just unlink the alert
            db.unlink_alert(alert_id)

        return jsonify({"success": True}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


# ============================================================================
# TRANSACTION DATA API
# ============================================================================


@app.route("/api/users/<user_id>/transactions", methods=["GET"])
def get_transactions(user_id):
    """Get all transactions for a user"""
    try:
        transactions = db.get_user_transactions(user_id)
        return jsonify({"transactions": transactions}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/users/<user_id>/transactions", methods=["POST"])
def save_transaction(user_id):
    """Save a transaction"""
    try:
        transaction = request.get_json()
        transaction["user_id"] = user_id
        transaction["created_at"] = datetime.utcnow()

        # Check if this transaction should be linked to an alert
        linked_alert_id = transaction.get("linkedEmailAlertId")
        if linked_alert_id:
            # Save the alert ID in the proper field
            transaction["linked_email_alert_id"] = linked_alert_id
            # Remove the camelCase version
            transaction.pop("linkedEmailAlertId", None)

        transaction_id = db.save_transaction(transaction)

        # If linked to an alert, link it bidirectionally
        if linked_alert_id:
            try:
                db.link_alert(linked_alert_id, transaction_id)
            except Exception as e:
                print(f"Warning: Could not link alert {linked_alert_id}: {e}")

        return jsonify({"success": True, "transaction_id": transaction_id}), 201
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/users/<user_id>/transactions/<transaction_id>", methods=["GET"])
def get_transaction(user_id, transaction_id):
    """Get a single transaction"""
    try:
        transaction = db.get_transaction_by_id(transaction_id)
        if not transaction:
            return jsonify({"error": "Transaction not found"}), 404

        # Verify transaction belongs to user
        if transaction.get("user_id") != user_id:
            return jsonify({"error": "Unauthorized"}), 403

        return jsonify(transaction), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/users/<user_id>/transactions/<transaction_id>", methods=["PUT"])
def update_transaction_endpoint(user_id, transaction_id):
    """Update a transaction (full update)"""
    try:
        # Get existing transaction
        existing = db.get_transaction_by_id(transaction_id)
        if not existing:
            return jsonify({"error": "Transaction not found"}), 404

        if existing.get("user_id") != user_id:
            return jsonify({"error": "Unauthorized"}), 403

        # Get update data
        update_data = request.get_json()

        # Don't allow changing user_id or id
        update_data.pop("user_id", None)
        update_data.pop("id", None)
        update_data.pop("transaction_id", None)

        # Update transaction
        db.update_transaction(transaction_id, update_data)

        return jsonify({"success": True}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/users/<user_id>/transactions/<transaction_id>", methods=["PATCH"])
def partial_update_transaction(user_id, transaction_id):
    """Partially update a transaction"""
    try:
        # Get existing transaction
        existing = db.get_transaction_by_id(transaction_id)
        if not existing:
            return jsonify({"error": "Transaction not found"}), 404

        if existing.get("user_id") != user_id:
            return jsonify({"error": "Unauthorized"}), 403

        # Get partial update data
        update_data = request.get_json()

        # Don't allow changing user_id or id
        update_data.pop("user_id", None)
        update_data.pop("id", None)
        update_data.pop("transaction_id", None)

        # Update transaction
        db.update_transaction(transaction_id, update_data)

        return jsonify({"success": True}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/users/<user_id>/transactions/<transaction_id>", methods=["DELETE"])
def delete_transaction_endpoint(user_id, transaction_id):
    """Delete a transaction with cascade handling"""
    try:
        # Get transaction
        transaction = db.get_transaction_by_id(transaction_id)
        if not transaction:
            return jsonify({"error": "Transaction not found"}), 404

        if transaction.get("user_id") != user_id:
            return jsonify({"error": "Unauthorized"}), 403

        # Delete with cascade (handles alert unlinking)
        db.delete_transaction_with_cascade(transaction_id)

        return jsonify({"success": True}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route(
    "/api/users/<user_id>/transactions/<transaction_id>/link-alert", methods=["PUT"]
)
def link_transaction_to_alert_endpoint(user_id, transaction_id):
    """Link a transaction to an alert"""
    try:
        data = request.get_json()
        alert_id = data.get("alert_id")

        if not alert_id:
            return jsonify({"error": "alert_id required"}), 400

        # Verify transaction ownership
        transaction = db.get_transaction_by_id(transaction_id)
        if not transaction:
            return jsonify({"error": "Transaction not found"}), 404
        if transaction.get("user_id") != user_id:
            return jsonify({"error": "Unauthorized"}), 403

        # Verify alert ownership
        alert = db.get_transaction_alert_by_id(alert_id)
        if not alert:
            return jsonify({"error": "Alert not found"}), 404
        if alert.get("user_id") != user_id:
            return jsonify({"error": "Unauthorized"}), 403

        # Link bidirectionally
        db.link_transaction_to_alert(transaction_id, alert_id)

        return jsonify({"success": True}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


# ============================================================================
# BUDGET DATA API
# ============================================================================


@app.route("/api/users/<user_id>/budget", methods=["GET"])
def get_budget(user_id):
    """Get user's budget allocation and income"""
    try:
        budget = db.get_user_budget(user_id)
        return jsonify(budget), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/users/<user_id>/budget", methods=["POST"])
def save_budget(user_id):
    """Save user's budget allocation and income"""
    try:
        budget_data = request.get_json()
        budget_data["user_id"] = user_id
        budget_data["updated_at"] = datetime.utcnow()

        db.save_user_budget(user_id, budget_data)

        return jsonify({"success": True}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/users/<user_id>/budget", methods=["DELETE"])
def delete_budget(user_id):
    """Delete user's budget"""
    try:
        db.delete_user_budget(user_id)
        return jsonify({"success": True}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/users/<user_id>/budget/categories", methods=["PATCH"])
def update_budget_categories(user_id):
    """Update only budget categories"""
    try:
        data = request.get_json()
        categories = data.get("categories")

        if not categories:
            return jsonify({"error": "categories required"}), 400

        db.update_budget_categories(user_id, categories)
        return jsonify({"success": True}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/users/<user_id>/budget/income", methods=["PATCH"])
def update_budget_income(user_id):
    """Update only budget income"""
    try:
        income_data = request.get_json()
        db.update_budget_income(user_id, income_data)
        return jsonify({"success": True}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


# ============================================================================
# SNAPSHOTS API
# ============================================================================


@app.route("/api/users/<user_id>/snapshots", methods=["GET"])
def get_snapshots(user_id):
    """Get historical snapshots"""
    try:
        period_type = request.args.get("type", "monthly")  # monthly or yearly
        snapshots = db.get_snapshots(user_id, period_type)
        return jsonify({"snapshots": snapshots}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


# ============================================================================
# GMAIL WATCH AUTO-RENEWAL
# ============================================================================


@app.route("/tasks/renew-watches", methods=["POST"])
def renew_watches():
    """
    Auto-renewal endpoint for Gmail watches

    This endpoint should be called daily by Cloud Scheduler
    It checks all active watches and renews any expiring in < 24 hours
    """
    try:
        # Verify this is from Cloud Scheduler (optional security)
        # You can add authentication here if needed

        print("🔄 [Scheduled Task] Gmail watch renewal check started")

        # Check and renew watches
        result = watch_manager.check_and_renew_watches()

        return jsonify(
            {
                "success": True,
                "timestamp": datetime.utcnow().isoformat(),
                "summary": result,
            }
        ), 200

    except Exception as e:
        print(f"❌ Error in watch renewal task: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


@app.route("/api/users/<user_id>/gmail-watch/status", methods=["GET"])
def get_watch_status(user_id):
    """Get Gmail watch status for a user"""
    try:
        status = watch_manager.get_watch_status(user_id)
        return jsonify(status), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/users/<user_id>/gmail-watch/setup", methods=["POST"])
def setup_user_watch(user_id):
    """
    Set up Gmail watch for a user

    Request body:
    {
        "access_token": "user's Gmail OAuth token"
    }
    """
    try:
        data = request.get_json()
        access_token = data.get("access_token")

        if not access_token:
            return jsonify({"error": "access_token required"}), 400

        # Get user email
        user = db.get_user_by_id(user_id)
        if not user:
            return jsonify({"error": "User not found"}), 404

        email = user.get("email")

        # Set up watch
        response = watch_manager.setup_watch(email, access_token)

        return jsonify(
            {
                "success": True,
                "history_id": response.get("historyId"),
                "expiration": response.get("expiration"),
            }
        ), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500


# ============================================================================
# MAIN
# ============================================================================

if __name__ == "__main__":
    port = int(os.getenv("PORT", 8080))
    host = os.getenv("HOST", "0.0.0.0")
    debug = os.getenv("FLASK_ENV") == "development"

    print(f"🚀 Starting BudgetInsight Backend Server")
    print(f"   Port: {port}")
    print(f"   Debug: {debug}")

    app.run(host=host, port=port, debug=debug)
