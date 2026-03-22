import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ai_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AiProvider _selectedProvider = AiProvider.anthropic;
  String _selectedModel = 'claude-opus-4-5';

  final _anthropicKeyCtrl = TextEditingController();
  final _openaiKeyCtrl = TextEditingController();
  final _geminiKeyCtrl = TextEditingController();

  bool _obscureAnthropic = true;
  bool _obscureOpenAI = true;
  bool _obscureGemini = true;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final providerStr = prefs.getString('ai_provider') ?? 'anthropic';
    AiProvider provider;
    switch (providerStr) {
      case 'openai': provider = AiProvider.openai; break;
      case 'gemini': provider = AiProvider.gemini; break;
      default: provider = AiProvider.anthropic;
    }
    setState(() {
      _selectedProvider = provider;
      _selectedModel = prefs.getString('ai_model') ?? 'claude-opus-4-5';
      _anthropicKeyCtrl.text = prefs.getString('anthropic_api_key') ?? '';
      _openaiKeyCtrl.text = prefs.getString('openai_api_key') ?? '';
      _geminiKeyCtrl.text = prefs.getString('gemini_api_key') ?? '';
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    String providerStr;
    switch (_selectedProvider) {
      case AiProvider.openai: providerStr = 'openai'; break;
      case AiProvider.gemini: providerStr = 'gemini'; break;
      default: providerStr = 'anthropic';
    }
    await prefs.setString('ai_provider', providerStr);
    await prefs.setString('ai_model', _selectedModel);
    await prefs.setString('anthropic_api_key', _anthropicKeyCtrl.text.trim());
    await prefs.setString('openai_api_key', _openaiKeyCtrl.text.trim());
    await prefs.setString('gemini_api_key', _geminiKeyCtrl.text.trim());

    setState(() => _saved = true);
    await Future.delayed(const Duration(seconds: 2));
    setState(() => _saved = false);
  }

  void _onProviderChanged(AiProvider p) {
    final info = AiService.getProviderInfo(p);
    setState(() {
      _selectedProvider = p;
      _selectedModel = info.models.first.id;
    });
  }

  @override
  void dispose() {
    _anthropicKeyCtrl.dispose();
    _openaiKeyCtrl.dispose();
    _geminiKeyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final providerInfo = AiService.getProviderInfo(_selectedProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          TextButton.icon(
            onPressed: _save,
            icon: Icon(_saved ? Icons.check : Icons.save_outlined,
                color: _saved ? Colors.greenAccent : AppTheme.primaryColor),
            label: Text(_saved ? 'Saved!' : 'Save',
                style: TextStyle(color: _saved ? Colors.greenAccent : AppTheme.primaryColor)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- Provider selection ---
          _sectionHeader('AI Provider'),
          const SizedBox(height: 10),
          ...AiService.providers.map((info) => _providerTile(info)),

          const SizedBox(height: 24),

          // --- Model selection ---
          _sectionHeader('Model'),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.07)),
            ),
            child: Column(
              children: providerInfo.models.asMap().entries.map((entry) {
                final idx = entry.key;
                final model = entry.value;
                final isLast = idx == providerInfo.models.length - 1;
                return Column(
                  children: [
                    RadioListTile<String>(
                      value: model.id,
                      groupValue: _selectedModel,
                      onChanged: (v) => setState(() => _selectedModel = v!),
                      activeColor: AppTheme.primaryColor,
                      title: Text(model.name,
                          style: const TextStyle(color: Colors.white, fontSize: 15)),
                      subtitle: Text(model.description,
                          style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ),
                    if (!isLast)
                      Divider(color: Colors.white.withOpacity(0.05), height: 1, indent: 16),
                  ],
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 24),

          // --- API Keys ---
          _sectionHeader('API Keys'),
          const SizedBox(height: 4),
          const Text(
            'Your keys are stored locally on device only.',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: 12),

          _apiKeyField(
            label: '🧠 Anthropic API Key',
            hint: 'sk-ant-...',
            controller: _anthropicKeyCtrl,
            obscure: _obscureAnthropic,
            onToggle: () => setState(() => _obscureAnthropic = !_obscureAnthropic),
            isActive: _selectedProvider == AiProvider.anthropic,
            helpUrl: 'console.anthropic.com',
          ),
          const SizedBox(height: 10),
          _apiKeyField(
            label: '⚡ OpenAI API Key',
            hint: 'sk-...',
            controller: _openaiKeyCtrl,
            obscure: _obscureOpenAI,
            onToggle: () => setState(() => _obscureOpenAI = !_obscureOpenAI),
            isActive: _selectedProvider == AiProvider.openai,
            helpUrl: 'platform.openai.com/api-keys',
          ),
          const SizedBox(height: 10),
          _apiKeyField(
            label: '✨ Gemini API Key',
            hint: 'AIza...',
            controller: _geminiKeyCtrl,
            obscure: _obscureGemini,
            onToggle: () => setState(() => _obscureGemini = !_obscureGemini),
            isActive: _selectedProvider == AiProvider.gemini,
            helpUrl: 'aistudio.google.com/apikey',
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        color: Colors.white38,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _providerTile(AiProviderInfo info) {
    final isSelected = _selectedProvider == info.provider;
    return GestureDetector(
      onTap: () => _onProviderChanged(info.provider),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withOpacity(0.15)
              : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor.withOpacity(0.6)
                : Colors.white.withOpacity(0.07),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(info.icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                info.name,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: AppTheme.primaryColor, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _apiKeyField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggle,
    required bool isActive,
    required String helpUrl,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive
              ? AppTheme.primaryColor.withOpacity(0.4)
              : Colors.white.withOpacity(0.05),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label,
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.white54,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  )),
              if (isActive) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Active',
                      style: TextStyle(color: AppTheme.primaryColor, fontSize: 10)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            obscureText: obscure,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'monospace'),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.white24),
              isDense: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
              suffixIcon: IconButton(
                icon: Icon(
                  obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: Colors.white38,
                  size: 18,
                ),
                onPressed: onToggle,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text('Get key at $helpUrl',
              style: const TextStyle(color: Colors.white24, fontSize: 11)),
        ],
      ),
    );
  }
}
