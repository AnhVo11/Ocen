"""Travel feasibility checker: car vs. flight decision tree.

Decision rules
--------------
* distance < 100 km  → check Google Maps driving time
* distance ≥ 100 km  → check Amadeus for available flights
  - Total travel time required = 30 min (origin airport transfer)
                                + 60 min (check-in buffer)
                                + flight duration
                                + 30 min (destination airport transfer)
  - If shortest flight fits within the gap → feasible by flight
  - Otherwise → not feasible

Vietnam city → IATA mapping covers the 14 domestic airports with scheduled
commercial service.
"""

import logging
import math
import re
from datetime import datetime
from typing import Any, Dict, Optional

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Vietnam domestic airport IATA codes
# ---------------------------------------------------------------------------

VIETNAM_IATA: Dict[str, str] = {
    "hanoi": "HAN",
    "hà nội": "HAN",
    "ha noi": "HAN",
    "ho chi minh": "SGN",
    "hồ chí minh": "SGN",
    "hcmc": "SGN",
    "saigon": "SGN",
    "sài gòn": "SGN",
    "da nang": "DAD",
    "đà nẵng": "DAD",
    "da lat": "DLI",
    "đà lạt": "DLI",
    "dalat": "DLI",
    "nha trang": "CXR",
    "hue": "HUI",
    "huế": "HUI",
    "vinh": "VII",
    "hai phong": "HPH",
    "hải phòng": "HPH",
    "buon ma thuot": "BMV",
    "buôn ma thuột": "BMV",
    "phu quoc": "PQC",
    "phú quốc": "PQC",
    "can tho": "VCA",
    "cần thơ": "VCA",
    "pleiku": "PXU",
    "quy nhon": "UIH",
    "quy nhơn": "UIH",
    "dong hoi": "VDH",
    "đồng hới": "VDH",
}

# Minutes of overhead for air travel independent of flight duration
_AIRPORT_TRANSFER_MINUTES = 30   # each end
_CHECKIN_BUFFER_MINUTES = 60
_TOTAL_OVERHEAD_MINUTES = _CHECKIN_BUFFER_MINUTES + 2 * _AIRPORT_TRANSFER_MINUTES  # 120


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def haversine(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Return the great-circle distance in kilometres between two points.

    Parameters
    ----------
    lat1, lon1:
        Latitude and longitude of point A in decimal degrees.
    lat2, lon2:
        Latitude and longitude of point B in decimal degrees.

    Returns
    -------
    float
        Distance in kilometres.
    """
    R = 6_371.0  # Earth's mean radius, km
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    d_phi = math.radians(lat2 - lat1)
    d_lambda = math.radians(lon2 - lon1)

    a = (
        math.sin(d_phi / 2) ** 2
        + math.cos(phi1) * math.cos(phi2) * math.sin(d_lambda / 2) ** 2
    )
    return 2 * R * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def _parse_iso_duration(iso_str: str) -> float:
    """Parse an ISO 8601 duration string (e.g. ``"PT2H30M"``) to minutes.

    Only hours and minutes components are considered (days are ignored for
    domestic flights).

    Parameters
    ----------
    iso_str:
        Duration string returned by the Amadeus API.

    Returns
    -------
    float
        Total duration in minutes.
    """
    hours_match = re.search(r"(\d+)H", iso_str)
    minutes_match = re.search(r"(\d+)M", iso_str)
    total = 0.0
    if hours_match:
        total += int(hours_match.group(1)) * 60
    if minutes_match:
        total += int(minutes_match.group(1))
    return total


def _get_iata(location: str) -> Optional[str]:
    """Map a location string to a Vietnamese IATA code, or None if unknown.

    Performs a case-insensitive substring search against VIETNAM_IATA keys.

    Parameters
    ----------
    location:
        Free-form location name, e.g. ``"Sân bay Đà Nẵng"`` or ``"Da Nang"``.
    """
    if not location:
        return None
    lower = location.lower()
    for key, iata in VIETNAM_IATA.items():
        if key in lower:
            return iata
    return None


def _get_attr(obj: Any, key: str, default: Any = None) -> Any:
    """Retrieve ``key`` from either a dict or an ORM model instance."""
    if isinstance(obj, dict):
        return obj.get(key, default)
    return getattr(obj, key, default)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------


def check_travel_feasibility(
    sched_a: Any,
    sched_b: Any,
    gmaps_client: Any,
    amadeus_client: Any,
) -> Dict[str, Any]:
    """Determine whether travel from sched_a's end to sched_b's start is feasible.

    Parameters
    ----------
    sched_a:
        The preceding event — either a ``Schedule`` ORM model or a dict with
        keys: ``end_time``, ``lat``, ``lng``, ``location``.
    sched_b:
        The following event — same structure as sched_a but uses ``start_time``.
    gmaps_client:
        Initialised ``googlemaps.Client`` instance.
    amadeus_client:
        Initialised ``amadeus.Client`` instance.

    Returns
    -------
    dict
        ``{"feasible": bool, "mode": "car"|"flight"|"none"|"unknown", "message": str}``
    """
    # Extract shared fields
    lat_a: Optional[float] = _get_attr(sched_a, "lat")
    lng_a: Optional[float] = _get_attr(sched_a, "lng")
    lat_b: Optional[float] = _get_attr(sched_b, "lat")
    lng_b: Optional[float] = _get_attr(sched_b, "lng")
    end_a: datetime = _get_attr(sched_a, "end_time")
    start_b: datetime = _get_attr(sched_b, "start_time")

    if lat_a is None or lat_b is None:
        return {
            "feasible": True,
            "mode": "unknown",
            "message": (
                "Không thể kiểm tra lịch trình di chuyển do thiếu tọa độ địa điểm.\n"
                "_(Cannot verify travel — missing coordinates.)_"
            ),
        }

    available_minutes: float = (start_b - end_a).total_seconds() / 60.0
    distance_km: float = haversine(lat_a, lng_a, lat_b, lng_b)

    # -----------------------------------------------------------------------
    # Short-distance: check by road
    # -----------------------------------------------------------------------
    if distance_km < 100:
        try:
            result = gmaps_client.distance_matrix(
                origins=[f"{lat_a},{lng_a}"],
                destinations=[f"{lat_b},{lng_b}"],
                mode="driving",
            )
            element = result["rows"][0]["elements"][0]
            if element["status"] == "OK":
                drive_min = element["duration"]["value"] / 60.0
                if drive_min <= available_minutes:
                    return {
                        "feasible": True,
                        "mode": "car",
                        "message": (
                            f"✅ Có thể đi xe ({int(drive_min)} phút lái xe, "
                            f"có {int(available_minutes)} phút)."
                        ),
                    }
                return {
                    "feasible": False,
                    "mode": "none",
                    "message": (
                        f"🚗 Cần {int(drive_min)} phút lái xe nhưng chỉ có "
                        f"{int(available_minutes)} phút giữa hai sự kiện."
                    ),
                }
        except Exception as exc:
            logger.warning("Distance Matrix error: %s", exc)
            return {
                "feasible": True,
                "mode": "unknown",
                "message": "Không thể kiểm tra thời gian lái xe (lỗi Google Maps).",
            }

    # -----------------------------------------------------------------------
    # Long-distance: check by flight
    # -----------------------------------------------------------------------
    loc_a: str = _get_attr(sched_a, "location", "") or ""
    loc_b: str = _get_attr(sched_b, "location", "") or ""

    iata_a = _get_iata(loc_a)
    iata_b = _get_iata(loc_b)

    if not iata_a or not iata_b:
        return {
            "feasible": True,
            "mode": "unknown",
            "message": (
                f"Khoảng cách {int(distance_km)} km — không tìm được mã sân bay "
                f"cho '{loc_a}' hoặc '{loc_b}'. Kiểm tra thủ công."
            ),
        }

    max_flight_minutes = available_minutes - _TOTAL_OVERHEAD_MINUTES

    if max_flight_minutes <= 0:
        return {
            "feasible": False,
            "mode": "none",
            "message": (
                f"✈️ Cần bay ({int(distance_km)} km) nhưng không đủ thời gian "
                f"({int(available_minutes)} phút < {_TOTAL_OVERHEAD_MINUTES} phút thủ tục tối thiểu)."
            ),
        }

    try:
        departure_date = end_a.date().isoformat()
        from app.integrations.amadeus import search_flights

        flights = search_flights(amadeus_client, iata_a, iata_b, departure_date)

        if not flights:
            return {
                "feasible": False,
                "mode": "none",
                "message": (
                    f"✈️ Không tìm thấy chuyến bay từ {iata_a} đến {iata_b} "
                    f"ngày {departure_date}."
                ),
            }

        # Find the shortest available itinerary
        min_flight_minutes = float("inf")
        for offer in flights:
            for itinerary in offer.get("itineraries", []):
                dur = _parse_iso_duration(itinerary.get("duration", "PT0M"))
                if dur < min_flight_minutes:
                    min_flight_minutes = dur

        if min_flight_minutes <= max_flight_minutes:
            return {
                "feasible": True,
                "mode": "flight",
                "message": (
                    f"✅ Có chuyến bay {iata_a}→{iata_b} ({int(min_flight_minutes)} phút bay). "
                    f"Tổng thời gian cần: {int(min_flight_minutes + _TOTAL_OVERHEAD_MINUTES)} phút, "
                    f"có {int(available_minutes)} phút."
                ),
            }

        return {
            "feasible": False,
            "mode": "none",
            "message": (
                f"✈️ Chuyến bay ngắn nhất {iata_a}→{iata_b} "
                f"({int(min_flight_minutes)} phút) + thủ tục ({_TOTAL_OVERHEAD_MINUTES} phút) "
                f"= {int(min_flight_minutes + _TOTAL_OVERHEAD_MINUTES)} phút, "
                f"nhưng chỉ có {int(available_minutes)} phút giữa hai sự kiện."
            ),
        }

    except Exception as exc:
        logger.warning("Amadeus flight search error: %s", exc)
        return {
            "feasible": True,
            "mode": "unknown",
            "message": f"Không thể kiểm tra chuyến bay: {exc}",
        }
