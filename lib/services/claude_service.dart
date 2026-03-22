import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ClaudeService {
  static const String _baseUrl = 'https://api.anthropic.com/v1/messages';
  static const String _model = 'claude-3-5-haiku-20241022'; // Correct model name

  Future<String?> _getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('anthropic_api_key');
  }

  Future<Map<String, String>> getChatResponse(
    String userMessage,
    List<Map<String, String>> history,
  ) async {
    final apiKey = await _getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      return {
        'text': 'Please set your Anthropic API key in Settings.',
        'summary': 'API key not configured.',
      };
    }

    final messages = [
      ...history,
      {'role': 'user', 'content': userMessage},
    ];

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'model': _model,
          'max_tokens': 1024,
          'system': '''You are OpenClaw, a helpful personal AI assistant running inside a voice-enabled Android app. 
Keep responses concise and conversational since they will be read aloud.
Avoid markdown, bullet points, or special formatting — use plain natural language.''',
          'messages': messages,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final fullText = data['content'][0]['text'] as String;
        // Clean text for TTS - remove markdown artifacts
        final cleanText = fullText
            .replaceAll(RegExp(r'\*\*|__|\*|_|`|#'), '')
            .replaceAll(RegExp(r'\n{2,}'), ' ')
            .trim();
        return {
          'text': fullText,
          'summary': cleanText,
        };
      } else {
        final errorBody = response.body;
        String errorMsg = 'Error ${response.statusCode}';
        try {
          final errData = jsonDecode(errorBody);
          errorMsg = errData['error']?['message'] ?? errorMsg;
        } catch (_) {}
        return {
          'text': 'API Error: $errorMsg',
          'summary': 'Sorry, there was an error: $errorMsg',
        };
      }
    } catch (e) {
      return {
        'text': 'Connection error: $e',
        'summary': 'Could not connect. Please check your internet connection.',
      };
    }
  }
}
