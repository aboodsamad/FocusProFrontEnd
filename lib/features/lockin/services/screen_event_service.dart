import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants/app_config.dart';
import '../../../core/services/auth_service.dart';

/// Sends batches of screen-switch events (from queryEvents) to the backend.
class ScreenEventService {
  static const _batchEndpoint = '${AppConfig.baseUrl}/screen-events/batch';
  static const _summaryEndpoint = '${AppConfig.baseUrl}/screen-events/summary';

  /// Posts [events] to the backend. Returns true on success.
  static Future<bool> sendBatch(List<Map<String, dynamic>> events) async {
    if (events.isEmpty) return true;
    try {
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) return false;

      final response = await http.post(
        Uri.parse(_batchEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'events': events}),
      );

      if (response.statusCode == 200) {
        debugPrint('[ScreenEvents] Synced ${events.length} events.');
        return true;
      } else {
        debugPrint('[ScreenEvents] Sync failed: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('[ScreenEvents] Network error: $e');
      return false;
    }
  }

  /// Fetches today's screen-time summary from the backend.
  /// Returns a map with keys like `totalMinutes`, `appBreakdown`, etc.
  /// Returns null on error.
  static Future<Map<String, dynamic>?> getSummary() async {
    try {
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) return null;

      final response = await http.get(
        Uri.parse(_summaryEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      debugPrint('[ScreenEvents] getSummary failed: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('[ScreenEvents] getSummary error: $e');
      return null;
    }
  }
}
