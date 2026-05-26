import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/schedule.dart';
import '../theme.dart';
import 'flight_search_sheet.dart';

/// A timeline-style schedule card.
///
/// [isFirst] and [isLast] control whether the connecting vertical line
/// extends above / below the timeline dot.
/// [isFeatured] renders the dark card variant.
class ScheduleCard extends StatelessWidget {
  final Schedule schedule;
  final VoidCallback? onTap;
  final bool isFirst;
  final bool isLast;
  final bool isFeatured; // dark card style

  const ScheduleCard({
    super.key,
    required this.schedule,
    this.onTap,
    this.isFirst = false,
    this.isLast = false,
    this.isFeatured = false,
  });

  void _openFlightSearch(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FlightSearchSheet(schedule: schedule),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Timeline column ──────────────────────────────────────────────
          SizedBox(
            width: 24,
            child: Column(
              children: [
                // Line above dot
                Container(
                  width: 2,
                  height: isFirst ? 16 : 24,
                  color: isFirst
                      ? Colors.transparent
                      : AppColors.timelineLine,
                ),
                // Dot
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFeatured
                        ? AppColors.cardDark
                        : Colors.transparent,
                    border: Border.all(
                      color: isFeatured
                          ? AppColors.cardDark
                          : AppColors.timelineLine,
                      width: 2,
                    ),
                  ),
                ),
                // Line below dot
                Container(
                  width: 2,
                  height: isLast ? 16 : double.infinity,
                  color: isLast
                      ? Colors.transparent
                      : AppColors.timelineLine,
                  constraints: const BoxConstraints(minHeight: 16),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // ── Card ─────────────────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _CardBody(
                schedule: schedule,
                isFeatured: isFeatured,
                onTap: onTap,
                onFlightSearch: () => _openFlightSearch(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardBody extends StatelessWidget {
  final Schedule schedule;
  final bool isFeatured;
  final VoidCallback? onTap;
  final VoidCallback onFlightSearch;

  const _CardBody({
    required this.schedule,
    required this.isFeatured,
    required this.onTap,
    required this.onFlightSearch,
  });

  @override
  Widget build(BuildContext context) {
    final timeFmt = DateFormat('HH:mm');
    final bg = isFeatured ? AppColors.cardDark : AppColors.cardLight;
    final titleColor = isFeatured ? Colors.white : AppColors.textPrimary;
    final subColor = isFeatured ? Colors.white54 : AppColors.textSecondary;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: isFeatured
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withAlpha(20),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          splashColor: Colors.white12,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top row: title + time ──────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon badge
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isFeatured
                            ? Colors.white12
                            : AppColors.cardSecondary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        schedule.isWork
                            ? Icons.work_outline_rounded
                            : Icons.event_rounded,
                        size: 20,
                        color: isFeatured
                            ? Colors.white70
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Title + location
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            schedule.title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: titleColor,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (schedule.location.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.location_on_rounded,
                                    size: 12, color: subColor),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    schedule.location,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: subColor,
                                      fontWeight: FontWeight.w400,
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

                    // Arrow button (featured) or plain time
                    if (isFeatured) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 15,
                          color: AppColors.cardDark,
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 14),

                // ── Time row ──────────────────────────────────────────────
                Row(
                  children: [
                    Icon(Icons.access_time_rounded,
                        size: 13, color: subColor),
                    const SizedBox(width: 5),
                    Text(
                      '${timeFmt.format(schedule.startTime)} – ${timeFmt.format(schedule.endTime)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: subColor,
                      ),
                    ),
                  ],
                ),

                // ── Badges ─────────────────────────────────────────────────
                if (schedule.isWork || schedule.needsTravel) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (schedule.needsTravel && schedule.travelMode == 'flight')
                        _Pill(
                          label: 'Cần bay',
                          icon: Icons.flight_takeoff_rounded,
                          dark: isFeatured,
                        ),
                      if (schedule.needsTravel && schedule.travelMode == 'car')
                        _Pill(
                          label: 'Di chuyển',
                          icon: Icons.directions_car_rounded,
                          dark: isFeatured,
                        ),
                      if (schedule.travelMinutes != null)
                        _Pill(
                          label: '${schedule.travelMinutes} phút',
                          icon: Icons.timer_outlined,
                          dark: isFeatured,
                        ),
                    ],
                  ),
                ],

                // ── Flight search button ───────────────────────────────────
                if (schedule.needsTravel && schedule.travelMode == 'flight') ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: onFlightSearch,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isFeatured
                            ? Colors.white12
                            : AppColors.cardSecondary,
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.flight_rounded,
                              size: 14,
                              color: isFeatured
                                  ? Colors.white70
                                  : AppColors.textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            'Xem chuyến bay',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isFeatured
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ],
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

/// Small pill badge used inside cards
class _Pill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool dark;

  const _Pill({required this.label, required this.icon, required this.dark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: dark ? Colors.white12 : AppColors.cardSecondary,
        borderRadius: BorderRadius.circular(50),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 11,
              color: dark ? Colors.white60 : AppColors.textSecondary),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: dark ? Colors.white70 : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
