import 'package:flutter_test/flutter_test.dart';
import 'package:liangsimajing/domain/models.dart';
import 'package:liangsimajing/domain/similarity_scorer.dart';

void main() {
  const scorer = SimilarityScorer();

  QueryFrame query() => const QueryFrame(
        facts: [],
        userInterpretations: [],
        unknowns: [],
        desiredOutcomes: [],
        hardConstraints: [],
        stakeholders: [],
        relationships: {'上级-下属'},
        powerBalance: PowerBalance.disadvantaged,
        coreConflicts: {'功劳与控制'},
        decisionStage: DecisionStage.escalating,
        informationQuality: InformationQuality.partial,
        timePressure: TimePressure.medium,
        reversibility: Reversibility.low,
        riskTypes: {'报复', '失去资源'},
        legalOrSafetyFlags: [],
        clarificationNeeded: false,
      );

  HistoricalCaseSummary candidate({
    required String id,
    required Set<String> conflicts,
    bool published = true,
    int passages = 2,
  }) =>
      HistoricalCaseSummary(
        caseId: id,
        title: id,
        isPublished: published,
        verifiedPassageCount: passages,
        features: SimilarityFeatures(
          relationships: const {'上级-下属'},
          powerBalance: PowerBalance.disadvantaged,
          coreConflicts: conflicts,
          decisionStage: DecisionStage.escalating,
          informationQuality: InformationQuality.partial,
          timePressure: TimePressure.medium,
          reversibility: Reversibility.low,
          riskTypes: const {'报复'},
          patterns: const {},
        ),
      );

  test('机制更相似的案例排在前面', () {
    final ranked = scorer.rank(query(), [
      candidate(id: 'CASE-WEAK', conflicts: {'家庭争执'}),
      candidate(id: 'CASE-STRONG', conflicts: {'功劳与控制'}),
    ]);

    expect(ranked.first.historicalCase.caseId, 'CASE-STRONG');
    expect(ranked.first.score, greaterThan(ranked.last.score));
  });

  test('未发布或证据不足的案例不参与召回', () {
    final ranked = scorer.rank(query(), [
      candidate(id: 'CASE-DRAFT', conflicts: {'功劳与控制'}, published: false),
      candidate(id: 'CASE-NO-EVIDENCE', conflicts: {'功劳与控制'}, passages: 1),
    ]);

    expect(ranked, isEmpty);
  });
}
