import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/schedule.dart';
import '../theme.dart';
import 'flight_search_sheet.dart';

/// A polished card that displays a single schedule entry.
class ScheduleCard extends StatelessWidget {
  final Schedule schedule;
  final VoidCallback? onTap;

  const ScheduleCard({super.key, required this.schedule, this.onTap});

  void _openFlightSearch(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FlightSearchSheet(schedule: schedule),
    );
  }

  Color get _accentColor =>
      schedule.isWork ? AppColors.primary : AppColors.accent;

  @override
  Widget build(BuildContext context) {
    final timeFmt = DateFormat('HH:mm');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(13),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: _accentColor.withAlpha(20),
          highlightColor: _accentColor.withAlpha(10),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Time block ─────────────────────────────────────────
                    Container(
                      width: 52,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 6),
                      decoration: BoxDecoration(
                        color: _accentColor.withAlpha(15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            timeFmt.format(schedule.startTime),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: _accentColor,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            height: 1,
                            color: _accentColor.withAlpha(60),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            timeFmt.format(schedule.endTime),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: _accentColor.withAlpha(180),
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 12),

                    // ── Title + location ───────────────────────────────────
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            schedule.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (schedule.location.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_rounded,
                                  size: 13,
                                  color: AppColors.textSecondary.withAlpha(180),
                                ),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    schedule.location,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    // ── Type indicator dot ─────────────────────────────────
                    const SizedBox(width: 8),
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: _accentColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),

                // ── Badges ────────────────────────────────────────────────
                if (schedule.isWork || schedule.needsTravel) ...[
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (schedule.isWork)
                        _Badge(
                          label: 'Công việc',
                          icon: Icons.work_outline_rounded,
                          color: AppColors.primary,
                        ),
                      if (schedule.needsTravel && schedule.travelMode == 'flight')
                        _Badge(
                          label: 'Cần bay',
                          icon: Icons.flight_takeoff_rounded,
                          color: AppColors.info,
                        ),
                      if (schedule.needsTravel && schedule.travelMode == 'car')
                        _Badge(
                          label: 'Di chuyển',
                          icon: Icons.directions_car_rounded,
                          color: Colors.teal.shade700,
                        ),
                      if (schedule.travelMinutes != null)
                        _Badge(
                          label: '${schedule.travelMinutes} phút',
                          icon: Icons.access_time_rounded,
                          color: AppColors.textSecondary,
                        ),
                    ],
                  ),
                ],

                // ── Flight search button ───────────────────────────────────
                if (schedule.needsTravel && schedule.travelMode == 'flight') ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _openFlightSearch(context),
                      icon: const Icon(Icons.flight_rounded, size: 15),
                      label: const Text('Xem chuyến bay'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.info,
                        side: BorderSide(
                            color: AppColors.info.withAlpha(120), width: 1.5),
                        backgroundColor: AppColors.info.withAlpha(10),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _Badge({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}
