import 'dart:async';

import 'package:flutter/material.dart';

import '../application/decision_engine.dart';
import '../data/local/history_repository.dart';
import '../data/secure_api_config_store.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    required this.config,
    required this.store,
    required this.onConfigChanged,
    super.key,
  });

  final ApiConfig config;
  final SecureApiConfigStore store;
  final ValueChanged<ApiConfig> onConfigChanged;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _question = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final HistoryRepository _repository = HistoryRepository();
  late final DecisionEngine _engine = DecisionEngine(repository: _repository);
  StreamSubscription<DecisionEngineEvent>? _subscription;
  List<HistoricalCaseRecord> _cases = const [];
  String _answer = '';
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _subscription?.cancel();
    _repository.dispose();
    _question.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    FocusScope.of(context).unfocus();
    await _subscription?.cancel();
    setState(() {
      _busy = true;
      _answer = '';
      _cases = const [];
      _error = null;
    });
    _subscription =
        _engine.analyze(question: _question.text, config: widget.config).listen(
      (event) {
        if (!mounted) return;
        setState(() {
          if (event.cases != null) _cases = event.cases!;
          if (event.delta != null) _answer += event.delta!;
          if (event.replacement != null) _answer = event.replacement!;
          if (event.done) _busy = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) {
            _scroll.animateTo(
              _scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
            );
          }
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _error = error.toString();
        });
      },
      onDone: () {
        if (mounted) setState(() => _busy = false);
      },
    );
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SettingsPage(
          store: widget.store,
          initial: widget.config,
          onSaved: widget.onConfigChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('两司马决策镜'),
        actions: [
          IconButton(
            tooltip: '模型设置',
            onPressed: _busy ? null : _openSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  _Header(config: widget.config),
                  if (_cases.isEmpty && _answer.isEmpty && _error == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 72),
                      child: Text(
                        '描述局面、目标、已经掌握的事实，\n以及绝对不能接受的代价。',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (_cases.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('本地召回的历史镜鉴',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ..._cases.map(_CaseCard.new),
                  ],
                  if (_answer.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: SelectableText(_answer),
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(_error!),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (_busy) const LinearProgressIndicator(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _question,
                      minLines: 2,
                      maxLines: 5,
                      enabled: !_busy,
                      decoration: const InputDecoration(
                        hintText: '例如：老板正在削弱我的职责，我应该争取、等待还是离开？',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filled(
                    tooltip: _busy ? '正在推演' : '开始推演',
                    onPressed: _busy ? null : _analyze,
                    icon: const Icon(Icons.arrow_upward),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.config});
  final ApiConfig config;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('《史记》察人，《资治通鉴》审势',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text('当前模型：${config.model} · ${config.maskedKey}'),
          ],
        ),
      ),
    );
  }
}

class _CaseCard extends StatelessWidget {
  const _CaseCard(this.item);
  final HistoricalCaseRecord item;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        title: Text(item.title),
        subtitle: Text('${item.groupName} · ${item.summary}'),
        children: [
          ...item.evidence.map(
            (evidence) => ListTile(
              dense: true,
              title: Text('${evidence.work} · ${evidence.location}'),
              subtitle: Text(evidence.textOriginal,
                  maxLines: 5, overflow: TextOverflow.ellipsis),
              trailing: Text(evidence.passageId),
            ),
          ),
        ],
      ),
    );
  }
}
