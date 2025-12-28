"""
Apple Push Notification Service (APNs)
Sends push notifications to iOS devices
"""

import json
import os

from apns2.client import APNsClient
from apns2.payload import Payload


class APNsService:
    def __init__(self):
        self.team_id = os.getenv("APNS_TEAM_ID")
        self.key_id = os.getenv("APNS_KEY_ID")
        self.auth_key_path = os.getenv("APNS_AUTH_KEY_PATH")
        self.bundle_id = os.getenv("APNS_BUNDLE_ID", "com.yourcompany.BudgetInsight")
        self.use_sandbox = os.getenv("APNS_USE_SANDBOX", "True").lower() == "true"

        self.client = None
        self.setup()

    def setup(self):
        """Initialize APNs client"""
        try:
            if not all([self.team_id, self.key_id, self.auth_key_path]):
                print("⚠️ APNs credentials not configured")
                return

            if not os.path.exists(self.auth_key_path):
                print(f"⚠️ APNs auth key not found at {self.auth_key_path}")
                return

            self.client = APNsClient(
                credentials=self.auth_key_path,
                use_sandbox=self.use_sandbox,
                use_alternative_port=False,
            )

            print("✅ APNs client initialized")
            print(f"   Mode: {'Sandbox' if self.use_sandbox else 'Production'}")

        except Exception as e:
            print(f"❌ Failed to initialize APNs: {str(e)}")

    def send_notification(self, device_token, title, body, badge=None, data=None):
        """
        Send push notification to iOS device

        Args:
            device_token: Device's APNs token
            title: Notification title
            body: Notification body
            badge: Badge count (optional)
            data: Custom data payload (optional)
        """
        if not self.client:
            print("⚠️ APNs client not initialized")
            return False

        try:
            # Create payload
            payload = Payload(
                alert={"title": title, "body": body},
                badge=badge,
                sound="default",
                custom=data or {},
            )

            # Send notification
            self.client.send_notification(device_token, payload, topic=self.bundle_id)

            print(f"✅ Push notification sent to {device_token[:10]}...")
            return True

        except Exception as e:
            print(f"❌ Failed to send push notification: {str(e)}")
            return False

    def send_silent_notification(self, device_token, data):
        """
        Send silent notification (background fetch)

        Args:
            device_token: Device's APNs token
            data: Custom data payload
        """
        if not self.client:
            print("⚠️ APNs client not initialized")
            return False

        try:
            # Silent notification with content-available
            payload = Payload(content_available=True, custom=data or {})

            self.client.send_notification(
                device_token,
                payload,
                topic=self.bundle_id,
                priority=5,  # Lower priority for background
            )

            print(f"✅ Silent notification sent to {device_token[:10]}...")
            return True

        except Exception as e:
            print(f"❌ Failed to send silent notification: {str(e)}")
            return False
