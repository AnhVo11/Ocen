/// Rule-based parser that turns Vietnamese voice input into event fields.
///
/// Example inputs the parser handles:
///   "thêm họp với đối tác lúc 3 giờ chiều thứ Hai tại văn phòng"
///   "đặt lịch ăn trưa lúc 12 giờ ngày mai"
///   "cuộc gặp khách hàng lúc 9 giờ sáng thứ Tư ở tầng 5 trong 2 tiếng"
class ParsedEvent {
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final String location;
  final bool parsed; // false if we couldn't extract a time

  const ParsedEvent({
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.location,
    required this.parsed,
  });
}

class VietnameseEventParser {
  // ─── Public API ─────────────────────────────────────────────────────────────

  ParsedEvent parse(String speech) {
    final text = _normalize(speech);

    final date = _extractDate(text);
    final timeResult = _extractTime(text);
    final location = _extractLocation(text);
    final durationMinutes = _extractDuration(text);
    final title = _extractTitle(text);

    if (timeResult == null) {
      // Can't parse a time → return unparsed sentinel
      final now = DateTime.now();
      return ParsedEvent(
        title: title.isEmpty ? speech : title,
        startTime: now,
        endTime: now.add(const Duration(hours: 1)),
        location: location,
        parsed: false,
      );
    }

    final start = DateTime(
      date.year,
      date.month,
      date.day,
      timeResult.hour,
      timeResult.minute,
    );
    final end = start.add(Duration(minutes: durationMinutes));

    return ParsedEvent(
      title: title.isEmpty ? 'Sự kiện mới' : title,
      startTime: start,
      endTime: end,
      location: location,
      parsed: true,
    );
  }

  // ─── Normalise ───────────────────────────────────────────────────────────────

  String _normalize(String s) =>
      s.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

  // ─── Date extraction ─────────────────────────────────────────────────────────

  DateTime _extractDate(String text) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (text.contains('ngày mai') || text.contains('mai')) {
      return today.add(const Duration(days: 1));
    }
    if (text.contains('hôm nay') || text.contains('hom nay')) {
      return today;
    }
    if (text.contains('ngày kia') || text.contains('ngày mốt')) {
      return today.add(const Duration(days: 2));
    }

    // Weekday: thứ Hai=2, Ba=3, Tư=4, Năm=5, Sáu=6, Bảy=7, Chủ Nhật=1
    final weekdayMap = {
      'thứ hai': DateTime.monday,
      'thu hai': DateTime.monday,
      'thứ ba': DateTime.tuesday,
      'thu ba': DateTime.tuesday,
      'thứ tư': DateTime.wednesday,
      'thu tu': DateTime.wednesday,
      'thứ năm': DateTime.thursday,
      'thu nam': DateTime.thursday,
      'thứ sáu': DateTime.friday,
      'thu sau': DateTime.friday,
      'thứ bảy': DateTime.saturday,
      'thu bay': DateTime.saturday,
      'chủ nhật': DateTime.sunday,
      'chu nhat': DateTime.sunday,
    };

    for (final entry in weekdayMap.entries) {
      if (text.contains(entry.key)) {
        return _nextWeekday(today, entry.value);
      }
    }

    return today; // default: today
  }

  DateTime _nextWeekday(DateTime from, int weekday) {
    int daysAhead = weekday - from.weekday;
    if (daysAhead <= 0) daysAhead += 7; // always future
    return from.add(Duration(days: daysAhead));
  }

  // ─── Time extraction ─────────────────────────────────────────────────────────

  ({int hour, int minute})? _extractTime(String text) {
    // Patterns:
    //   lúc 3 giờ chiều        → 15:00
    //   lúc 9 giờ sáng         → 09:00
    //   lúc 14 giờ             → 14:00
    //   lúc 10 giờ 30          → 10:30
    //   lúc 10 giờ rưỡi        → 10:30
    //   lúc 12 giờ trưa        → 12:00
    //   3 giờ tối              → 21:00 (evening)

    // Match: (lúc )? N giờ (M phút)? (sáng|trưa|chiều|tối)?
    final re = RegExp(
      r'(?:lúc|luc)\s+(\d{1,2})\s*giờ'
      r'(?:\s+(\d{1,2})\s*(?:phút|ph)?)?'
      r'(?:\s+(sáng|sang|trưa|trua|chiều|chieu|tối|toi|đêm|dem))?',
    );

    var m = re.firstMatch(text);

    // Also try without "lúc" keyword: just "9 giờ sáng"
    if (m == null) {
      final re2 = RegExp(
        r'(\d{1,2})\s*giờ'
        r'(?:\s+(\d{1,2})\s*(?:phút|ph)?)?'
        r'(?:\s+(sáng|sang|trưa|trua|chiều|chieu|tối|toi|đêm|dem))?',
      );
      m = re2.firstMatch(text);
    }

    if (m == null) return null;

    int hour = int.parse(m.group(1)!);
    int minute = m.group(2) != null ? int.parse(m.group(2)!) : 0;

    // "rưỡi" = half past
    if (text.contains('rưỡi') || text.contains('ruoi')) minute = 30;

    final period = m.group(3) ?? '';
    if (period.contains('chiều') || period.contains('chieu')) {
      if (hour < 12) hour += 12;
    } else if (period.contains('tối') || period.contains('toi') ||
        period.contains('đêm') || period.contains('dem')) {
      if (hour < 12) hour += 12;
      if (hour < 18) hour += 6; // 6 PM minimum for evening
    } else if (period.contains('trưa') || period.contains('trua')) {
      hour = 12;
    } else if (period.contains('sáng') || period.contains('sang')) {
      if (hour == 12) hour = 0;
    } else {
      // No AM/PM hint — if hour <= 7 it's probably PM (afternoon meeting)
      // This heuristic avoids "3 giờ" being 3 AM
      if (hour > 0 && hour <= 7) hour += 12;
    }

    hour = hour.clamp(0, 23);
    minute = minute.clamp(0, 59);
    return (hour: hour, minute: minute);
  }

  // ─── Duration extraction ──────────────────────────────────────────────────────

  int _extractDuration(String text) {
    // "trong 2 tiếng" / "trong 1 giờ" / "kéo dài 30 phút"
    final re = RegExp(
        r'(?:trong|kéo dài|keo dai)\s+(\d+)\s*(tiếng|tieng|giờ|gio|phút|phut)');
    final m = re.firstMatch(text);
    if (m == null) return 60; // default 1 hour

    final n = int.parse(m.group(1)!);
    final unit = m.group(2)!;
    if (unit.contains('phút') || unit.contains('phut')) return n;
    return n * 60;
  }

  // ─── Location extraction ──────────────────────────────────────────────────────

  String _extractLocation(String text) {
    // "tại X" or "ở X" — capture until end or until another keyword
    final re = RegExp(
        r'(?:tại|tai|ở|o)\s+(.+?)(?:\s+(?:lúc|luc|trong|kéo|thứ|chu|ngay|hôm|mai|lúc)|\s*$)');
    final m = re.firstMatch(text);
    if (m == null) return '';
    return _capitalizeFirst(m.group(1)!.trim());
  }

  // ─── Title extraction ─────────────────────────────────────────────────────────

  String _extractTitle(String text) {
    // Remove filler words at the start
    String t = text;
    for (final filler in [
      'thêm lịch',
      'them lich',
      'đặt lịch',
      'dat lich',
      'thêm',
      'them',
      'đặt',
      'dat',
      'tạo',
      'tao',
      'lịch',
      'lich',
    ]) {
      if (t.startsWith(filler)) {
        t = t.substring(filler.length).trim();
        break;
      }
    }

    // Remove location chunk "tại/ở ..."
    t = t.replaceAll(
        RegExp(r'(?:tại|tai|ở|o)\s+\S+(?:\s+\S+){0,4}'), '').trim();

    // Remove time chunk "lúc N giờ ..."
    t = t.replaceAll(
        RegExp(
            r'(?:lúc|luc)\s+\d{1,2}\s*giờ(?:\s+\d{1,2})?(?:\s+(?:sáng|sang|trưa|trua|chiều|chieu|tối|toi|đêm|dem|rưỡi|ruoi))?'),
        '').trim();

    // Also remove bare "N giờ sáng/chiều/tối"
    t = t.replaceAll(
        RegExp(
            r'\d{1,2}\s*giờ(?:\s+\d{1,2})?(?:\s+(?:sáng|sang|trưa|trua|chiều|chieu|tối|toi|đêm|dem|rưỡi|ruoi))?'),
        '').trim();

    // Remove duration chunk
    t = t.replaceAll(
        RegExp(
            r'(?:trong|kéo dài|keo dai)\s+\d+\s*(?:tiếng|tieng|giờ|gio|phút|phut)'),
        '').trim();

    // Remove weekday / date words
    for (final d in [
      'thứ hai',
      'thứ ba',
      'thứ tư',
      'thứ năm',
      'thứ sáu',
      'thứ bảy',
      'chủ nhật',
      'ngày mai',
      'hôm nay',
      'ngày kia',
      'ngày mốt',
    ]) {
      t = t.replaceAll(d, '').trim();
    }

    // Clean up double spaces
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();

    return _capitalizeFirst(t);
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────────

  String _capitalizeFirst(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
