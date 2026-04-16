import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../features/home/providers/user_provider.dart';
import '../models/focus_room.dart';
import '../services/focus_room_service.dart';

class FocusRoomSessionPage extends StatefulWidget {
  final FocusRoom room;
  final String? inviteCode;
  const FocusRoomSessionPage({Key? key, required this.room, this.inviteCode}) : super(key: key);

  @override
  State<FocusRoomSessionPage> createState() => _FocusRoomSessionPageState();
}

class _FocusRoomSessionPageState extends State<FocusRoomSessionPage> {
  // ── presence state ────────────────────────────────────────────────────────
  List<RoomMember> _members = [];
  bool _loading = true;
  String? _error;
  String? _myGoal;
  String? _myInviteCode;
  String? _roomInviteCode;
  Timer? _pollTimer;
  Timer? _ticker;
  final Stopwatch _stopwatch = Stopwatch();
  String _elapsed = '00:00';
  bool _joined = false;

  // ── chat state ────────────────────────────────────────────────────────────
  List<RoomMessage> _messages = [];
  final Set<int> _messageIds = {};
  Timer? _chatPollTimer;
  String? _lastMessageTimestamp;
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final FocusNode _chatFocusNode = FocusNode();
  bool _sendingMessage = false;
  int _unreadCount = 0;

  // ── tab state ─────────────────────────────────────────────────────────────
  bool _showChat = true;

  @override
  void initState() {
    super.initState();
    _stopwatch.start();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        final d = _stopwatch.elapsed;
        setState(() {
          _elapsed = '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
        });
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _askGoal());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pollTimer?.cancel();
    _chatPollTimer?.cancel();
    _stopwatch.stop();
    _chatController.dispose();
    _chatScrollController.dispose();
    _chatFocusNode.dispose();
    if (_joined) FocusRoomService.leaveRoomRest(widget.room.id);
    super.dispose();
  }

  Future<void> _askGoal() async {
    final goalCtl = TextEditingController();
    final goal = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Text(widget.room.emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.room.name,
              style: const TextStyle(color: AppColors.onSurface, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Manrope'),
            ),
          ),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('What are you working on?', style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: goalCtl,
              style: const TextStyle(color: AppColors.onSurface),
              decoration: InputDecoration(
                hintText: 'e.g. Finishing chapter 3 (optional)',
                hintStyle: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13),
                filled: true,
                fillColor: AppColors.surfaceContainerHigh,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('Skip', style: TextStyle(color: AppColors.onSurfaceVariant)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, goalCtl.text.trim()),
            child: const Text('Join Room', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (goal == null) { Navigator.pop(context); return; }
    _myGoal = goal.isEmpty ? null : goal;
    _myInviteCode = widget.inviteCode;
    _joinAndPoll();
  }

  Future<void> _joinAndPoll() async {
    try {
      final room = await FocusRoomService.joinRoomRest(widget.room.id, _myGoal, inviteCode: _myInviteCode);
      _joined = true;
      if (mounted) {
        setState(() {
          _members = room.members;
          _loading = false;
          _roomInviteCode = room.inviteCode;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
      return;
    }

    try {
      final msgs = await FocusRoomService.fetchMessages(widget.room.id, null);
      if (mounted && msgs.isNotEmpty) {
        setState(() {
          _messages = msgs;
          _messageIds.addAll(msgs.map((m) => m.id));
          _lastMessageTimestamp = msgs.last.sentAt;
        });
        _scrollToBottom();
      }
    } catch (_) {}

    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      try {
        final room = await FocusRoomService.getRoom(widget.room.id);
        if (mounted) setState(() => _members = room.members);
      } catch (_) {}
    });

    _chatPollTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) async {
      try {
        final newMsgs = await FocusRoomService.fetchMessages(widget.room.id, _lastMessageTimestamp);
        final unique = newMsgs.where((m) => !_messageIds.contains(m.id)).toList();
        if (unique.isNotEmpty && mounted) {
          setState(() {
            _messageIds.addAll(unique.map((m) => m.id));
            _messages.addAll(unique);
            _lastMessageTimestamp = unique.last.sentAt;
            if (!_showChat) _unreadCount += unique.length;
          });
          if (_showChat) _scrollToBottom();
        }
      } catch (_) {}
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final content = _chatController.text.trim();
    if (content.isEmpty || _sendingMessage) return;
    setState(() => _sendingMessage = true);
    _chatController.clear();
    _chatFocusNode.requestFocus();
    try {
      final msg = await FocusRoomService.sendMessage(widget.room.id, content);
      if (mounted && !_messageIds.contains(msg.id)) {
        setState(() {
          _messageIds.add(msg.id);
          _messages.add(msg);
          _lastMessageTimestamp = msg.sentAt;
        });
        _scrollToBottom();
      }
    } catch (_) {} finally {
      if (mounted) {
        setState(() => _sendingMessage = false);
        _chatFocusNode.requestFocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUsername = context.read<UserProvider>().username ?? '';
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            if (!_loading && _error == null) _buildBottomNavTabs(),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
            else if (_error != null)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Error: $_error', style: const TextStyle(color: AppColors.error)),
                  ),
                ),
              )
            else
              Expanded(
                child: IndexedStack(
                  index: _showChat ? 1 : 0,
                  children: [
                    _buildMembersSection(myUsername),
                    _buildChatSection(myUsername),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final myUsername = context.read<UserProvider>().username ?? '';
    final isCreator = widget.room.createdBy == myUsername;
    final code = _roomInviteCode ?? widget.room.inviteCode;

    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Text(widget.room.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.room.name,
              style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold, fontFamily: 'Manrope'),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Invite code share
          if (widget.room.isPrivate && isCreator && code != null) ...[
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Row(children: [
                    const Icon(Icons.lock_rounded, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Text('Invite code copied: $code'),
                  ]),
                  duration: const Duration(seconds: 3),
                ));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(children: [
                  Icon(Icons.lock_rounded, color: Colors.white, size: 13),
                  SizedBox(width: 4),
                  Text('Share', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ]),
              ),
            ),
          ],
          // Delete room
          if (isCreator) ...[
            GestureDetector(
              onTap: () => _confirmDeleteRoom(context),
              child: Container(
                width: 36,
                height: 36,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.delete_outline_rounded, color: Colors.white70, size: 16),
              ),
            ),
          ],
          // Live Session badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primaryContainer.withOpacity(0.6)),
            ),
            child: const Text('Live Session', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteRoom(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 22),
          SizedBox(width: 10),
          Text('Delete Room', style: TextStyle(color: AppColors.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
        ]),
        content: Text(
          'Are you sure you want to delete "${widget.room.name}"? This will remove all messages and cannot be undone.',
          style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.onSurfaceVariant)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await FocusRoomService.deleteRoom(widget.room.id);
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  // ── Bottom nav tabs (Chat / Members) ───────────────────────────────────────
  Widget _buildBottomNavTabs() {
    return Container(
      color: AppColors.surfaceContainerLowest,
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            _TabButton(
              icon: Icons.chat_bubble_rounded,
              label: 'Chat',
              active: _showChat,
              badge: _showChat ? 0 : _unreadCount,
              onTap: () {
                setState(() { _showChat = true; _unreadCount = 0; });
                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
              },
            ),
            _TabButton(
              icon: Icons.group_rounded,
              label: 'Members',
              active: !_showChat,
              badge: 0,
              onTap: () => setState(() => _showChat = false),
            ),
          ],
        ),
      ),
    );
  }

  // ── Members tab ───────────────────────────────────────────────────────────
  Widget _buildMembersSection(String myUsername) {
    return Column(
      children: [
        // Timer card
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Text(
                  'CURRENT FOCUS',
                  style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2),
                ),
                const SizedBox(height: 8),
                Text(
                  _elapsed,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 52,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Manrope',
                    letterSpacing: -2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_members.length} active minds in flow state',
                  style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
        // Members header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Focus Group', style: TextStyle(color: AppColors.primary, fontSize: 20, fontWeight: FontWeight.w800, fontFamily: 'Manrope')),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(color: AppColors.secondaryContainer, borderRadius: BorderRadius.circular(20)),
                child: Text('${_members.length} Online', style: const TextStyle(color: AppColors.onSecondaryContainer, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        // Members list
        Expanded(
          child: _members.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🧑‍💻', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 12),
                      const Text("You're the only one here", style: TextStyle(color: AppColors.onSurface, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      const Text('Others will appear when they join', style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  physics: const BouncingScrollPhysics(),
                  itemCount: _members.length,
                  itemBuilder: (_, i) => _MemberRow(
                    member: _members[i],
                    isMe: _members[i].username == myUsername,
                  ),
                ),
        ),
      ],
    );
  }

  // ── Chat tab ──────────────────────────────────────────────────────────────
  Widget _buildChatSection(String myUsername) {
    return Column(
      children: [
        // Session timestamp
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Session Started',
              style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.5),
            ),
          ),
        ),
        // Messages
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('💬', style: TextStyle(fontSize: 40)),
                      const SizedBox(height: 12),
                      const Text('No messages yet', style: TextStyle(color: AppColors.onSurface, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      const Text('Be the first to say hi!', style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12)),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _chatScrollController,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  itemCount: _messages.length,
                  itemBuilder: (_, i) => _ChatBubble(message: _messages[i], isMe: _messages[i].username == myUsername),
                ),
        ),
        // Input
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: AppColors.outlineVariant.withOpacity(0.3)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20)],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    focusNode: _chatFocusNode,
                    style: const TextStyle(color: AppColors.onSurface, fontSize: 14),
                    maxLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: const InputDecoration(
                      hintText: 'Message the room...',
                      hintStyle: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primaryContainer),
                      child: _sendingMessage
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Tab button ────────────────────────────────────────────────────────────────

class _TabButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final int badge;
  final VoidCallback onTap;
  const _TabButton({required this.icon, required this.label, required this.active, required this.badge, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: active
              ? const BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.all(Radius.circular(0)),
                )
              : null,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: active ? Colors.white : AppColors.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: active ? Colors.white : AppColors.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              if (badge > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(10)),
                  child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Member row ────────────────────────────────────────────────────────────────

class _MemberRow extends StatelessWidget {
  final RoomMember member;
  final bool isMe;
  const _MemberRow({required this.member, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final initial = (member.displayName.isNotEmpty ? member.displayName[0] : member.username[0]).toUpperCase();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: isMe ? const Border(left: BorderSide(color: AppColors.secondary, width: 4)) : null,
      ),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: AppColors.primaryContainer,
                ),
                child: Center(
                  child: Text(initial, style: const TextStyle(color: AppColors.onPrimaryContainer, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.secondary,
                    border: Border.all(color: AppColors.surfaceContainerLowest, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isMe ? member.displayName : member.displayName,
                      style: const TextStyle(color: AppColors.onSurface, fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Manrope'),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('You', style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                if (member.goal != null && member.goal!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(member.goal!, style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          const Icon(Icons.more_vert_rounded, color: AppColors.outlineVariant, size: 18),
        ],
      ),
    );
  }
}

// ── Chat bubble ───────────────────────────────────────────────────────────────

class _ChatBubble extends StatelessWidget {
  final RoomMessage message;
  final bool isMe;
  const _ChatBubble({required this.message, required this.isMe});

  String _formatTime(String isoTimestamp) {
    try {
      final dt = DateTime.parse(isoTimestamp).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'PM' : 'AM'}';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 4),
              child: Text(
                message.username,
                style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ],
          Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (isMe) const SizedBox.shrink(),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isMe ? AppColors.primaryContainer : const Color(0xFF2E3132),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isMe ? 18 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 18),
                    ),
                  ),
                  child: Text(
                    message.content,
                    style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.45),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(top: 4, left: isMe ? 0 : 12, right: isMe ? 12 : 0),
            child: Text(
              _formatTime(message.sentAt),
              style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}
