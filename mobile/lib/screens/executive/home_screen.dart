import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/schedule.dart';
import '../../models/user_role.dart';
import '../../services/api_service.dart';
import '../../theme.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/schedule_card.dart';
import '../../widgets/travel_gap_card.dart';
import '../../widgets/voice_input_sheet.dart';

/// Read-only schedule view for the executive.
/// Shows today's events in Tab 1 and upcoming week in Tab 2.
class ExecutiveHomeScreen extends StatefulWidget {
  const ExecutiveHomeScreen({super.key});

  @override
  State<ExecutiveHomeScreen> createState() => _ExecutiveHomeScreenState();
}

class _ExecutiveHomeScreenState extends State<ExecutiveHomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _api = ApiService();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _openVoiceInput() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VoiceInputSheet(
        apiService: _api,
        onScheduleAdded: () => setState(() {}), // refresh lists
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Schedule> todaySchedules = _api.getTodaySchedules();
    final List<Schedule> allSchedules = _api.getUpcomingSchedules();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lịch của tôi', // My schedule
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              DateFormat('dd/MM/yyyy').format(DateTime.now()),
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Hôm nay'), // Today
            Tab(text: 'Tuần này'), // This week
          ],
        ),
      ),
      drawer: const AppDrawer(role: UserRole.executive),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openVoiceInput,
        icon: const Icon(Icons.mic),
        label: const Text('Thêm bằng giọng nói'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          // ── Today ──────────────────────────────────────────────────────
          _ScheduleList(
            schedules: todaySchedules,
            emptyMessage: 'Hôm nay không có lịch nào.', // No events today
            groupByDate: false,
          ),

          // ── This week ──────────────────────────────────────────────────
          _ScheduleList(
            schedules: allSchedules,
            emptyMessage: 'Không có lịch sắp tới.', // No upcoming events
            groupByDate: true,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable schedule list with optional date-group headers
// ---------------------------------------------------------------------------

class _ScheduleList extends StatelessWidget {
  final List<Schedule> schedules;
  final String emptyMessage;
  final bool groupByDate;

  const _ScheduleList({
    required this.schedules,
    required this.emptyMessage,
    required this.groupByDate,
  });

  @override
  Widget build(BuildContext context) {
    if (schedules.isEmpty) {
      return _EmptyState(message: emptyMessage);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: schedules.length,
      itemBuilder: (context, i) {
        final schedule = schedules[i];
        final prev = i > 0 ? schedules[i - 1] : null;
        final showHeader = groupByDate &&
            (i == 0 || !_sameDay(schedules[i - 1].startTime, schedule.startTime));

        // Show travel gap when two consecutive same-day events both have locations
        // and there's at least a 5-minute window between them.
        final showTravelGap = prev != null &&
            !showHeader &&
            prev.location.isNotEmpty &&
            schedule.location.isNotEmpty &&
            schedule.startTime.difference(prev.endTime).inMinutes >= 5;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showHeader)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  DateFormat('EEE, dd/MM').format(schedule.startTime),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    fontSize: 13,
                  ),
                ),
              ),
            if (showTravelGap)
              TravelGapCard(prev: prev!, next: schedule),
            ScheduleCard(schedule: schedule),
          ],
        );
      },
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _EmptyState extends StatelessWidget {
  final String message;

  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.event_available_outlined,
            size: 72,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
