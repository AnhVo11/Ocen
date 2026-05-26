import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme.dart';

/// Horizontal week-day selector strip.
/// Shows 7 days; tapping a day calls [onDaySelected].
class WeekStrip extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDaySelected;

  const WeekStrip({
    super.key,
    required this.selectedDate,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    // Build the 7-day window centred around today
    final today = DateTime.now();
    final startOfWeek =
        today.subtract(Duration(days: today.weekday - 1)); // Monday

    return SizedBox(
      height: 72,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(7, (i) {
          final day = startOfWeek.add(Duration(days: i));
          final isSelected = _sameDay(day, selectedDate);
          final isToday = _sameDay(day, today);

          return Expanded(
            child: GestureDetector(
              onTap: () => onDaySelected(day),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeInOut,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.pillActive
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Day name: Mon, Tue…
                    Text(
                      DateFormat('EEE').format(day).substring(0, 2),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                        color: isSelected
                            ? Colors.white60
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Day number
                    Text(
                      day.day.toString(),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? Colors.white
                            : isToday
                                ? AppColors.textPrimary
                                : AppColors.textPrimary,
                      ),
                    ),
                    // Today dot
                    const SizedBox(height: 3),
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: isToday && !isSelected ? 1.0 : 0.0,
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: AppColors.cardDark,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
