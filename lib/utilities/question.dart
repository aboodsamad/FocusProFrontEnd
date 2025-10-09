class Question {
  int id;
  String text;
  List<String> options;
  int correctIndex;
  Question({
    required this.id,
    required this.text,
    required this.options,
    required this.correctIndex,
  });
}
