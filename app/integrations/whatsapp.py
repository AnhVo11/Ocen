"""Twilio WhatsApp API client.

Provides a thin wrapper around the Twilio REST client for sending WhatsApp
messages.  All configuration is read from environment variables so this module
is safe to import without side effects.
"""

import logging
import os
from functools import lru_cache

from twilio.rest import Client

logger = logging.getLogger(__name__)

# WhatsApp sandbox / production number registered in Twilio console
_DEFAULT_FROM = "whatsapp:+14155238886"


@lru_cache(maxsize=1)
def _get_client() -> Client:
    """Return a cached Twilio REST client.

    Raises
    ------
    ValueError
        If TWILIO_ACCOUNT_SID or TWILIO_AUTH_TOKEN env vars are missing.
    """
    account_sid = os.getenv("TWILIO_ACCOUNT_SID")
    auth_token = os.getenv("TWILIO_AUTH_TOKEN")
    if not account_sid or not auth_token:
        raise ValueError(
            "TWILIO_ACCOUNT_SID and TWILIO_AUTH_TOKEN must be set in environment."
        )
    return Client(account_sid, auth_token)


def send_whatsapp_message(to: str, body: str) -> str:
    """Send a WhatsApp message via Twilio and return the message SID.

    Parameters
    ----------
    to:
        Recipient WhatsApp number in E.164 format with prefix,
        e.g. ``"whatsapp:+84901234567"``.
    body:
        Message text (plain text or WhatsApp-formatted markdown).

    Returns
    -------
    str
        Twilio message SID for tracking.

    Raises
    ------
    twilio.base.exceptions.TwilioRestException
        On API errors (wrong number format, rate-limit, etc.).
    """
    client = _get_client()
    from_number = os.getenv("TWILIO_WHATSAPP_FROM", _DEFAULT_FROM)

    message = client.messages.create(
        from_=from_number,
        to=to,
        body=body,
    )
    logger.info("Sent WhatsApp message sid=%s to=%s", message.sid, to)
    return message.sid
