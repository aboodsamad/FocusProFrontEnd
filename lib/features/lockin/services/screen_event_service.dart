import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants/app_config.dart';
import '../../../core/services/auth_service.dart';
import '../models/app_usage_stat_model.dart';

class ScreenEventService {
  static const _dailyUsageEndpoint = '${AppConfig.baseUrl}/screen-events/daily-usage';
  static const _summaryBase        = '${AppConfig.baseUrl}/screen-events/summary';

  /// Returns today's date in ISO format "yyyy-MM-dd" using the device's local timezone.
  static String _todayIso() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Posts today's aggregated app-usage totals to the backend (upserted per app per day).
  static Future<bool> sendDailyUsage(List<AppUsageStatModel> stats) async {
    if (stats.isEmpty) return true;
    try {
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) return false;

      final response = await http.post(
        Uri.parse(_dailyUsageEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          // Include device local date so backend stores under the correct calendar day
          // regardless of server timezone (Render runs UTC).
          'usageDate': _todayIso(),
          'usageStats': stats
              .map((s) => {
                    'packageName': s.packageName,
                    'appName': s.appName,
                    'totalMinutesToday': s.totalMinutesToday,
                  })
              .toList(),
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('[ScreenEvents] Daily usage synced (${stats.length} apps).');
        return true;
      }
      debugPrint('[ScreenEvents] Daily usage sync failed: ${response.statusCode}');
      return false;
    } catch (e) {
      debugPrint('[ScreenEvents] sendDailyUsage error: $e');
      return false;
    }
  }

  /// Fetches today's screen-time summary from the backend.
  /// Returns a list of maps with keys: packageName, appName, totalMinutes, usageDate.
  static Future<List<Map<String, dynamic>>> getSummary() async {
    try {
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) return [];

      // Pass device local date so backend filters the correct day regardless of server timezone.
      final uri = Uri.parse(_summaryBase).replace(
        queryParameters: {'date': _todayIso()},
      );
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        return list.cast<Map<String, dynamic>>();
      }
      debugPrint('[ScreenEvents] getSummary failed: ${response.statusCode}');
      return [];
    } catch (e) {
      debugPrint('[ScreenEvents] getSummary error: $e');
      return [];
    }
  }
}
