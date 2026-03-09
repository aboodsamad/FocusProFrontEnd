/// Dimension types — each drives a different UI widget
enum DiagnosticDimension {
  screenHabits, // slider UI
  attention,    // interactive task UI
  lifestyle,    // option cards
  learning,     // option cards
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

  factory DiagnosticQuestion.fromJson(Map<String, dynamic> json) {
    final dimMap = {
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
}

/// What the frontend sends back for each answered question
class DiagnosticAnswer {
  final int questionId;
  final String selectedOption; // 'A' | 'B' | 'C' | 'D'
  final int pointsEarned;

  DiagnosticAnswer({
    required this.questionId,
    required this.selectedOption,
    required this.pointsEarned,
  });

  Map<String, dynamic> toJson() => {
    'question_id':     questionId,
    'selected_option': selectedOption,
    'points_earned':   pointsEarned,
  };
}
