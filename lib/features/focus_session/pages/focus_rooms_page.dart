import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../features/home/providers/user_provider.dart';
import '../models/focus_room.dart';
import '../services/focus_room_service.dart';
import 'focus_room_session_page.dart';

class FocusRoomsPage extends StatefulWidget {
  const FocusRoomsPage({Key? key}) : super(key: key);

  @override
  State<FocusRoomsPage> createState() => _FocusRoomsPageState();
}

class _FocusRoomsPageState extends State<FocusRoomsPage> {
  List<FocusRoom> _rooms = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rooms = await FocusRoomService.getRooms();
      if (mounted) setState(() => _rooms = rooms);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openCreateSheet() {
    final nameCtl = TextEditingController();
    String selectedEmoji = '🎯';
    const emojis = ['🎯', '🔥', '📚', '💡', '🧠', '⚡', '🌙', '🎵'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F1624),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Create a Room',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              // Emoji picker
              const Text('Pick an emoji',
                  style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                children: emojis.map((e) {
                  final selected = e == selectedEmoji;
                  return GestureDetector(
                    onTap: () => setSheet(() => selectedEmoji = e),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primaryA.withOpacity(0.2)
                            : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? AppColors.primaryA
                              : Colors.transparent,
                        ),
                      ),
                      child: Text(e, style: const TextStyle(fontSize: 22)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Room name field
              const Text('Room name',
                  style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: nameCtl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'e.g. Deep Work Session',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 24),

              // Create button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ).copyWith(
                    backgroundColor: WidgetStateProperty.all(Colors.transparent),
                    overlayColor: WidgetStateProperty.all(
                        AppColors.primaryA.withOpacity(0.1)),
                  ),
                  onPressed: () async {
                    final name = nameCtl.text.trim();
                    if (name.isEmpty) return;
                    Navigator.pop(ctx);
                    try {
                      await FocusRoomService.createRoom(name, selectedEmoji);
                      await _loadRooms();
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    }
                  },
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primaryA, AppColors.primaryB],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Text(
                          'Create Room',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080D1A),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white70, size: 16),
            ),
          ),
          const SizedBox(width: 14),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Focus Rooms',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              Text('Study with others in real time',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
          const Spacer(),
          // Refresh
          GestureDetector(
            onTap: _loadRooms,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: const Icon(Icons.refresh_rounded,
                  color: Colors.white70, size: 18),
            ),
          ),
          const SizedBox(width: 8),
          // Create room
          GestureDetector(
            onTap: _openCreateSheet,
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [AppColors.primaryA, AppColors.primaryB]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.add_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 4),
                  Text('New',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryA),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, color: Colors.grey[700], size: 48),
            const SizedBox(height: 12),
            Text(_error!,
                style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _loadRooms,
              child: const Text('Retry',
                  style: TextStyle(color: AppColors.primaryA)),
            ),
          ],
        ),
      );
    }
    if (_rooms.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🏠', style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            const Text('No rooms yet',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Be the first to create one!',
                style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _openCreateSheet,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryA,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: const Text('Create Room'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRooms,
      color: AppColors.primaryA,
      backgroundColor: const Color(0xFF0F1624),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        itemCount: _rooms.length,
        itemBuilder: (_, i) => _RoomCard(
          room: _rooms[i],
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FocusRoomSessionPage(room: _rooms[i]),
              ),
            );
            // Reload member counts when we come back
            _loadRooms();
          },
        ),
      ),
    );
  }
}

// ── Room card widget ───────────────────────────────────────────────────────

class _RoomCard extends StatefulWidget {
  final FocusRoom room;
  final VoidCallback onTap;
  const _RoomCard({required this.room, required this.onTap});

  @override
  State<_RoomCard> createState() => _RoomCardState();
}

class _RoomCardState extends State<_RoomCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final count = widget.room.memberCount;
    final active = count > 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF0F1624),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _hovered
                    ? AppColors.primaryA.withOpacity(0.45)
                    : Colors.white.withOpacity(0.07),
                width: _hovered ? 1.5 : 1.0,
              ),
              boxShadow: _hovered
                  ? [
                      BoxShadow(
                          color: AppColors.primaryA.withOpacity(0.12),
                          blurRadius: 20,
                          spreadRadius: 2)
                    ]
                  : [],
            ),
            child: Row(
              children: [
                // Emoji badge
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.primaryA.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(widget.room.emoji,
                        style: const TextStyle(fontSize: 26)),
                  ),
                ),
                const SizedBox(width: 14),

                // Room info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.room.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: active
                                  ? const Color(0xFF10B981)
                                  : Colors.grey[700],
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            active
                                ? '$count ${count == 1 ? 'person' : 'people'} focusing'
                                : 'Empty — be the first!',
                            style: TextStyle(
                                color: active
                                    ? const Color(0xFF10B981)
                                    : Colors.grey[600],
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Arrow
                Icon(Icons.arrow_forward_ios_rounded,
                    color:
                        _hovered ? AppColors.primaryA : Colors.grey[700],
                    size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
