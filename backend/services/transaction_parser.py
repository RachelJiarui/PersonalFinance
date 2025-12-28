"""
Transaction Parser
Parses Discover transaction emails into structured data
"""

import logging
import re
from datetime import datetime

logger = logging.getLogger(__name__)


class TransactionParser:
    def __init__(self):
        # Multiple regex patterns for different merchant name formats
        self.merchant_patterns = [
            # Standard format: "at Whole Foods"
            r"at\s+([A-Z][A-Za-z0-9\s\-\.&']+?)(?:\s+on|\s+for|\s+was|\.|$)",
            # With special chars: "at McDonald's", "at H&M"
            r"at\s+([A-Z][A-Za-z0-9\s\-\.&'#@!]+?)(?:\s+on|\s+for|\s+was|\.|$)",
            # Multiline: capture until newline or period
            r"at\s+([^\n\.]+?)(?:\s+on|\s+for|\s+was|\.|$|\n)",
            # Fallback: anything after "at" until punctuation
            r"at\s+(.+?)(?:\.|,|;|\n|$)",
        ]

        # Amount pattern - handles various formats
        self.amount_pattern = r"\$?([\d,]+\.\d{2})"

        # Date patterns - multiple formats
        self.date_patterns = [
            r"(\d{1,2}/\d{1,2}/\d{4})",  # MM/DD/YYYY or M/D/YYYY
            r"(\d{4}-\d{2}-\d{2})",  # YYYY-MM-DD
            r"(\w+\s+\d{1,2},\s+\d{4})",  # January 1, 2025
        ]

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
                logger.warning(
                    f"Could not extract amount from email {message['id'][:10]}. "
                    f"Subject: {subject}"
                )
                return None

            try:
                amount = float(amount_match.group(1).replace(",", ""))
            except ValueError as e:
                logger.error(f"Invalid amount format: {amount_match.group(1)}")
                return None

            # Extract merchant - try multiple patterns
            merchant = None
            for pattern in self.merchant_patterns:
                merchant_match = re.search(pattern, body, re.IGNORECASE | re.MULTILINE)
                if merchant_match:
                    merchant = merchant_match.group(1).strip()
                    # Clean up extra whitespace and newlines
                    merchant = re.sub(r"\s+", " ", merchant)
                    merchant = self.clean_merchant_name(merchant)
                    break

            if not merchant:
                logger.warning(
                    f"Could not extract merchant from email {message['id'][:10]}. "
                    f"Using fallback. Body preview: {body[:200]}"
                )
                merchant = "Unknown Merchant"

            # Extract transaction date - try multiple formats
            transaction_date = None
            for date_pattern in self.date_patterns:
                date_match = re.search(date_pattern, body)
                if date_match:
                    date_str = date_match.group(1)
                    transaction_date = self._parse_date(date_str)
                    if transaction_date:
                        break

            if not transaction_date:
                # Use email received date as fallback
                logger.info(
                    f"Could not extract date from email {message['id'][:10]}. "
                    f"Using current date as fallback."
                )
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

            logger.info(f"✅ Parsed transaction: {merchant} - ${amount:.2f}")

            return alert

        except Exception as e:
            logger.error(
                f"❌ Error parsing Discover email {message.get('id', 'unknown')[:10]}: {str(e)}",
                exc_info=True,
            )
            # Log the email body for debugging (truncated)
            try:
                from services.gmail_service import GmailService

                gmail = GmailService()
                body = gmail.get_message_body(message)
                logger.debug(f"Failed email body preview: {body[:500]}")
            except:
                pass
            return None

    def parse_amount(self, text):
        """Extract dollar amount from text"""
        match = re.search(self.amount_pattern, text)
        if match:
            return float(match.group(1).replace(",", ""))
        return None

    def _parse_date(self, date_str):
        """
        Parse date string in multiple formats

        Args:
            date_str: Date string to parse

        Returns:
            datetime object or None if parsing fails
        """
        date_formats = [
            "%m/%d/%Y",  # 12/26/2025
            "%Y-%m-%d",  # 2025-12-26
            "%B %d, %Y",  # December 26, 2025
            "%b %d, %Y",  # Dec 26, 2025
        ]

        for fmt in date_formats:
            try:
                return datetime.strptime(date_str, fmt)
            except ValueError:
                continue

        logger.warning(f"Could not parse date: {date_str}")
        return None

    def clean_merchant_name(self, merchant):
        """
        Clean up merchant name - remove suffixes, extra chars, normalize

        Args:
            merchant: Raw merchant name from email

        Returns:
            Cleaned merchant name
        """
        if not merchant:
            return "Unknown Merchant"

        # Remove common business suffixes
        suffixes = [
            " INC",
            " LLC",
            " CORP",
            " CO",
            " LTD",
            " LP",
            " LLP",
            " INCORPORATED",
            " CORPORATION",
            " COMPANY",
            " LIMITED",
        ]
        merchant_upper = merchant.upper()

        for suffix in suffixes:
            if merchant_upper.endswith(suffix):
                merchant = merchant[: -len(suffix)]

        # Remove trailing special characters
        merchant = merchant.rstrip(".,;:!-")

        # Collapse multiple spaces
        merchant = re.sub(r"\s+", " ", merchant)

        # Title case for better display
        merchant = merchant.strip().title()

        return merchant if merchant else "Unknown Merchant"
