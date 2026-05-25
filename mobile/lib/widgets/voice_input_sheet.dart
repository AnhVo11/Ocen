import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/schedule.dart';
import '../services/api_service.dart';
import '../services/vietnamese_event_parser.dart';
import '../services/voice_service.dart';
import '../theme.dart';

/// Bottom sheet that handles the full voice → parse → confirm → save pipeline.
///
/// Usage:
///   showModalBottomSheet(
///     context: context,
///     isScrollControlled: true,
///     builder: (_) => VoiceInputSheet(apiService: _api),
///   );
class VoiceInputSheet extends StatefulWidget {
  final ApiService apiService;
  final VoidCallback? onScheduleAdded;

  const VoiceInputSheet({
    super.key,
    required this.apiService,
    this.onScheduleAdded,
  });

  @override
  State<VoiceInputSheet> createState() => _VoiceInputSheetState();
}

enum _SheetState {
  initialising,
  ready,       // waiting for user to tap mic
  listening,   // actively recording
  processing,  // parsed, showing event details
  conflict,    // conflict detected, awaiting decision
  saving,      // saving to ApiService
  done,        // saved OK
  error,       // STT or parse error
}

class _VoiceInputSheetState extends State<VoiceInputSheet>
    with SingleTickerProviderStateMixin {
  final _voice = VoiceService();
  final _parser = VietnameseEventParser();

  _SheetState _state = _SheetState.initialising;
  String _spokenText = '';
  ParsedEvent? _parsed;
  Schedule? _conflictingSchedule;
  String _errorMsg = '';

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _init();
  }

  Future<void> _init() async {
    final ok = await _voice.init();
    if (!mounted) return;
    if (ok) {
      setState(() => _state = _SheetState.ready);
      // Auto-start listening when sheet opens
      await _startListening();
    } else {
      setState(() {
        _state = _SheetState.error;
        _errorMsg = 'Không thể khởi tạo micro. Vui lòng kiểm tra quyền micro.';
      });
    }
  }

  Future<void> _startListening() async {
    setState(() {
      _state = _SheetState.listening;
      _spokenText = '';
    });

    await _voice.startListening(
      onResult: (text, isFinal) {
        if (!mounted) return;
        setState(() => _spokenText = text);
        if (isFinal && text.isNotEmpty) {
          _processText(text);
        }
      },
      onDone: () {
        if (!mounted) return;
        if (_spokenText.isEmpty) {
          setState(() {
            _state = _SheetState.error;
            _errorMsg = 'Không nghe thấy gì. Vui lòng thử lại.';
          });
        }
      },
    );
  }

  Future<void> _processText(String text) async {
    final event = _parser.parse(text);

    if (!event.parsed) {
      setState(() {
        _state = _SheetState.error;
        _errorMsg =
            'Không nhận ra giờ bắt đầu. Ví dụ: "họp lúc 3 giờ chiều ngày mai".';
      });
      await _voice.speakParseError();
      return;
    }

    // Check conflict
    final conflict = widget.apiService.checkConflict(
      event.startTime,
      event.endTime,
    );

    setState(() {
      _parsed = event;
      if (conflict.hasConflict) {
        _state = _SheetState.conflict;
        _conflictingSchedule = conflict.conflictingSchedule;
      } else {
        _state = _SheetState.processing;
      }
    });

    if (conflict.hasConflict) {
      final timeFmt = DateFormat('HH:mm');
      await _voice.speakConflict(
        event.title,
        conflict.conflictingSchedule!.title,
        timeFmt.format(conflict.conflictingSchedule!.startTime),
      );
    }
  }

  Future<void> _save({bool isUrgent = false}) async {
    if (_parsed == null) return;
    setState(() => _state = _SheetState.saving);

    final timeFmt = DateFormat('HH:mm');
    final timeStr = timeFmt.format(_parsed!.startTime);

    final result = await widget.apiService.checkAndSave(
      title: _parsed!.title,
      startTime: _parsed!.startTime,
      endTime: _parsed!.endTime,
      location: _parsed!.location,
      isUrgent: isUrgent,
    );

    if (!mounted) return;
    setState(() => _state = _SheetState.done);

    if (isUrgent) {
      await _voice.speakConflictAdded(_parsed!.title);
    } else {
      // Include travel warning in confirmation if travel info is available
      String? travelWarning;
      if (result.travel != null && !result.travel!.feasible) {
        travelWarning = result.travel!.message;
      } else if (result.travel != null &&
          result.travel!.feasible &&
          result.travel!.mode != 'unknown') {
        travelWarning = result.travel!.message;
      }
      await _voice.speakConfirm(
        _parsed!.title,
        timeStr,
        _parsed!.location,
        travelWarning: travelWarning,
      );
    }

    widget.onScheduleAdded?.call();

    if (mounted) {
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _cancel() async {
    await _voice.speakConflictCancelled();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _voice.dispose();
    super.dispose();
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              _buildBody(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case _SheetState.initialising:
        return _StatusView(
          icon: const CircularProgressIndicator(),
          title: 'Đang khởi động micro...',
        );

      case _SheetState.ready:
        return _StatusView(
          icon: const Icon(Icons.mic_none, size: 56, color: AppColors.primary),
          title: 'Chạm để nói',
        );

      case _SheetState.listening:
        return Column(
          children: [
            ScaleTransition(
              scale: _pulseAnim,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mic, size: 44, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Đang nghe...',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary),
            ),
            const SizedBox(height: 12),
            if (_spokenText.isNotEmpty)
              Text(
                '"$_spokenText"',
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () async {
                await _voice.stopListening();
                if (mounted) Navigator.of(context).pop();
              },
              icon: const Icon(Icons.stop, color: AppColors.error),
              label: const Text('Hủy', style: TextStyle(color: AppColors.error)),
            ),
          ],
        );

      case _SheetState.processing:
        return _ParsedEventView(
          event: _parsed!,
          onConfirm: () => _save(),
          onCancel: () => Navigator.of(context).pop(),
        );

      case _SheetState.conflict:
        return _ConflictView(
          newEvent: _parsed!,
          conflicting: _conflictingSchedule!,
          onAddAnyway: () => _save(isUrgent: true),
          onCancel: _cancel,
        );

      case _SheetState.saving:
        return _StatusView(
          icon: const CircularProgressIndicator(),
          title: 'Đang lưu...',
        );

      case _SheetState.done:
        return _StatusView(
          icon: const Icon(Icons.check_circle, size: 56, color: Colors.green),
          title: 'Đã thêm lịch!',
          subtitle: _parsed?.title,
        );

      case _SheetState.error:
        return Column(
          children: [
            const Icon(Icons.error_outline, size: 56, color: AppColors.error),
            const SizedBox(height: 12),
            Text(
              _errorMsg,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.error),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _startListening,
              icon: const Icon(Icons.mic),
              label: const Text('Thử lại'),
            ),
          ],
        );
    }
  }
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

class _StatusView extends StatelessWidget {
  final Widget icon;
  final String title;
  final String? subtitle;

  const _StatusView({required this.icon, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          icon,
          const SizedBox(height: 12),
          Text(title,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!,
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textSecondary)),
          ],
        ],
      ),
    );
  }
}

class _ParsedEventView extends StatelessWidget {
  final ParsedEvent event;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _ParsedEventView({
    required this.event,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('EEE, dd/MM/yyyy', 'vi_VN');
    final timeFmt = DateFormat('HH:mm');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Thêm sự kiện này?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _EventInfoCard(
          title: event.title,
          date: dateFmt.format(event.startTime),
          time:
              '${timeFmt.format(event.startTime)} – ${timeFmt.format(event.endTime)}',
          location: event.location,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onCancel,
                child: const Text('Hủy'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onConfirm,
                icon: const Icon(Icons.check),
                label: const Text('Xác nhận'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ConflictView extends StatelessWidget {
  final ParsedEvent newEvent;
  final Schedule conflicting;
  final VoidCallback onAddAnyway;
  final VoidCallback onCancel;

  const _ConflictView({
    required this.newEvent,
    required this.conflicting,
    required this.onAddAnyway,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final timeFmt = DateFormat('HH:mm');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  color: AppColors.error, size: 26),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                '⚠️ Xung đột lịch trình!',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.error),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // New event
        const Text('Sự kiện mới:',
            style: TextStyle(
                fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        _EventInfoCard(
          title: newEvent.title,
          date: DateFormat('dd/MM/yyyy').format(newEvent.startTime),
          time:
              '${timeFmt.format(newEvent.startTime)} – ${timeFmt.format(newEvent.endTime)}',
          location: newEvent.location,
          borderColor: AppColors.primary,
        ),
        const SizedBox(height: 12),
        // Conflicting event
        const Text('Bị trùng với:',
            style: TextStyle(
                fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        _EventInfoCard(
          title: conflicting.title,
          date: DateFormat('dd/MM/yyyy').format(conflicting.startTime),
          time:
              '${timeFmt.format(conflicting.startTime)} – ${timeFmt.format(conflicting.endTime)}',
          location: conflicting.location,
          borderColor: AppColors.error,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onCancel,
                child: const Text('Hủy'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onAddAnyway,
                icon: const Icon(Icons.bolt),
                label: const Text('Khẩn cấp'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _EventInfoCard extends StatelessWidget {
  final String title;
  final String date;
  final String time;
  final String location;
  final Color borderColor;

  const _EventInfoCard({
    required this.title,
    required this.date,
    required this.time,
    required this.location,
    this.borderColor = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: borderColor.withAlpha(13),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          _InfoRow(icon: Icons.calendar_today_outlined, text: date),
          const SizedBox(height: 4),
          _InfoRow(icon: Icons.access_time, text: time),
          if (location.isNotEmpty) ...[
            const SizedBox(height: 4),
            _InfoRow(icon: Icons.location_on_outlined, text: location),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
