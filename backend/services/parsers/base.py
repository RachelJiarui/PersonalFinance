from abc import ABC, abstractmethod
from typing import Dict, Optional


class EmailParser(ABC):
    """Base class for all transaction email parsers."""

    @abstractmethod
    def matches(self, subject: str, from_email: str) -> bool:
        """Return True if this parser handles the given email."""

    @abstractmethod
    def parse_transaction(self, email_body: str) -> Optional[Dict]:
        """
        Extract transaction details from the email body.

        Returns a dict with keys: merchant, transaction_date, amount, card_last4
        or None if parsing fails.
        """
