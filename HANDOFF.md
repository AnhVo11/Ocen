# OCEN App — Project Handoff Brief
_Last updated: 26 May 2026. Paste this entire file into a new chat to resume work._

---

## What Is OCEN?

A Flutter mobile app (Android) that acts as an AI scheduling assistant for Anh's father, who is a corporate executive. Three roles:
- **Giám Đốc / Executive:** views schedule, gets travel alerts, sees flight options
- **Thư Ký / Secretary:** adds/edits schedule entries via voice or form
- **Tài Xế / Driver:** views travel schedule

**IMPORTANT: This is a standalone app. No WhatsApp, no Twilio, no Telegram. Do not add any messaging integrations.**

Project root: `C:\Users\anhvo\Desktop\Ocen\`

---

## Tech Stack

| Layer | Tech |
|---|---|
| Mobile frontend | Flutter / Dart (Android emulator: Pixel 6 API 34) |
| Local storage | SQLite via `sqflite` |
| Notifications | `flutter_local_notifications ^18.0.0` + `timezone` |
| Voice input | `speech_to_text ^7.0.0` |
| TTS | `flutter_tts ^4.0.0` |
| HTTP | `http ^1.2.0` |
| Localisation | `intl ^0.20.2` + `flutter_localizations` |
| Maps | Google Maps Directions API (key in app_config.dart) |
| Flight data | **Local scraped data** (AviationStack scraper, NOT Amadeus) |
| Backend | Python + FastAPI + SQLAlchemy + SQLite + APScheduler |

**Android build config:** `mobile/android/app/build.gradle.kts`
**Run script:** Double-click `C:\Users\anhvo\Desktop\Ocen\restart_flutter.vbs` to kill old dart/flutter processes and launch fresh `flutter run`.

---

## API Keys

File: `mobile/lib/config/app_config.dart`

```dart
static const String googleMapsApiKey = 'AIzaSyCrHfSuWEKqOH1KUT1Izz3O0rjIIAIdM_Y';
static const String backendUrl       = 'http://10.0.2.2:8000';  // emulator → host localhost
static const Duration backendTimeout = Duration(seconds: 5);
```

- **Google Maps Directions API** key is live. Enable Directions API in Google Cloud Console if not done yet.
- **Amadeus is NOT used** — replaced with local flight data. Amadeus is being decommissioned July 2026 anyway.
- **AviationStack key** (for scraping): `79a21b1d287b568c59b733d2f8dcaf9f` — used only when running the scraper manually.

---

## Design System (B&W, implemented May 26 2026)

All UI now follows a minimal black & white design. No gradients, no bright colours.

```dart
// mobile/lib/theme.dart — AppColors
background     = Color(0xFFF4F4F6)   // Page background (very light grey)
cardDark       = Color(0xFF1A1A1A)   // Featured dark card / active pill
cardLight      = Color(0xFFFFFFFF)   // Default white card
cardSecondary  = Color(0xFFEFEFEF)   // Soft grey (icon backgrounds)
textPrimary    = Color(0xFF1A1A1A)
textSecondary  = Color(0xFF8A8A8A)
timelineLine   = Color(0xFFE0E0E0)
pillActive     = Color(0xFF1A1A1A)   // Week strip selected day
error          = Color(0xFFC62828)   // Deep red (conflict dialogs)
warning        = Color(0xFFBF360C)   // Deep orange-red (urgent events)
success        = Color(0xFF2E7D32)   // Deep green (travel check OK)
```

Card radius: 24px. Pill radius: 50px. Checkbox radius: 6px.
Card shadow: `0px 8px 24px rgba(0,0,0,0.08)`.

---

## Backend (FastAPI — `app/`)

### Running the backend
```
cd C:\Users\anhvo\Desktop\Ocen
start_backend.bat        # or: python -m uvicorn app.main:app --reload --port 8000
```

### Key endpoints
| Method | Path | Purpose |
|---|---|---|
| GET | `/schedules` | List all schedules |
| POST | `/schedules` | Create schedule |
| PUT | `/schedules/{id}` | Update schedule |
| DELETE | `/schedules/{id}` | Delete schedule |
| GET | `/flights` | Query flights: `?from_iata=SGN&to_iata=HAN&date=2026-05-26` |
| GET | `/flights/routes` | List all available routes |

### Flight data loading
On startup, `app/main.py` calls `_load_flights_if_empty()` which:
1. Tries to bulk-load `FlightSchedule/data/vietnam_flights_2026.csv` (full year CSV, doesn't exist yet)
2. Falls back to loading daily JSON files from `FlightSchedule/data/YYYY-MM-DD.json`

The Flutter app queries the backend first; if unreachable or empty it falls back to mock flights.

---

## Flight Data (AviationStack Scraper — `FlightSchedule/`)

### What's been scraped
- **2026-05-26.json** — 925 flights (VN: 496, VJ: 322, VASCO: 46, Bamboo: 36, Vietravel: 25)
- 6 Vietnamese airlines: VN (Vietnam Airlines), VJ (VietJet), QH (Bamboo), VU (Vietravel), BL (Pacific Airlines), 0V (VASCO)
- 21 domestic airports covered

### How to scrape more dates
```bash
cd C:\Users\anhvo\Desktop\Ocen\FlightSchedule
python fetch_schedule.py --key 79a21b1d287b568c59b733d2f8dcaf9f
# Scrapes today by default. Saves to data/YYYY-MM-DD.json
```

### Strategy (agreed with Anh)
- Run `fetch_schedule.py` daily for **7–14 more days** to build up a data bank
- After 7+ days of data: run `python build_year.py` to generate `data/vietnam_flights_2026.csv`
- Re-scrape a specific date ONLY if dad reports incorrect flight info

---

## Current App State (What's Working — as of 26 May 2026)

- ✅ **New B&W UI** is live and running on Pixel 6 API 34 emulator
- ✅ **Role select screen** — OCEN brand, 3 role cards (Giám Đốc, Thư Ký, Tài Xế)
- ✅ **Executive home screen** — date header, week strip, timeline cards, floating bottom nav
- ✅ **Staff home screen** — same layout, refresh icon instead of menu
- ✅ **All 3 roles** have both voice and form add-schedule buttons (via bottom nav)
- ✅ **Schedule cards** — timeline dot, featured dark card for first work event, pills, "Xem chuyến bay" button
- ✅ **Week strip** — 7-day selector, active day = black pill, today gets a dot
- ✅ **Voice input** via `VoiceInputSheet`
- ✅ **Flight search sheet** — queries backend `/flights`, falls back to mock
- ✅ **Local notifications** — 30 min before events, T-24h/T-3h departure alerts
- ✅ **Backend** — FastAPI + SQLite, loads local flight JSON on startup
- ✅ **Flutter → Backend** connection configured (http://10.0.2.2:8000)

---

## What's NOT Done Yet

### Medium priority
- [ ] **Backend ↔ Flutter sync for schedules** — Flutter app currently stores schedules in local SQLite (`sqflite`), not the backend. The backend's `/schedules` endpoints exist but Flutter isn't calling them yet. Need to update `ApiService` to POST/GET from backend instead of local DB.
- [ ] **Scrape more flight data** — Only 1 day scraped (2026-05-26). Run `fetch_schedule.py` daily. Need 7+ days before running `build_year.py`.
- [ ] **Enable Google Directions API** in Google Cloud Console if not already done (needed for car travel-time estimates).

### Low priority / nice to have
- [ ] **Delete** `FlightSchedule/data/vn_raw_schedule.json` (test file, not git-tracked, safe to delete)
- [ ] **Update README.md** — still says "WhatsApp Smart Scheduling"
- [ ] **iOS build** (needs Mac)
- [ ] **Push notifications** from backend when secretary adds a schedule
- [ ] **Edit/delete schedule** from executive view
- [ ] **All schedules list** screen (beyond current day view)

---

## File Tree (Key Parts)

```
Ocen/
├── mobile/
│   ├── lib/
│   │   ├── main.dart                        ← Routes: / → RoleSelect, /executive, /staff, /add-schedule
│   │   ├── theme.dart                       ← B&W design system (AppColors + AppTheme)
│   │   ├── config/
│   │   │   └── app_config.dart              ← API keys, backendUrl
│   │   ├── models/
│   │   │   ├── schedule.dart
│   │   │   └── user_role.dart
│   │   ├── services/
│   │   │   ├── api_service.dart             ← Local SQLite CRUD + AI travel check
│   │   │   ├── amadeus_service.dart         ← Now queries backend /flights, mock fallback
│   │   │   ├── notification_service.dart
│   │   │   └── maps_service.dart            ← Google Maps directions
│   │   ├── screens/
│   │   │   ├── role_select_screen.dart      ← Landing screen (B&W redesign)
│   │   │   ├── executive/home_screen.dart   ← B&W timeline layout
│   │   │   ├── staff/home_screen.dart       ← B&W timeline layout
│   │   │   ├── staff/add_schedule_screen.dart
│   │   │   └── shared/
│   │   │       ├── conflict_dialog.dart
│   │   │       └── travel_check_screen.dart
│   │   └── widgets/
│   │       ├── schedule_card.dart           ← Timeline card (B&W redesign)
│   │       ├── week_strip.dart              ← 7-day date selector (new)
│   │       ├── flight_search_sheet.dart     ← Flight list bottom sheet
│   │       ├── voice_input_sheet.dart       ← Voice entry
│   │       ├── travel_gap_card.dart
│   │       └── app_drawer.dart
│   ├── android/app/build.gradle.kts         ← Desugaring enabled
│   └── pubspec.yaml
├── app/                                     ← Python FastAPI backend
│   ├── main.py                              ← Routes + flight loader
│   └── db/
│       └── models.py                        ← Schedule + Flight SQLAlchemy models
├── FlightSchedule/
│   ├── fetch_schedule.py                    ← AviationStack daily scraper
│   ├── build_year.py                        ← Merge daily JSONs → CSV (run after 7+ days)
│   └── data/
│       └── 2026-05-26.json                  ← 925 flights scraped
├── restart_flutter.vbs                      ← Double-click to rebuild app
├── start_backend.bat                        ← Start the Python backend
└── HANDOFF.md                               ← This file
```

---

## Data Model: `Schedule`

```dart
class Schedule {
  final String id;
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final String location;
  final String? notes;
  final bool isWork;
  final bool needsTravel;
  final String? travelMode;    // 'car', 'flight', or null
  final int? travelMinutes;    // estimated travel duration
}
```

## Data Model: `Flight` (SQLAlchemy, backend)

```python
class Flight(Base):
    date          # "2026-05-26"
    airline       # "Vietnam Airlines"
    flight_number # "VN123"
    from_iata     # "SGN"
    to_iata       # "HAN"
    from_name     # "Tan Son Nhat"
    to_name       # "Noi Bai"
    dep_time      # "06:30"
    arr_time      # "08:30"
    status        # "scheduled"
```

---

## Notes For Next Session

- **Terminal is click-tier** in Cowork — Claude can see it but can't type. To check build errors, look at the CMD window in the taskbar (multiple may be open from previous runs; the most recent is the rightmost one). Or ask user to paste output.
- **VS Code is also click-tier.** Use `restart_flutter.vbs` to rebuild, not VS Code's run button.
- **Multiple CMD windows** will be open from previous builds. The active flutter run is identifiable by its process ID in the log output and "Flutter run key commands." appearing without a subsequent error.
- The Android emulator shows up in Android Studio's "Running Devices - Ocen" floating window. If the emulator isn't visible, open Android Studio.
- **Git:** all UI changes are committed and pushed to main branch as of 26 May 2026.
- User email: anhvo8438@gmail.com
