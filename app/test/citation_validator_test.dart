import 'package:flutter_test/flutter_test.dart';
import 'package:liangsimajing/domain/citation_validator.dart';
import 'package:liangsimajing/domain/models.dart';

void main() {
  const validator = CitationValidator();
  const passage = Passage(
    passageId: 'SJ-TEST-001',
    work: '史记',
    location: '卷一',
    textOriginal: '甲乙丙丁，戊己庚辛。',
  );

  test('接受原文连续子串', () {
    final result = validator.validate(
      citations: const [
        CitationDraft(
          claimId: 'CLAIM-1',
          passageId: 'SJ-TEST-001',
          quotedText: '乙丙丁',
        ),
      ],
      passages: const {'SJ-TEST-001': passage},
    );
    expect(result.single.isValid, isTrue);
  });

  test('拒绝模型拼接或补写的引文', () {
    final result = validator.validate(
      citations: const [
        CitationDraft(
          claimId: 'CLAIM-2',
          passageId: 'SJ-TEST-001',
          quotedText: '甲乙庚辛',
        ),
      ],
      passages: const {'SJ-TEST-001': passage},
    );
    expect(result.single.isValid, isFalse);
    expect(result.single.message, contains('降级'));
  });
}
