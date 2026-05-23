"""Google Maps Distance Matrix & Geocoding API client.

Uses the ``googlemaps`` Python SDK.  The client is lazily instantiated and
cached so repeated calls within a process share a single HTTP session.
"""

import logging
import os
from functools import lru_cache
from typing import Optional, Tuple

import googlemaps

logger = logging.getLogger(__name__)


@lru_cache(maxsize=1)
def get_googlemaps_client() -> googlemaps.Client:
    """Return a cached Google Maps client.

    Raises
    ------
    ValueError
        If GOOGLE_MAPS_API_KEY is not set.
    """
    api_key = os.getenv("GOOGLE_MAPS_API_KEY")
    if not api_key:
        raise ValueError("GOOGLE_MAPS_API_KEY environment variable is not set.")
    return googlemaps.Client(key=api_key)


def geocode_location(
    gmaps: googlemaps.Client, location: str
) -> Optional[Tuple[float, float]]:
    """Convert a location string to (latitude, longitude).

    Parameters
    ----------
    gmaps:
        Initialised Google Maps client.
    location:
        Free-form location string, e.g. ``"Hội trường Thành phố Đà Nẵng"``.

    Returns
    -------
    tuple[float, float] or None
        ``(lat, lng)`` of the best geocoding result, or ``None`` if no result.
    """
    try:
        results = gmaps.geocode(location)
        if results:
            loc = results[0]["geometry"]["location"]
            return loc["lat"], loc["lng"]
    except Exception as exc:
        logger.warning("Geocoding failed for %r: %s", location, exc)
    return None


def get_driving_duration_minutes(
    gmaps: googlemaps.Client,
    origin_lat: float,
    origin_lng: float,
    dest_lat: float,
    dest_lng: float,
) -> Optional[float]:
    """Return the estimated driving duration in minutes between two coordinates.

    Parameters
    ----------
    gmaps:
        Initialised Google Maps client.
    origin_lat, origin_lng:
        Starting point coordinates.
    dest_lat, dest_lng:
        Destination coordinates.

    Returns
    -------
    float or None
        Duration in minutes, or ``None`` if the API returned no valid route.
    """
    try:
        result = gmaps.distance_matrix(
            origins=[f"{origin_lat},{origin_lng}"],
            destinations=[f"{dest_lat},{dest_lng}"],
            mode="driving",
        )
        element = result["rows"][0]["elements"][0]
        if element["status"] == "OK":
            return element["duration"]["value"] / 60.0
    except Exception as exc:
        logger.warning(
            "Distance Matrix API error for (%s,%s)->(%s,%s): %s",
            origin_lat,
            origin_lng,
            dest_lat,
            dest_lng,
            exc,
        )
    return None
