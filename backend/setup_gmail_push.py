#!/usr/bin/env python3
"""
Gmail Push Notification Setup Script

This script sets up Gmail push notifications for your account to receive
real-time alerts when Discover sends "Transaction Alert" emails.

Requirements:
1. Google Cloud project with Gmail API enabled
2. OAuth 2.0 credentials configured
3. Pub/Sub topic created (gmail-notifications)
4. User grants Gmail access to the app

Usage:
    python setup_gmail_push.py --email your.email@gmail.com
"""

import argparse
import os
import pickle
from pathlib import Path

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

# Gmail API scopes required
SCOPES = [
    "https://www.googleapis.com/auth/gmail.readonly",
    "https://www.googleapis.com/auth/gmail.modify",
]


def get_credentials():
    """
    Get or create Gmail OAuth credentials

    This will:
    1. Check for existing credentials in token.pickle
    2. Refresh if expired
    3. Launch OAuth flow if needed
    """
    creds = None
    token_file = Path("token.pickle")

    # Load existing credentials
    if token_file.exists():
        with open(token_file, "rb") as token:
            creds = pickle.load(token)

    # Refresh or get new credentials
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            print("🔄 Refreshing expired credentials...")
            creds.refresh(Request())
        else:
            print("🔐 Starting OAuth flow...")
            print("    A browser window will open for Gmail authorization")

            # Check for oauth_credentials.json
            if not Path("oauth_credentials.json").exists():
                print("\n❌ ERROR: oauth_credentials.json not found!")
                print(
                    "    Please download OAuth credentials from Google Cloud Console:"
                )
                print("    1. Go to console.cloud.google.com/apis/credentials")
                print("    2. Create Credentials → OAuth 2.0 Client ID")
                print("    3. Application type: Desktop app")
                print("    4. Download JSON and save as oauth_credentials.json")
                return None

            flow = InstalledAppFlow.from_client_secrets_file(
                "oauth_credentials.json", SCOPES
            )
            creds = flow.run_local_server(port=0)

        # Save credentials for future use
        with open(token_file, "wb") as token:
            pickle.dump(creds, token)
        print("✅ Credentials saved to token.pickle")

    return creds


def setup_gmail_watch(email, topic_name=None):
    """
    Set up Gmail push notifications

    Args:
        email: User's Gmail address
        topic_name: Pub/Sub topic (defaults to env var or projects/PROJECT/topics/gmail-notifications)
    """
    # Get credentials
    creds = get_credentials()
    if not creds:
        return False

    try:
        # Build Gmail service
        service = build("gmail", "v1", credentials=creds)

        # Get topic name from env or construct default
        if not topic_name:
            project_id = os.getenv("GOOGLE_CLOUD_PROJECT", "personal-finance-482417")
            topic_name = f"projects/{project_id}/topics/gmail-notifications"

        print(f"\n📧 Setting up Gmail push notifications...")
        print(f"   Email: {email}")
        print(f"   Topic: {topic_name}")

        # Set up watch
        request_body = {"labelIds": ["INBOX"], "topicName": topic_name}

        response = service.users().watch(userId="me", body=request_body).execute()

        print("\n✅ Gmail watch successfully configured!")
        print(f"   History ID: {response.get('historyId')}")
        print(
            f"   Expiration: {response.get('expiration')} (timestamp in milliseconds)"
        )

        # Calculate expiration time
        import datetime

        expiration_ms = int(response.get("expiration"))
        expiration_dt = datetime.datetime.fromtimestamp(expiration_ms / 1000)
        print(f"   Expires at: {expiration_dt.strftime('%Y-%m-%d %H:%M:%S')}")

        print("\n📝 Important Notes:")
        print("   • Watch expires after 7 days - you'll need to renew it")
        print("   • New emails from discover.com will trigger webhooks")
        print("   • Only emails with subject 'Transaction Alert' will be processed")
        print(f"   • Save this history ID: {response.get('historyId')}")

        # Save history ID to file
        history_file = Path("last_history_id.txt")
        with open(history_file, "w") as f:
            f.write(response.get("historyId"))
        print(f"   • History ID saved to {history_file}")

        return True

    except HttpError as error:
        print(f"\n❌ Error setting up Gmail watch: {error}")

        if "permission" in str(error).lower():
            print("\n🔧 Permission Issue - Possible fixes:")
            print("   1. Grant Pub/Sub permissions to Gmail:")
            print(f"      gcloud projects add-iam-policy-binding {project_id} \\")
            print(
                "         --member=serviceAccount:gmail-api-push@system.gserviceaccount.com \\"
            )
            print("         --role=roles/pubsub.publisher")
            print("\n   2. Ensure the Pub/Sub topic exists:")
            print(f"      gcloud pubsub topics describe gmail-notifications")

        return False


def test_gmail_connection():
    """Test Gmail API connection"""
    creds = get_credentials()
    if not creds:
        return False

    try:
        service = build("gmail", "v1", credentials=creds)

        # Get user profile
        profile = service.users().getProfile(userId="me").execute()

        print("\n✅ Gmail API connection successful!")
        print(f"   Email: {profile.get('emailAddress')}")
        print(f"   Messages: {profile.get('messagesTotal')}")
        print(f"   Threads: {profile.get('threadsTotal')}")

        return True

    except HttpError as error:
        print(f"\n❌ Gmail API connection failed: {error}")
        return False


def list_recent_discover_emails():
    """List recent emails from Discover to verify setup"""
    creds = get_credentials()
    if not creds:
        return

    try:
        service = build("gmail", "v1", credentials=creds)

        print("\n📨 Searching for recent Discover emails...")

        # Search for emails from Discover with "Transaction Alert" subject
        query = 'from:discover.com subject:"Transaction Alert"'
        results = (
            service.users()
            .messages()
            .list(userId="me", q=query, maxResults=5)
            .execute()
        )

        messages = results.get("messages", [])

        if not messages:
            print("   No Discover transaction alerts found")
            print("   Make sure you've received some transaction emails from Discover")
            return

        print(f"\n   Found {len(messages)} recent transaction alerts:")

        for msg in messages:
            message = (
                service.users()
                .messages()
                .get(
                    userId="me",
                    id=msg["id"],
                    format="metadata",
                    metadataHeaders=["From", "Subject", "Date"],
                )
                .execute()
            )

            headers = message.get("payload", {}).get("headers", [])
            subject = next(
                (h["value"] for h in headers if h["name"] == "Subject"), "No subject"
            )
            date = next((h["value"] for h in headers if h["name"] == "Date"), "No date")

            print(f"\n   • {subject}")
            print(f"     Date: {date}")
            print(f"     ID: {msg['id']}")

    except HttpError as error:
        print(f"\n❌ Error searching emails: {error}")


def main():
    parser = argparse.ArgumentParser(
        description="Set up Gmail push notifications for Discover transaction alerts"
    )
    parser.add_argument("--email", help="Your Gmail address", default="me")
    parser.add_argument(
        "--test", action="store_true", help="Test Gmail API connection only"
    )
    parser.add_argument(
        "--list-emails",
        action="store_true",
        help="List recent Discover transaction emails",
    )
    parser.add_argument("--topic", help="Pub/Sub topic name (optional)", default=None)

    args = parser.parse_args()

    print("=" * 60)
    print("Gmail Push Notification Setup")
    print("=" * 60)

    if args.test:
        test_gmail_connection()
    elif args.list_emails:
        list_recent_discover_emails()
    else:
        # Full setup
        if test_gmail_connection():
            list_recent_discover_emails()
            setup_gmail_watch(args.email, args.topic)

    print("\n" + "=" * 60)


if __name__ == "__main__":
    main()
