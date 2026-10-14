import 'package:flutter/material.dart';

import '../data/secure_api_config_store.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    required this.store,
    required this.onSaved,
    this.initial,
    this.firstRun = false,
    super.key,
  });

  final SecureApiConfigStore store;
  final ValueChanged<ApiConfig> onSaved;
  final ApiConfig? initial;
  final bool firstRun;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _baseUrl;
  late final TextEditingController _model;
  final TextEditingController _key = TextEditingController();
  bool _saving = false;
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    _baseUrl = TextEditingController(
      text: widget.initial?.baseUrl ?? 'https://api.openai.com',
    );
    _model = TextEditingController(text: widget.initial?.model ?? 'gpt-5-mini');
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _model.dispose();
    _key.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final previousKey = widget.initial?.apiKey ?? '';
    final config = ApiConfig(
      baseUrl: _baseUrl.text,
      model: _model.text,
      apiKey: _key.text.trim().isEmpty ? previousKey : _key.text,
    );
    setState(() => _saving = true);
    try {
      await widget.store.save(config);
      widget.onSaved(config);
      if (mounted && !widget.firstRun) Navigator.of(context).pop();
    } on FormatException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.firstRun ? '首次配置' : '模型设置')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('API Key 仅加密保存在本机',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text('不要把 Key 写进源码或分享安装后的应用数据。建议使用独立、低额度的项目 Key。'),
            const SizedBox(height: 24),
            TextField(
              controller: _baseUrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'API Base URL',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _model,
              decoration: const InputDecoration(
                labelText: '模型名称',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _key,
              obscureText: _obscureKey,
              enableSuggestions: false,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: widget.initial == null
                    ? 'API Key'
                    : 'API Key（留空则保持 ${widget.initial!.maskedKey}）',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscureKey = !_obscureKey),
                  icon: Icon(
                      _obscureKey ? Icons.visibility : Icons.visibility_off),
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.lock),
              label: const Text('安全保存'),
            ),
          ],
        ),
      ),
    );
  }
}
