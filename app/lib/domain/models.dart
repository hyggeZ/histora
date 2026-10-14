enum PowerBalance {
  dominant,
  advantaged,
  balanced,
  disadvantaged,
  dependent,
  unknown
}

enum DecisionStage { emerging, escalating, crisis, aftermath, exit, unknown }

enum InformationQuality {
  poor,
  partial,
  asymmetric,
  adequate,
  deceptive,
  unknown
}

enum TimePressure { low, medium, high, immediate, unknown }

enum Reversibility { high, medium, low, none, unknown }

enum EvidenceClass {
  recordedFact,
  historianComment,
  compilerInterpretation,
  modelInference,
  counterfactual,
}

class QueryFrame {
  const QueryFrame({
    required this.facts,
    required this.userInterpretations,
    required this.unknowns,
    required this.desiredOutcomes,
    required this.hardConstraints,
    required this.stakeholders,
    required this.relationships,
    required this.powerBalance,
    required this.coreConflicts,
    required this.decisionStage,
    required this.informationQuality,
    required this.timePressure,
    required this.reversibility,
    required this.riskTypes,
    required this.legalOrSafetyFlags,
    required this.clarificationNeeded,
  });

  final List<String> facts;
  final List<String> userInterpretations;
  final List<String> unknowns;
  final List<String> desiredOutcomes;
  final List<String> hardConstraints;
  final List<String> stakeholders;
  final Set<String> relationships;
  final PowerBalance powerBalance;
  final Set<String> coreConflicts;
  final DecisionStage decisionStage;
  final InformationQuality informationQuality;
  final TimePressure timePressure;
  final Reversibility reversibility;
  final Set<String> riskTypes;
  final List<String> legalOrSafetyFlags;
  final bool clarificationNeeded;
}

class SimilarityFeatures {
  const SimilarityFeatures({
    required this.relationships,
    required this.powerBalance,
    required this.coreConflicts,
    required this.decisionStage,
    required this.informationQuality,
    required this.timePressure,
    required this.reversibility,
    required this.riskTypes,
    required this.patterns,
  });

  final Set<String> relationships;
  final PowerBalance powerBalance;
  final Set<String> coreConflicts;
  final DecisionStage decisionStage;
  final InformationQuality informationQuality;
  final TimePressure timePressure;
  final Reversibility reversibility;
  final Set<String> riskTypes;
  final Set<String> patterns;
}

class HistoricalCaseSummary {
  const HistoricalCaseSummary({
    required this.caseId,
    required this.title,
    required this.features,
    required this.isPublished,
    required this.verifiedPassageCount,
  });

  final String caseId;
  final String title;
  final SimilarityFeatures features;
  final bool isPublished;
  final int verifiedPassageCount;
}

class Passage {
  const Passage({
    required this.passageId,
    required this.work,
    required this.location,
    required this.textOriginal,
  });

  final String passageId;
  final String work;
  final String location;
  final String textOriginal;
}

class CitationDraft {
  const CitationDraft({
    required this.claimId,
    required this.passageId,
    required this.quotedText,
  });

  final String claimId;
  final String passageId;
  final String quotedText;
}

class CitationValidation {
  const CitationValidation({
    required this.citation,
    required this.isValid,
    this.message,
  });

  final CitationDraft citation;
  final bool isValid;
  final String? message;
}
