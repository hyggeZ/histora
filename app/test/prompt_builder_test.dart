import 'package:flutter_test/flutter_test.dart';
import 'package:liangsimajing/application/prompt_builder.dart';
import 'package:liangsimajing/domain/models.dart';

void main() {
  const frame = QueryFrame(
    facts: ['事实'],
    userInterpretations: [],
    unknowns: [],
    desiredOutcomes: ['降低风险'],
    hardConstraints: [],
    stakeholders: [],
    relationships: {},
    powerBalance: PowerBalance.unknown,
    coreConflicts: {},
    decisionStage: DecisionStage.unknown,
    informationQuality: InformationQuality.unknown,
    timePressure: TimePressure.unknown,
    reversibility: Reversibility.unknown,
    riskTypes: {},
    legalOrSafetyFlags: [],
    clarificationNeeded: false,
  );

  test('证据超出预算时拒绝组装而不是静默截断', () {
    const builder = PromptBuilder(maxEvidenceCharacters: 20);
    expect(
      () => builder.build(
        originalQuestion: '测试',
        frame: frame,
        selectedCases: const [],
        passages: const {
          'SJ-TEST-001': Passage(
            passageId: 'SJ-TEST-001',
            work: '史记',
            location: '卷一',
            textOriginal: '这是一段超过上下文预算的测试原文。',
          ),
        },
      ),
      throwsStateError,
    );
  });
}
