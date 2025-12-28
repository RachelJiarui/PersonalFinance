"""
Gmail API Service
Handles Gmail API interactions and watch setup
"""

import base64
import os

from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError


class GmailService:
    def __init__(self):
        self.watch_topic = os.getenv("GMAIL_WATCH_TOPIC", "gmail-notifications")
        self.label_ids = os.getenv("GMAIL_WATCH_LABEL_IDS", "INBOX").split(",")

    def get_service(self, access_token):
        """Create Gmail API service with user's access token"""
        credentials = Credentials(token=access_token)
        return build("gmail", "v1", credentials=credentials)

    def setup_watch(self, user_id, access_token):
        """
        Set up Gmail push notifications for a user

        Args:
            user_id: User's email address
            access_token: User's Gmail OAuth access token

        Returns:
            Watch response with expiration timestamp
        """
        try:
            service = self.get_service(access_token)

            request_body = {"labelIds": self.label_ids, "topicName": self.watch_topic}

            response = (
                service.users().watch(userId=user_id, body=request_body).execute()
            )

            print(f"✅ Gmail watch set up for {user_id}")
            print(f"   Expiration: {response.get('expiration')}")

            return response

        except HttpError as error:
            print(f"❌ Error setting up Gmail watch: {error}")
            raise

    def stop_watch(self, user_id, access_token):
        """Stop Gmail push notifications"""
        try:
            service = self.get_service(access_token)
            service.users().stop(userId=user_id).execute()
            print(f"✅ Gmail watch stopped for {user_id}")
        except HttpError as error:
            print(f"❌ Error stopping Gmail watch: {error}")
            raise

    def get_message_history(self, user_id, access_token, start_history_id):
        """
        Get message history since last processed history ID

        Args:
            user_id: User's email address
            access_token: User's Gmail OAuth access token
            start_history_id: Last processed history ID

        Returns:
            List of new messages
        """
        try:
            service = self.get_service(access_token)

            history = (
                service.users()
                .history()
                .list(
                    userId=user_id,
                    startHistoryId=start_history_id,
                    historyTypes=["messageAdded"],
                )
                .execute()
            )

            messages = []
            if "history" in history:
                for record in history["history"]:
                    if "messagesAdded" in record:
                        for msg in record["messagesAdded"]:
                            message_id = msg["message"]["id"]
                            # Fetch full message details
                            full_message = self.get_message(
                                user_id, access_token, message_id
                            )
                            if full_message:
                                messages.append(full_message)

            return messages

        except HttpError as error:
            print(f"❌ Error getting message history: {error}")
            return []

    def get_message(self, user_id, access_token, message_id):
        """Get full message details"""
        try:
            service = self.get_service(access_token)

            message = (
                service.users()
                .messages()
                .get(userId=user_id, id=message_id, format="full")
                .execute()
            )

            return message

        except HttpError as error:
            print(f"❌ Error getting message: {error}")
            return None

    def is_from_sender(self, message, sender_email):
        """Check if message is from specific sender"""
        headers = message.get("payload", {}).get("headers", [])

        for header in headers:
            if header["name"].lower() == "from":
                return sender_email.lower() in header["value"].lower()

        return False

    def get_message_body(self, message):
        """Extract message body from Gmail message"""
        try:
            payload = message.get("payload", {})

            # Try to get body from parts
            if "parts" in payload:
                for part in payload["parts"]:
                    if part["mimeType"] == "text/plain":
                        data = part["body"].get("data", "")
                        if data:
                            return base64.urlsafe_b64decode(data).decode("utf-8")
                    elif part["mimeType"] == "text/html":
                        data = part["body"].get("data", "")
                        if data:
                            return base64.urlsafe_b64decode(data).decode("utf-8")

            # Try direct body
            if "body" in payload and "data" in payload["body"]:
                data = payload["body"]["data"]
                return base64.urlsafe_b64decode(data).decode("utf-8")

            return ""

        except Exception as e:
            print(f"❌ Error extracting message body: {e}")
            return ""

    def get_message_subject(self, message):
        """Extract subject from Gmail message"""
        headers = message.get("payload", {}).get("headers", [])

        for header in headers:
            if header["name"].lower() == "subject":
                return header["value"]

        return ""

    def get_message_date(self, message):
        """Extract date from Gmail message"""
        headers = message.get("payload", {}).get("headers", [])

        for header in headers:
            if header["name"].lower() == "date":
                return header["value"]

        return ""
        return ""
