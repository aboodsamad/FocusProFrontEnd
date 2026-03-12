enum DiagnosticDimension {
  screenHabits,
  attention,
  lifestyle,
  learning,
}

class DiagnosticQuestion {
  final int id;
  final String questionText;
  final String optionA;
  final String optionB;
  final String optionC;
  final String optionD;
  final int pointsA;
  final int pointsB;
  final int pointsC;
  final int pointsD;
  final DiagnosticDimension dimension;
  final int displayOrder;

  DiagnosticQuestion({
    required this.id,
    required this.questionText,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.optionD,
    required this.pointsA,
    required this.pointsB,
    required this.pointsC,
    required this.pointsD,
    required this.dimension,
    required this.displayOrder,
  });

  List<String> get options => [optionA, optionB, optionC, optionD];
  List<int> get points => [pointsA, pointsB, pointsC, pointsD];

  // Used only for the fallback hardcoded list (snake_case map keys)
  factory DiagnosticQuestion.fromFallback(Map<String, dynamic> json) {
    const dimMap = {
      'screen_habits': DiagnosticDimension.screenHabits,
      'attention':     DiagnosticDimension.attention,
      'lifestyle':     DiagnosticDimension.lifestyle,
      'learning':      DiagnosticDimension.learning,
    };
    return DiagnosticQuestion(
      id:           json['id'],
      questionText: json['question_text'],
      optionA:      json['option_a'],
      optionB:      json['option_b'],
      optionC:      json['option_c'],
      optionD:      json['option_d'],
      pointsA:      json['points_a'],
      pointsB:      json['points_b'],
      pointsC:      json['points_c'],
      pointsD:      json['points_d'],
      dimension:    dimMap[json['dimension']] ?? DiagnosticDimension.lifestyle,
      displayOrder: json['display_order'],
    );
  }

  // Used when parsing the API response (camelCase keys from Spring Boot)
  // Points are injected separately since DiagnosticQuestionDTO doesn't expose them
  factory DiagnosticQuestion.fromApi(
    Map<String, dynamic> json, {
    required int pointsA,
    required int pointsB,
    required int pointsC,
    required int pointsD,
  }) {
    const dimMap = {
      'screen_habits': DiagnosticDimension.screenHabits,
      'attention':     DiagnosticDimension.attention,
      'lifestyle':     DiagnosticDimension.lifestyle,
      'learning':      DiagnosticDimension.learning,
    };
    return DiagnosticQuestion(
      id:           json['id'],
      questionText: json['questionText'],
      optionA:      json['optionA'],
      optionB:      json['optionB'],
      optionC:      json['optionC'],
      optionD:      json['optionD'],
      pointsA:      pointsA,
      pointsB:      pointsB,
      pointsC:      pointsC,
      pointsD:      pointsD,
      dimension:    dimMap[json['dimension']] ?? DiagnosticDimension.lifestyle,
      displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
    );
  }
}

// ── What Flutter sends back per answered question ─────────────────────────────
class DiagnosticAnswer {
  final int questionId;
  final String selectedOption; // 'A' | 'B' | 'C' | 'D'
  final int pointsEarned;

  DiagnosticAnswer({
    required this.questionId,
    required this.selectedOption,
    required this.pointsEarned,
  });

  // MUST match Java DiagnosticAnswerDTO field names exactly (camelCase)
  // Java fields: questionId, selectedOption, pointsEarned
  Map<String, dynamic> toJson() => {
    'questionId':     questionId,
    'selectedOption': selectedOption,
    'pointsEarned':   pointsEarned,
  };
}
