import 'models.dart';

class CitationValidator {
  const CitationValidator();

  List<CitationValidation> validate({
    required Iterable<CitationDraft> citations,
    required Map<String, Passage> passages,
  }) {
    return citations.map((citation) {
      final passage = passages[citation.passageId];
      if (passage == null) {
        return CitationValidation(
          citation: citation,
          isValid: false,
          message: '引用指向不存在的 passage_id',
        );
      }
      if (citation.quotedText.trim().isEmpty) {
        return CitationValidation(
          citation: citation,
          isValid: false,
          message: '引用文本为空',
        );
      }
      if (!passage.textOriginal.contains(citation.quotedText)) {
        return CitationValidation(
          citation: citation,
          isValid: false,
          message: '引用不是指定原文的连续子串，必须降级为概述',
        );
      }
      return CitationValidation(citation: citation, isValid: true);
    }).toList(growable: false);
  }
}
