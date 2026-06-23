"""
Email parsers for transaction alert emails.

To add a new parser:
  1. Create a new file in services/parsers/ and subclass EmailParser from services.parsers.base
  2. Implement `matches()` and `parse_transaction()`
  3. Import and append an instance to PARSERS below
"""

from services.parsers.base import EmailParser
from services.parsers.discover import DiscoverEmailParser
from services.parsers.savorone import SavorOneEmailParser

# Re-export EmailParser so existing imports from this module still work
__all__ = ["EmailParser", "PARSERS"]

# Registry of all active parsers. Add new parsers here.
PARSERS: list[EmailParser] = [
    DiscoverEmailParser(),
    SavorOneEmailParser(),
]
