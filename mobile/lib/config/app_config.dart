/// App-level configuration — paste your API keys here.
///
/// ── Backend REST API ─────────────────────────────────────────────────────────
/// The Python backend exposes a REST API that the app syncs with.
///
/// Android emulator → host machine's localhost:
///   http://10.0.2.2:8000
///
/// iOS simulator / physical device on same network:
///   http://<your-LAN-IP>:8000  (e.g. http://192.168.1.100:8000)
///
/// Leave [backendUrl] empty to run fully offline (local SQLite only).
///
/// ── Google Maps ──────────────────────────────────────────────────────────────
/// 1. Go to https://console.cloud.google.com
/// 2. Create a project → APIs & Services → Library → "Directions API" → Enable
/// 3. APIs & Services → Credentials → + Create Credentials → API key
///
/// Free quota: $200/month credit ≈ 40,000 calls. No charges for personal use.
///
/// ── Amadeus Flight Search ────────────────────────────────────────────────────
/// 1. Go to https://developers.amadeus.com/register
/// 2. Create an app → copy the API Key and API Secret shown
///
/// Free test tier: 2,000 calls/month — more than enough for personal use.
/// When ready for real data, switch amadeusBaseUrl to production URL.
class AppConfig {
  AppConfig._();

  // ── Backend ─────────────────────────────────────────────────────────────────

  /// Base URL of the Python REST API backend.
  ///
  /// Android emulator uses 10.0.2.2 to reach the host machine's localhost.
  /// Change to your LAN IP for a physical device or iOS simulator.
  static const String backendUrl = 'http://10.0.2.2:8000';

  /// How long to wait for the backend before falling back to local SQLite.
  static const Duration backendTimeout = Duration(seconds: 5);

  static bool get backendEnabled => backendUrl.isNotEmpty;

  // ── Google Maps ─────────────────────────────────────────────────────────────

  /// Google Maps Directions API key. Leave empty to use offline fallback.
  static const String googleMapsApiKey = 'AIzaSyCrHfSuWEKqOH1KUT1Izz3O0rjIIAIdM_Y';

  // ── Amadeus ─────────────────────────────────────────────────────────────────

  /// Amadeus API Key (client_id). Leave empty to use mock flight data.
  static const String amadeusApiKey = '';

  /// Amadeus API Secret (client_secret).
  static const String amadeusApiSecret = '';

  /// Amadeus base URL.
  /// Test:       https://test.api.amadeus.com
  /// Production: https://api.amadeus.com
  static const String amadeusBaseUrl = 'https://test.api.amadeus.com';

  // ── Feature flags ───────────────────────────────────────────────────────────

  static bool get mapsEnabled => googleMapsApiKey.isNotEmpty;
  static bool get flightSearchEnabled =>
      amadeusApiKey.isNotEmpty && amadeusApiSecret.isNotEmpty;
}
