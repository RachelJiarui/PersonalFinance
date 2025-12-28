"""
Transaction Parser
Parses Discover transaction emails into structured data
"""

import re
from datetime import datetime


class TransactionParser:
    def __init__(self):
        # Regex patterns for Discover emails
        self.amount_pattern = r"\$?([\d,]+\.\d{2})"
        self.merchant_pattern = r"at\s+([A-Z][A-Za-z0-9\s\-\.]+)"
        self.date_pattern = r"(\d{1,2}/\d{1,2}/\d{4})"

    def parse_discover_email(self, message):
        """
        Parse a Discover transaction email

        Args:
            message: Gmail message object

        Returns:
            Dictionary with transaction data or None
        """
        try:
            from services.gmail_service import GmailService

            gmail = GmailService()

            subject = gmail.get_message_subject(message)
            body = gmail.get_message_body(message)
            message_date = gmail.get_message_date(message)

            # Check if this is a transaction alert
            subject_lower = subject.lower()
            if not any(
                keyword in subject_lower
                for keyword in ["purchase", "transaction", "transaction alert"]
            ):
                return None

            # Specifically look for "Transaction Alert" subject from Discover
            is_transaction_alert = "transaction alert" in subject_lower

            # Extract amount
            amount_match = re.search(self.amount_pattern, body)
            if not amount_match:
                return None
            amount = float(amount_match.group(1).replace(",", ""))

            # Extract merchant
            merchant_match = re.search(self.merchant_pattern, body)
            merchant = (
                merchant_match.group(1).strip()
                if merchant_match
                else "Unknown Merchant"
            )

            # Extract transaction date
            date_match = re.search(self.date_pattern, body)
            if date_match:
                date_str = date_match.group(1)
                transaction_date = datetime.strptime(date_str, "%m/%d/%Y")
            else:
                # Use email received date as fallback
                transaction_date = datetime.now()

            # Create transaction alert object
            alert = {
                "email_id": message["id"],
                "merchant": merchant,
                "amount": amount,
                "date": transaction_date.isoformat(),
                "raw_email_body": body[:500],  # Store first 500 chars
                "subject": subject,
                "received_at": datetime.now().isoformat(),
            }

            print(f"💰 Parsed transaction: {merchant} - ${amount}")

            return alert

        except Exception as e:
            print(f"❌ Error parsing Discover email: {str(e)}")
            return None

    def parse_amount(self, text):
        """Extract dollar amount from text"""
        match = re.search(self.amount_pattern, text)
        if match:
            return float(match.group(1).replace(",", ""))
        return None

    def clean_merchant_name(self, merchant):
        """Clean up merchant name"""
        # Remove common suffixes
        suffixes = [" INC", " LLC", " CORP", " CO", " LTD"]
        merchant_upper = merchant.upper()

        for suffix in suffixes:
            if merchant_upper.endswith(suffix):
                merchant = merchant[: -len(suffix)]

        return merchant.strip()
