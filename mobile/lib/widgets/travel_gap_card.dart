import 'package:flutter/material.dart';

import '../models/schedule.dart';
import '../services/maps_service.dart';
import '../theme.dart';

/// Slim card displayed between two consecutive events to show the real
/// travel time needed to get from [prev] to [next].
///
/// Uses FutureBuilder so the UI stays responsive while the Maps API call
/// completes in the background.
class TravelGapCard extends StatefulWidget {
  final Schedule prev;
  final Schedule next;

  const TravelGapCard({
    super.key,
    required this.prev,
    required this.next,
  });

  @override
  State<TravelGapCard> createState() => _TravelGapCardState();
}

class _TravelGapCardState extends State<TravelGapCard> {
  late final Future<MapsResult> _future;
  final _maps = MapsService();

  @override
  void initState() {
    super.initState();
    final gapMinutes =
        widget.next.startTime.difference(widget.prev.endTime).inMinutes;
    _future = _maps.getTravelInfo(
      origin: widget.prev.location,
      destination: widget.next.location,
      gapMinutes: gapMinutes,
      departureTime: widget.prev.endTime,
    );
  }

  @override
  Widget build(BuildContext context) {
    final gapMinutes =
        widget.next.startTime.difference(widget.prev.endTime).inMinutes;
    if (gapMinutes <= 0) return const SizedBox.shrink();

    return FutureBuilder<MapsResult>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _GapBar(
            icon: Icons.directions_car_outlined,
            text: 'Đang kiểm tra thời gian di chuyển...',
            color: AppColors.textSecondary,
            feasible: true,
            loading: true,
          );
        }

        if (snap.hasError || !snap.hasData) {
          return _GapBar(
            icon: Icons.swap_vert,
            text: '$gapMinutes phút giữa hai sự kiện',
            color: AppColors.textSecondary,
            feasible: true,
          );
        }

        final result = snap.data!;
        final icon = result.mode == TravelMode.flight
            ? Icons.flight
            : result.mode == TravelMode.driving
                ? Icons.directions_car
                : Icons.swap_vert;

        final color = result.feasible ? Colors.teal.shade700 : AppColors.error;

        return _GapBar(
          icon: icon,
          text: result.summary,
          color: color,
          feasible: result.feasible,
        );
      },
    );
  }
}

class _GapBar extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final bool feasible;
  final bool loading;

  const _GapBar({
    required this.icon,
    required this.text,
    required this.color,
    required this.feasible,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
      child: Row(
        children: [
          // Left timeline dot + line
          Column(
            children: [
              Container(width: 2, height: 8, color: Colors.grey.shade300),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: feasible
                      ? color.withAlpha(20)
                      : AppColors.error.withAlpha(20),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: feasible ? color : AppColors.error,
                    width: 1.5,
                  ),
                ),
                child: loading
                    ? Padding(
                        padding: const EdgeInsets.all(5),
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: color,
                        ),
                      )
                    : Icon(icon, size: 13, color: color),
              ),
              Container(width: 2, height: 8, color: Colors.grey.shade300),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight:
                    feasible ? FontWeight.normal : FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!feasible)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.warning_amber_rounded,
                  size: 16, color: AppColors.error),
            ),
        ],
      ),
    );
  }
}
