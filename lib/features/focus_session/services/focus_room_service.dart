import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:stomp_dart_client/stomp_dart_client.dart';
import '../../../core/services/auth_service.dart';
import '../models/focus_room.dart';

class FocusRoomService {
  static String get _base => AuthService.baseUrl;
  static String get _wsUrl =>
      _base.replaceFirst('http://', 'ws://').replaceFirst('https://', 'wss://') + '/ws';

  // ── HTTP: get all rooms (optional category filter) ────────────────────────
  static Future<List<FocusRoom>> getRooms({String? category}) async {
    final token = await AuthService.getToken();
    final uri = (category != null && category.isNotEmpty && category != 'All')
        ? Uri.parse('$_base/rooms?category=${Uri.encodeComponent(category)}')
        : Uri.parse('$_base/rooms');

    final resp = await http
        .get(uri, headers: {'Authorization': 'Bearer $token'})
        .timeout(const Duration(seconds: 8));

    if (resp.statusCode == 200) {
      final List<dynamic> list = jsonDecode(resp.body);
      return list.map((j) => FocusRoom.fromJson(j as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to load rooms (${resp.statusCode})');
  }

  // ── HTTP: get a single room with members ──────────────────────────────────
  static Future<FocusRoom> getRoom(int id) async {
    final token = await AuthService.getToken();
    final resp = await http
        .get(Uri.parse('$_base/rooms/$id'), headers: {'Authorization': 'Bearer $token'})
        .timeout(const Duration(seconds: 8));

    if (resp.statusCode == 200) {
      return FocusRoom.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to load room (${resp.statusCode})');
  }

  // ── HTTP: create a room ────────────────────────────────────────────────────
  static Future<FocusRoom> createRoom({
    required String name,
    required String emoji,
    String category = 'Study',
    String? description,
    int maxMembers = 0,
    bool isPrivate = false,
  }) async {
    final token = await AuthService.getToken();
    final resp = await http
        .post(
          Uri.parse('$_base/rooms'),
          headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
          body: jsonEncode({
            'name': name,
            'emoji': emoji,
            'category': category,
            'description': description,
            'maxMembers': maxMembers,
            'isPrivate': isPrivate,
          }),
        )
        .timeout(const Duration(seconds: 8));

    if (resp.statusCode == 200 || resp.statusCode == 201) {
      return FocusRoom.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to create room (${resp.statusCode})');
  }

  // ── HTTP: join a room ──────────────────────────────────────────────────────
  static Future<FocusRoom> joinRoomRest(int roomId, String? goal,
      {String? inviteCode}) async {
    final token = await AuthService.getToken();
    final resp = await http
        .post(
          Uri.parse('$_base/rooms/$roomId/join'),
          headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
          body: jsonEncode({'goal': goal ?? '', 'inviteCode': inviteCode ?? ''}),
        )
        .timeout(const Duration(seconds: 8));

    if (resp.statusCode == 200) {
      return FocusRoom.fromJson(jsonDecode(resp.body));
    }

    // Parse error message from backend
    try {
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      throw Exception(body['error'] ?? 'Join failed (${resp.statusCode})');
    } catch (_) {
      throw Exception('Join failed (${resp.statusCode})');
    }
  }

  // ── HTTP: leave a room ────────────────────────────────────────────────────
  static Future<void> leaveRoomRest(int roomId) async {
    final token = await AuthService.getToken();
    try {
      await http
          .post(Uri.parse('$_base/rooms/$roomId/leave'),
              headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  // ── HTTP: fetch messages (last 50 or incremental after a timestamp) ────────
  static Future<List<RoomMessage>> fetchMessages(int roomId, String? after) async {
    final token = await AuthService.getToken();
    final uri = (after != null && after.isNotEmpty)
        ? Uri.parse('$_base/rooms/$roomId/messages?after=${Uri.encodeComponent(after)}')
        : Uri.parse('$_base/rooms/$roomId/messages');
    final resp = await http
        .get(uri, headers: {'Authorization': 'Bearer $token'})
        .timeout(const Duration(seconds: 8));
    if (resp.statusCode == 200) {
      final List<dynamic> list = jsonDecode(resp.body);
      return list.map((j) => RoomMessage.fromJson(j as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to load messages (${resp.statusCode})');
  }

  // ── HTTP: send a message ──────────────────────────────────────────────────
  static Future<RoomMessage> sendMessage(int roomId, String content) async {
    final token = await AuthService.getToken();
    final resp = await http
        .post(
          Uri.parse('$_base/rooms/$roomId/messages'),
          headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
          body: jsonEncode({'content': content}),
        )
        .timeout(const Duration(seconds: 8));
    if (resp.statusCode == 200 || resp.statusCode == 201) {
      return RoomMessage.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to send message (${resp.statusCode})');
  }

  // ── WebSocket: connect ────────────────────────────────────────────────────
  static Future<StompClient> connect({
    required int roomId,
    required String? goal,
    required void Function(RoomEvent event) onEvent,
    required void Function(String error) onError,
  }) async {
    final token = await AuthService.getToken();
    late StompClient client;
    client = StompClient(
      config: StompConfig(
        url: _wsUrl,
        stompConnectHeaders: {'Authorization': 'Bearer $token'},
        webSocketConnectHeaders: {'Authorization': 'Bearer $token'},
        onConnect: (frame) {
          client.subscribe(
            destination: '/topic/room/$roomId',
            callback: (frame) {
              if (frame.body == null) return;
              try {
                final json = jsonDecode(frame.body!) as Map<String, dynamic>;
                onEvent(RoomEvent.fromJson(json));
              } catch (e) {
                onError('Failed to parse event: $e');
              }
            },
          );
          client.send(
              destination: '/app/room/$roomId/join',
              body: jsonEncode({'goal': goal ?? ''}));
        },
        onDisconnect: (_) {},
        onStompError: (frame) => onError(frame.body ?? 'STOMP error'),
        onWebSocketError: (error) => onError('WebSocket error: $error'),
        onDebugMessage: (_) {},
      ),
    );
    client.activate();
    return client;
  }

  // ── WebSocket: send leave event ───────────────────────────────────────────
  static void sendLeave(StompClient client, int roomId) {
    if (client.connected) {
      client.send(destination: '/app/room/$roomId/leave');
    }
  }
}
