import 'dart:async';

import '../data/local/history_repository.dart';
import '../data/remote/chat_provider.dart';
import '../data/secure_api_config_store.dart';
import 'answer_citation_guard.dart';

class DecisionEngineEvent {
  const DecisionEngineEvent({
    this.delta,
    this.replacement,
    this.cases,
    this.done = false,
  });

  final String? delta;
  final String? replacement;
  final List<HistoricalCaseRecord>? cases;
  final bool done;
}

class DecisionEngine {
  DecisionEngine({
    required HistoryRepository repository,
    OpenAiCompatibleChatProvider? provider,
  })  : _repository = repository,
        _provider = provider ?? OpenAiCompatibleChatProvider();

  final HistoryRepository _repository;
  final OpenAiCompatibleChatProvider _provider;
  final AnswerCitationGuard _citationGuard = const AnswerCitationGuard();

  Stream<DecisionEngineEvent> analyze({
    required String question,
    required ApiConfig config,
  }) async* {
    final trimmed = question.trim();
    if (trimmed.length < 8) {
      throw const FormatException('请再补充一些局面、目标或限制条件');
    }
    await _repository.initialize();
    final cases = _repository.searchCases(trimmed);
    yield DecisionEngineEvent(cases: cases);
    final allowedPassages = <String, String>{
      for (final item in cases)
        for (final passage in item.evidence)
          passage.passageId: passage.textOriginal,
    };
    final evidence = _evidencePayload(cases);
    final messages = [
      {'role': 'system', 'content': _systemPrompt},
      {
        'role': 'user',
        'content': '现实问题：\n$trimmed\n\n只允许使用以下候选案例与原文证据：\n$evidence',
      },
    ];
    final completeAnswer = StringBuffer();
    await for (final event in _provider.stream(
      baseUri: Uri.parse(config.baseUrl),
      apiKey: config.apiKey,
      model: config.model,
      messages: messages,
    )) {
      if (event is TextDelta) {
        completeAnswer.write(event.text);
        yield DecisionEngineEvent(delta: event.text);
      } else if (event is ChatDone) {
        final guarded = _citationGuard.sanitize(
          completeAnswer.toString(),
          allowedPassages,
        );
        if (guarded.invalidCitationCount > 0) {
          yield DecisionEngineEvent(replacement: guarded.text);
        }
        yield const DecisionEngineEvent(done: true);
      }
    }
  }

  String _evidencePayload(List<HistoricalCaseRecord> cases) {
    final buffer = StringBuffer();
    for (final item in cases) {
      buffer
        ..writeln('CASE ${item.caseId}｜${item.title}｜${item.groupName}')
        ..writeln('编者摘要：${item.summary}')
        ..writeln('编者分析：${item.body}');
      for (final passage in item.evidence) {
        buffer
          ..writeln(
              'PASSAGE ${passage.passageId}｜${passage.work}｜${passage.location}')
          ..writeln(passage.textOriginal);
      }
      buffer.writeln();
    }
    return buffer.toString();
  }

  static const _systemPrompt = '''
你是“两司马决策镜”。先区分用户陈述中的事实、解释、猜测和未知，再分析目标、权力结构、时间压力、可逆性及失败代价。

你只能使用用户消息中列出的 CASE 和 PASSAGE 作为具体史料。不得创造 ID，不得凭记忆补充古籍原句。凡用中文引号引用古籍，文字必须是对应 PASSAGE 的连续原文，并紧跟 [PASSAGE-ID]。编者摘要与分析不是古籍原文，不得放进原文引号。

按以下顺序回答：
1. 局面定帧；
2. 关键未知；
3. 2至3个历史镜鉴，每例说明相似点、不同点、当时选项、实际选择、短长期结果、显性与隐性代价、原文证据；
4. 跨案例规律；
5. 现实行动方案：低风险试探、首选路径、升级条件、止损线、观察信号；
6. 风险与失效条件；
7. 哪些属于史实、编者解释或你的推断。

历史相似不代表结果必然相同。必须校正古今法律、制度、身份、暴力条件和信息环境差异。不得提供报复、欺骗、操纵、违法或伤害方案。证据不足时明确降级为一般决策框架。
''';
}
