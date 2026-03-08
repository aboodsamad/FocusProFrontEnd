class Question {
  final int id;
  final String text;
  final List<String> options;
  final int correctIndex;

  Question({
    required this.id,
    required this.text,
    required this.options,
    required this.correctIndex,
  });
}
