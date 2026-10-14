import 'models.dart';

class ScoredCase {
  const ScoredCase({
    required this.historicalCase,
    required this.score,
    required this.reasons,
  });

  final HistoricalCaseSummary historicalCase;
  final double score;
  final List<String> reasons;
}

class SimilarityScorer {
  const SimilarityScorer();

  static const _coreConflictWeight = 0.24;
  static const _powerBalanceWeight = 0.18;
  static const _relationshipWeight = 0.14;
  static const _decisionStageWeight = 0.12;
  static const _reversibilityWeight = 0.12;
  static const _informationQualityWeight = 0.08;
  static const _timePressureWeight = 0.06;
  static const _riskWeight = 0.06;

  List<ScoredCase> rank(
    QueryFrame query,
    Iterable<HistoricalCaseSummary> candidates, {
    int limit = 20,
  }) {
    final scored = candidates
        .where((item) => item.isPublished && item.verifiedPassageCount >= 2)
        .map((item) => _score(query, item))
        .toList()
      ..sort((a, b) {
        final scoreOrder = b.score.compareTo(a.score);
        return scoreOrder != 0
            ? scoreOrder
            : a.historicalCase.caseId.compareTo(b.historicalCase.caseId);
      });
    return scored.take(limit).toList(growable: false);
  }

  ScoredCase _score(QueryFrame query, HistoricalCaseSummary item) {
    final features = item.features;
    final reasons = <String>[];
    var score = 0.0;

    final conflictScore = _jaccard(query.coreConflicts, features.coreConflicts);
    score += conflictScore * _coreConflictWeight;
    if (conflictScore > 0) reasons.add('核心矛盾相似');

    if (_sameKnown(query.powerBalance, features.powerBalance)) {
      score += _powerBalanceWeight;
      reasons.add('权力结构相似');
    }

    final relationshipScore =
        _jaccard(query.relationships, features.relationships);
    score += relationshipScore * _relationshipWeight;
    if (relationshipScore > 0) reasons.add('关系类型相似');

    if (_sameKnown(query.decisionStage, features.decisionStage)) {
      score += _decisionStageWeight;
      reasons.add('决策阶段相似');
    }
    if (_sameKnown(query.reversibility, features.reversibility)) {
      score += _reversibilityWeight;
      reasons.add('可逆性相似');
    }
    if (_sameKnown(query.informationQuality, features.informationQuality)) {
      score += _informationQualityWeight;
      reasons.add('信息结构相似');
    }
    if (_sameKnown(query.timePressure, features.timePressure)) {
      score += _timePressureWeight;
      reasons.add('时间压力相似');
    }

    final riskScore = _jaccard(query.riskTypes, features.riskTypes);
    score += riskScore * _riskWeight;
    if (riskScore > 0) reasons.add('失败风险相似');

    return ScoredCase(
      historicalCase: item,
      score: double.parse(score.clamp(0, 1).toStringAsFixed(6)),
      reasons: reasons,
    );
  }

  bool _sameKnown(Object query, Object candidate) {
    return !query.toString().endsWith('.unknown') && query == candidate;
  }

  double _jaccard(Set<String> left, Set<String> right) {
    if (left.isEmpty || right.isEmpty) return 0;
    final intersection = left.intersection(right).length;
    final union = left.union(right).length;
    return union == 0 ? 0 : intersection / union;
  }
}
