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
    try {
      final resp = await http
          .get(Uri.parse('$_base/book/all'), headers: await _authHeaders())
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final List<dynamic> data = jsonDecode(resp.body);
        final List<BookModel> books = [];
        for (final e in data) {
          try { books.add(BookModel.fromJson(e)); } catch (_) {}
        }
        return books;
      }
      print('BookService.getAllBooks: status ${resp.statusCode}');
      return [];
    } catch (e) {
      print('BookService.getAllBooks error: $e');
      return [];
    }
  }

  /// GET /book/recommended/{level}
  static Future<List<BookModel>> getBooksByLevel(int level) async {
    try {
      final resp = await http
          .get(Uri.parse('$_base/book/recommended/$level'), headers: await _authHeaders())
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final List<dynamic> data = jsonDecode(resp.body);
        final List<BookModel> books = [];
        for (final e in data) {
          try { books.add(BookModel.fromJson(e)); } catch (_) {}
        }
        return books;
      }
      print('BookService.getBooksByLevel: status ${resp.statusCode}');
      return [];
    } catch (e) {
      print('BookService.getBooksByLevel error: $e');
      return [];
    }
  }

  /// GET /book/{title}
  static Future<BookModel?> getBookByTitle(String title) async {
    try {
      final resp = await http
          .get(Uri.parse('$_base/book/${Uri.encodeComponent(title)}'), headers: await _authHeaders())
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        return BookModel.fromJson(jsonDecode(resp.body));
      }
      print('BookService.getBookByTitle: status ${resp.statusCode}');
      return null;
    } catch (e) {
      print('BookService.getBookByTitle error: $e');
      return null;
    }
  }

  /// GET /book/{bookId}/snippets
  static Future<List<BookSnippetModel>> getSnippets(int bookId) async {
    try {
      final resp = await http
          .get(Uri.parse('$_base/book/$bookId/snippets'), headers: await _authHeaders())
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final List<dynamic> data = jsonDecode(resp.body);
        final List<BookSnippetModel> list = [];
        for (final e in data) {
          try { list.add(BookSnippetModel.fromJson(e)); } catch (_) {}
        }
        list.sort((a, b) => (a.sequenceOrder ?? 0).compareTo(b.sequenceOrder ?? 0));
        return list;
      }
      print('BookService.getSnippets: status ${resp.statusCode}');
      return [];
    } catch (e) {
      print('BookService.getSnippets error: $e');
      return [];
    }
  }

  /// GET /book/{bookId}/completed-snippets
  /// Returns the list of snippet IDs the user has already completed.
  static Future<Set<int>> getCompletedSnippetIds(int bookId) async {
    try {
      final resp = await http
          .get(Uri.parse('$_base/book/$bookId/completed-snippets'), headers: await _authHeaders())
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final List<dynamic> data = jsonDecode(resp.body);
        return data
            .map<int>((e) => (e['snippetId'] ?? e['id'] ?? 0) as int)
            .toSet();
      }
    } catch (_) {}
    return {};
  }

  /// POST /book/snippet/{snippetId}/complete
  static Future<void> markSnippetComplete(int snippetId) async {
    try {
      await http
          .post(
            Uri.parse('$_base/book/snippet/$snippetId/complete'),
            headers: await _authHeaders(),
          )
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      print('BookService.markSnippetComplete error (snippetId=$snippetId): $e');
    }
  }
}
