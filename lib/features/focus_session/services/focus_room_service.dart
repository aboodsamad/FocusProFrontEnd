import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:stomp_dart_client/stomp_dart_client.dart';
import '../../../core/services/auth_service.dart';
import '../models/focus_room.dart';

class FocusRoomService {
  static String get _base => AuthService.baseUrl;
  static String get _wsUrl => _base.replaceFirst('http://', 'ws://').replaceFirst('https://', 'wss://') + '/ws';

  // ── HTTP: get all rooms ───────────────────────────────────────────────────
  static Future<List<FocusRoom>> getRooms() async {
    final token = await AuthService.getToken();
    print('TOKEN: $token');
    final resp = await http
        .get(Uri.parse('$_base/rooms'), headers: {'Authorization': 'Bearer $token'})
        .timeout(const Duration(seconds: 8));

    if (resp.statusCode == 200) {
      final List<dynamic> list = jsonDecode(resp.body);
      return list.map((j) => FocusRoom.fromJson(j as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to load rooms (${resp.statusCode})');
  }

  // ── HTTP: get a single room with members ─────────────────────────────────
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

  // ── HTTP: create a room ───────────────────────────────────────────────────
  static Future<FocusRoom> createRoom(String name, String emoji) async {
    final token = await AuthService.getToken();
    final resp = await http
        .post(
          Uri.parse('$_base/rooms'),
          headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
          body: jsonEncode({'name': name, 'emoji': emoji}),
        )
        .timeout(const Duration(seconds: 8));

    if (resp.statusCode == 200 || resp.statusCode == 201) {
      return FocusRoom.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to create room (${resp.statusCode})');
  }

  // ── WebSocket: connect and return the StompClient ────────────────────────
  // The caller (FocusRoomSessionPage) owns the client and must call
  // client.deactivate() in its dispose() method.
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
        // Pass the JWT in STOMP connect headers — the server reads this via Principal
        stompConnectHeaders: {'Authorization': 'Bearer $token'},
        webSocketConnectHeaders: {'Authorization': 'Bearer $token'},
        onConnect: (frame) {
          // Step 1: subscribe to the room's topic to receive events
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

          // Step 2: tell the server we joined
          client.send(destination: '/app/room/$roomId/join', body: jsonEncode({'goal': goal ?? ''}));
        },
        onDisconnect: (_) {},
        onStompError: (frame) => onError(frame.body ?? 'STOMP error'),
        onWebSocketError: (error) => onError('WebSocket error: $error'),
        onDebugMessage: (_) {}, // silence debug logs in prod
      ),
    );

    client.activate();
    return client;
  }

  // ── WebSocket: send a leave event ────────────────────────────────────────
  static void sendLeave(StompClient client, int roomId) {
    if (client.connected) {
      client.send(destination: '/app/room/$roomId/leave');
    }
  }

  static Future<FocusRoom> joinRoomRest(int roomId, String? goal) async {
    final token = await AuthService.getToken();
    final resp = await http
        .post(
          Uri.parse('$_base/rooms/$roomId/join'),
          headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
          body: jsonEncode({'goal': goal ?? ''}),
        )
        .timeout(const Duration(seconds: 8));
    if (resp.statusCode == 200) {
      return FocusRoom.fromJson(jsonDecode(resp.body));
    }
    throw Exception('Join failed (${resp.statusCode})');
  }

  static Future<void> leaveRoomRest(int roomId) async {
    final token = await AuthService.getToken();
    try {
      await http
          .post(Uri.parse('$_base/rooms/$roomId/leave'), headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }
}
