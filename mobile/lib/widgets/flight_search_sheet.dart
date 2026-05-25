import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/app_config.dart';
import '../models/schedule.dart';
import '../services/amadeus_service.dart';
import '../theme.dart';

/// Bottom sheet that searches for and displays available flights for a schedule
/// that requires air travel.
///
/// Usage:
///   showModalBottomSheet(
///     context: context,
///     isScrollControlled: true,
///     builder: (_) => FlightSearchSheet(schedule: schedule),
///   );
class FlightSearchSheet extends StatefulWidget {
  final Schedule schedule;

  /// Where the executive is departing from. Defaults to TP.HCM (SGN).
  final String originLocation;

  const FlightSearchSheet({
    super.key,
    required this.schedule,
    this.originLocation = 'tp.hcm',
  });

  @override
  State<FlightSearchSheet> createState() => _FlightSearchSheetState();
}

class _FlightSearchSheetState extends State<FlightSearchSheet> {
  final _amadeus = AmadeusService();
  late Future<List<FlightOffer>> _searchFuture;

  @override
  void initState() {
    super.initState();
    _runSearch();
  }

  void _runSearch() {
    _searchFuture = _amadeus.searchFlights(
      origin: widget.originLocation,
      destination: widget.schedule.location,
      departureDate: widget.schedule.startTime,
    );
  }

  @override
  Widget build(BuildContext context) {
    final originCode =
        AmadeusService.cityToIata(widget.originLocation) ?? 'SGN';
    final destCode =
        AmadeusService.cityToIata(widget.schedule.location) ?? '???';
    final dateStr =
        DateFormat('dd/MM/yyyy').format(widget.schedule.startTime);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // ── Drag handle ────────────────────────────────────────────
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // ── Header ─────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(20),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.flight_takeoff,
                              color: AppColors.primary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Chuyến bay $originCode → $destCode',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                dateStr,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Meeting deadline banner
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.access_alarm,
                              size: 15, color: Colors.amber.shade800),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Cần có mặt tại '
                              '${widget.schedule.location.split(',').first} '
                              'lúc ${DateFormat('HH:mm').format(widget.schedule.startTime)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),
              const Divider(height: 1),

              // ── Flight list ────────────────────────────────────────────
              Expanded(
                child: FutureBuilder<List<FlightOffer>>(
                  future: _searchFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text(
                              'Đang tìm chuyến bay...',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return _ErrorView(
                        onRetry: () => setState(() => _runSearch()),
                      );
                    }

                    final offers = snapshot.data ?? [];
                    if (offers.isEmpty) {
                      return const Center(
                        child: Text(
                          'Không tìm thấy chuyến bay nào.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      );
                    }

                    final meetingStart = widget.schedule.startTime;
                    final viable = offers
                        .where((o) => o.segments.last.arrivalTime
                            .isBefore(meetingStart))
                        .toList();
                    final tooLate = offers
                        .where((o) => !o.segments.last.arrivalTime
                            .isBefore(meetingStart))
                        .toList();

                    return ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      children: [
                        if (viable.isNotEmpty) ...[
                          _SectionLabel(
                              label: '✅ Kịp giờ họp',
                              color: Colors.green.shade700),
                          const SizedBox(height: 8),
                          ...viable.map((o) => _FlightCard(offer: o)),
                        ],
                        if (tooLate.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _SectionLabel(
                              label: '⚠️ Có thể trễ giờ họp',
                              color: AppColors.warning),
                          const SizedBox(height: 8),
                          ...tooLate
                              .map((o) => _FlightCard(offer: o, dimmed: true)),
                        ],
                        const SizedBox(height: 16),
                        Center(
                          child: Text(
                            AppConfig.flightSearchEnabled
                                ? 'Dữ liệu từ Amadeus • Giá có thể thay đổi'
                                : '⚠️ Dữ liệu mẫu — thêm Amadeus API key để xem giá thật',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  final String label;
  final Color color;

  const _SectionLabel({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: color,
      ),
    );
  }
}

class _FlightCard extends StatelessWidget {
  final FlightOffer offer;
  final bool dimmed;

  const _FlightCard({required this.offer, this.dimmed = false});

  @override
  Widget build(BuildContext context) {
    final seg = offer.segments.first;
    final timeFmt = DateFormat('HH:mm');
    final dep = timeFmt.format(seg.departureTime);
    final arr = timeFmt.format(seg.arrivalTime);
    final dur = AmadeusService.formatDuration(offer.totalDuration);
    final isMultiLeg = offer.segments.length > 1;

    return Opacity(
      opacity: dimmed ? 0.55 : 1.0,
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Carrier badge
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    seg.carrierCode,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Times + airline
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          dep,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                dur,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      height: 1,
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  Icon(
                                    isMultiLeg
                                        ? Icons.connecting_airports
                                        : Icons.flight,
                                    size: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                  Expanded(
                                    child: Container(
                                      height: 1,
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                isMultiLeg ? 'Nối chuyến' : 'Bay thẳng',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          arr,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${offer.airline} • ${seg.carrierCode}${seg.flightNumber}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Price
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    offer.price,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: dimmed ? Colors.grey : AppColors.primary,
                    ),
                    textAlign: TextAlign.right,
                  ),
                  const Text(
                    '/ người',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, size: 48, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          const Text(
            'Không thể tải dữ liệu chuyến bay.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }
}
