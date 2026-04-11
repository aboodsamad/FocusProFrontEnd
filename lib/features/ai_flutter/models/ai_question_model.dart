class AiQuestionModel {
  final int    questionId;
  final String questionText;
  final String optionA;
  final String optionB;
  final String optionC;
  final String optionD;

  const AiQuestionModel({
    required this.questionId,
    required this.questionText,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.optionD,
  });

  factory AiQuestionModel.fromJson(Map<String, dynamic> json) {
    return AiQuestionModel(
      questionId:   json['questionId']   as int,
      questionText: json['questionText'] as String,
      optionA:      json['optionA']      as String,
      optionB:      json['optionB']      as String,
      optionC:      json['optionC']      as String,
      optionD:      json['optionD']      as String,
    );
  }

  /// Returns the display text for a given letter key (A/B/C/D).
  String optionText(String letter) {
    return switch (letter) {
      'A' => optionA,
      'B' => optionB,
      'C' => optionC,
      'D' => optionD,
      _   => '',
    };
  }
}

// ── Result DTOs (parsed from submission response) ─────────────────────────────

class AiAnswerResult {
  final int    questionId;
  final String chosenAnswer;
  final String correctAnswer;
  final bool   correct;

  const AiAnswerResult({
    required this.questionId,
    required this.chosenAnswer,
    required this.correctAnswer,
    required this.correct,
  });

  factory AiAnswerResult.fromJson(Map<String, dynamic> json) {
    return AiAnswerResult(
      questionId:    json['questionId']    as int,
      chosenAnswer:  json['chosenAnswer']  as String,
      correctAnswer: json['correctAnswer'] as String,
      correct:       json['correct']       as bool,
    );
  }
}

class SnippetCheckResult {
  final int                correctCount;
  final int                totalQuestions;
  final bool               passed;
  final double             focusScoreGained;
  final double             newFocusScore;
  final List<AiAnswerResult> results;
  final String             message;

  const SnippetCheckResult({
    required this.correctCount,
    required this.totalQuestions,
    required this.passed,
    required this.focusScoreGained,
    required this.newFocusScore,
    required this.results,
    required this.message,
  });

  factory SnippetCheckResult.fromJson(Map<String, dynamic> json) {
    return SnippetCheckResult(
      correctCount:     json['correctCount']     as int,
      totalQuestions:   json['totalQuestions']   as int,
      passed:           json['passed']           as bool,
      focusScoreGained: (json['focusScoreGained'] as num).toDouble(),
      newFocusScore:    (json['newFocusScore']    as num).toDouble(),
      results: (json['results'] as List)
          .map((e) => AiAnswerResult.fromJson(e as Map<String, dynamic>))
          .toList(),
      message: json['message'] as String,
    );
  }
}

class RetentionTestResult {
  final int                correctCount;
  final int                totalQuestions;
  final double             scoreDelta;
  final double             newFocusScore;
  final List<AiAnswerResult> results;
  final String             message;

  const RetentionTestResult({
    required this.correctCount,
    required this.totalQuestions,
    required this.scoreDelta,
    required this.newFocusScore,
    required this.results,
    required this.message,
  });

  factory RetentionTestResult.fromJson(Map<String, dynamic> json) {
    return RetentionTestResult(
      correctCount:   json['correctCount']   as int,
      totalQuestions: json['totalQuestions'] as int,
      scoreDelta:     (json['scoreDelta']    as num).toDouble(),
      newFocusScore:  (json['newFocusScore'] as num).toDouble(),
      results: (json['results'] as List)
          .map((e) => AiAnswerResult.fromJson(e as Map<String, dynamic>))
          .toList(),
      message: json['message'] as String,
    );
  }
}
