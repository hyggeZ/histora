import 'dart:convert';

import '../domain/models.dart';
import '../domain/similarity_scorer.dart';

class PromptBundle {
  const PromptBundle({required this.system, required this.user});
  final String system;
  final String user;
}

class PromptBuilder {
  const PromptBuilder({this.maxEvidenceCharacters = 18000});

  final int maxEvidenceCharacters;

  PromptBundle build({
    required String originalQuestion,
    required QueryFrame frame,
    required List<ScoredCase> selectedCases,
    required Map<String, Passage> passages,
  }) {
    final evidence = passages.values.map((passage) {
      return {
        'passage_id': passage.passageId,
        'work': passage.work,
        'location': passage.location,
        'text_original': passage.textOriginal,
      };
    }).toList(growable: false);
    final encodedEvidence = jsonEncode(evidence);
    if (encodedEvidence.length > maxEvidenceCharacters) {
      throw StateError('核验史料超出上下文预算，请减少候选段落');
    }

    return PromptBundle(
      system: _systemPrompt,
      user: jsonEncode({
        'question': originalQuestion,
        'query_frame': _frameToJson(frame),
        'allowed_cases': selectedCases
            .map((item) => {
                  'case_id': item.historicalCase.caseId,
                  'title': item.historicalCase.title,
                  'score': item.score,
                  'match_reasons': item.reasons,
                })
            .toList(growable: false),
        'allowed_passages': evidence,
      }),
    );
  }

  Map<String, Object> _frameToJson(QueryFrame frame) => {
        'facts': frame.facts,
        'user_interpretations': frame.userInterpretations,
        'unknowns': frame.unknowns,
        'desired_outcomes': frame.desiredOutcomes,
        'hard_constraints': frame.hardConstraints,
        'stakeholders': frame.stakeholders,
        'relationships': frame.relationships.toList(),
        'power_balance': frame.powerBalance.name,
        'core_conflicts': frame.coreConflicts.toList(),
        'decision_stage': frame.decisionStage.name,
        'information_quality': frame.informationQuality.name,
        'time_pressure': frame.timePressure.name,
        'reversibility': frame.reversibility.name,
        'risk_types': frame.riskTypes.toList(),
        'legal_or_safety_flags': frame.legalOrSafetyFlags,
        'clarification_needed': frame.clarificationNeeded,
      };

  static const _systemPrompt = '''
你是“两司马决策镜”的受约束分析器。你只能使用输入中的 allowed_cases 和 allowed_passages 作为具体历史证据。

硬规则：
1. 不得创造新的 case_id 或 passage_id。
2. 所有中文引号内的古籍原文必须是某条 text_original 的连续子串，并紧跟 [passage_id]。
3. 不得补全、拼接或改写原文后仍称其为原文。
4. 明确区分史书直接记载、史家评论、编者解释、你的推断和反事实。
5. 每个历史案例必须同时说明相似点和差异点。
6. 历史相似不等于结果必然相同；必须校正古今制度、法律、身份、暴力条件和信息环境差异。
7. 不提供报复、欺骗、操纵、违法或伤害方案。
8. 证据不足时明确降级为一般决策框架，不得凭记忆补充史料。

回答顺序：局面定帧、关键未知、历史镜鉴、跨案例规律、现实行动方案、风险与失效条件、证据与推断说明。
行动方案必须包含低风险试探、首选路径、升级条件、止损线和观察信号。
''';
}
