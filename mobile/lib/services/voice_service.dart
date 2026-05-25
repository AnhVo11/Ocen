import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Wraps speech-to-text listening and text-to-speech output.
/// All TTS responses are in Vietnamese.
class VoiceService {
  final _stt = SpeechToText();
  final _tts = FlutterTts();

  bool _sttReady = false;
  bool _listening = false;

  bool get isListening => _listening;

  // ─── Initialise ──────────────────────────────────────────────────────────────

  Future<bool> init() async {
    // TTS setup
    await _tts.setLanguage('vi-VN');
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    // STT setup
    _sttReady = await _stt.initialize(
      onError: _onSttError,
      debugLogging: kDebugMode,
    );
    return _sttReady;
  }

  // ─── STT ─────────────────────────────────────────────────────────────────────

  /// Start listening. [onResult] is called with the recognised text.
  /// [onDone] is called when the session ends (silence timeout).
  Future<void> startListening({
    required void Function(String text, bool isFinal) onResult,
    required void Function() onDone,
  }) async {
    if (!_sttReady || _listening) return;

    _listening = true;
    await _stt.listen(
      localeId: 'vi_VN',
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
      onResult: (SpeechRecognitionResult result) {
        onResult(result.recognizedWords, result.finalResult);
        if (result.finalResult) {
          _listening = false;
          onDone();
        }
      },
    );
  }

  Future<void> stopListening() async {
    if (!_listening) return;
    _listening = false;
    await _stt.stop();
  }

  void _onSttError(SpeechRecognitionError error) {
    _listening = false;
    debugPrint('STT error: ${error.errorMsg}');
  }

  // ─── TTS ─────────────────────────────────────────────────────────────────────

  Future<void> speak(String text) async {
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
  }

  // ─── Canned Vietnamese responses ─────────────────────────────────────────────

  Future<void> speakConfirm(
      String title, String timeStr, String location,
      {String? travelWarning}) async {
    final loc = location.isNotEmpty ? ' tại $location' : '';
    final travel =
        travelWarning != null ? ' Lưu ý: $travelWarning' : ' Không có xung đột lịch trình.';
    await speak('Đã thêm $title lúc $timeStr$loc.$travel');
  }

  Future<void> speakConflict(
      String newTitle, String conflictTitle, String conflictTime) async {
    await speak(
        'Cảnh báo! $newTitle bị trùng với $conflictTitle lúc $conflictTime. '
        'Bạn có muốn thêm khẩn cấp không?');
  }

  Future<void> speakConflictCancelled() async {
    await speak('Đã hủy. Sự kiện chưa được thêm.');
  }

  Future<void> speakConflictAdded(String title) async {
    await speak('Đã thêm $title dù có xung đột.');
  }

  Future<void> speakParseError() async {
    await speak(
        'Xin lỗi, tôi không hiểu. Vui lòng nói rõ giờ bắt đầu. '
        'Ví dụ: thêm họp lúc ba giờ chiều ngày mai.');
  }

  Future<void> speakReady() async {
    await speak('Tôi đang nghe. Hãy nói lịch cần thêm.');
  }

  // ─── Cleanup ──────────────────────────────────────────────────────────────────

  Future<void> dispose() async {
    await _stt.stop();
    await _tts.stop();
  }
}
