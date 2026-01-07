"""
Email Parser for Transaction Alerts
Parses Discover card transaction emails
"""

import re
from datetime import datetime
from html import unescape
from typing import Dict, Optional


class DiscoverEmailParser:
    """Parser for Discover Card transaction alert emails"""

    @staticmethod
    def is_discover_transaction_alert(subject: str, from_email: str) -> bool:
        """
        Check if email is a Discover transaction alert

        Args:
            subject: Email subject line
            from_email: Sender email address

        Returns:
            True if this is a Discover transaction alert
        """
        # Accept real Discover emails
        if (
            subject == "Transaction Alert"
            and "discover@services.discover.com" in from_email.lower()
        ):
            return True

        # Accept test emails (send yourself an email with this subject for testing)
        if subject == "TEST" and "rachel.j.chen@gmail.com" in from_email.lower():
            return True

        return False

    @staticmethod
    def parse_transaction(email_body: str) -> Optional[Dict]:
        """
        Parse transaction details from Discover email body
        Handles both HTML and plain text formats

        Args:
            email_body: Email body (HTML or plain text)

        Returns:
            Dict with merchant, date, amount, or None if parsing fails
        """
        try:
            # Check if this is HTML content
            is_html = bool(re.search(r"<html|<br|<p", email_body, re.IGNORECASE))

            if is_html:
                # Parse HTML format - transaction details are in the HTML
                # Pattern: Merchant: Preply Inc.<br/>
                merchant_match = re.search(
                    r"Merchant:\s*([^<\n]+?)(?:<br|</)", email_body, re.IGNORECASE
                )
                if not merchant_match:
                    return None
                merchant = unescape(merchant_match.group(1).strip())

                # Extract date from HTML
                date_match = re.search(
                    r"Date:\s*([^<\n]+?)(?:<br|</)", email_body, re.IGNORECASE
                )
                if not date_match:
                    return None
                date_str = unescape(date_match.group(1).strip())

                # Extract amount from HTML
                amount_match = re.search(
                    r"Amount:\s*\$?([\d,]+\.?\d*)(?:<br|</|\s)",
                    email_body,
                    re.IGNORECASE,
                )
                if not amount_match:
                    return None
                amount_str = amount_match.group(1).replace(",", "")
                amount = float(amount_str)

            else:
                # Parse plain text format
                merchant_match = re.search(
                    r"Merchant:\s*(.+?)(?:\n|$)", email_body, re.IGNORECASE
                )
                if not merchant_match:
                    return None
                merchant = merchant_match.group(1).strip()

                # Extract date
                date_match = re.search(
                    r"Date:\s*(.+?)(?:\n|$)", email_body, re.IGNORECASE
                )
                if not date_match:
                    return None
                date_str = date_match.group(1).strip()

                # Extract amount
                amount_match = re.search(
                    r"Amount:\s*\$?([\d,]+\.?\d*)", email_body, re.IGNORECASE
                )
                if not amount_match:
                    return None
                amount_str = amount_match.group(1).replace(",", "")
                amount = float(amount_str)

            # Parse date (e.g., "December 30, 2025" or "January 06, 2026")
            try:
                transaction_date = datetime.strptime(date_str, "%B %d, %Y")
            except ValueError:
                # Try alternative format if needed
                print(f"Failed to parse date: {date_str}")
                return None

            # Extract card last 4 digits if available
            card_match = re.search(r"Last 4 #:\s*(\d{4})", email_body, re.IGNORECASE)
            card_last4 = card_match.group(1) if card_match else None

            return {
                "merchant": merchant,
                "transaction_date": transaction_date.isoformat(),
                "amount": amount,
                "card_last4": card_last4,
            }

        except Exception as e:
            print(f"Error parsing Discover email: {e}")
            return None
