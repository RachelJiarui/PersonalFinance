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
            current_history_id = notification_data.get("historyId")

            print(
                f"📧 [PubSub] Email: {email_address}, HistoryId: {current_history_id}"
            )

            # Get the last processed history ID
            last_history_id = self._get_last_history_id()

            if last_history_id:
                print(
                    f"📧 [PubSub] Using history API to fetch changes since {last_history_id}"
                )
                result = self._process_history_changes(
                    last_history_id, current_history_id
                )
            else:
                print(f"📧 [PubSub] No previous history ID, fetching recent messages")
                result = self._process_new_messages()

            # Update the last processed history ID
            if current_history_id:
                self._save_last_history_id(current_history_id)

            return result

        except Exception as e:
            print(f"❌ [PubSub] Error processing notification: {e}")
            return {"status": "error", "error": str(e)}

    def _process_new_messages(self) -> Dict:
        """
        Process new messages from Gmail
        Fetches recent messages and processes Discover transaction alerts
        Now uses batch processing for efficiency
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
                    maxResults=5,  # Only check last 5 messages (enough for most cases)
                )
                .execute()
            )

            messages = results.get("messages", [])

            if not messages:
                return {"status": "no_messages"}

            # Extract message IDs and use batch processing
            message_ids = [msg["id"] for msg in messages]
            print(f"📧 [PubSub] Found {len(message_ids)} recent messages")

            return self._process_messages_batch(message_ids)

        except Exception as e:
            print(f"❌ [PubSub] Error processing messages: {e}")
            return {"status": "error", "error": str(e)}

    def _process_history_changes(
        self, start_history_id: str, current_history_id: str
    ) -> Dict:
        """
        Process changes using Gmail history API (more efficient)
        Only fetches messages that were added since last check
        """
        try:
            service = self.gmail_service.get_gmail_service()

            print(
                f"📧 [PubSub Handler] Fetching history changes from {start_history_id}"
            )

            # Get history of changes
            history_response = (
                service.users()
                .history()
                .list(
                    userId="me",
                    startHistoryId=start_history_id,
                    labelId="INBOX",
                    historyTypes=["messageAdded"],
                )
                .execute()
            )

            changes = history_response.get("history", [])
            print(f"📧 [PubSub Handler] Found {len(changes)} history changes")

            if not changes:
                return {"status": "no_changes"}

            # Collect all new message IDs
            message_ids = []
            for change in changes:
                messages_added = change.get("messagesAdded", [])
                for msg in messages_added:
                    if "INBOX" in msg.get("message", {}).get("labelIds", []):
                        message_ids.append(msg["message"]["id"])

            print(f"📧 [PubSub Handler] Found {len(message_ids)} new INBOX messages")

            if not message_ids:
                return {"status": "no_new_messages"}

            # Process these specific messages using batch
            return self._process_messages_batch(message_ids)

        except Exception as e:
            print(f"❌ [PubSub Handler] Error processing history: {e}")
            # Fallback to old method
            print(f"⚠️ [PubSub Handler] Falling back to fetching recent messages")
            return self._process_new_messages()

    def _process_messages_batch(self, message_ids: list) -> Dict:
        """
        Process multiple messages using Gmail batch API (more efficient)
        """
        try:
            from googleapiclient.http import BatchHttpRequest

            service = self.gmail_service.get_gmail_service()
            alerts_created = []

            print(
                f"📧 [PubSub Handler] Processing {len(message_ids)} messages in batch"
            )

            # Process in batches of 100 (Gmail API limit)
            for i in range(0, len(message_ids), 100):
                batch_ids = message_ids[i : i + 100]
                messages_data = []

                def callback(request_id, response, exception):
                    if exception:
                        print(f"❌ [Batch] Error fetching message: {exception}")
                    else:
                        messages_data.append(response)

                batch = service.new_batch_http_request(callback=callback)

                for msg_id in batch_ids:
                    batch.add(
                        service.users()
                        .messages()
                        .get(userId="me", id=msg_id, format="full")
                    )

                batch.execute()

                # Process fetched messages
                for message in messages_data:
                    alert_id = self._process_single_message(message)
                    if alert_id:
                        alerts_created.append(alert_id)

            return {
                "status": "success",
                "alerts_created": alerts_created,
                "count": len(alerts_created),
            }

        except Exception as e:
            print(f"❌ [PubSub Handler] Batch processing error: {e}")
            # Fallback to one-by-one processing
            return self._process_messages_individually(message_ids)

    def _process_messages_individually(self, message_ids: list) -> Dict:
        """
        Fallback: Process messages one by one
        """
        alerts_created = []

        for message_id in message_ids:
            try:
                message = self.gmail_service.get_message(message_id)
                if message:
                    alert_id = self._process_single_message(message)
                    if alert_id:
                        alerts_created.append(alert_id)
            except Exception as e:
                print(f"❌ [PubSub Handler] Error processing message {message_id}: {e}")
                continue

        return {
            "status": "success",
            "alerts_created": alerts_created,
            "count": len(alerts_created),
        }

    def _process_single_message(self, message: Dict) -> str:
        """
        Process a single message and create alert if it matches criteria
        Returns alert_id if created, None otherwise
        """
        try:
            message_id = message["id"]

            # Check if already processed
            existing = self.db.get_transaction_alert_by_email_id(message_id)
            if existing:
                print(f"⏭️  [PubSub Handler] Already processed message {message_id}")
                return None

            # Parse headers
            headers = self.gmail_service.parse_message_headers(message)
            subject = headers.get("subject", "")
            from_email = headers.get("from", "")

            # Check if it's a transaction alert
            if not self.parser.is_discover_transaction_alert(subject, from_email):
                return None

            print(
                f"✅ [PubSub Handler] Matched transaction alert: {subject} from {from_email}"
            )

            # Get email body
            body = self.gmail_service.get_message_body(message)

            # Parse transaction
            transaction_data = self.parser.parse_transaction(body)
            if not transaction_data:
                print(
                    f"⚠️ [PubSub Handler] Failed to parse transaction from {message_id}"
                )
                return None

            print(f"✅ [PubSub Handler] Parsed transaction: {transaction_data}")

            # Create alert
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
            print(
                f"✅ [PubSub Handler] Created alert {alert_id} for ${transaction_data['amount']} at {transaction_data['merchant']}"
            )

            return alert_id

        except Exception as e:
            print(f"❌ [PubSub Handler] Error processing single message: {e}")
            return None

    def _get_last_history_id(self) -> str:
        """Get the last processed history ID from Firestore"""
        try:
            doc = (
                self.db.db.collection("gmail_watch")
                .document(self.gmail_service.user_email)
                .get()
            )
            if doc.exists:
                data = doc.to_dict()
                return data.get("last_history_id")
            return None
        except Exception as e:
            print(f"⚠️ [PubSub Handler] Error getting last history ID: {e}")
            return None

    def _save_last_history_id(self, history_id: str):
        """Save the last processed history ID to Firestore"""
        try:
            self.db.db.collection("gmail_watch").document(
                self.gmail_service.user_email
            ).set(
                {
                    "last_history_id": history_id,
                    "updated_at": self.db.db.server_timestamp(),
                },
                merge=True,
            )
            print(f"✅ [PubSub Handler] Saved history ID: {history_id}")
        except Exception as e:
            print(f"⚠️ [PubSub Handler] Error saving history ID: {e}")
