import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme.dart';

/// Displays the travel-feasibility result between consecutive events.
/// Green card = feasible, red card = not feasible.
class TravelCheckScreen extends StatelessWidget {
  final TravelResult travel;
  final String scheduleTitle;

  const TravelCheckScreen({
    super.key,
    required this.travel,
    required this.scheduleTitle,
  });

  @override
  Widget build(BuildContext context) {
    final ok = travel.feasible;
    final cardColor = ok ? AppColors.success : AppColors.error;
    final bgColor =
        ok ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE);

    final (modeIcon, modeLabel) = switch (travel.mode) {
      'car' => ('🚗', 'Đi xe'), // By car
      'flight' => ('✈️', 'Đi máy bay'), // By flight
      _ => ('❓', 'Không xác định'), // Unknown
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Kiểm tra di chuyển')), // Travel check
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Status card ───────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 28),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cardColor.withAlpha(77)),
              ),
              child: Column(
                children: [
                  Icon(
                    ok
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    color: cardColor,
                    size: 60,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    ok
                        ? 'Có thể di chuyển kịp' // Can travel in time
                        : 'Không đủ thời gian!', // Not enough time!
                    style: TextStyle(
                      color: cardColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    travel.message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: cardColor.withAlpha(204),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // ── Mode detail ───────────────────────────────────────────
            if (ok && travel.mode != 'unknown') ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Text(modeIcon, style: const TextStyle(fontSize: 34)),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Phương tiện: $modeLabel', // Transport:
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        if (travel.minutes != null)
                          Text(
                            'Thời gian di chuyển: ${travel.minutes} phút', // Travel time: X min
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // ── Schedule being added ──────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(13),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.primary.withAlpha(38)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event, color: AppColors.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      scheduleTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // ── Confirm ───────────────────────────────────────────────
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.check),
              label: const Text(
                'Xác nhận', // Confirm
                style: TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
