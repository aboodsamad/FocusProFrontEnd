class BookSnippetModel {
  final int id;
  final int bookId;
  final String snippetTitle;
  final String snippetText;
  final String? snippetAudioUrl;
  final int? pageNumber;
  final int? durationSeconds;
  final int? sequenceOrder;
  final bool isCompleted;

  BookSnippetModel({
    required this.id,
    required this.bookId,
    required this.snippetTitle,
    required this.snippetText,
    this.snippetAudioUrl,
    this.pageNumber,
    this.durationSeconds,
    this.sequenceOrder,
    this.isCompleted = false,
  });

  factory BookSnippetModel.fromJson(Map<String, dynamic> json) {
    return BookSnippetModel(
      id: json['id'] ?? 0,
      bookId: json['bookId'] ?? 0,
      snippetTitle: json['snippetTitle'] ?? '',
      snippetText: json['snippetText'] ?? '',
      snippetAudioUrl: json['snippetAudioUrl'],
      pageNumber: json['pageNumber'],
      durationSeconds: json['durationSeconds'],
      sequenceOrder: json['sequenceOrder'],
      isCompleted: json['isCompleted'] ?? false,
    );
  }

  BookSnippetModel copyWith({bool? isCompleted}) {
    return BookSnippetModel(
      id: id,
      bookId: bookId,
      snippetTitle: snippetTitle,
      snippetText: snippetText,
      snippetAudioUrl: snippetAudioUrl,
      pageNumber: pageNumber,
      durationSeconds: durationSeconds,
      sequenceOrder: sequenceOrder,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  String get durationLabel {
    if (durationSeconds == null) return '';
    final m = durationSeconds! ~/ 60;
    final s = durationSeconds! % 60;
    return m > 0 ? '${m}m ${s}s' : '${s}s';
  }
}