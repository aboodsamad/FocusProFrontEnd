class BookModel {
  final int id;
  final String title;
  final String author;
  final int level;
  final String category;
  final String description;
  final String? audioUrl;
  final String? bookPagesUrl;
  final int? totalPages;

  BookModel({
    required this.id,
    required this.title,
    required this.author,
    required this.level,
    required this.category,
    required this.description,
    this.audioUrl,
    this.bookPagesUrl,
    this.totalPages,
  });

  factory BookModel.fromJson(Map<String, dynamic> json) {
    return BookModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      author: json['author'] ?? '',
      level: json['level'] ?? 1,
      category: json['category'] ?? '',
      description: json['description'] ?? '',
      audioUrl: json['audioUrl'],
      bookPagesUrl: json['bookPagesUrl'],
      totalPages: json['totalPages'],
    );
  }

  String get levelLabel {
    switch (level) {
      case 1: return 'Beginner';
      case 2: return 'Intermediate';
      case 3: return 'Advanced';
      default: return 'All Levels';
    }
  }
}
