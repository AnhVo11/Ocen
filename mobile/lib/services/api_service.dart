import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/schedule.dart';
import 'database_service.dart';
import 'maps_service.dart';
import 'notification_service.dart';

// ---------------------------------------------------------------------------
// Result types
// ---------------------------------------------------------------------------

class ConflictResult {
  final bool hasConflict;
  final Schedule? conflictingSchedule;

  const ConflictResult({required this.hasConflict, this.conflictingSchedule});
}

class TravelResult {
  final bool feasible;

  /// 'car', 'flight', 'none', or 'unknown'
  final String mode;
  final String message;
  final int? minutes;

  const TravelResult({
    required this.feasible,
    required this.mode,
    required this.message,
    this.minutes,
  });
}

class SaveResult {
  final bool success;
  final Schedule? schedule;
  final ConflictResult? conflict;
  final TravelResult? travel;

  /// True when the schedule was saved to the backend; false means local-only.
  final bool syncedToBackend;

  const SaveResult({
    required this.success,
    this.schedule,
    this.conflict,
    this.travel,
    this.syncedToBackend = false,
  });
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

/// Handles all data operations.
///
/// On startup, attempts to sync from the Python backend REST API.
/// Falls back gracefully to local SQLite if the backend is unreachable.
///
/// All writes are persisted to local SQLite immediately.  When the backend
/// is reachable, writes are also pushed to the server so they appear in the
/// WhatsApp bot's view of the schedule.
class ApiService {
  final _db = DatabaseService();
  final _maps = MapsService();

  // In-memory cache — shared across all instances.
  static List<Schedule> _schedules = [];
  static bool _loaded = false;

  // Whether the last sync attempt reached the backend.
  static bool _backendReachable = false;

  static String get _base => AppConfig.backendUrl;
  static Duration get _timeout => AppConfig.backendTimeout;

  // Seed data shown on first launch (empty DB, backend also unreachable).
  static List<Schedule> _seedData() => [
        Schedule(
          id: '1',
          title: 'Họp Hội Đồng Quản Trị',
          startTime: _today(hour: 9, minute: 0),
          endTime: _today(hour: 11, minute: 0),
          location: 'Phòng họp Tầng 12, TP.HCM',
          notes: 'Báo cáo tài chính Q2',
          isWork: true,
          needsTravel: false,
        ),
        Schedule(
          id: '2',
          title: 'Gặp Đối Tác Hà Nội',
          startTime: _today(hour: 14, minute: 0),
          endTime: _today(hour: 16, minute: 30),
          location: 'Khách sạn Metropole, Hà Nội',
          notes: 'Ký kết hợp đồng phân phối',
          isWork: true,
          needsTravel: true,
          travelMode: 'flight',
          travelMinutes: 120,
        ),
        Schedule(
          id: '3',
          title: 'Kiểm Tra Nhà Máy Đà Nẵng',
          startTime: _daysFromNow(1, hour: 8, minute: 30),
          endTime: _daysFromNow(1, hour: 12, minute: 0),
          location: 'Khu Công Nghiệp Hòa Khánh, Đà Nẵng',
          isWork: true,
          needsTravel: true,
          travelMode: 'flight',
          travelMinutes: 75,
        ),
        Schedule(
          id: '4',
          title: 'Tiệc Sinh Nhật Gia Đình',
          startTime: _daysFromNow(2, hour: 18, minute: 0),
          endTime: _daysFromNow(2, hour: 21, minute: 0),
          location: 'Nhà hàng Ngọc Linh, Quận 3, TP.HCM',
          isWork: false,
          needsTravel: false,
        ),
      ];

  // ---------------------------------------------------------------------------
  // Init — call once at app startup
  // ---------------------------------------------------------------------------

  /// Initialises local DB, then attempts a backend sync.
  ///
  /// On first launch with no local data AND no backend:
  ///   → seeds with demo schedules.
  ///
  /// On first launch with backend reachable:
  ///   → pulls schedules from server, stores locally.
  ///
  /// On subsequent launches:
  ///   → loads local DB, then merges any new backend schedules in background.
  Future<void> init() async {
    if (_loaded) return;
    await _db.init();

    // Always load local data first so the UI can show something immediately.
    final localRows = await _db.getAllSchedules();

    if (localRows.isEmpty) {
      // First launch — try backend; fall back to seed data.
      final synced = await _syncFromBackend();
      if (!synced) {
        final seed = _seedData();
        await _db.insertAll(seed);
        _schedules = seed;
      }
    } else {
      _schedules = localRows;
      // Background sync — merge in any schedules added via WhatsApp bot.
      _syncFromBackend(); // intentionally not awaited
    }

    _loaded = true;

    // Schedule local notifications for all upcoming events.
    await NotificationService.scheduleAll(
      _schedules.where((s) => s.startTime.isAfter(DateTime.now())).toList(),
    );
  }

  // ---------------------------------------------------------------------------
  // Public sync helper — call to force a refresh from the backend
  // ---------------------------------------------------------------------------

  /// Pulls all schedules from the backend and merges into local SQLite.
  ///
  /// Returns true if the backend was reachable.
  Future<bool> syncNow() async {
    final ok = await _syncFromBackend();
    return ok;
  }

  bool get isBackendReachable => _backendReachable;

  // ---------------------------------------------------------------------------
  // Read operations
  // ---------------------------------------------------------------------------

  /// All schedules whose end time is in the future, sorted chronologically.
  List<Schedule> getUpcomingSchedules() {
    final now = DateTime.now();
    return [..._schedules.where((s) => s.endTime.isAfter(now))]
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  /// Schedules starting today (local time), sorted by start time.
  List<Schedule> getTodaySchedules() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    return [
      ..._schedules.where(
        (s) =>
            s.startTime.isAfter(todayStart) &&
            s.startTime.isBefore(todayEnd),
      )
    ]..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  // ---------------------------------------------------------------------------
  // Conflict detection
  // ---------------------------------------------------------------------------

  ConflictResult checkConflict(DateTime start, DateTime end) {
    for (final s in _schedules) {
      if (start.isBefore(s.endTime) && end.isAfter(s.startTime)) {
        return ConflictResult(hasConflict: true, conflictingSchedule: s);
      }
    }
    return const ConflictResult(hasConflict: false);
  }

  // ---------------------------------------------------------------------------
  // Travel feasibility
  // ---------------------------------------------------------------------------

  Future<TravelResult> checkTravelAsync(
    Schedule? prev,
    DateTime newStart,
    String newLocation,
  ) async {
    if (prev == null) {
      return const TravelResult(
        feasible: true,
        mode: 'unknown',
        message: 'Không có sự kiện trước đó.',
      );
    }

    final gapMinutes = newStart.difference(prev.endTime).inMinutes;

    final result = await _maps.getTravelInfo(
      origin: prev.location,
      destination: newLocation,
      gapMinutes: gapMinutes,
      departureTime: prev.endTime,
    );

    final modeStr = result.mode == TravelMode.driving
        ? 'car'
        : result.mode == TravelMode.flight
            ? 'flight'
            : 'unknown';

    return TravelResult(
      feasible: result.feasible,
      mode: result.feasible ? modeStr : 'none',
      message: result.summary,
      minutes: result.minutes,
    );
  }

  /// Synchronous fallback for widgets that cannot await.
  TravelResult checkTravel(
    Schedule? prev,
    DateTime newStart,
    String newLocation,
  ) {
    if (prev == null) {
      return const TravelResult(
        feasible: true,
        mode: 'unknown',
        message: 'Không có sự kiện trước đó.',
      );
    }
    final gapMinutes = newStart.difference(prev.endTime).inMinutes;
    final prevLoc = prev.location.toLowerCase();
    final newLoc = newLocation.toLowerCase();

    final isInterCity =
        (prevLoc.contains('hà nội') || prevLoc.contains('hanoi')) &&
            (newLoc.contains('hcm') ||
                newLoc.contains('hồ chí minh') ||
                newLoc.contains('sài gòn'));

    if (isInterCity) {
      return TravelResult(
        feasible: gapMinutes >= 240,
        mode: gapMinutes >= 240 ? 'flight' : 'none',
        message: gapMinutes >= 240
            ? 'Có thể bay từ Hà Nội đến TP.HCM (khoảng 2 giờ bay).'
            : 'Không đủ thời gian. Cần ít nhất 4 giờ nhưng chỉ có $gapMinutes phút.',
        minutes: 120,
      );
    }

    return TravelResult(
      feasible: gapMinutes >= 30,
      mode: gapMinutes >= 30 ? 'car' : 'none',
      message: gapMinutes >= 30
          ? 'Có thể đi xe (dự kiến ${gapMinutes ~/ 2} phút lái xe).'
          : 'Không đủ thời gian. Chỉ có $gapMinutes phút giữa hai sự kiện.',
      minutes: gapMinutes ~/ 2,
    );
  }

  // ---------------------------------------------------------------------------
  // Save
  // ---------------------------------------------------------------------------

  Future<SaveResult> checkAndSave({
    required String title,
    required DateTime startTime,
    required DateTime endTime,
    required String location,
    String? notes,
    bool isUrgent = false,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));

    final conflict = checkConflict(startTime, endTime);

    final upcoming = getUpcomingSchedules();
    Schedule? prev;
    for (final s in upcoming.reversed) {
      if (s.endTime.isBefore(startTime)) {
        prev = s;
        break;
      }
    }
    final travel = await checkTravelAsync(prev, startTime, location);

    // Build a provisional local schedule (uses timestamp as ID).
    final localId = DateTime.now().millisecondsSinceEpoch.toString();
    final provisional = Schedule(
      id: localId,
      title: title,
      startTime: startTime,
      endTime: endTime,
      location: location,
      notes: notes,
      isWork: true,
      needsTravel: travel.mode == 'car' || travel.mode == 'flight',
      travelMode: (travel.mode == 'none' || travel.mode == 'unknown')
          ? null
          : travel.mode,
      travelMinutes: travel.minutes,
    );

    // Try to push to backend — if successful, use the server-assigned ID.
    final backendSchedule = await _pushToBackend(provisional);
    final finalSchedule = backendSchedule ?? provisional;

    // Persist to local SQLite.
    await _db.insertSchedule(finalSchedule);
    _schedules.add(finalSchedule);

    // Schedule notification reminders.
    await NotificationService.scheduleReminders(finalSchedule);

    return SaveResult(
      success: true,
      schedule: finalSchedule,
      conflict: conflict.hasConflict ? conflict : null,
      travel: travel,
      syncedToBackend: backendSchedule != null,
    );
  }

  // ---------------------------------------------------------------------------
  // Update / Delete (also syncs to backend when reachable)
  // ---------------------------------------------------------------------------

  Future<bool> deleteSchedule(String id) async {
    // Remove from local cache and SQLite.
    _schedules.removeWhere((s) => s.id == id);
    await _db.deleteSchedule(id);

    // Attempt to delete from backend (ignore errors — local delete is the source of truth).
    if (_backendReachable) {
      await _deleteFromBackend(id);
    }
    return true;
  }

  Future<Schedule?> updateSchedule(Schedule updated) async {
    // Update local cache.
    final idx = _schedules.indexWhere((s) => s.id == updated.id);
    if (idx != -1) _schedules[idx] = updated;
    await _db.updateSchedule(updated);

    // Attempt to push update to backend.
    if (_backendReachable) {
      await _patchOnBackend(updated);
    }
    return updated;
  }

  // ---------------------------------------------------------------------------
  // Private — backend HTTP helpers
  // ---------------------------------------------------------------------------

  /// Pulls all schedules from the backend and upserts them into local SQLite.
  Future<bool> _syncFromBackend() async {
    if (!AppConfig.backendEnabled) return false;

    try {
      final response = await http
          .get(Uri.parse('$_base/schedules'))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data =
            jsonDecode(response.body) as List<dynamic>;
        final backendSchedules = data
            .map((j) => Schedule.fromJson(j as Map<String, dynamic>))
            .toList();

        // Upsert each backend schedule into local SQLite (replace on conflict).
        for (final s in backendSchedules) {
          await _db.insertSchedule(s); // DatabaseService uses ConflictAlgorithm.replace
        }

        // Reload from SQLite to capture both backend and local-only schedules.
        _schedules = await _db.getAllSchedules();
        _backendReachable = true;
        return true;
      }
      _backendReachable = false;
      return false;
    } on SocketException {
      _backendReachable = false;
      return false; // No network
    } on TimeoutException {
      _backendReachable = false;
      return false; // Backend not running
    } catch (_) {
      _backendReachable = false;
      return false;
    }
  }

  /// POSTs a new schedule to the backend.
  ///
  /// Returns the backend-assigned [Schedule] (with server ID) on success,
  /// or null if the backend is unreachable.
  Future<Schedule?> _pushToBackend(Schedule s) async {
    if (!AppConfig.backendEnabled) return null;

    try {
      final response = await http
          .post(
            Uri.parse('$_base/schedules'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(_toBackendJson(s)),
          )
          .timeout(_timeout);

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _backendReachable = true;
        // Preserve local travel fields (backend doesn't store them).
        return Schedule.fromJson(data).copyWith(
          needsTravel: s.needsTravel,
          travelMode: s.travelMode,
          travelMinutes: s.travelMinutes,
        );
      }
      return null;
    } on SocketException {
      _backendReachable = false;
      return null;
    } on TimeoutException {
      _backendReachable = false;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// PUTs updated fields to the backend.
  Future<void> _patchOnBackend(Schedule s) async {
    if (!AppConfig.backendEnabled) return;

    // Backend IDs are integers; skip if this schedule has a local timestamp ID.
    final backendId = int.tryParse(s.id);
    if (backendId == null) return;

    try {
      await http
          .put(
            Uri.parse('$_base/schedules/$backendId'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(_toBackendJson(s)),
          )
          .timeout(_timeout);
    } catch (_) {
      // Non-fatal — local DB is already updated.
    }
  }

  /// DELETEs a schedule from the backend by ID.
  Future<void> _deleteFromBackend(String id) async {
    if (!AppConfig.backendEnabled) return;

    final backendId = int.tryParse(id);
    if (backendId == null) return; // Local-only schedule (timestamp ID)

    try {
      await http
          .delete(Uri.parse('$_base/schedules/$backendId'))
          .timeout(_timeout);
    } catch (_) {
      // Non-fatal — local delete already happened.
    }
  }

  /// Maps a Flutter [Schedule] to the JSON body expected by the backend API.
  Map<String, dynamic> _toBackendJson(Schedule s) => {
        'title': s.title,
        'start_time': s.startTime.toIso8601String(),
        'end_time': s.endTime.toIso8601String(),
        'location': s.location,
        'notes': s.notes,
        'is_work': s.isWork,
        'created_by': 'app',
      };

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static DateTime _today({required int hour, required int minute}) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  static DateTime _daysFromNow(int days,
      {required int hour, required int minute}) {
    final base = DateTime.now().add(Duration(days: days));
    return DateTime(base.year, base.month, base.day, hour, minute);
  }
}
