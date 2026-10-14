import 'package:flutter_test/flutter_test.dart';
import 'package:liangsimajing/application/answer_citation_guard.dart';

void main() {
  const guard = AnswerCitationGuard();
  const passages = {
    'SJ-000001': '甲乙丙丁，戊己庚辛。',
  };

  test('保留能够精确回查的引文', () {
    final result = guard.sanitize('原文“乙丙丁” [SJ-000001]', passages);
    expect(result.invalidCitationCount, 0);
    expect(result.text, contains('“乙丙丁”'));
  });

  test('隐藏补写、拼接或不存在 ID 的引文', () {
    final result = guard.sanitize(
      '伪引“甲乙庚辛” [SJ-000001]，未知“甲乙” [ZZTJ-999999]。',
      passages,
    );
    expect(result.invalidCitationCount, 2);
    expect(result.text, isNot(contains('甲乙庚辛')));
    expect(result.text, contains('未通过原文核验'));
  });
}
