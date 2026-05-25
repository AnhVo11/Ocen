import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

// ---------------------------------------------------------------------------
// Data models
// ---------------------------------------------------------------------------

class FlightSegment {
  final String departureCode;
  final String arrivalCode;
  final DateTime departureTime;
  final DateTime arrivalTime;
  final String carrierCode;
  final String flightNumber;
  final String duration; // e.g. "PT2H5M"

  const FlightSegment({
    required this.departureCode,
    required this.arrivalCode,
    required this.departureTime,
    required this.arrivalTime,
    required this.carrierCode,
    required this.flightNumber,
    required this.duration,
  });
}

class FlightOffer {
  final List<FlightSegment> segments;
  final String price;       // formatted, e.g. "1,234,000 VND"
  final String currency;
  final String totalDuration; // e.g. "PT2H5M"
  final String airline;     // human-readable airline name

  const FlightOffer({
    required this.segments,
    required this.price,
    required this.currency,
    required this.totalDuration,
    required this.airline,
  });
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

class AmadeusService {
  String? _accessToken;
  DateTime? _tokenExpiry;

  // ── Airport code lookup ───────────────────────────────────────────────────

  /// Maps common Vietnamese city/location keywords → IATA airport code.
  static String? cityToIata(String location) {
    final loc = location.toLowerCase();

    if (loc.contains('hà nội') ||
        loc.contains('hanoi') ||
        loc.contains('ha noi') ||
        loc.contains('nội bài')) return 'HAN';

    if (loc.contains('hồ chí minh') ||
        loc.contains('ho chi minh') ||
        loc.contains('sài gòn') ||
        loc.contains('saigon') ||
        loc.contains('tân sơn nhất') ||
        loc.contains('tp.hcm') ||
        loc.contains('tphcm') ||
        loc.contains('hcm')) return 'SGN';

    if (loc.contains('đà nẵng') ||
        loc.contains('da nang') ||
        loc.contains('danang')) return 'DAD';

    if (loc.contains('đà lạt') || loc.contains('da lat')) return 'DLI';

    if (loc.contains('nha trang') ||
        loc.contains('cam ranh')) return 'CXR';

    if (loc.contains('phú quốc') || loc.contains('phu quoc')) return 'PQC';

    if (loc.contains('huế') || loc.contains('hue')) return 'HUI';

    if (loc.contains('cần thơ') || loc.contains('can tho')) return 'VCA';

    if (loc.contains('hải phòng') || loc.contains('hai phong')) return 'HPH';

    if (loc.contains('vinh')) return 'VII';

    if (loc.contains('buôn ma thuột') ||
        loc.contains('buon ma thuot')) return 'BMV';

    if (loc.contains('quy nhơn') || loc.contains('quy nhon')) return 'UIH';

    return null;
  }

  // ── Airline name lookup ───────────────────────────────────────────────────

  static String airlineName(String code) {
    const names = {
      'VN': 'Vietnam Airlines',
      'VJ': 'VietJet Air',
      'QH': 'Bamboo Airways',
      'VU': 'Vietravel Airlines',
      '0V': 'VASCO',
      'BL': 'Pacific Airlines',
      'AK': 'AirAsia',
      'FD': 'Thai AirAsia',
      'SQ': 'Singapore Airlines',
      'TG': 'Thai Airways',
      'CX': 'Cathay Pacific',
    };
    return names[code] ?? code;
  }

  // ── Duration formatter ────────────────────────────────────────────────────

  /// Converts ISO 8601 duration "PT2H5M" → "2g 5p" (Vietnamese shorthand).
  static String formatDuration(String iso) {
    final h = RegExp(r'(\d+)H').firstMatch(iso)?.group(1);
    final m = RegExp(r'(\d+)M').firstMatch(iso)?.group(1);
    if (h != null && m != null) return '${h}g ${m}p';
    if (h != null) return '${h}g';
    if (m != null) return '${m}p';
    return iso;
  }

  // ── OAuth token ───────────────────────────────────────────────────────────

  Future<bool> _ensureToken() async {
    if (_accessToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return true;
    }

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.amadeusBaseUrl}/v1/security/oauth2/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'client_credentials',
          'client_id': AppConfig.amadeusApiKey,
          'client_secret': AppConfig.amadeusApiSecret,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _accessToken = data['access_token'] as String;
        final expiresIn = (data['expires_in'] as int?) ?? 1799;
        _tokenExpiry =
            DateTime.now().add(Duration(seconds: expiresIn - 60));
        return true;
      }
      debugPrint('Amadeus token error: ${response.statusCode} ${response.body}');
      return false;
    } catch (e) {
      debugPrint('Amadeus token exception: $e');
      return false;
    }
  }

  // ── Flight search ─────────────────────────────────────────────────────────

  /// Search for one-way flights.
  ///
  /// Tries the OCEN backend first (scraped Vietnam domestic schedule).
  /// Falls back to mock data if the backend is unreachable or returns nothing.
  ///
  /// [origin] and [destination] can be IATA codes or location strings
  /// (will be resolved via [cityToIata]).
  Future<List<FlightOffer>> searchFlights({
    required String origin,
    required String destination,
    required DateTime departureDate,
    int adults = 1,
    int maxResults = 6,
  }) async {
    final originCode = cityToIata(origin) ?? origin.toUpperCase();
    final destCode = cityToIata(destination) ?? destination.toUpperCase();
    final dateStr =
        '${departureDate.year}-${departureDate.month.toString().padLeft(2, '0')}-${departureDate.day.toString().padLeft(2, '0')}';

    // ── Try OCEN backend first (scraped real schedule) ──────────────────────
    if (AppConfig.backendEnabled) {
      try {
        final uri = Uri.parse('${AppConfig.backendUrl}/flights').replace(
          queryParameters: {
            'from': originCode,
            'to': destCode,
            'date': dateStr,
          },
        );
        final response = await http
            .get(uri)
            .timeout(AppConfig.backendTimeout);

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body) as List;
          if (data.isNotEmpty) {
            final offers = _parseBackendFlights(data, departureDate);
            if (offers.isNotEmpty) return offers;
          }
        }
      } catch (e) {
        debugPrint('Backend flight search unavailable: $e');
      }
    }

    // ── Fallback: mock data ─────────────────────────────────────────────────
    return _mockFlights(originCode, destCode, departureDate);
  }

  // ── Backend response parser ───────────────────────────────────────────────

  /// Parses the OCEN backend `/flights` response into [FlightOffer] objects.
  ///
  /// Each item has: airline, flight_number, from_iata, to_iata,
  /// dep_time ("HH:MM"), arr_time ("HH:MM"), date ("YYYY-MM-DD").
  List<FlightOffer> _parseBackendFlights(
      List<dynamic> data, DateTime baseDate) {
    final List<FlightOffer> result = [];
    final base = DateTime(baseDate.year, baseDate.month, baseDate.day);

    for (final item in data) {
      try {
        final depParts = (item['dep_time'] as String).split(':');
        final arrParts = (item['arr_time'] as String).split(':');
        final dep = base.add(Duration(
          hours: int.parse(depParts[0]),
          minutes: int.parse(depParts[1]),
        ));
        final arr = base.add(Duration(
          hours: int.parse(arrParts[0]),
          minutes: int.parse(arrParts[1]),
        ));
        // Handle overnight flights (arr < dep means it lands next day)
        final arrAdjusted = arr.isBefore(dep) ? arr.add(const Duration(days: 1)) : arr;

        final durMin = arrAdjusted.difference(dep).inMinutes;
        final durStr =
            'PT${durMin ~/ 60}H${durMin % 60 == 0 ? '' : '${durMin % 60}M'}';

        result.add(FlightOffer(
          segments: [
            FlightSegment(
              departureCode: item['from_iata'] as String,
              arrivalCode: item['to_iata'] as String,
              departureTime: dep,
              arrivalTime: arrAdjusted,
              carrierCode: (item['flight_number'] as String).substring(0, 2),
              flightNumber: item['flight_number'] as String,
              duration: durStr,
            ),
          ],
          price: '',          // not available in scraped data
          currency: 'VND',
          totalDuration: durStr,
          airline: item['airline'] as String,
        ));
      } catch (e) {
        debugPrint('Backend flight parse error: $e');
      }
    }
    return result;
  }

  // ── Mock data (used when backend is unreachable or returns empty) ────────

  List<FlightOffer> _mockFlights(
      String origin, String destination, DateTime date) {
    final base = DateTime(date.year, date.month, date.day);

    final schedule = [
      _mockOffer(origin, destination, base, 5, 0, 6, 20, 'VN', '201', 1850000),
      _mockOffer(origin, destination, base, 7, 30, 8, 50, 'VJ', '101', 990000),
      _mockOffer(origin, destination, base, 10, 0, 11, 15, 'VN', '203', 2150000),
      _mockOffer(origin, destination, base, 13, 20, 14, 40, 'QH', '401', 1250000),
      _mockOffer(origin, destination, base, 16, 0, 17, 20, 'VJ', '105', 1100000),
      _mockOffer(origin, destination, base, 19, 45, 21, 5, 'VN', '209', 1750000),
    ];

    return schedule;
  }

  FlightOffer _mockOffer(
      String origin,
      String dest,
      DateTime base,
      int depH,
      int depM,
      int arrH,
      int arrM,
      String carrier,
      String flightNum,
      int priceVnd) {
    final dep = base.add(Duration(hours: depH, minutes: depM));
    final arr = base.add(Duration(hours: arrH, minutes: arrM));
    final durMin = arr.difference(dep).inMinutes;
    final durStr =
        'PT${durMin ~/ 60}H${durMin % 60 == 0 ? '' : '${durMin % 60}M'}';

    return FlightOffer(
      segments: [
        FlightSegment(
          departureCode: origin,
          arrivalCode: dest,
          departureTime: dep,
          arrivalTime: arr,
          carrierCode: carrier,
          flightNumber: flightNum,
          duration: durStr,
        ),
      ],
      price: '${_formatNumber(priceVnd)} VND',
      currency: 'VND',
      totalDuration: durStr,
      airline: airlineName(carrier),
    );
  }

  static String _formatNumber(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
