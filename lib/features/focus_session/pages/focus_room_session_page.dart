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
  final String? inviteCode; // pre-filled for private rooms joined from rooms list
  const FocusRoomSessionPage({Key? key, required this.room, this.inviteCode})
      : super(key: key);

  @override
  State<FocusRoomSessionPage> createState() => _FocusRoomSessionPageState();
}

class _FocusRoomSessionPageState extends State<FocusRoomSessionPage> {
  // ── presence state ────────────────────────────────────────────────────────
  List<RoomMember> _members = [];
  bool _loading = true;
  String? _error;
  String? _myGoal;
  String? _myInviteCode;   // invite code passed in from rooms list
  String? _roomInviteCode; // invite code returned by the join response (has real value)
  Timer? _pollTimer;
  Timer? _ticker;
  final Stopwatch _stopwatch = Stopwatch();
  String _elapsed = '00:00';
  bool _joined = false;

  // ── chat state ────────────────────────────────────────────────────────────
  List<RoomMessage> _messages = [];
  final Set<int> _messageIds = {}; // deduplication guard
  Timer? _chatPollTimer;
  String? _lastMessageTimestamp;
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final FocusNode _chatFocusNode = FocusNode();
  bool _sendingMessage = false;
  int _unreadCount = 0;

  // ── tab state ─────────────────────────────────────────────────────────────
  bool _showChat = true; // true = Chat tab shown by default

  @override
  void initState() {
    super.initState();
    _stopwatch.start();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        final d = _stopwatch.elapsed;
        setState(() {
          _elapsed =
              '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
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
    if (_joined) {
      FocusRoomService.leaveRoomRest(widget.room.id);
    }
    super.dispose();
  }

  Future<void> _askGoal() async {
    final goalCtl = TextEditingController();
    final goal = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0F1624),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Text(widget.room.emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(widget.room.name,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
          ),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('What are you working on?',
                style: TextStyle(color: Colors.grey[400], fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: goalCtl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g. Finishing chapter 3 (optional)',
                hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                filled: true,
                fillColor: Colors.white.withOpacity(0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: Text('Skip', style: TextStyle(color: Colors.grey[500])),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryA,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, goalCtl.text.trim()),
            child: const Text('Join Room'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (goal == null) {
      Navigator.pop(context);
      return;
    }

    _myGoal = goal.isEmpty ? null : goal;
    // Use invite code passed from rooms list (or from creator seeing their own code)
    _myInviteCode = widget.inviteCode;
    _joinAndPoll();
  }

  Future<void> _joinAndPoll() async {
    try {
      final room = await FocusRoomService.joinRoomRest(
          widget.room.id, _myGoal, inviteCode: _myInviteCode);
      _joined = true;
      if (mounted) {
        setState(() {
          _members = room.members;
          _loading = false;
          // Store invite code from join response so the creator can share it
          _roomInviteCode = room.inviteCode;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
      return;
    }

    // Load initial messages
    try {
      final msgs =
          await FocusRoomService.fetchMessages(widget.room.id, null);
      if (mounted && msgs.isNotEmpty) {
        setState(() {
          _messages = msgs;
          _messageIds.addAll(msgs.map((m) => m.id));
          _lastMessageTimestamp = msgs.last.sentAt;
        });
        _scrollToBottom();
      }
    } catch (_) {}

    // Poll member list every 4 seconds
    _pollTimer =
        Timer.periodic(const Duration(seconds: 4), (_) async {
      try {
        final room = await FocusRoomService.getRoom(widget.room.id);
        if (mounted) setState(() => _members = room.members);
      } catch (_) {}
    });

    // Poll for new chat messages every 2.5 seconds
    _chatPollTimer =
        Timer.periodic(const Duration(milliseconds: 2500), (_) async {
      try {
        final newMsgs = await FocusRoomService.fetchMessages(
            widget.room.id, _lastMessageTimestamp);
        // Deduplicate: only keep messages whose ID we haven't seen yet.
        // This prevents a race where the poll fetches a message that
        // _sendMessage() already appended from the POST response.
        final unique =
            newMsgs.where((m) => !_messageIds.contains(m.id)).toList();
        if (unique.isNotEmpty && mounted) {
          setState(() {
            _messageIds.addAll(unique.map((m) => m.id));
            _messages.addAll(unique);
            _lastMessageTimestamp = unique.last.sentAt;
            // Count unread only when the chat tab is not active
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
    // Keep keyboard / text field focused so the user can type again
    // immediately after hitting Enter, without tapping the field again.
    _chatFocusNode.requestFocus();

    try {
      final msg =
          await FocusRoomService.sendMessage(widget.room.id, content);
      if (mounted) {
        // Only add if the poll timer hasn't already inserted this message.
        if (!_messageIds.contains(msg.id)) {
          setState(() {
            _messageIds.add(msg.id);
            _messages.add(msg);
            _lastMessageTimestamp = msg.sentAt;
          });
          _scrollToBottom();
        }
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _sendingMessage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUsername = context.read<UserProvider>().username ?? '';
    return Scaffold(
      backgroundColor: const Color(0xFF080D1A),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            if (!_loading && _error == null) ...[
              const SizedBox(height: 12),
              _buildTabBar(),
            ],
            if (_loading)
              const Expanded(
                  child: Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primaryA)))
            else if (_error != null)
              Expanded(
                  child: Center(
                      child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Error: $_error',
                    style: const TextStyle(color: Colors.red)),
              )))
            else
              // IndexedStack keeps both views alive so chat polling
              // and scroll position are preserved when switching tabs
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

  // ── Tab bar ───────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          _buildTab(
            label: 'Members',
            icon: Icons.people_outline_rounded,
            active: !_showChat,
            onTap: () => setState(() => _showChat = false),
            badge: 0,
          ),
          _buildTab(
            label: 'Chat',
            icon: Icons.chat_bubble_outline_rounded,
            active: _showChat,
            onTap: () {
              setState(() {
                _showChat = true;
                _unreadCount = 0;
              });
              // Wait one frame for IndexedStack to surface the ListView
              // before scrolling, so hasClients is guaranteed true.
              WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
            },
            badge: _unreadCount,
          ),
        ]),
      ),
    );
  }

  Widget _buildTab({
    required String label,
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
    required int badge,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            gradient: active
                ? const LinearGradient(
                    colors: [AppColors.primaryA, AppColors.primaryB])
                : null,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 15,
                  color: active ? Colors.white : Colors.grey[500]),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      color: active ? Colors.white : Colors.grey[500],
                      fontSize: 13,
                      fontWeight: active
                          ? FontWeight.bold
                          : FontWeight.normal)),
              if (badge > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('$badge',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final myUsername = context.read<UserProvider>().username ?? '';
    final isCreator = widget.room.createdBy == myUsername;
    // Use the code from the join response (includes real value even when
    // navigated from list view where inviteCode is null for privacy)
    final code = _roomInviteCode ?? widget.room.inviteCode;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white70, size: 16),
          ),
        ),
        const SizedBox(width: 12),
        Text(widget.room.emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(widget.room.name,
              style: const TextStyle(color: Colors.white,
                  fontSize: 17, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis),
        ),
        // Share invite code button (creator of private rooms only)
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
                color: AppColors.primaryA.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primaryA.withOpacity(0.3)),
              ),
              child: const Row(children: [
                Icon(Icons.lock_rounded, color: AppColors.primaryA, size: 13),
                SizedBox(width: 4),
                Text('Share Code',
                    style: TextStyle(color: AppColors.primaryA,
                        fontSize: 11, fontWeight: FontWeight.bold)),
              ]),
            ),
          ),
        ],
        // Timer
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primaryA.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primaryA.withOpacity(0.3)),
          ),
          child: Row(children: [
            const Icon(Icons.timer_outlined, color: AppColors.primaryA, size: 14),
            const SizedBox(width: 4),
            Text(_elapsed, style: const TextStyle(
                color: AppColors.primaryA,
                fontWeight: FontWeight.bold, fontSize: 13)),
          ]),
        ),
      ]),
    );
  }

  // ── Members tab ───────────────────────────────────────────────────────────

  Widget _buildMembersSection(String myUsername) {
    final catColor = categoryColor(widget.room.category);
    final maxM = widget.room.maxMembers;
    final capacityText = maxM > 0
        ? '${_members.length} / $maxM'
        : '${_members.length} / ∞';

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              catColor.withOpacity(0.20),
              AppColors.primaryA.withOpacity(0.10),
            ]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: catColor.withOpacity(0.30)),
          ),
          child: Row(children: [
            Container(
              width: 10, height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF10B981),
                boxShadow: [BoxShadow(
                    color: const Color(0xFF10B981).withOpacity(0.5),
                    blurRadius: 6)],
              ),
            ),
            const SizedBox(width: 10),
            // Category badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: catColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(categoryEmoji(widget.room.category),
                    style: const TextStyle(fontSize: 11)),
                const SizedBox(width: 4),
                Text(widget.room.category,
                    style: TextStyle(color: catColor,
                        fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${_members.length} ${_members.length == 1 ? 'person' : 'people'} focusing',
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ),
            // Capacity pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(capacityText,
                  style: TextStyle(color: Colors.grey[400],
                      fontSize: 11, fontWeight: FontWeight.w500)),
            ),
          ]),
        ),
      ),
      Expanded(
        child: _members.isEmpty
            ? Center(
                child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🧑‍💻',
                      style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  const Text("You're the only one here",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Others will appear when they join',
                      style: TextStyle(
                          color: Colors.grey[600], fontSize: 12)),
                ],
              ))
            : GridView.builder(
                padding: const EdgeInsets.all(20),
                physics: const BouncingScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.05,
                ),
                itemCount: _members.length,
                itemBuilder: (_, i) => _MemberCard(
                    member: _members[i],
                    isMe: _members[i].username == myUsername),
              ),
      ),
    ]);
  }

  // ── Chat tab ──────────────────────────────────────────────────────────────

  Widget _buildChatSection(String myUsername) {
    return Column(children: [
      // Message list
      Expanded(
        child: _messages.isEmpty
            ? Center(
                child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('💬',
                      style: TextStyle(fontSize: 40)),
                  const SizedBox(height: 12),
                  const Text('No messages yet',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Be the first to say hi!',
                      style: TextStyle(
                          color: Colors.grey[600], fontSize: 12)),
                ],
              ))
            : ListView.builder(
                controller: _chatScrollController,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                itemCount: _messages.length,
                itemBuilder: (_, i) => _ChatBubble(
                    message: _messages[i],
                    isMe: _messages[i].username == myUsername),
              ),
      ),
      // Input row
      Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        decoration: BoxDecoration(
          color: const Color(0xFF0A1020),
          border: Border(
            top: BorderSide(
                color: Colors.white.withOpacity(0.08)),
          ),
        ),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _chatController,
              focusNode: _chatFocusNode,
              style: const TextStyle(
                  color: Colors.white, fontSize: 14),
              maxLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              decoration: InputDecoration(
                hintText: 'Message the room...',
                hintStyle: TextStyle(
                    color: Colors.grey[600], fontSize: 14),
                filled: true,
                fillColor: Colors.white.withOpacity(0.06),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryA,
                    AppColors.primaryB
                  ],
                ),
              ),
              child: _sendingMessage
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 18),
            ),
          ),
        ]),
      ),
    ]);
  }
}

// ── Member card ───────────────────────────────────────────────────────────────

class _MemberCard extends StatelessWidget {
  final RoomMember member;
  final bool isMe;
  const _MemberCard({required this.member, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final initial = (member.displayName.isNotEmpty
            ? member.displayName[0]
            : member.username[0])
        .toUpperCase();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1624),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMe
              ? AppColors.primaryA.withOpacity(0.45)
              : Colors.white.withOpacity(0.07),
          width: isMe ? 1.5 : 1.0,
        ),
      ),
      child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: isMe
                        ? [AppColors.primaryA, AppColors.primaryB]
                        : [
                            const Color(0xFF1E2A40),
                            const Color(0xFF2A3A55)
                          ],
                  ),
                ),
                child: Center(
                    child: Text(initial,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold))),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF10B981),
                    border: Border.all(
                        color: const Color(0xFF0F1624), width: 2),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            Text(isMe ? 'You' : member.displayName,
                style: TextStyle(
                    color:
                        isMe ? AppColors.primaryA : Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            if (member.goal != null &&
                member.goal!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(member.goal!,
                  style: TextStyle(
                      color: Colors.grey[500], fontSize: 10),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center),
            ],
          ]),
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
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 13,
              backgroundColor: const Color(0xFF1E2A40),
              child: Text(
                message.username.isNotEmpty
                    ? message.username[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 3),
                    child: Text(message.username,
                        style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 11,
                            fontWeight: FontWeight.w500)),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: isMe
                        ? const LinearGradient(colors: [
                            AppColors.primaryA,
                            AppColors.primaryB,
                          ])
                        : null,
                    color: isMe ? null : const Color(0xFF161E30),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                  ),
                  child: Text(message.content,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14)),
                ),
                Padding(
                  padding:
                      const EdgeInsets.only(top: 3, left: 4, right: 4),
                  child: Text(_formatTime(message.sentAt),
                      style: TextStyle(
                          color: Colors.grey[600], fontSize: 10)),
                ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }
}
