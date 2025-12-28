"""
Gmail Watch Manager
Handles automatic renewal of Gmail push notifications
"""

import os
import time
from datetime import datetime, timedelta

from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError


class GmailWatchManager:
    """Manages Gmail watch lifecycle including auto-renewal"""

    def __init__(self, firestore_service):
        self.db = firestore_service
        self.watch_topic = os.getenv("GMAIL_WATCH_TOPIC")
        self.label_ids = os.getenv("GMAIL_WATCH_LABEL_IDS", "INBOX").split(",")

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
            credentials = Credentials(token=access_token)
            service = build("gmail", "v1", credentials=credentials)

            request_body = {"labelIds": self.label_ids, "topicName": self.watch_topic}

            response = (
                service.users().watch(userId=user_id, body=request_body).execute()
            )

            expiration_ms = int(response.get("expiration"))
            history_id = response.get("historyId")

            # Store watch info in Firestore
            self._save_watch_info(user_id, expiration_ms, history_id, access_token)

            expiration_dt = datetime.fromtimestamp(expiration_ms / 1000)
            print(f"✅ Gmail watch set up for {user_id}")
            print(f"   History ID: {history_id}")
            print(f"   Expiration: {expiration_dt.strftime('%Y-%m-%d %H:%M:%S')}")

            return response

        except HttpError as error:
            print(f"❌ Error setting up Gmail watch: {error}")
            raise

    def check_and_renew_watches(self):
        """
        Check all active watches and renew if expiring soon

        This should be called daily (e.g., via Cloud Scheduler)
        Renews any watch that expires in < 24 hours
        """
        try:
            print("🔄 Checking Gmail watches for renewal...")

            # Get all users with active watches
            users = self._get_users_with_watches()

            renewed_count = 0
            failed_count = 0

            for user in users:
                user_id = user.get("user_id")
                email = user.get("email")
                watch_info = user.get("gmail_watch", {})

                expiration_ms = watch_info.get("expiration")
                access_token = watch_info.get("access_token")

                if not expiration_ms or not access_token:
                    print(f"⚠️ User {email} missing watch info, skipping")
                    continue

                # Check if expiring in < 24 hours
                expiration_dt = datetime.fromtimestamp(expiration_ms / 1000)
                time_remaining = expiration_dt - datetime.now()

                if time_remaining.total_seconds() < 24 * 3600:  # 24 hours
                    print(
                        f"🔄 Renewing watch for {email} (expires in {time_remaining.days} days, {time_remaining.seconds // 3600} hours)"
                    )

                    try:
                        self.setup_watch(email, access_token)
                        renewed_count += 1
                        print(f"✅ Renewed watch for {email}")
                    except Exception as e:
                        print(f"❌ Failed to renew watch for {email}: {e}")
                        failed_count += 1
                else:
                    days_remaining = time_remaining.days
                    print(
                        f"✓ Watch for {email} is active ({days_remaining} days remaining)"
                    )

            print(f"\n📊 Renewal Summary:")
            print(f"   Total users: {len(users)}")
            print(f"   Renewed: {renewed_count}")
            print(f"   Failed: {failed_count}")

            return {
                "total": len(users),
                "renewed": renewed_count,
                "failed": failed_count,
            }

        except Exception as e:
            print(f"❌ Error in check_and_renew_watches: {e}")
            raise

    def stop_watch(self, user_id, access_token):
        """Stop Gmail push notifications for a user"""
        try:
            credentials = Credentials(token=access_token)
            service = build("gmail", "v1", credentials=credentials)

            service.users().stop(userId=user_id).execute()

            # Remove watch info from Firestore
            self._remove_watch_info(user_id)

            print(f"✅ Gmail watch stopped for {user_id}")

        except HttpError as error:
            print(f"❌ Error stopping Gmail watch: {error}")
            raise

    def _save_watch_info(self, user_id, expiration_ms, history_id, access_token):
        """Save watch information to Firestore"""
        watch_info = {
            "expiration": expiration_ms,
            "history_id": history_id,
            "access_token": access_token,
            "created_at": int(time.time() * 1000),
            "last_renewed": int(time.time() * 1000),
        }

        self.db.db.collection("users").document(user_id).update(
            {"gmail_watch": watch_info, "updated_at": self.db.db.SERVER_TIMESTAMP}
        )

    def _remove_watch_info(self, user_id):
        """Remove watch information from Firestore"""
        self.db.db.collection("users").document(user_id).update(
            {"gmail_watch": None, "updated_at": self.db.db.SERVER_TIMESTAMP}
        )

    def _get_users_with_watches(self):
        """Get all users who have active Gmail watches"""
        users_ref = self.db.db.collection("users")

        # Query for users with gmail_watch field
        users = users_ref.where("gmail_watch", "!=", None).stream()

        return [{"user_id": user.id, **user.to_dict()} for user in users]

    def get_watch_status(self, user_id):
        """Get current watch status for a user"""
        user = self.db.get_user_by_id(user_id)

        if not user or "gmail_watch" not in user:
            return {"active": False, "message": "No active watch"}

        watch_info = user["gmail_watch"]
        expiration_ms = watch_info.get("expiration")

        if not expiration_ms:
            return {"active": False, "message": "Watch info incomplete"}

        expiration_dt = datetime.fromtimestamp(expiration_ms / 1000)
        time_remaining = expiration_dt - datetime.now()

        if time_remaining.total_seconds() < 0:
            return {
                "active": False,
                "expired": True,
                "expired_at": expiration_dt.isoformat(),
                "message": f"Watch expired {abs(time_remaining.days)} days ago",
            }

        return {
            "active": True,
            "expiration": expiration_dt.isoformat(),
            "days_remaining": time_remaining.days,
            "hours_remaining": time_remaining.seconds // 3600,
            "message": f"Watch active, expires in {time_remaining.days} days",
        }
