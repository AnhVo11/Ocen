"""
fetch_today.py
--------------
Run this script EVERY DAY to collect today's flights for all Vietnamese airlines.
After 7-14 days it will detect when the weekly pattern repeats and tell you to stop.

Usage:
    python3 fetch_today.py --key YOUR_API_KEY

Run once per day, ideally at the same time each day (e.g. 8am).
"""

import requests
import json
import time
import argparse
from datetime import date, datetime
from pathlib import Path

# ─── All Vietnamese Airlines ──────────────────────────────────────────────────

AIRLINES = {
    "VN": "Vietnam Airlines",
    "VJ": "Vietjet Air",
    "QH": "Bamboo Airways",
    "VU": "Vietravel Airlines",
    "BL": "Pacific Airlines",
    "0V": "VASCO",
}

# All Vietnam domestic airports
VIETNAM_AIRPORTS = {
    "HAN", "SGN", "DAD", "HPH", "VII", "HUI", "PQC", "CXR",
    "UIH", "DLI", "BMV", "VCA", "PXU", "VDH", "TBB", "DIN",
    "VCS", "CAH", "VKG", "VCL", "THD",
}

DATA_DIR = Path("data")
DATA_DIR.mkdir(exist_ok=True)

# ─── Fetch ────────────────────────────────────────────────────────────────────

def fetch_airline_flights(api_key: str, airline_iata: str) -> list[dict]:
    """Fetch real-time flights for one airline (free tier compatible)."""
    url = "http://api.aviationstack.com/v1/flights"
    all_flights = []
    offset = 0

    while True:
        params = {
            "access_key": api_key,
            "airline_iata": airline_iata,
            "limit": 100,
            "offset": offset,
        }

        try:
            resp = requests.get(url, params=params, timeout=15)
            resp.raise_for_status()
            data = resp.json()
        except requests.RequestException as e:
            print(f"    ⚠️  Request failed: {e}")
            break

        if "error" in data:
            print(f"    ⚠️  API error: {data['error']['message']}")
            break

        flights = data.get("data", [])
        if not flights:
            break

        # Filter domestic Vietnam only
        domestic = [
            f for f in flights
            if f.get("departure", {}).get("iata") in VIETNAM_AIRPORTS
            and f.get("arrival", {}).get("iata") in VIETNAM_AIRPORTS
        ]
        all_flights.extend(domestic)

        total = data.get("pagination", {}).get("total", 0)
        offset += 100
        if offset >= total:
            break

        time.sleep(0.5)

    return all_flights


def clean_flight(f: dict, airline_name: str, today: str) -> dict:
    dep = f.get("departure", {})
    arr = f.get("arrival", {})
    flight = f.get("flight", {})

    dep_scheduled = dep.get("scheduled", "")
    arr_scheduled = arr.get("scheduled", "")

    # Extract HH:MM from datetime string
    dep_time = dep_scheduled[11:16] if len(dep_scheduled) >= 16 else ""
    arr_time = arr_scheduled[11:16] if len(arr_scheduled) >= 16 else ""

    return {
        "date": today,
        "airline": airline_name,
        "flight_number": flight.get("iata", ""),
        "from_iata": dep.get("iata", ""),
        "from_name": dep.get("airport", ""),
        "to_iata": arr.get("iata", ""),
        "to_name": arr.get("airport", ""),
        "dep_time": dep_time,
        "arr_time": arr_time,
        "status": f.get("flight_status", ""),
    }


# ─── Duplicate Detection ──────────────────────────────────────────────────────

def check_duplicates(today: str, today_flights: list[dict]) -> bool:
    """
    Compare today's flight numbers+times against all previous days.
    If an exact match is found (same weekday, same flights), we're done.
    """
    history_file = DATA_DIR / "all_days.json"
    if not history_file.exists():
        return False

    with open(history_file, encoding="utf-8") as f:
        history = json.load(f)

    today_date = date.fromisoformat(today)
    today_weekday = today_date.weekday()

    # Build a fingerprint: sorted set of "flight_number|dep_time" for today
    today_fp = set(
        f"{f['flight_number']}|{f['dep_time']}"
        for f in today_flights
        if f["flight_number"] and f["dep_time"]
    )

    for past_date_str, past_flights in history.items():
        past_date = date.fromisoformat(past_date_str)
        # Only compare same weekday
        if past_date.weekday() != today_weekday:
            continue
        # Skip if less than 6 days apart (need at least 1 full week gap)
        if abs((today_date - past_date).days) < 6:
            continue

        past_fp = set(
            f"{f['flight_number']}|{f['dep_time']}"
            for f in past_flights
            if f["flight_number"] and f["dep_time"]
        )

        if not today_fp or not past_fp:
            continue

        # Check overlap percentage
        overlap = len(today_fp & past_fp) / max(len(today_fp), len(past_fp))
        if overlap >= 0.85:  # 85% match = same schedule
            print(f"\n🔁 Schedule repeats! Today ({today}) matches {past_date_str}")
            print(f"   Overlap: {overlap:.0%} — you can stop running this script.")
            return True

    return False


# ─── Main ─────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Fetch today's Vietnam flights")
    parser.add_argument("--key", required=True, help="Your AviationStack API key")
    args = parser.parse_args()

    today = str(date.today())
    print("=" * 55)
    print(f"  Vietnam Flight Collector — {today}")
    print("=" * 55)

    # Load existing history
    history_file = DATA_DIR / "all_days.json"
    if history_file.exists():
        with open(history_file, encoding="utf-8") as f:
            history = json.load(f)
    else:
        history = {}

    # Skip if already fetched today
    if today in history:
        print(f"\n✅ Already fetched today ({today}). Come back tomorrow!")
        return

    # Fetch all airlines
    all_today = []
    for iata, name in AIRLINES.items():
        print(f"\n✈️  {name} ({iata})...", end="", flush=True)
        flights = fetch_airline_flights(args.key, iata)
        cleaned = [clean_flight(f, name, today) for f in flights]
        all_today.extend(cleaned)
        print(f" {len(cleaned)} flights")
        time.sleep(1)  # pause between airlines

    # Save today's data as its own file
    day_file = DATA_DIR / f"{today}.json"
    with open(day_file, "w", encoding="utf-8") as f:
        json.dump(all_today, f, ensure_ascii=False, indent=2)

    # Update history
    history[today] = all_today
    with open(history_file, "w", encoding="utf-8") as f:
        json.dump(history, f, ensure_ascii=False, indent=2)

    print(f"\n✅ Saved {len(all_today)} flights → data/{today}.json")
    print(f"   Total days collected: {len(history)}")

    # Check if schedule has started repeating
    is_duplicate = check_duplicates(today, all_today)

    if not is_duplicate:
        days_left = max(0, 7 - len(history))
        if days_left > 0:
            print(f"\n📅 Keep running daily — about {days_left} more day(s) to go.")
        else:
            print(f"\n📅 {len(history)} days collected. Run again tomorrow to check for repeats.")

    print("\n👉 To build the full year schedule: python3 build_year.py")


if __name__ == "__main__":
    main()