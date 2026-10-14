class GuardedAnswer {
  const GuardedAnswer({required this.text, required this.invalidCitationCount});

  final String text;
  final int invalidCitationCount;
}

class AnswerCitationGuard {
  const AnswerCitationGuard();

  static final _citation = RegExp(
    r'[“"]([^”"]+)[”"]\s*\[((?:SJ|ZZTJ)-\d{6})\]',
    multiLine: true,
  );

  GuardedAnswer sanitize(
    String answer,
    Map<String, String> allowedPassages,
  ) {
    var invalid = 0;
    final sanitized = answer.replaceAllMapped(_citation, (match) {
      final quote = match.group(1)!;
      final passageId = match.group(2)!;
      final original = allowedPassages[passageId];
      if (original != null && original.contains(quote)) return match.group(0)!;
      invalid += 1;
      return '（未通过原文核验的引文已隐藏）[$passageId]';
    });
    return GuardedAnswer(text: sanitized, invalidCitationCount: invalid);
  }
}
