import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ClaudeService {
  static const String _baseUrl = 'https://api.anthropic.com/v1/messages';
  static const String _model = 'claude-haiku-4-5'; // Fast & cheap for voice

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
          'max_tokens': 2048,
          'system': '''You are OpenClaw, a helpful personal AI assistant. 
You are running inside a voice-enabled Android app.
When responding, give a complete, detailed answer.
Keep responses clear and well-structured.''',
          'messages': messages,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final fullText = data['content'][0]['text'] as String;

        // Generate voice summary
        final summary = await _generateSummary(fullText, apiKey);

        return {
          'text': fullText,
          'summary': summary,
        };
      } else {
        return {
          'text': 'Error: ${response.statusCode} — ${response.body}',
          'summary': 'There was an error getting a response.',
        };
      }
    } catch (e) {
      return {
        'text': 'Connection error: $e',
        'summary': 'Could not connect to the AI.',
      };
    }
  }

  Future<String> _generateSummary(String fullText, String apiKey) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'model': 'claude-haiku-4-5',
          'max_tokens': 100,
          'messages': [
            {
              'role': 'user',
              'content':
                  'Summarize this response in 1-2 short sentences for voice reading. Be conversational and natural, no markdown:\n\n$fullText',
            }
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['content'][0]['text'] as String;
      }
    } catch (e) {
      // fallback: use first 150 chars
    }

    // Fallback: first sentence
    final firstPeriod = fullText.indexOf('.');
    if (firstPeriod > 0 && firstPeriod < 200) {
      return fullText.substring(0, firstPeriod + 1);
    }
    return fullText.substring(0, fullText.length.clamp(0, 150));
  }
}
