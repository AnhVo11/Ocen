import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

// ─── Result type ─────────────────────────────────────────────────────────────

enum TravelMode { driving, flight, unknown }

class MapsResult {
  /// Human-readable Vietnamese summary, e.g. "35 phút lái xe" or "cần máy bay"
  final String summary;

  /// Travel duration in minutes (drive or approximate flight).
  final int minutes;

  /// Straight-line distance in kilometres between origin and destination.
  final double distanceKm;

  /// Whether the trip is feasible within the available time gap.
  final bool feasible;

  final TravelMode mode;

  const MapsResult({
    required this.summary,
    required this.minutes,
    required this.distanceKm,
    required this.feasible,
    required this.mode,
  });
}

// ─── Service ─────────────────────────────────────────────────────────────────

/// Calls the Google Maps Directions API to get real driving time between two
/// event locations.  Automatically suggests flight when distance > 500 km.
///
/// Falls back to [MapsResult] with [TravelMode.unknown] when the API key is
/// missing or the network call fails.
class MapsService {
  static const String _baseUrl =
      'https://maps.googleapis.com/maps/api/directions/json';

  /// Returns real travel information between [origin] and [destination].
  /// [gapMinutes] is the available window; used to decide feasibility.
  Future<MapsResult> getTravelInfo({
    required String origin,
    required String destination,
    required int gapMinutes,
    DateTime? departureTime,
  }) async {
    if (!AppConfig.mapsEnabled || origin.isEmpty || destination.isEmpty) {
      return _fallback(origin, destination, gapMinutes);
    }

    try {
      final depTime = departureTime ?? DateTime.now();
      final depUnix = depTime.millisecondsSinceEpoch ~/ 1000;

      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'origin': origin,
        'destination': destination,
        'mode': 'driving',
        'departure_time': depUnix.toString(),
        'traffic_model': 'best_guess',
        'language': 'vi',
        'key': AppConfig.googleMapsApiKey,
      });

      final response =
          await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return _fallback(origin, destination, gapMinutes);
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final status = data['status'] as String;

      if (status != 'OK') {
        // Could be ZERO_RESULTS (long distance / cross-sea route)
        if (status == 'ZERO_RESULTS') {
          // Likely a flight route — estimate from crow-fly using Geocoding
          return _flightResult(gapMinutes);
        }
        return _fallback(origin, destination, gapMinutes);
      }

      final leg =
          (data['routes'] as List).first['legs'] as List;
      final firstLeg = leg.first as Map<String, dynamic>;

      // Prefer duration_in_traffic if available (requires departure_time)
      final durationData = firstLeg['duration_in_traffic'] as Map? ??
          firstLeg['duration'] as Map;
      final drivingSeconds = durationData['value'] as int;
      final drivingMinutes = (drivingSeconds / 60).ceil();

      final distanceData = firstLeg['distance'] as Map<String, dynamic>;
      final distanceMetres = distanceData['value'] as int;
      final distanceKm = distanceMetres / 1000.0;

      // If driving distance > 500 km, a flight makes more sense
      if (distanceKm > 500) {
        return _flightResult(gapMinutes, distanceKm: distanceKm);
      }

      final feasible = gapMinutes >= drivingMinutes + 10; // 10-min buffer
      final summary = feasible
          ? 'Lái xe $drivingMinutes phút (${distanceKm.toStringAsFixed(0)} km)'
          : 'Cần $drivingMinutes phút lái xe — chỉ có $gapMinutes phút trống';

      return MapsResult(
        summary: summary,
        minutes: drivingMinutes,
        distanceKm: distanceKm,
        feasible: feasible,
        mode: TravelMode.driving,
      );
    } catch (_) {
      return _fallback(origin, destination, gapMinutes);
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  /// Used when the route is clearly inter-city / requires a flight.
  MapsResult _flightResult(int gapMinutes, {double distanceKm = 0}) {
    // Hanoi–HCMC is ~120 min flight + airport time ≈ 240 min door-to-door
    const flightMinutes = 120;
    const doorToDoor = 240; // includes airport transit time
    final feasible = gapMinutes >= doorToDoor;
    final summary = feasible
        ? 'Bay khoảng $flightMinutes phút (cần ~$doorToDoor phút kể cả sân bay)'
        : 'Cần ~$doorToDoor phút (bay) — chỉ có $gapMinutes phút trống';
    return MapsResult(
      summary: summary,
      minutes: flightMinutes,
      distanceKm: distanceKm,
      feasible: feasible,
      mode: TravelMode.flight,
    );
  }

  /// Returns a rough offline estimate when Maps API is unavailable.
  MapsResult _fallback(
      String origin, String destination, int gapMinutes) {
    final originLower = origin.toLowerCase();
    final destLower = destination.toLowerCase();

    // Detect inter-city trips by keywords
    final isInterCity = _isInterCity(originLower, destLower);

    if (isInterCity) {
      return _flightResult(gapMinutes);
    }

    final estimatedMinutes = (gapMinutes * 0.6).round().clamp(15, 90);
    final feasible = gapMinutes >= estimatedMinutes + 10;
    return MapsResult(
      summary: feasible
          ? 'Dự tính ~$estimatedMinutes phút di chuyển (ước tính)'
          : 'Có thể không đủ thời gian di chuyển ($gapMinutes phút trống)',
      minutes: estimatedMinutes,
      distanceKm: 0,
      feasible: feasible,
      mode: TravelMode.unknown,
    );
  }

  bool _isInterCity(String a, String b) {
    const cities = {
      'hcm': ['hà nội', 'hanoi', 'đà nẵng', 'danang', 'cần thơ'],
      'hồ chí minh': ['hà nội', 'hanoi', 'đà nẵng', 'danang'],
      'sài gòn': ['hà nội', 'hanoi', 'đà nẵng', 'danang'],
      'hà nội': ['hcm', 'hồ chí minh', 'sài gòn', 'đà nẵng', 'danang'],
      'đà nẵng': ['hcm', 'hồ chí minh', 'hà nội', 'hanoi'],
      'danang': ['hcm', 'hồ chí minh', 'hà nội', 'hanoi'],
    };

    for (final entry in cities.entries) {
      if (a.contains(entry.key)) {
        for (final other in entry.value) {
          if (b.contains(other)) return true;
        }
      }
    }
    return false;
  }
}
