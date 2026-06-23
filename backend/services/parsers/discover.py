import re
from datetime import datetime
from html import unescape
from typing import Dict, Optional

from services.parsers.base import EmailParser


class DiscoverEmailParser(EmailParser):
    """Parser for Discover Card transaction alert emails."""

    def matches(self, subject: str, from_email: str) -> bool:
        if (
            subject == "Transaction Alert"
            and "discover@services.discover.com" in from_email.lower()
        ):
            return True

        # Test emails (send yourself an email with this subject for testing)
        if subject == "TEST" and "rachel.j.chen@gmail.com" in from_email.lower():
            return True

        return False

    def parse_transaction(self, email_body: str) -> Optional[Dict]:
        try:
            is_html = bool(re.search(r"<html|<br|<p", email_body, re.IGNORECASE))

            if is_html:
                merchant_match = re.search(
                    r"Merchant:\s*([^<\n]+?)(?:<br|</)", email_body, re.IGNORECASE
                )
                if not merchant_match:
                    return None
                merchant = unescape(merchant_match.group(1).strip())

                date_match = re.search(
                    r"Date:\s*([^<\n]+?)(?:<br|</)", email_body, re.IGNORECASE
                )
                if not date_match:
                    return None
                date_str = unescape(date_match.group(1).strip())

                amount_match = re.search(
                    r"Amount:\s*\$?([\d,]+\.?\d*)(?:<br|</|\s)",
                    email_body,
                    re.IGNORECASE,
                )
                if not amount_match:
                    return None
                amount = float(amount_match.group(1).replace(",", ""))

            else:
                merchant_match = re.search(
                    r"Merchant:\s*(.+?)(?:\n|$)", email_body, re.IGNORECASE
                )
                if not merchant_match:
                    return None
                merchant = merchant_match.group(1).strip()

                date_match = re.search(
                    r"Date:\s*(.+?)(?:\n|$)", email_body, re.IGNORECASE
                )
                if not date_match:
                    return None
                date_str = date_match.group(1).strip()

                amount_match = re.search(
                    r"Amount:\s*\$?([\d,]+\.?\d*)", email_body, re.IGNORECASE
                )
                if not amount_match:
                    return None
                amount = float(amount_match.group(1).replace(",", ""))

            try:
                transaction_date = datetime.strptime(date_str, "%B %d, %Y")
            except ValueError:
                print(f"Failed to parse date: {date_str}")
                return None

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
