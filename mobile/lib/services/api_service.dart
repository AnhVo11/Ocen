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

  const SaveResult({
    required this.success,
    this.schedule,
    this.conflict,
    this.travel,
  });
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

/// Handles all data operations.
///
/// Backed by SQLite (via DatabaseService) for persistence across restarts.
/// The in-memory [_schedules] list is used as a fast synchronous cache;
/// all writes also persist to the database.
class ApiService {
  static const String baseUrl = 'http://localhost:8000';

  final _db = DatabaseService();
  final _maps = MapsService();

  // In-memory cache — shared across all instances.
  static List<Schedule> _schedules = [];
  static bool _loaded = false;

  // Seed data shown on first launch (empty DB).
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

  /// Loads persisted schedules from SQLite. Seeds the database on first run.
  Future<void> init() async {
    if (_loaded) return;
    await _db.init();

    final rows = await _db.getAllSchedules();
    if (rows.isEmpty) {
      // First launch — seed with demo data
      final seed = _seedData();
      await _db.insertAll(seed);
      _schedules = seed;
    } else {
      _schedules = rows;
    }

    _loaded = true;

    // Schedule reminders for all upcoming events
    await NotificationService.scheduleAll(
      _schedules.where((s) => s.startTime.isAfter(DateTime.now())).toList(),
    );
  }

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

    final newSchedule = Schedule(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
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

    // Persist to DB
    await _db.insertSchedule(newSchedule);
    _schedules.add(newSchedule);

    // Schedule notification reminders
    await NotificationService.scheduleReminders(newSchedule);

    return SaveResult(
      success: true,
      schedule: newSchedule,
      conflict: conflict.hasConflict ? conflict : null,
      travel: travel,
    );
  }

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
