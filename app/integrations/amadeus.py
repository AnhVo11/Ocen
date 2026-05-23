"""Amadeus Flight Search API client.

Wraps the official ``amadeus`` Python SDK for searching flight offers between
Vietnamese airports.  The client is lazily instantiated and cached.
"""

import logging
import os
from functools import lru_cache
from typing import Any, Dict, List

from amadeus import Client, ResponseError

logger = logging.getLogger(__name__)


@lru_cache(maxsize=1)
def get_amadeus_client() -> Client:
    """Return a cached Amadeus API client.

    Raises
    ------
    ValueError
        If AMADEUS_API_KEY or AMADEUS_API_SECRET are missing.
    """
    api_key = os.getenv("AMADEUS_API_KEY")
    api_secret = os.getenv("AMADEUS_API_SECRET")
    if not api_key or not api_secret:
        raise ValueError(
            "AMADEUS_API_KEY and AMADEUS_API_SECRET must be set in environment."
        )
    return Client(client_id=api_key, client_secret=api_secret)


def search_flights(
    amadeus_client: Client,
    origin: str,
    destination: str,
    date_str: str,
    max_results: int = 10,
) -> List[Dict[str, Any]]:
    """Search for one-way flight offers between two IATA airport codes.

    Parameters
    ----------
    amadeus_client:
        Initialised Amadeus client.
    origin:
        IATA code of departure airport (e.g. ``"HAN"``).
    destination:
        IATA code of arrival airport (e.g. ``"SGN"``).
    date_str:
        Departure date in ``YYYY-MM-DD`` format.
    max_results:
        Maximum number of offers to return (Amadeus caps this at 250).

    Returns
    -------
    list[dict]
        Raw Amadeus flight offer objects.  Each offer contains an
        ``itineraries`` list with a ``duration`` field in ISO 8601 format
        (e.g. ``"PT1H30M"``).

    Raises
    ------
    RuntimeError
        Wraps Amadeus ``ResponseError`` with a human-readable message.
    """
    try:
        response = amadeus_client.shopping.flight_offers_search.get(
            originLocationCode=origin,
            destinationLocationCode=destination,
            departureDate=date_str,
            adults=1,
            max=max_results,
        )
        return response.data or []
    except ResponseError as exc:
        raise RuntimeError(
            f"Amadeus API error searching {origin}→{destination} on {date_str}: {exc}"
        ) from exc
