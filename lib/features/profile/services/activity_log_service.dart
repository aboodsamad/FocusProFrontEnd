import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/services/auth_service.dart';
import '../models/activity_log.dart';

class ActivityLogService {
  static Future<List<ActivityLog>> fetchLogs() async {
    final token = await AuthService.getToken();
    if (token == null) return [];

    final url = Uri.parse('${AuthService.baseUrl}/activity/logs');
    try {
      final resp = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final List<dynamic> data = jsonDecode(resp.body);
        return data
            .map((j) => ActivityLog.fromJson(j as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      print('ActivityLogService.fetchLogs error: $e');
      return [];
    }
  }
}
