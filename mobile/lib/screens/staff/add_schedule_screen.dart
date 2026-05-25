import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/api_service.dart';
import '../../theme.dart';
import '../shared/conflict_dialog.dart';
import '../shared/travel_check_screen.dart';

/// Form screen for adding a new schedule entry.
/// Validates input, runs conflict + travel checks, then saves.
class AddScheduleScreen extends StatefulWidget {
  const AddScheduleScreen({super.key});

  @override
  State<AddScheduleScreen> createState() => _AddScheduleScreenState();
}

class _AddScheduleScreenState extends State<AddScheduleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  DateTime _date = DateTime.now();
  TimeOfDay _startTime = TimeOfDay.now();
  late TimeOfDay _endTime;
  bool _isUrgent = false;
  bool _loading = false;

  final _api = ApiService();

  @override
  void initState() {
    super.initState();
    final now = TimeOfDay.now();
    _endTime = TimeOfDay(
      hour: (now.hour + 1) % 24,
      minute: now.minute,
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // ── Date / time pickers ──────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickStartTime() async {
    final picked =
        await showTimePicker(context: context, initialTime: _startTime);
    if (picked != null) setState(() => _startTime = picked);
  }

  Future<void> _pickEndTime() async {
    final picked =
        await showTimePicker(context: context, initialTime: _endTime);
    if (picked != null) setState(() => _endTime = picked);
  }

  DateTime _combine(TimeOfDay t) =>
      DateTime(_date.year, _date.month, _date.day, t.hour, t.minute);

  // ── Submit ───────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final start = _combine(_startTime);
    final end = _combine(_endTime);

    if (!end.isAfter(start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Giờ kết thúc phải sau giờ bắt đầu.', // End time must be after start time
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final result = await _api.checkAndSave(
        title: _titleCtrl.text.trim(),
        startTime: start,
        endTime: end,
        location: _locationCtrl.text.trim(),
        notes: _notesCtrl.text.trim().isEmpty
            ? null
            : _notesCtrl.text.trim(),
        isUrgent: _isUrgent,
      );

      if (!mounted) return;

      // Show conflict dialog if needed
      if (result.conflict != null && result.conflict!.hasConflict) {
        final proceed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => ConflictDialog(
            conflictingSchedule: result.conflict!.conflictingSchedule!,
            isUrgent: _isUrgent,
          ),
        );
        if (proceed != true) {
          setState(() => _loading = false);
          return;
        }
      }

      // Show travel check screen
      if (result.travel != null && mounted) {
        await Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => TravelCheckScreen(
              travel: result.travel!,
              scheduleTitle: _titleCtrl.text.trim(),
            ),
          ),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã lưu lịch thành công! ✅'), // Schedule saved!
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(title: const Text('Thêm lịch mới')), // Add new schedule
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Title ──────────────────────────────────────────────────
              const _Label('Tiêu đề *'), // Title
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  hintText: 'Tên sự kiện hoặc cuộc họp...',
                  prefixIcon: Icon(Icons.title),
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Vui lòng nhập tiêu đề' // Please enter a title
                    : null,
              ),
              const SizedBox(height: 20),

              // ── Date ───────────────────────────────────────────────────
              const _Label('Ngày *'), // Date
              _TapField(
                icon: Icons.calendar_today_outlined,
                text: dateFmt.format(_date),
                onTap: _pickDate,
              ),
              const SizedBox(height: 20),

              // ── Times ──────────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _Label('Giờ bắt đầu *'), // Start time
                        _TapField(
                          icon: Icons.access_time_outlined,
                          text: _startTime.format(context),
                          onTap: _pickStartTime,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _Label('Giờ kết thúc *'), // End time
                        _TapField(
                          icon: Icons.access_time_filled_outlined,
                          text: _endTime.format(context),
                          onTap: _pickEndTime,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Location ───────────────────────────────────────────────
              const _Label('Địa điểm *'), // Location
              TextFormField(
                controller: _locationCtrl,
                decoration: const InputDecoration(
                  hintText: 'Địa chỉ hoặc tên địa điểm...',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Vui lòng nhập địa điểm' // Please enter a location
                    : null,
              ),
              const SizedBox(height: 20),

              // ── Notes ──────────────────────────────────────────────────
              const _Label('Ghi chú'), // Notes (optional)
              TextFormField(
                controller: _notesCtrl,
                decoration: const InputDecoration(
                  hintText: 'Thông tin thêm (không bắt buộc)...',
                  prefixIcon: Icon(Icons.notes_outlined),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 20),

              // ── Urgent toggle ──────────────────────────────────────────
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: _isUrgent
                      ? AppColors.warning.withAlpha(25)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _isUrgent
                        ? AppColors.warning
                        : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.priority_high_rounded,
                      color: _isUrgent
                          ? AppColors.warning
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Khẩn cấp', // Urgent
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _isUrgent
                                  ? AppColors.warning
                                  : AppColors.textPrimary,
                            ),
                          ),
                          const Text(
                            'Cho phép thêm dù có xung đột', // Allow adding even with conflicts
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isUrgent,
                      onChanged: (v) => setState(() => _isUrgent = v),
                      activeThumbColor: AppColors.warning,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ── Submit ─────────────────────────────────────────────────
              ElevatedButton.icon(
                onPressed: _loading ? null : _submit,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(
                  _loading ? 'Đang kiểm tra...' : 'Kiểm tra & Lưu', // Check & Save
                  style: const TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Local helper widgets
// ---------------------------------------------------------------------------

class _Label extends StatelessWidget {
  final String text;

  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

/// A read-only field that opens a picker on tap.
class _TapField extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const _TapField({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: InputDecoration(prefixIcon: Icon(icon)),
        child: Text(text),
      ),
    );
  }
}
