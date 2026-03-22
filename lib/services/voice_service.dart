import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

class VoiceService {
  final FlutterTts _tts = FlutterTts();
  final SpeechToText _stt = SpeechToText();

  bool _isSttAvailable = false;
  bool _isSpeaking = false;
  bool _isListening = false;

  Future<void> init() async {
    // TTS setup
    await _tts.setLanguage('en-IN');
    await _tts.setSpeechRate(0.95);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    // Pick best available voice
    final voices = await _tts.getVoices;
    if (voices != null) {
      // Prefer Google voices on Samsung
      final googleVoice = (voices as List).firstWhere(
        (v) => v['name'].toString().contains('en-in') ||
            v['name'].toString().contains('en-IN'),
        orElse: () => null,
      );
      if (googleVoice != null) {
        await _tts.setVoice({
          'name': googleVoice['name'],
          'locale': googleVoice['locale'],
        });
      }
    }

    // STT setup
    _isSttAvailable = await _stt.initialize(
      onError: (error) => print('STT Error: $error'),
    );

    _tts.setCompletionHandler(() {
      _isSpeaking = false;
    });
  }

  Future<void> speak(String text) async {
    if (_isSpeaking) await _tts.stop();
    _isSpeaking = true;
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
    _isSpeaking = false;
  }

  bool get isSpeaking => _isSpeaking;
  bool get isListening => _isListening;
  bool get isSttAvailable => _isSttAvailable;

  Future<void> startListening({
    required Function(String text) onResult,
    required Function() onDone,
  }) async {
    if (!_isSttAvailable) return;
    if (_isSpeaking) await stop();

    _isListening = true;
    await _stt.listen(
      onResult: (SpeechRecognitionResult result) {
        if (result.finalResult) {
          _isListening = false;
          onResult(result.recognizedWords);
          onDone();
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      localeId: 'en_IN',
      cancelOnError: true,
      partialResults: false,
    );
  }

  Future<void> stopListening() async {
    await _stt.stop();
    _isListening = false;
  }

  void dispose() {
    _tts.stop();
    _stt.stop();
  }
}
