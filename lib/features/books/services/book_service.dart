import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/services/auth_service.dart';
import '../models/book_model.dart';
import '../models/book_snippet_model.dart';

class BookService {
  static String get _base => AuthService.baseUrl;

  static Future<Map<String, String>> _authHeaders() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// GET /book/all
  static Future<List<BookModel>> getAllBooks() async {
    final resp = await http.get(
      Uri.parse('$_base/book/all'),
      headers: await _authHeaders(),
    ).timeout(const Duration(seconds: 10));

    if (resp.statusCode == 200) {
      final List<dynamic> data = jsonDecode(resp.body);
      return data.map((e) => BookModel.fromJson(e)).toList();
    }
    throw Exception('Failed to load books (${resp.statusCode})');
  }

  /// GET /book/recommended/{level}
  static Future<List<BookModel>> getBooksByLevel(int level) async {
    final resp = await http.get(
      Uri.parse('$_base/book/recommended/$level'),
      headers: await _authHeaders(),
    ).timeout(const Duration(seconds: 10));

    if (resp.statusCode == 200) {
      final List<dynamic> data = jsonDecode(resp.body);
      return data.map((e) => BookModel.fromJson(e)).toList();
    }
    throw Exception('Failed to load books for level $level');
  }

  /// GET /book/{title}
  static Future<BookModel> getBookByTitle(String title) async {
    final resp = await http.get(
      Uri.parse('$_base/book/${Uri.encodeComponent(title)}'),
      headers: await _authHeaders(),
    ).timeout(const Duration(seconds: 10));

    if (resp.statusCode == 200) {
      return BookModel.fromJson(jsonDecode(resp.body));
    }
    throw Exception('Book not found');
  }

  /// GET /book/{bookId}/snippets
  static Future<List<BookSnippetModel>> getSnippets(int bookId) async {
    final resp = await http.get(
      Uri.parse('$_base/book/$bookId/snippets'),
      headers: await _authHeaders(),
    ).timeout(const Duration(seconds: 10));

    if (resp.statusCode == 200) {
      final List<dynamic> data = jsonDecode(resp.body);
      final list = data.map((e) => BookSnippetModel.fromJson(e)).toList();
      list.sort((a, b) => (a.sequenceOrder ?? 0).compareTo(b.sequenceOrder ?? 0));
      return list;
    }
    throw Exception('Failed to load snippets');
  }

  /// POST /book/snippet/{snippetId}/complete
  static Future<void> markSnippetComplete(int snippetId) async {
    await http.post(
      Uri.parse('$_base/book/snippet/$snippetId/complete'),
      headers: await _authHeaders(),
    ).timeout(const Duration(seconds: 8));
  }
}
