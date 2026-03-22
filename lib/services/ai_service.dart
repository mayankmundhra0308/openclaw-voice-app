import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

enum AiProvider { anthropic, openai, gemini }

class AiProviderInfo {
  final AiProvider provider;
  final String name;
  final String icon;
  final List<AiModel> models;

  const AiProviderInfo({
    required this.provider,
    required this.name,
    required this.icon,
    required this.models,
  });
}

class AiModel {
  final String id;
  final String name;
  final String description;

  const AiModel({required this.id, required this.name, required this.description});
}

class AiService {
  static const List<AiProviderInfo> providers = [
    AiProviderInfo(
      provider: AiProvider.anthropic,
      name: 'Anthropic',
      icon: '🧠',
      models: [
        AiModel(id: 'claude-opus-4-5', name: 'Claude Opus 4', description: 'Most capable'),
        AiModel(id: 'claude-sonnet-4-5', name: 'Claude Sonnet 4', description: 'Balanced'),
        AiModel(id: 'claude-3-5-haiku-20241022', name: 'Claude Haiku 3.5', description: 'Fast & cheap'),
      ],
    ),
    AiProviderInfo(
      provider: AiProvider.openai,
      name: 'OpenAI',
      icon: '⚡',
      models: [
        AiModel(id: 'gpt-4o', name: 'GPT-4o', description: 'Most capable'),
        AiModel(id: 'gpt-4o-mini', name: 'GPT-4o mini', description: 'Fast & cheap'),
        AiModel(id: 'o1-mini', name: 'o1 mini', description: 'Reasoning model'),
      ],
    ),
    AiProviderInfo(
      provider: AiProvider.gemini,
      name: 'Google Gemini',
      icon: '✨',
      models: [
        AiModel(id: 'gemini-2.0-flash', name: 'Gemini 2.0 Flash', description: 'Latest & fast'),
        AiModel(id: 'gemini-1.5-pro', name: 'Gemini 1.5 Pro', description: 'Most capable'),
        AiModel(id: 'gemini-1.5-flash', name: 'Gemini 1.5 Flash', description: 'Fast & efficient'),
      ],
    ),
  ];

  static AiProviderInfo getProviderInfo(AiProvider provider) {
    return providers.firstWhere((p) => p.provider == provider);
  }

  Future<Map<String, String>> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'provider': prefs.getString('ai_provider') ?? 'anthropic',
      'model': prefs.getString('ai_model') ?? 'claude-opus-4-5',
      'anthropic_key': prefs.getString('anthropic_api_key') ?? '',
      'openai_key': prefs.getString('openai_api_key') ?? '',
      'gemini_key': prefs.getString('gemini_api_key') ?? '',
    };
  }

  Future<String> getChatResponse(
    String userMessage,
    List<Map<String, String>> history,
  ) async {
    final settings = await getSettings();
    final providerStr = settings['provider']!;
    final model = settings['model']!;

    AiProvider provider;
    switch (providerStr) {
      case 'openai':
        provider = AiProvider.openai;
        break;
      case 'gemini':
        provider = AiProvider.gemini;
        break;
      default:
        provider = AiProvider.anthropic;
    }

    switch (provider) {
      case AiProvider.anthropic:
        return _callAnthropic(userMessage, history, model, settings['anthropic_key']!);
      case AiProvider.openai:
        return _callOpenAI(userMessage, history, model, settings['openai_key']!);
      case AiProvider.gemini:
        return _callGemini(userMessage, history, model, settings['gemini_key']!);
    }
  }

  Future<String> _callAnthropic(
    String userMessage,
    List<Map<String, String>> history,
    String model,
    String apiKey,
  ) async {
    if (apiKey.isEmpty) return 'Please set your Anthropic API key in Settings.';

    final messages = [...history, {'role': 'user', 'content': userMessage}];

    try {
      final response = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'model': model,
          'max_tokens': 1024,
          'system': 'You are a helpful AI assistant in a voice app. Keep responses concise and conversational — they will be read aloud. Use plain language, no markdown.',
          'messages': messages,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['content'][0]['text'] as String;
      } else {
        final err = jsonDecode(response.body);
        return 'Error: ${err['error']?['message'] ?? response.statusCode}';
      }
    } catch (e) {
      return 'Connection error. Please check your internet.';
    }
  }

  Future<String> _callOpenAI(
    String userMessage,
    List<Map<String, String>> history,
    String model,
    String apiKey,
  ) async {
    if (apiKey.isEmpty) return 'Please set your OpenAI API key in Settings.';

    final messages = [
      {'role': 'system', 'content': 'You are a helpful AI assistant in a voice app. Keep responses concise and conversational — they will be read aloud. Use plain language, no markdown.'},
      ...history,
      {'role': 'user', 'content': userMessage},
    ];

    try {
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': model,
          'messages': messages,
          'max_tokens': 1024,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'] as String;
      } else {
        final err = jsonDecode(response.body);
        return 'Error: ${err['error']?['message'] ?? response.statusCode}';
      }
    } catch (e) {
      return 'Connection error. Please check your internet.';
    }
  }

  Future<String> _callGemini(
    String userMessage,
    List<Map<String, String>> history,
    String model,
    String apiKey,
  ) async {
    if (apiKey.isEmpty) return 'Please set your Gemini API key in Settings.';

    // Convert history to Gemini format
    final contents = <Map<String, dynamic>>[];
    for (final msg in history) {
      contents.add({
        'role': msg['role'] == 'user' ? 'user' : 'model',
        'parts': [{'text': msg['content']}],
      });
    }
    contents.add({
      'role': 'user',
      'parts': [{'text': userMessage}],
    });

    try {
      final response = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'system_instruction': {
            'parts': [{'text': 'You are a helpful AI assistant in a voice app. Keep responses concise and conversational — they will be read aloud. Use plain language, no markdown.'}]
          },
          'contents': contents,
          'generationConfig': {'maxOutputTokens': 1024},
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['candidates'][0]['content']['parts'][0]['text'] as String;
      } else {
        final err = jsonDecode(response.body);
        return 'Error: ${err['error']?['message'] ?? response.statusCode}';
      }
    } catch (e) {
      return 'Connection error. Please check your internet.';
    }
  }
}
