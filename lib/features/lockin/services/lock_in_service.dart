import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/services/auth_service.dart';
import '../models/focus_schedule_model.dart';
import '../models/lock_in_session_model.dart';

class LockInService {
  static String get _base => AuthService.baseUrl;
  static const _timeout = Duration(seconds: 10);

  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken() ?? '';
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// POST /lockin/start
  static Future<LockInSessionModel> startLockIn(int prepMinutes, int durationMinutes,
      {int? scheduleId}) async {
    final headers = await _headers();
    final body = jsonEncode({
      if (scheduleId != null) 'scheduleId': scheduleId,
      'prepTimerMinutes': prepMinutes,
      'durationMinutes': durationMinutes,
    });
    try {
      final resp = await http
          .post(Uri.parse('$_base/lockin/start'), headers: headers, body: body)
          .timeout(_timeout);
      if (resp.statusCode == 200) {
        return LockInSessionModel.fromJson(
            jsonDecode(resp.body) as Map<String, dynamic>);
      }
      throw Exception('startLockIn failed: ${resp.statusCode}');
    } catch (e) {
      debugPrint('LockInService.startLockIn error: $e');
      rethrow;
    }
  }

  /// POST /lockin/{id}/end?early=...
  static Future<LockInSessionModel> endLockIn(int sessionId, bool early) async {
    final headers = await _headers();
    try {
      final resp = await http
          .post(Uri.parse('$_base/lockin/$sessionId/end?early=$early'),
              headers: headers)
          .timeout(_timeout);
      if (resp.statusCode == 200) {
        return LockInSessionModel.fromJson(
            jsonDecode(resp.body) as Map<String, dynamic>);
      }
      throw Exception('endLockIn failed: ${resp.statusCode}');
    } catch (e) {
      debugPrint('LockInService.endLockIn error: $e');
      rethrow;
    }
  }

  /// GET /lockin/active — returns null if no active session
  static Future<LockInSessionModel?> getActiveSession() async {
    final headers = await _headers();
    try {
      final resp = await http
          .get(Uri.parse('$_base/lockin/active'), headers: headers)
          .timeout(_timeout);
      if (resp.statusCode == 200) {
        return LockInSessionModel.fromJson(
            jsonDecode(resp.body) as Map<String, dynamic>);
      }
      if (resp.statusCode == 404) return null;
      throw Exception('getActiveSession failed: ${resp.statusCode}');
    } catch (e) {
      debugPrint('LockInService.getActiveSession error: $e');
      return null;
    }
  }

  /// POST /lockin/schedules
  static Future<FocusScheduleModel> createSchedule({
    required String scheduleType,
    required String scheduledTime,
    required int durationMinutes,
    required int prepTimerMinutes,
    required bool isRecurring,
    String? daysOfWeek,
  }) async {
    final headers = await _headers();
    final body = jsonEncode({
      'scheduleType': scheduleType,
      'scheduledTime': scheduledTime,
      'durationMinutes': durationMinutes,
      'prepTimerMinutes': prepTimerMinutes,
      'recurring': isRecurring,
      if (daysOfWeek != null) 'daysOfWeek': daysOfWeek,
    });
    try {
      final resp = await http
          .post(Uri.parse('$_base/lockin/schedules'), headers: headers, body: body)
          .timeout(_timeout);
      if (resp.statusCode == 200) {
        return FocusScheduleModel.fromJson(
            jsonDecode(resp.body) as Map<String, dynamic>);
      }
      throw Exception('createSchedule failed: ${resp.statusCode}');
    } catch (e) {
      debugPrint('LockInService.createSchedule error: $e');
      rethrow;
    }
  }

  /// GET /lockin/schedules
  static Future<List<FocusScheduleModel>> getSchedules() async {
    final headers = await _headers();
    try {
      final resp = await http
          .get(Uri.parse('$_base/lockin/schedules'), headers: headers)
          .timeout(_timeout);
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List<dynamic>;
        return list
            .map((e) => FocusScheduleModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw Exception('getSchedules failed: ${resp.statusCode}');
    } catch (e) {
      debugPrint('LockInService.getSchedules error: $e');
      return [];
    }
  }

  /// PATCH /lockin/schedules/{id}/toggle
  static Future<FocusScheduleModel> toggleSchedule(int id) async {
    final headers = await _headers();
    try {
      final resp = await http
          .patch(Uri.parse('$_base/lockin/schedules/$id/toggle'), headers: headers)
          .timeout(_timeout);
      if (resp.statusCode == 200) {
        return FocusScheduleModel.fromJson(
            jsonDecode(resp.body) as Map<String, dynamic>);
      }
      throw Exception('toggleSchedule failed: ${resp.statusCode}');
    } catch (e) {
      debugPrint('LockInService.toggleSchedule error: $e');
      rethrow;
    }
  }

  /// DELETE /lockin/schedules/{id}
  static Future<void> deleteSchedule(int id) async {
    final headers = await _headers();
    try {
      final resp = await http
          .delete(Uri.parse('$_base/lockin/schedules/$id'), headers: headers)
          .timeout(_timeout);
      if (resp.statusCode != 204 && resp.statusCode != 200) {
        throw Exception('deleteSchedule failed: ${resp.statusCode}');
      }
    } catch (e) {
      debugPrint('LockInService.deleteSchedule error: $e');
      rethrow;
    }
  }
}
