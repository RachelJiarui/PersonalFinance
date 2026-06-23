import quopri
import re
from datetime import datetime
from typing import Dict, Optional

from services.parsers.base import EmailParser


class SavorOneEmailParser(EmailParser):
    """Parser for Capital One Savor/SavorOne card transaction alert emails."""

    def matches(self, subject: str, from_email: str) -> bool:
        return (
            subject == "A new transaction was charged to your account"
            and "capitalone@notification.capitalone.com" in from_email.lower()
        )

    def parse_transaction(self, email_body: str) -> Optional[Dict]:
        try:
            # Capital One HTML emails use quoted-printable encoding.
            # Decode it first so patterns work reliably (e.g. "7733" won't be split as "773=\n3").
            body = email_body
            if "=3D" in body or "=\n" in body:
                body = quopri.decodestring(body.encode()).decode(
                    "utf-8", errors="replace"
                )

            # All key data lives in one sentence in both the plain-text and HTML parts:
            # "on Jun. 18, 2026, at CONTES BIKE SHOP LEXIN, a pending authorization
            #  or purchase in the amount of $20.13 was placed or charged"

            merchant_match = re.search(
                r"on\s+[A-Za-z]+\.?\s+\d{1,2},\s+\d{4},\s+at\s+(.+?),\s+a\s+pending",
                body,
                re.IGNORECASE,
            )
            if not merchant_match:
                return None
            merchant = merchant_match.group(1).strip()

            date_match = re.search(
                r"on\s+([A-Za-z]+\.?\s+\d{1,2},\s+\d{4}),\s+at\s+",
                body,
                re.IGNORECASE,
            )
            if not date_match:
                return None
            date_str = date_match.group(1).strip()

            amount_match = re.search(
                r"in the amount of\s+\$?([\d,]+\.?\d*)",
                body,
                re.IGNORECASE,
            )
            if not amount_match:
                return None
            amount = float(amount_match.group(1).replace(",", ""))

            card_match = re.search(r"ending in\s+(\d{4})", body, re.IGNORECASE)
            card_last4 = card_match.group(1) if card_match else None

            # Normalize "Jun. 18, 2026" → "Jun 18, 2026" before strptime
            date_str_normalized = re.sub(r"([A-Za-z]+)\.", r"\1", date_str).strip()
            try:
                transaction_date = datetime.strptime(date_str_normalized, "%b %d, %Y")
            except ValueError:
                print(f"Failed to parse Capital One date: {date_str}")
                return None

            return {
                "merchant": merchant,
                "transaction_date": transaction_date.isoformat(),
                "amount": amount,
                "card_last4": card_last4,
            }

        except Exception as e:
            print(f"Error parsing Capital One Savor email: {e}")
            return None
