import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

class VoiceService {
  // Синглтон
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  String _currentLocaleId = 'en_US';

  Completer<String>? _completer;
  String _recognizedText = "";

  /// 1. Инициализация и проверка прав
  Future<bool> initialize() async {
    _isInitialized = false;

    final micStatus = await Permission.microphone.request();
    if (micStatus != PermissionStatus.granted) {
      debugPrint('❌ Error: No microphone access');
      return false;
    }

    try {
      _isInitialized = await _speech.initialize(
        onError: (error) {
          debugPrint('STT Error: ${error.errorMsg}');
          _isInitialized = false;
        },
        onStatus: _onStatus,
      );

      if (_isInitialized) {
        var systemLocale = await _speech.systemLocale();
        final locales = await _speech.locales();

        final hasRu = locales.any((l) => l.localeId.startsWith('ru'));
        final hasEn = locales.any((l) => l.localeId.startsWith('en'));

        _currentLocaleId = hasRu
            ? locales.firstWhere((l) => l.localeId.startsWith('ru')).localeId
            : hasEn
                ? locales
                    .firstWhere((l) => l.localeId.startsWith('en'))
                    .localeId
                : (systemLocale?.localeId ?? 'en_US');

        debugPrint('Selected locale: $_currentLocaleId');
        debugPrint('✅ STT Initialized.');
      }
    } catch (e) {
      debugPrint('❌ STT Init Error: $e');
      _isInitialized = false;
    }

    return _isInitialized;
  }

  /// Обработчик статусов микрофона
  void _onStatus(String status) {
    debugPrint('🎤 STT Status: $status');
    if (status == 'notListening' || status == 'done') {
      if (_completer != null && !_completer!.isCompleted) {
        _completer!.complete(_recognizedText);
      }
    }
    if (status == 'error') {
      _isInitialized = false;
      if (_completer != null && !_completer!.isCompleted) {
        _completer!.complete('');
      }
    }
  }

  /// 2. Начать запись голоса
  Future<String> startListening(
      {Function(String text)? onPartialResult}) async {
    if (!_isInitialized) {
      bool inited = await initialize();
      if (!inited) return "";
    }

    if (_speech.isListening) {
      await stopListening();
    }

    _recognizedText = "";
    _completer = Completer<String>();

    await _speech.listen(
      onResult: (result) {
        _recognizedText = result.recognizedWords;
        // Добавлено расширенное логирование
        debugPrint(
            '🗣️ Partial: ${result.recognizedWords} | final: ${result.finalResult}');

        if (onPartialResult != null) {
          onPartialResult(_recognizedText);
        }

        if (result.finalResult && !_completer!.isCompleted) {
          _completer!.complete(_recognizedText);
        }
      },
      localeId: _currentLocaleId,
      listenOptions: stt.SpeechListenOptions(
        cancelOnError: true,
        partialResults: true,
      ),
      pauseFor: const Duration(seconds: 3),
    );

    return _completer!.future;
  }

  /// 3. Остановить запись
  Future<void> stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.complete(_recognizedText);
    }
  }
}

final voiceService = VoiceService();
