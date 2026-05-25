"""
build_year.py
-------------
Run this AFTER collecting at least 7 days of data with fetch_today.py.
Builds the full year schedule by repeating the weekly pattern.

Usage:
    python3 build_year.py
    python3 build_year.py --year 2026
"""

import json
import csv
import argparse
from datetime import date, timedelta
from pathlib import Path
from collections import defaultdict

DATA_DIR = Path("data")
HISTORY_FILE = DATA_DIR / "all_days.json"

# IATA season boundaries
SUMMER_START = date(2026, 3, 29)
SUMMER_END   = date(2026, 10, 25)


def is_summer(d: date) -> bool:
    return SUMMER_START <= d <= SUMMER_END


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--year", type=int, default=2026)
    args = parser.parse_args()

    if not HISTORY_FILE.exists():
        print("❌ No data found. Run fetch_today.py for at least 7 days first.")
        return

    with open(HISTORY_FILE, encoding="utf-8") as f:
        history = json.load(f)

    print("=" * 55)
    print("  Vietnam Flight Schedule Builder")
    print("=" * 55)
    print(f"\n📂 Found data for {len(history)} days:")
    for d in sorted(history.keys()):
        print(f"   {d} — {len(history[d])} flights")

    if len(history) < 7:
        print(f"\n⚠️  Only {len(history)} days collected — ideally need 7.")
        print("   Results may be incomplete. Continue anyway? (y/n): ", end="")
        if input().strip().lower() != "y":
            return

    # ── Build weekday templates (separate summer/winter) ──
    summer_template = defaultdict(list)
    winter_template = defaultdict(list)

    for date_str, flights in history.items():
        d = date.fromisoformat(date_str)
        weekday = d.weekday()
        if is_summer(d):
            summer_template[weekday].extend(flights)
        else:
            winter_template[weekday].extend(flights)

    # Deduplicate within each weekday template
    def dedup(flights):
        seen = set()
        result = []
        for f in flights:
            key = f"{f['airline']}|{f['flight_number']}|{f['dep_time']}"
            if key not in seen:
                seen.add(key)
                result.append(f)
        return result

    for wd in range(7):
        summer_template[wd] = dedup(summer_template[wd])
        winter_template[wd] = dedup(winter_template[wd])

    # ── Expand across the full year ──
    print(f"\n📅 Building schedule for {args.year}...")
    all_flights = []
    start = date(args.year, 1, 1)
    end   = date(args.year, 12, 31)
    current = start

    while current <= end:
        weekday = current.weekday()
        template = summer_template if is_summer(current) else winter_template
        for f in template[weekday]:
            row = f.copy()
            row["date"] = str(current)
            all_flights.append(row)
        current += timedelta(days=1)

    # Sort by date, airline, dep_time
    all_flights.sort(key=lambda x: (x["date"], x["airline"], x["dep_time"]))

    # ── Write CSV ──
    out_csv = DATA_DIR / f"vietnam_flights_{args.year}.csv"
    fieldnames = [
        "date", "airline", "flight_number",
        "from_iata", "from_name",
        "to_iata", "to_name",
        "dep_time", "arr_time", "status",
    ]
    with open(out_csv, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(all_flights)

    # ── Write JSON ──
    out_json = DATA_DIR / f"vietnam_flights_{args.year}.json"
    with open(out_json, "w", encoding="utf-8") as f:
        json.dump(all_flights, f, ensure_ascii=False, indent=2)

    # ── Stats ──
    import os
    print(f"\n✅ Done!")
    print(f"   Total flights:  {len(all_flights):,}")
    print(f"   CSV → {out_csv}  ({os.path.getsize(out_csv)/1024:.0f} KB)")
    print(f"   JSON → {out_json}  ({os.path.getsize(out_json)/1024:.0f} KB)")

    from collections import Counter
    by_airline = Counter(f["airline"] for f in all_flights)
    print(f"\n📊 Flights per airline (full year):")
    for airline, count in by_airline.most_common():
        print(f"   {airline}: {count:,}")


if __name__ == "__main__":
    main()