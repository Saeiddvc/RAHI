import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

class VoiceService {
  final FlutterTts _tts = FlutterTts();

  bool _initialized = false;
  bool _available = true;
  String? _lastSpokenText;
  DateTime? _lastSpokenTime;

  bool get isAvailable => _available;

  Future<void> _ensureInitialized() async {
    if (_initialized || !_available) return;

    try {
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      await _tts.setSpeechRate(0.5);
      await _tts.awaitSpeakCompletion(false);
      _initialized = true;
    } catch (_) {
      _available = false;
    }
  }

  Future<bool> speak(String text, String languageCode) async {
    final normalized = text.trim();
    if (normalized.isEmpty || !_available) return false;

    final now = DateTime.now();
    if (_lastSpokenText == normalized &&
        _lastSpokenTime != null &&
        now.difference(_lastSpokenTime!) < const Duration(seconds: 8)) {
      return true;
    }

    await _ensureInitialized();
    if (!_available) return false;

    try {
      final requestedLocale = _localeFor(languageCode);
      final requestedSupported =
          await _isLanguageAvailable(requestedLocale);

      var locale = requestedLocale;
      if (!requestedSupported) {
        const fallback = 'en-US';
        final fallbackSupported = await _isLanguageAvailable(fallback);
        if (!fallbackSupported) {
          return false;
        }
        locale = fallback;
      }

      await _tts.setLanguage(locale);
      await _tts.stop();

      final result = await _tts.speak(normalized);
      final success = result == 1 || result == true;

      if (success) {
        _lastSpokenText = normalized;
        _lastSpokenTime = now;
      }

      return success;
    } catch (_) {
      _available = false;
      return false;
    }
  }

  Future<bool> _isLanguageAvailable(String locale) async {
    try {
      final result = await _tts.isLanguageAvailable(locale);
      return result == true || result == 1;
    } catch (_) {
      return false;
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {
      // TTS shutdown is best-effort.
    }
  }

  String _localeFor(String code) {
    return switch (code) {
      'fa' => 'fa-IR',
      'ar' => 'ar-SA',
      _ => 'en-US',
    };
  }

  void dispose() {
    _tts.stop();
  }
}

final voiceServiceProvider = Provider<VoiceService>((ref) {
  final service = VoiceService();
  ref.onDispose(service.dispose);
  return service;
});
