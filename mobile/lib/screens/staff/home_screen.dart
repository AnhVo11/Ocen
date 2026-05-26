import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/schedule.dart';
import '../../services/api_service.dart';
import '../../theme.dart';
import '../../widgets/schedule_card.dart';
import '../../widgets/voice_input_sheet.dart';
import '../../widgets/week_strip.dart';

class StaffHomeScreen extends StatefulWidget {
  const StaffHomeScreen({super.key});

  @override
  State<StaffHomeScreen> createState() => _StaffHomeScreenState();
}

class _StaffHomeScreenState extends State<StaffHomeScreen> {
  final _api = ApiService();
  DateTime _selectedDate = DateTime.now();

  List<Schedule> get _schedulesForDay {
    final all = _api.getUpcomingSchedules();
    return all.where((s) {
      return s.startTime.year == _selectedDate.year &&
          s.startTime.month == _selectedDate.month &&
          s.startTime.day == _selectedDate.day;
    }).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
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

  Future<void> _goToAddSchedule() async {
    final added = await Navigator.pushNamed(context, '/add-schedule');
    if (added == true) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final schedules = _schedulesForDay;
    final isToday = _isSameDay(_selectedDate, DateTime.now());
    final dateLabel = isToday
        ? 'Hôm nay'
        : DateFormat('EEE, dd/MM').format(_selectedDate);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dateLabel,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${schedules.length} sự kiện',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _IconBtn(
                    icon: Icons.refresh_rounded,
                    onTap: () => setState(() {}),
                  ),
                ],
              ),
            ),

            // ── Week strip ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: WeekStrip(
                selectedDate: _selectedDate,
                onDaySelected: (d) => setState(() => _selectedDate = d),
              ),
            ),

            const SizedBox(height: 8),

            // ── Timeline ──────────────────────────────────────────────────
            Expanded(
              child: schedules.isEmpty
                  ? _EmptyState(onAdd: _goToAddSchedule)
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 8, bottom: 120),
                      itemCount: schedules.length,
                      itemBuilder: (context, i) {
                        final s = schedules[i];
                        final isFeatured = s.isWork &&
                            schedules.indexWhere((e) => e.isWork) == i;
                        return ScheduleCard(
                          schedule: s,
                          isFirst: i == 0,
                          isLast: i == schedules.length - 1,
                          isFeatured: isFeatured,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),

      // ── Floating bottom nav ───────────────────────────────────────────────
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _BottomNavBar(
        onVoice: _openVoiceInput,
        onAdd: _goToAddSchedule,
        onBack: () => Navigator.pop(context),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ---------------------------------------------------------------------------
// Floating bottom nav bar
// ---------------------------------------------------------------------------

class _BottomNavBar extends StatelessWidget {
  final VoidCallback onVoice;
  final VoidCallback onAdd;
  final VoidCallback onBack;

  const _BottomNavBar({
    required this.onVoice,
    required this.onAdd,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 16,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            icon: Icons.home_rounded,
            label: 'Trang chủ',
            active: true,
            onTap: () {},
          ),
          _NavItem(
            icon: Icons.mic_rounded,
            label: 'Giọng nói',
            onTap: onVoice,
          ),
          // Centre FAB
          GestureDetector(
            onTap: onAdd,
            child: Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: AppColors.cardDark,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
          _NavItem(
            icon: Icons.calendar_month_rounded,
            label: 'Lịch',
            onTap: () {},
          ),
          _NavItem(
            icon: Icons.person_outline_rounded,
            label: 'Vai trò',
            onTap: onBack,
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 22,
            color: active ? AppColors.textPrimary : AppColors.textSecondary,
          ),
          const SizedBox(height: 2),
          if (active)
            Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: AppColors.cardDark,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.cardLight,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: AppColors.textPrimary),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.cardSecondary,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.add_circle_outline_rounded,
              size: 36,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Chưa có lịch',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Thêm lịch mới cho ngày này.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
