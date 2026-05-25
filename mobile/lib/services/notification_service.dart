import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/schedule.dart';

/// Schedules local push notifications to remind the executive before events.
///
/// • 30 minutes before every event → "Sắp đến giờ họp!"
/// • If travel is needed, also fires [travelMinutes + 20] minutes before
///   so the father knows when to leave.
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  // ─── Init ────────────────────────────────────────────────────────────────────

  static Future<void> init() async {
    tz_data.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(settings);

    // Request permission on Android 13+
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _ready = true;
  }

  // ─── Schedule reminders for a single event ───────────────────────────────────

  static Future<void> scheduleReminders(Schedule schedule) async {
    if (!_ready) return;

    final now = DateTime.now();

    // ── 30-min reminder ──────────────────────────────────────────────────────
    final remind30 = schedule.startTime.subtract(const Duration(minutes: 30));
    if (remind30.isAfter(now)) {
      await _scheduleNotification(
        id: _idFor(schedule.id, 0),
        title: '📅 Sắp đến lịch: ${schedule.title}',
        body: 'Bắt đầu lúc ${_hhmm(schedule.startTime)}'
            '${schedule.location.isNotEmpty ? ' tại ${schedule.location}' : ''}',
        scheduledDate: remind30,
      );
    }

    // ── Travel reminder (depart-on-time alert) ───────────────────────────────
    if (schedule.needsTravel && schedule.travelMinutes != null) {
      final buffer = schedule.travelMinutes! + 20; // travel + 20 min buffer
      final departBy =
          schedule.startTime.subtract(Duration(minutes: buffer));
      if (departBy.isAfter(now)) {
        final modeEmoji =
            schedule.travelMode == 'flight' ? '✈️' : '🚗';
        await _scheduleNotification(
          id: _idFor(schedule.id, 1),
          title: '$modeEmoji Đến giờ xuất phát!',
          body: 'Cần ${schedule.travelMinutes} phút để đến '
              '${schedule.location.isNotEmpty ? schedule.location : "địa điểm"}. '
              'Xuất phát ngay để kịp lúc ${_hhmm(schedule.startTime)}.',
          scheduledDate: departBy,
        );
      }
    }
  }

  // ─── Cancel reminders for an event ───────────────────────────────────────────

  static Future<void> cancelReminders(String scheduleId) async {
    if (!_ready) return;
    await _plugin.cancel(_idFor(scheduleId, 0));
    await _plugin.cancel(_idFor(scheduleId, 1));
  }

  // ─── Schedule all reminders in bulk ──────────────────────────────────────────

  static Future<void> scheduleAll(List<Schedule> schedules) async {
    for (final s in schedules) {
      await scheduleReminders(s);
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  static Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    try {
      final tzDate = tz.TZDateTime.from(scheduledDate, tz.local);
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'ocen_reminders',
            'OCEN Reminders',
            channelDescription: 'Nhắc nhở lịch trình từ OCEN',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('Notification schedule failed: $e');
    }
  }

  /// Stable integer ID derived from schedule id + slot index.
  static int _idFor(String scheduleId, int slot) {
    return (scheduleId.hashCode.abs() % 100000) * 10 + slot;
  }

  static String _hhmm(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
