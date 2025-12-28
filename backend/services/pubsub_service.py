"""
Google Cloud Pub/Sub Service
Handles Gmail push notification subscriptions
"""

import base64
import os

from google.cloud import pubsub_v1
from google.oauth2 import service_account


class PubSubService:
    def __init__(self):
        self.project_id = os.getenv("GOOGLE_CLOUD_PROJECT")
        self.topic_name = os.getenv("PUBSUB_TOPIC", "gmail-notifications")
        self.subscription_name = os.getenv(
            "PUBSUB_SUBSCRIPTION", "gmail-notifications-sub"
        )

        # Initialize credentials
        credentials_path = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
        if credentials_path and os.path.exists(credentials_path):
            self.credentials = service_account.Credentials.from_service_account_file(
                credentials_path
            )
        else:
            self.credentials = None

        self.publisher = None
        self.subscriber = None
        self.setup()

    def setup(self):
        """Set up Pub/Sub publisher and subscriber"""
        try:
            if self.credentials:
                self.publisher = pubsub_v1.PublisherClient(credentials=self.credentials)
                self.subscriber = pubsub_v1.SubscriberClient(
                    credentials=self.credentials
                )
            else:
                self.publisher = pubsub_v1.PublisherClient()
                self.subscriber = pubsub_v1.SubscriberClient()

            print("✅ Pub/Sub client initialized")
        except Exception as e:
            print(f"❌ Failed to initialize Pub/Sub: {str(e)}")

    def is_connected(self):
        """Check if Pub/Sub is connected"""
        return self.publisher is not None

    def verify_push_request(self, request):
        """
        Verify that the push request came from Google Cloud Pub/Sub
        You can add additional verification here (e.g., JWT tokens)
        """
        # For now, simple verification - in production, verify JWT tokens
        return True

    def create_topic(self):
        """Create a Pub/Sub topic for Gmail notifications"""
        try:
            topic_path = self.publisher.topic_path(self.project_id, self.topic_name)
            topic = self.publisher.create_topic(request={"name": topic_path})
            print(f"✅ Created topic: {topic.name}")
            return topic
        except Exception as e:
            print(f"⚠️ Topic may already exist: {str(e)}")
            return None

    def create_subscription(self, push_endpoint):
        """
        Create a push subscription to receive notifications
        push_endpoint: Your server's webhook URL (e.g., https://your-domain.com/webhooks/gmail)
        """
        try:
            topic_path = self.publisher.topic_path(self.project_id, self.topic_name)
            subscription_path = self.subscriber.subscription_path(
                self.project_id, self.subscription_name
            )

            push_config = pubsub_v1.types.PushConfig(push_endpoint=push_endpoint)

            subscription = self.subscriber.create_subscription(
                request={
                    "name": subscription_path,
                    "topic": topic_path,
                    "push_config": push_config,
                }
            )

            print(f"✅ Created subscription: {subscription.name}")
            return subscription

        except Exception as e:
            print(f"⚠️ Subscription may already exist: {str(e)}")
            return None

    def get_topic_path(self):
        """Get the full topic path for Gmail watch setup"""
        return f"projects/{self.project_id}/topics/{self.topic_name}"

    def publish_message(self, data):
        """Publish a message to the topic (for testing)"""
        try:
            topic_path = self.publisher.topic_path(self.project_id, self.topic_name)
            data_bytes = data.encode("utf-8")
            future = self.publisher.publish(topic_path, data_bytes)
            message_id = future.result()
            print(f"✅ Published message: {message_id}")
            return message_id
        except Exception as e:
            print(f"❌ Failed to publish message: {str(e)}")
            return None
