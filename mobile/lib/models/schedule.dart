/// A calendar event / schedule entry.
class Schedule {
  final String id;
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final String location;
  final String? notes;
  final bool isWork;
  final bool needsTravel;

  /// 'car', 'flight', or null when no travel is required.
  final String? travelMode;

  /// Estimated travel duration in minutes, or null.
  final int? travelMinutes;

  const Schedule({
    required this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.location,
    this.notes,
    required this.isWork,
    required this.needsTravel,
    this.travelMode,
    this.travelMinutes,
  });

  factory Schedule.fromJson(Map<String, dynamic> json) {
    return Schedule(
      id: json['id'].toString(),
      title: json['title'] as String,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: DateTime.parse(json['end_time'] as String),
      location: (json['location'] as String?) ?? '',
      notes: json['notes'] as String?,
      isWork: (json['is_work'] as bool?) ?? false,
      needsTravel: (json['needs_travel'] as bool?) ?? false,
      travelMode: json['travel_mode'] as String?,
      travelMinutes: json['travel_minutes'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'start_time': startTime.toIso8601String(),
        'end_time': endTime.toIso8601String(),
        'location': location,
        'notes': notes,
        'is_work': isWork,
        'needs_travel': needsTravel,
        'travel_mode': travelMode,
        'travel_minutes': travelMinutes,
      };

  Schedule copyWith({
    String? id,
    String? title,
    DateTime? startTime,
    DateTime? endTime,
    String? location,
    String? notes,
    bool? isWork,
    bool? needsTravel,
    String? travelMode,
    int? travelMinutes,
  }) =>
      Schedule(
        id: id ?? this.id,
        title: title ?? this.title,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        location: location ?? this.location,
        notes: notes ?? this.notes,
        isWork: isWork ?? this.isWork,
        needsTravel: needsTravel ?? this.needsTravel,
        travelMode: travelMode ?? this.travelMode,
        travelMinutes: travelMinutes ?? this.travelMinutes,
      );
}
