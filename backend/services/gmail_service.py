"""
Gmail Service for BudgetInsight
Handles OAuth authentication and Gmail API interactions
"""

import base64
import json
import os
from datetime import datetime
from typing import Dict, Optional

from google.cloud import firestore
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import Flow
from googleapiclient.discovery import build


class GmailService:
    """Gmail OAuth and API service"""

    SCOPES = [
        "https://www.googleapis.com/auth/gmail.readonly",
        "https://www.googleapis.com/auth/gmail.metadata",
    ]

    def __init__(self, firestore_client: firestore.Client):
        """Initialize Gmail service"""
        self.db = firestore_client
        self.user_email = "rachel.j.chen@gmail.com"
        self.project_id = os.getenv("GOOGLE_CLOUD_PROJECT", "personal-finance-482417")
        self.topic_name = f"projects/{self.project_id}/topics/gmail-finance-notifs"

        # OAuth credentials from environment
        self.client_id = os.getenv("GMAIL_CLIENT_ID")
        self.client_secret = os.getenv("GMAIL_CLIENT_SECRET")
        self.redirect_uri = os.getenv(
            "GMAIL_REDIRECT_URI",
            "https://budgetinsight-backend-ofgbl6d3ea-uc.a.run.app/api/gmail/oauth/callback",
        )

    def get_oauth_flow(self) -> Flow:
        """Create OAuth flow for authorization"""
        client_config = {
            "web": {
                "client_id": self.client_id,
                "client_secret": self.client_secret,
                "auth_uri": "https://accounts.google.com/o/oauth2/auth",
                "token_uri": "https://oauth2.googleapis.com/token",
                "redirect_uris": [self.redirect_uri],
            }
        }

        flow = Flow.from_client_config(
            client_config, scopes=self.SCOPES, redirect_uri=self.redirect_uri
        )
        return flow

    def get_authorization_url(self) -> str:
        """Generate OAuth authorization URL"""
        flow = self.get_oauth_flow()
        auth_url, _ = flow.authorization_url(
            access_type="offline", include_granted_scopes="true", prompt="consent"
        )
        return auth_url

    def exchange_code_for_token(self, code: str) -> Dict:
        """Exchange authorization code for access token"""
        flow = self.get_oauth_flow()
        flow.fetch_token(code=code)

        credentials = flow.credentials
        token_data = {
            "token": credentials.token,
            "refresh_token": credentials.refresh_token,
            "token_uri": credentials.token_uri,
            "client_id": credentials.client_id,
            "client_secret": credentials.client_secret,
            "scopes": credentials.scopes,
            "expiry": credentials.expiry.isoformat() if credentials.expiry else None,
        }

        # Store in Firestore
        self._save_credentials(token_data)

        return token_data

    def _save_credentials(self, token_data: Dict):
        """Save OAuth credentials to Firestore"""
        self.db.collection("gmail_credentials").document(self.user_email).set(
            {"token_data": token_data, "updated_at": firestore.SERVER_TIMESTAMP}
        )

    def _load_credentials(self) -> Optional[Credentials]:
        """Load OAuth credentials from Firestore"""
        doc = self.db.collection("gmail_credentials").document(self.user_email).get()
        if not doc.exists:
            return None

        data = doc.to_dict()
        token_data = data.get("token_data")
        if not token_data:
            return None

        # Parse expiry
        expiry = None
        if token_data.get("expiry"):
            expiry = datetime.fromisoformat(token_data["expiry"])

        credentials = Credentials(
            token=token_data.get("token"),
            refresh_token=token_data.get("refresh_token"),
            token_uri=token_data.get("token_uri"),
            client_id=token_data.get("client_id"),
            client_secret=token_data.get("client_secret"),
            scopes=token_data.get("scopes"),
            expiry=expiry,
        )

        return credentials

    def is_authenticated(self) -> bool:
        """Check if user has valid Gmail credentials"""
        credentials = self._load_credentials()
        return credentials is not None

    def get_gmail_service(self):
        """Get authenticated Gmail API service"""
        credentials = self._load_credentials()
        if not credentials:
            raise ValueError(
                "No Gmail credentials found. User must authenticate first."
            )

        # Refresh token if expired
        if credentials.expired and credentials.refresh_token:
            from google.auth.transport.requests import Request

            credentials.refresh(Request())

            # Save refreshed token
            token_data = {
                "token": credentials.token,
                "refresh_token": credentials.refresh_token,
                "token_uri": credentials.token_uri,
                "client_id": credentials.client_id,
                "client_secret": credentials.client_secret,
                "scopes": credentials.scopes,
                "expiry": credentials.expiry.isoformat()
                if credentials.expiry
                else None,
            }
            self._save_credentials(token_data)

        return build("gmail", "v1", credentials=credentials)

    def setup_push_notifications(self) -> Dict:
        """
        Set up Gmail push notifications via Pub/Sub
        Must be called after OAuth is complete
        """
        service = self.get_gmail_service()

        request_body = {"topicName": self.topic_name, "labelIds": ["INBOX"]}

        response = service.users().watch(userId="me", body=request_body).execute()

        # Store watch response in Firestore
        self.db.collection("gmail_watch").document(self.user_email).set(
            {
                "history_id": response.get("historyId"),
                "expiration": response.get("expiration"),
                "updated_at": firestore.SERVER_TIMESTAMP,
            }
        )

        return response

    def get_message(self, message_id: str) -> Optional[Dict]:
        """Fetch a specific Gmail message by ID"""
        try:
            service = self.get_gmail_service()
            message = (
                service.users()
                .messages()
                .get(userId="me", id=message_id, format="full")
                .execute()
            )
            return message
        except Exception as e:
            print(f"Error fetching message {message_id}: {e}")
            return None

    def parse_message_headers(self, message: Dict) -> Dict:
        """Parse useful headers from Gmail message"""
        headers = {}
        payload = message.get("payload", {})

        for header in payload.get("headers", []):
            name = header.get("name", "").lower()
            value = header.get("value", "")

            if name in ["from", "to", "subject", "date"]:
                headers[name] = value

        return headers

    def get_message_body(self, message: Dict) -> str:
        """Extract plain text body from Gmail message"""
        payload = message.get("payload", {})

        # Try to get plain text part
        def get_text_from_parts(parts):
            for part in parts:
                mime_type = part.get("mimeType", "")

                if mime_type == "text/plain":
                    data = part.get("body", {}).get("data", "")
                    if data:
                        return base64.urlsafe_b64decode(data).decode("utf-8")

                # Recursively check nested parts
                if "parts" in part:
                    text = get_text_from_parts(part["parts"])
                    if text:
                        return text

            return None

        # Check if message has parts
        if "parts" in payload:
            text = get_text_from_parts(payload["parts"])
            if text:
                return text

        # If no parts, try direct body
        body_data = payload.get("body", {}).get("data", "")
        if body_data:
            return base64.urlsafe_b64decode(body_data).decode("utf-8")

        return ""
