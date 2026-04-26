import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants/app_config.dart';
import '../../../core/services/auth_service.dart';

/// Sends batches of screen-switch events to the backend.
/// Called by ScreenEventSyncer every 30 seconds.
class ScreenEventService {
  static const _endpoint = '${AppConfig.baseUrl}/screen-events/batch';

  /// Posts [events] (each a map with packageName, appName, activityName, startedAt)
  /// to the backend. Returns true on success, false on any error.
  static Future<bool> sendBatch(List<Map<String, dynamic>> events) async {
    if (events.isEmpty) return true;
    try {
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) return false;

      final response = await http.post(
        Uri.parse(_endpoint),
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
}
