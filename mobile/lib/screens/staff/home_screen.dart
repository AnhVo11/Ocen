import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/user_role.dart';
import '../../services/api_service.dart';
import '../../theme.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/schedule_card.dart';
import '../../widgets/voice_input_sheet.dart';

/// Home screen for secretary / driver — shows all upcoming schedules
/// and exposes the "Add schedule" FAB.
class StaffHomeScreen extends StatefulWidget {
  const StaffHomeScreen({super.key});

  @override
  State<StaffHomeScreen> createState() => _StaffHomeScreenState();
}

class _StaffHomeScreenState extends State<StaffHomeScreen> {
  final _api = ApiService();

  Future<void> _goToAddSchedule() async {
    final added = await Navigator.pushNamed(context, '/add-schedule');
    if (added == true) setState(() {}); // refresh list
  }

  void _openVoiceInput() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VoiceInputSheet(
        apiService: _api,
        onScheduleAdded: () => setState(() {}),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final schedules = _api.getUpcomingSchedules();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý lịch'), // Schedule management
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới', // Refresh
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      drawer: const AppDrawer(role: UserRole.secretary),

      body: schedules.isEmpty
          ? const _EmptyState()
          : ListView.builder(
              padding: const EdgeInsets.only(top: 12, bottom: 100),
              itemCount: schedules.length,
              itemBuilder: (context, i) {
                final schedule = schedules[i];
                final showHeader = i == 0 ||
                    !_sameDay(
                      schedules[i - 1].startTime,
                      schedule.startTime,
                    );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showHeader)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                        child: _DateChip(schedule.startTime),
                      ),
                    ScheduleCard(schedule: schedule),
                  ],
                );
              },
            ),

      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'staff_voice',
            onPressed: _openVoiceInput,
            icon: const Icon(Icons.mic_rounded, size: 20),
            label: const Text('Giọng nói',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'staff_form',
            onPressed: _goToAddSchedule,
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('Thêm lịch',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DateChip extends StatelessWidget {
  final DateTime date;

  const _DateChip(this.date);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        DateFormat('EEE dd/MM/yyyy').format(date),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today_outlined,
              size: 72, color: AppColors.textSecondary),
          SizedBox(height: 16),
          Text(
            'Chưa có lịch nào.', // No schedules yet
            style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
          ),
          SizedBox(height: 8),
          Text(
            'Nhấn + để thêm lịch mới.', // Tap + to add a new schedule
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
