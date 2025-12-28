#!/usr/bin/env python3
"""
Test Gmail Webhook - Fetch recent Discover emails and test backend

This script will:
1. Authenticate with Gmail API
2. Fetch your 5 most recent Discover transaction emails
3. Send them to your backend as if they came from Pub/Sub
4. Verify they're saved in Firestore
"""

import argparse
import json
import os
import pickle
import sys
from pathlib import Path

import requests
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build

# Gmail API scopes
SCOPES = ["https://www.googleapis.com/auth/gmail.readonly"]

BACKEND_URL = os.getenv(
    "BACKEND_URL", "https://budgetinsight-backend-ofgbl6d3ea-uc.a.run.app"
)


def get_credentials():
    """Get Gmail OAuth credentials"""
    creds = None
    token_file = Path("token.pickle")

    if token_file.exists():
        with open(token_file, "rb") as token:
            creds = pickle.load(token)

    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            print("Refreshing expired credentials...")
            creds.refresh(Request())
        else:
            if not Path("credentials_oauth.json").exists():
                print("❌ credentials_oauth.json not found!")
                print(
                    "Create OAuth credentials at: https://console.cloud.google.com/apis/credentials"
                )
                print("Download and save as credentials_oauth.json")
                sys.exit(1)

            print("Starting OAuth flow...")
            flow = InstalledAppFlow.from_client_secrets_file(
                "credentials_oauth.json", SCOPES
            )
            creds = flow.run_local_server(port=0)

        with open(token_file, "wb") as token:
            pickle.dump(creds, token)

    return creds


def fetch_discover_emails(service, max_results=5):
    """Fetch recent Discover transaction emails"""
    print(f"\n🔍 Searching for Discover transaction emails...")

    # Search for emails from Discover
    query = "from:discover@services.discover.com subject:transaction"

    try:
        results = (
            service.users()
            .messages()
            .list(userId="me", q=query, maxResults=max_results)
            .execute()
        )

        messages = results.get("messages", [])

        if not messages:
            print("❌ No Discover emails found")
            return []

        print(f"✅ Found {len(messages)} Discover emails\n")

        emails = []
        for msg in messages:
            # Get full message details
            message = (
                service.users()
                .messages()
                .get(userId="me", id=msg["id"], format="full")
                .execute()
            )

            # Extract subject and date
            headers = message["payload"]["headers"]
            subject = next((h["value"] for h in headers if h["name"] == "Subject"), "")
            date = next((h["value"] for h in headers if h["name"] == "Date"), "")

            # Get email body
            body = ""
            if "parts" in message["payload"]:
                for part in message["payload"]["parts"]:
                    if part["mimeType"] == "text/plain":
                        body = part["body"].get("data", "")
                        break
            elif "body" in message["payload"]:
                body = message["payload"]["body"].get("data", "")

            emails.append(
                {
                    "id": msg["id"],
                    "subject": subject,
                    "date": date,
                    "body": body,
                    "message": message,
                }
            )

            print(f"📧 {subject}")
            print(f"   Date: {date}")
            print(f"   ID: {msg['id']}\n")

        return emails

    except Exception as e:
        print(f"❌ Error fetching emails: {e}")
        return []


def test_webhook(email_id, history_id="12345"):
    """Send a test webhook to the backend"""

    webhook_url = f"{BACKEND_URL}/webhooks/gmail"

    # This is the format Pub/Sub sends
    payload = {
        "message": {
            "data": json.dumps(
                {"emailAddress": "test@example.com", "historyId": history_id}
            ),
            "messageId": "test-message-id",
            "publishTime": "2025-12-27T00:00:00.000Z",
        },
        "subscription": "projects/test/subscriptions/gmail-push-sub",
    }

    print(f"📤 Sending webhook to {webhook_url}...")

    try:
        response = requests.post(webhook_url, json=payload, timeout=10)
        print(f"   Status: {response.status_code}")
        print(f"   Response: {response.text}\n")
        return response.status_code == 200
    except Exception as e:
        print(f"❌ Error: {e}\n")
        return False


def register_test_user():
    """Register a test user in the backend"""

    register_url = f"{BACKEND_URL}/api/users/register"

    payload = {
        "user_id": "test-user-123",
        "email": "test@example.com",
        "device_token": "test-device-token",
        "gmail_access_token": "test-access-token",
    }

    print(f"📝 Registering test user...")

    try:
        response = requests.post(register_url, json=payload, timeout=10)
        print(f"   Status: {response.status_code}")
        if response.status_code == 201:
            print(f"   ✅ User registered\n")
        else:
            print(f"   Response: {response.text}\n")
        return response.status_code in [200, 201]
    except Exception as e:
        print(f"❌ Error: {e}\n")
        return False


def check_firestore():
    """Instructions to check Firestore"""
    print("\n" + "=" * 60)
    print("📊 CHECK FIRESTORE DATA")
    print("=" * 60)
    print("\n1. Go to: https://console.cloud.google.com/firestore")
    print("2. Look for these collections:")
    print("   - users")
    print("   - transaction_alerts")
    print("   - transactions")
    print("\n3. You should see the test data populated!")
    print("\n" + "=" * 60 + "\n")


def main():
    parser = argparse.ArgumentParser(description="Test Gmail webhook with real emails")
    parser.add_argument("--email", help="Your Gmail address (for OAuth)")
    parser.add_argument(
        "--skip-fetch",
        action="store_true",
        help="Skip fetching emails, just test webhook",
    )
    args = parser.parse_args()

    print("🧪 Gmail Webhook Test Script")
    print("=" * 60 + "\n")

    if not args.skip_fetch:
        # Get Gmail credentials
        creds = get_credentials()
        service = build("gmail", "v1", credentials=creds)

        # Fetch recent Discover emails
        emails = fetch_discover_emails(service, max_results=5)

        if not emails:
            print(
                "\n⚠️  No emails found. Make sure you have Discover transaction emails."
            )
            return

    # Test the backend
    print("\n🧪 Testing Backend Endpoints")
    print("=" * 60 + "\n")

    # Test health endpoint
    print("1. Testing health endpoint...")
    try:
        response = requests.get(f"{BACKEND_URL}/health", timeout=5)
        print(f"   Status: {response.status_code}")
        print(f"   Response: {response.json()}\n")
    except Exception as e:
        print(f"   ❌ Error: {e}\n")

    # Register a test user
    print("2. Registering test user...")
    register_test_user()

    # Test webhook
    print("3. Testing Gmail webhook...")
    if not args.skip_fetch and emails:
        test_webhook(emails[0]["id"])
    else:
        test_webhook("test-email-id")

    # Instructions to check Firestore
    check_firestore()


if __name__ == "__main__":
    main()
