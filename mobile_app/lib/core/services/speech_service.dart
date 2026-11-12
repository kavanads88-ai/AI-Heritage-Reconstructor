import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum SpeechStatus { idle, speaking, paused }

/// Abstraction so screens (and tests) do not depend on the TTS plugin directly.
abstract class SpeechService extends ChangeNotifier {
  SpeechStatus get status;

  /// Last engine error (for example: no English voice installed), or null.
  String? get error;

  /// Starts speaking [text], or resumes if currently paused with the same text.
  Future<void> speak(String text);
  Future<void> pause();
  Future<void> stop();
}

/// English text-to-speech using the phone's built-in engine via flutter_tts.
///
/// Pause is implemented as "stop + remember position" and resume as "speak the rest",
/// which behaves the same on every Android version (native pause support varies).
class FlutterTtsService extends SpeechService {
  FlutterTtsService() {
    _init();
  }

  final FlutterTts _tts = FlutterTts();
  SpeechStatus _status = SpeechStatus.idle;
  String? _error;
  String _text = '';
  int _offset = 0; // absolute character offset into _text that was last spoken
  int _base = 0; // offset where the current utterance started

  @override
  SpeechStatus get status => _status;

  @override
  String? get error => _error;

  Future<void> _init() async {
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.45);
      await _tts.setPitch(1.0);
      _tts.setCompletionHandler(() {
        if (_status == SpeechStatus.speaking) {
          _status = SpeechStatus.idle;
          _offset = 0;
          notifyListeners();
        }
      });
      _tts.setCancelHandler(() {
        if (_status == SpeechStatus.speaking) {
          _status = SpeechStatus.idle;
          notifyListeners();
        }
      });
      _tts.setErrorHandler((dynamic message) {
        _error = 'Text-to-speech problem: $message. Check that an English voice is installed on this phone.';
        _status = SpeechStatus.idle;
        notifyListeners();
      });
      _tts.setProgressHandler((String text, int start, int end, String word) {
        _offset = _base + start;
      });
    } catch (e) {
      _error = 'Text-to-speech is not available on this device ($e).';
      notifyListeners();
    }
  }

  @override
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    _error = null;
    try {
      if (_status == SpeechStatus.paused && text == _text && _offset < _text.length) {
        _base = _offset;
      } else {
        _text = text;
        _offset = 0;
        _base = 0;
        if (_status != SpeechStatus.idle) await _tts.stop();
      }
      _status = SpeechStatus.speaking;
      notifyListeners();
      await _tts.speak(_text.substring(_base));
    } catch (e) {
      _error = 'Could not start speech: $e';
      _status = SpeechStatus.idle;
      notifyListeners();
    }
  }

  @override
  Future<void> pause() async {
    if (_status != SpeechStatus.speaking) return;
    _status = SpeechStatus.paused; // set first so the cancel handler does not reset it
    notifyListeners();
    try {
      await _tts.stop();
    } catch (_) {
      // ignore: engine already stopped
    }
  }

  @override
  Future<void> stop() async {
    _status = SpeechStatus.idle;
    _offset = 0;
    _base = 0;
    notifyListeners();
    try {
      await _tts.stop();
    } catch (_) {
      // ignore
    }
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }
}
