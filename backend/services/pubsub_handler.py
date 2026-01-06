"""
Pub/Sub Handler for Gmail Notifications
Processes incoming Gmail push notifications
"""

import base64
import json
from typing import Dict

from services.email_parser import DiscoverEmailParser
from services.firestore_service import FirestoreService
from services.gmail_service import GmailService


class PubSubHandler:
    """Handler for Gmail Pub/Sub notifications"""

    def __init__(
        self, gmail_service: GmailService, firestore_service: FirestoreService
    ):
        self.gmail_service = gmail_service
        self.db = firestore_service
        self.parser = DiscoverEmailParser()

    def process_notification(self, pubsub_message: Dict) -> Dict:
        """
        Process a Gmail Pub/Sub notification

        Args:
            pubsub_message: Pub/Sub message from Gmail

        Returns:
            Processing result with status and any created alert ID
        """
        try:
            # Decode Pub/Sub message
            if "message" not in pubsub_message:
                return {"status": "error", "error": "No message in payload"}

            message_data = pubsub_message["message"].get("data", "")
            if not message_data:
                return {"status": "error", "error": "No data in message"}

            # Decode base64
            decoded_data = base64.b64decode(message_data).decode("utf-8")
            notification_data = json.loads(decoded_data)

            print(f"📧 [PubSub] Received notification: {notification_data}")

            # Extract email address and history ID
            email_address = notification_data.get("emailAddress")
            history_id = notification_data.get("historyId")

            # For now, we'll fetch the latest message from the inbox
            # In production, you'd use history.list() to get only new messages
            # But for simplicity, we'll just process new INBOX messages

            return self._process_new_messages()

        except Exception as e:
            print(f"❌ [PubSub] Error processing notification: {e}")
            return {"status": "error", "error": str(e)}

    def _process_new_messages(self) -> Dict:
        """
        Process new messages from Gmail
        Fetches recent messages and processes Discover transaction alerts
        """
        try:
            service = self.gmail_service.get_gmail_service()

            # List messages from INBOX with label filter
            # Only get messages from last 5 minutes to avoid re-processing
            results = (
                service.users()
                .messages()
                .list(
                    userId="me",
                    labelIds=["INBOX"],
                    maxResults=10,  # Only check last 10 messages
                )
                .execute()
            )

            messages = results.get("messages", [])

            if not messages:
                return {"status": "no_messages"}

            alerts_created = []

            for msg_ref in messages:
                message_id = msg_ref["id"]

                # Check if we already processed this email
                existing = self.db.get_transaction_alert_by_email_id(message_id)
                if existing:
                    print(f"⏭️  [PubSub] Already processed message {message_id}")
                    continue

                # Fetch full message
                message = self.gmail_service.get_message(message_id)
                if not message:
                    continue

                # Parse headers
                headers = self.gmail_service.parse_message_headers(message)
                subject = headers.get("subject", "")
                from_email = headers.get("from", "")

                # Check if it's a Discover transaction alert
                if not self.parser.is_discover_transaction_alert(subject, from_email):
                    print(
                        f"⏭️  [PubSub] Not a Discover alert: {subject} from {from_email}"
                    )
                    continue

                # Get email body
                body = self.gmail_service.get_message_body(message)

                # Parse transaction details
                transaction_data = self.parser.parse_transaction(body)
                if not transaction_data:
                    print(
                        f"⚠️ [PubSub] Failed to parse transaction from message {message_id}"
                    )
                    continue

                # Create transaction alert
                alert_data = {
                    "email_id": message_id,
                    "merchant": transaction_data["merchant"],
                    "transaction_date": transaction_data["transaction_date"],
                    "amount": transaction_data["amount"],
                    "raw_email_body": body,
                    "card_last4": transaction_data.get("card_last4"),
                    "is_resolved": False,
                }

                alert_id = self.db.create_transaction_alert(alert_data)
                alerts_created.append(alert_id)

                print(
                    f"✅ [PubSub] Created transaction alert {alert_id} for ${transaction_data['amount']} at {transaction_data['merchant']}"
                )

            return {
                "status": "success",
                "alerts_created": alerts_created,
                "count": len(alerts_created),
            }

        except Exception as e:
            print(f"❌ [PubSub] Error processing messages: {e}")
            return {"status": "error", "error": str(e)}
