import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../features/home/providers/user_provider.dart';
import '../models/focus_room.dart';
import '../services/focus_room_service.dart';
import 'focus_room_session_page.dart';

// ── Page ──────────────────────────────────────────────────────────────────────

class FocusRoomsPage extends StatefulWidget {
  const FocusRoomsPage({Key? key}) : super(key: key);

  @override
  State<FocusRoomsPage> createState() => _FocusRoomsPageState();
}

class _FocusRoomsPageState extends State<FocusRoomsPage> {
  List<FocusRoom> _allRooms = [];
  bool _loading = true;
  String? _error;
  String _selectedCategory = 'All';
  String _sortBy = 'active'; // 'active' | 'az' | 'empty'

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    setState(() { _loading = true; _error = null; });
    try {
      final rooms = await FocusRoomService.getRooms();
      if (mounted) setState(() => _allRooms = rooms);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<FocusRoom> get _filteredRooms {
    var rooms = _allRooms.where((r) {
      if (_selectedCategory == 'All') return true;
      return r.category.toLowerCase() == _selectedCategory.toLowerCase();
    }).toList();

    switch (_sortBy) {
      case 'az':
        rooms.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'empty':
        rooms.sort((a, b) => a.memberCount.compareTo(b.memberCount));
        break;
      case 'active':
      default:
        rooms.sort((a, b) => b.memberCount.compareTo(a.memberCount));
        break;
    }
    return rooms;
  }

  void _openCreateSheet() {
    final nameCtl = TextEditingController();
    final descCtl = TextEditingController();
    String selectedEmoji = '🎯';
    String selectedCategory = 'Study';
    int maxMembers = 0;
    bool isPrivate = false;

    const emojis = ['🎯', '🔥', '📚', '💡', '🧠', '⚡', '🌙', '🎵',
                    '💼', '🎨', '💪', '🧘', '🎮', '🔬', '🌐', '✨'];
    const capacities = [
      {'label': '2',  'value': 2},
      {'label': '4',  'value': 4},
      {'label': '8',  'value': 8},
      {'label': '16', 'value': 16},
      {'label': '∞',  'value': 0},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0C1120),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) {
          return DraggableScrollableSheet(
            initialChildSize: 0.92,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (_, scrollCtl) => SingleChildScrollView(
              controller: scrollCtl,
              padding: EdgeInsets.only(
                left: 24, right: 24, top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2)),
                  )),
                  const SizedBox(height: 20),

                  // Title
                  Row(children: [
                    Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [AppColors.primaryA, AppColors.primaryB]),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text('Create a Room',
                        style: TextStyle(color: Colors.white,
                            fontSize: 20, fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 28),

                  // ── Emoji picker ──────────────────────────────────────────
                  _sheetLabel('Room Emoji'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: emojis.map((e) {
                      final sel = e == selectedEmoji;
                      return GestureDetector(
                        onTap: () => setSheet(() => selectedEmoji = e),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                            color: sel
                                ? AppColors.primaryA.withOpacity(0.18)
                                : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: sel ? AppColors.primaryA : Colors.white12),
                          ),
                          child: Center(child: Text(e,
                              style: const TextStyle(fontSize: 22))),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // ── Room name ─────────────────────────────────────────────
                  _sheetLabel('Room Name'),
                  const SizedBox(height: 8),
                  _sheetField(nameCtl, 'e.g. Deep Work Session'),
                  const SizedBox(height: 20),

                  // ── Description ───────────────────────────────────────────
                  _sheetLabel('Description (optional)'),
                  const SizedBox(height: 8),
                  _sheetField(descCtl, 'What will people work on here?'),
                  const SizedBox(height: 24),

                  // ── Category picker ───────────────────────────────────────
                  _sheetLabel('Category'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: kCategories.map((cat) {
                      final name = cat['name'] as String;
                      final emoji = cat['emoji'] as String;
                      final color = cat['color'] as Color;
                      final sel = name == selectedCategory;
                      return GestureDetector(
                        onTap: () => setSheet(() => selectedCategory = name),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: sel
                                ? color.withOpacity(0.18)
                                : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: sel ? color : Colors.white12,
                              width: sel ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(emoji, style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 6),
                            Text(name,
                                style: TextStyle(
                                    color: sel ? color : Colors.grey[400],
                                    fontSize: 13,
                                    fontWeight: sel
                                        ? FontWeight.bold
                                        : FontWeight.normal)),
                          ]),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // ── Capacity picker ───────────────────────────────────────
                  _sheetLabel('Max Members'),
                  const SizedBox(height: 12),
                  Row(
                    children: capacities.map((cap) {
                      final label = cap['label'] as String;
                      final value = cap['value'] as int;
                      final sel = maxMembers == value;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setSheet(() => maxMembers = value),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              gradient: sel
                                  ? const LinearGradient(colors: [
                                      AppColors.primaryA, AppColors.primaryB])
                                  : null,
                              color: sel ? null : Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: sel
                                    ? Colors.transparent
                                    : Colors.white12),
                            ),
                            child: Center(
                              child: Text(label,
                                  style: TextStyle(
                                      color: sel
                                          ? Colors.white
                                          : Colors.grey[400],
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // ── Private toggle ────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isPrivate
                          ? AppColors.primaryA.withOpacity(0.1)
                          : Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isPrivate
                            ? AppColors.primaryA.withOpacity(0.3)
                            : Colors.white12,
                      ),
                    ),
                    child: Row(children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: isPrivate
                              ? AppColors.primaryA.withOpacity(0.2)
                              : Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isPrivate ? Icons.lock_rounded : Icons.lock_open_rounded,
                          color: isPrivate ? AppColors.primaryA : Colors.grey[500],
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(isPrivate ? 'Private Room' : 'Public Room',
                              style: TextStyle(
                                color: isPrivate ? Colors.white : Colors.grey[300],
                                fontWeight: FontWeight.bold, fontSize: 14)),
                          Text(
                            isPrivate
                                ? 'An invite code will be generated'
                                : 'Anyone can find and join',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 11)),
                        ],
                      )),
                      Switch(
                        value: isPrivate,
                        onChanged: (v) => setSheet(() => isPrivate = v),
                        activeColor: AppColors.primaryA,
                        inactiveTrackColor: Colors.white12,
                      ),
                    ]),
                  ),
                  const SizedBox(height: 32),

                  // ── Create button ─────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: GestureDetector(
                      onTap: () async {
                        final name = nameCtl.text.trim();
                        if (name.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Please enter a room name')),
                          );
                          return;
                        }
                        Navigator.pop(ctx);
                        try {
                          final room = await FocusRoomService.createRoom(
                            name: name,
                            emoji: selectedEmoji,
                            category: selectedCategory,
                            description: descCtl.text.trim().isEmpty
                                ? null : descCtl.text.trim(),
                            maxMembers: maxMembers,
                            isPrivate: isPrivate,
                          );
                          await _loadRooms();
                          if (mounted && room.isPrivate && room.inviteCode != null) {
                            _showInviteCodeDialog(room);
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        }
                      },
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [AppColors.primaryA, AppColors.primaryB]),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Text('Create Room',
                              style: TextStyle(color: Colors.white,
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showInviteCodeDialog(FocusRoom room) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0F1624),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Text('🔒', style: TextStyle(fontSize: 24)),
          SizedBox(width: 10),
          Text('Room Created!',
              style: TextStyle(color: Colors.white,
                  fontSize: 18, fontWeight: FontWeight.bold)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Share this invite code with people you want to join:',
              style: TextStyle(color: Colors.grey[400], fontSize: 13)),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: room.inviteCode!));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Invite code copied!')),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [AppColors.primaryA, AppColors.primaryB]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(room.inviteCode!,
                    style: const TextStyle(color: Colors.white,
                        fontSize: 28, fontWeight: FontWeight.bold,
                        letterSpacing: 6)),
                const SizedBox(width: 10),
                const Icon(Icons.copy_rounded, color: Colors.white70, size: 18),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          Text('Tap to copy', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it', style: TextStyle(color: AppColors.primaryA)),
          ),
        ],
      ),
    );
  }

  Widget _sheetLabel(String text) => Text(text,
      style: TextStyle(color: Colors.grey[400], fontSize: 13,
          fontWeight: FontWeight.w500));

  Widget _sheetField(TextEditingController ctl, String hint) => TextField(
    controller: ctl,
    style: const TextStyle(color: Colors.white, fontSize: 14),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
      filled: true,
      fillColor: Colors.white.withOpacity(0.06),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080D1A),
      body: SafeArea(
        child: Column(children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildCategoryBar(),
          const SizedBox(height: 4),
          Expanded(child: _buildBody()),
        ]),
      ),
    );
  }

  Widget _buildHeader() {
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
        const SizedBox(width: 14),
        const Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Focus Rooms',
                style: TextStyle(color: Colors.white, fontSize: 20,
                    fontWeight: FontWeight.bold)),
            Text('Study with others in real time',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
          ]),
        ),
        // Sort menu
        PopupMenuButton<String>(
          color: const Color(0xFF0F1624),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          onSelected: (v) => setState(() => _sortBy = v),
          itemBuilder: (_) => [
            _sortItem('active', '🔥 Most Active'),
            _sortItem('az',     '🔤 A–Z'),
            _sortItem('empty',  '🌙 Emptiest First'),
          ],
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: const Icon(Icons.sort_rounded, color: Colors.white70, size: 18),
          ),
        ),
        const SizedBox(width: 8),
        // Join with code
        GestureDetector(
          onTap: _openJoinByCodeSheet,
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFEC4899).withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFEC4899).withOpacity(0.30)),
            ),
            child: const Icon(Icons.vpn_key_rounded,
                color: Color(0xFFEC4899), size: 17),
          ),
        ),
        const SizedBox(width: 8),
        // Refresh
        GestureDetector(
          onTap: _loadRooms,
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 18),
          ),
        ),
        const SizedBox(width: 8),
        // Create
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
            child: const Row(children: [
              Icon(Icons.add_rounded, color: Colors.white, size: 18),
              SizedBox(width: 4),
              Text('New', style: TextStyle(color: Colors.white,
                  fontWeight: FontWeight.bold, fontSize: 13)),
            ]),
          ),
        ),
      ]),
    );
  }

  PopupMenuItem<String> _sortItem(String value, String label) =>
      PopupMenuItem(
        value: value,
        child: Text(label,
            style: TextStyle(
                color: _sortBy == value ? AppColors.primaryA : Colors.white70,
                fontWeight: _sortBy == value
                    ? FontWeight.bold : FontWeight.normal)),
      );

  Widget _buildCategoryBar() {
    final filters = ['All', ...kCategories.map((c) => c['name'] as String)];
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final name = filters[i];
          final isAll = name == 'All';
          final sel = _selectedCategory == name;
          final color = isAll ? AppColors.primaryA : categoryColor(name);
          final emoji = isAll ? null : categoryEmoji(name);
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = name),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: sel ? color.withOpacity(0.18) : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: sel ? color : Colors.white.withOpacity(0.08),
                  width: sel ? 1.5 : 1.0,
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (emoji != null) ...[
                  Text(emoji, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 5),
                ],
                Text(name,
                    style: TextStyle(
                        color: sel ? color : Colors.grey[500],
                        fontSize: 13,
                        fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryA));
    }
    if (_error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.wifi_off_rounded, color: Colors.grey[700], size: 48),
        const SizedBox(height: 12),
        Text(_error!, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        const SizedBox(height: 16),
        TextButton(onPressed: _loadRooms,
            child: const Text('Retry',
                style: TextStyle(color: AppColors.primaryA))),
      ]));
    }

    final rooms = _filteredRooms;

    if (rooms.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('🏠', style: TextStyle(fontSize: 52)),
        const SizedBox(height: 16),
        Text(
          _selectedCategory == 'All' ? 'No rooms yet' : 'No $_selectedCategory rooms',
          style: const TextStyle(color: Colors.white, fontSize: 18,
              fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(
          _selectedCategory == 'All'
              ? 'Be the first to create one!'
              : 'Create the first $_selectedCategory room!',
          style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: _openCreateSheet,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [AppColors.primaryA, AppColors.primaryB]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text('Create Room',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ]));
    }

    return RefreshIndicator(
      onRefresh: _loadRooms,
      color: AppColors.primaryA,
      backgroundColor: const Color(0xFF0F1624),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        itemCount: rooms.length,
        itemBuilder: (_, i) {
          final myUsername = context.read<UserProvider>().username ?? '';
          return _RoomCard(
            room: rooms[i],
            myUsername: myUsername,
            onTap: () async {
              if (rooms[i].isPrivate) {
                await _handlePrivateRoomJoin(rooms[i], myUsername);
              } else {
                await _navigateToRoom(rooms[i]);
              }
              _loadRooms();
            },
            onDelete: rooms[i].createdBy == myUsername
                ? () => _deleteRoom(rooms[i])
                : null,
          );
        },
      ),
    );
  }

  Future<void> _handlePrivateRoomJoin(FocusRoom room, String myUsername) async {
    // Creator can enter directly (they know the code)
    if (room.createdBy == myUsername) {
      await _navigateToRoom(room);
      return;
    }

    final codeCtl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0F1624),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Text('🔒', style: TextStyle(fontSize: 22)),
          SizedBox(width: 10),
          Text('Private Room',
              style: TextStyle(color: Colors.white, fontSize: 17,
                  fontWeight: FontWeight.bold)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Enter the invite code to join "${room.name}":',
              style: TextStyle(color: Colors.grey[400], fontSize: 13)),
          const SizedBox(height: 14),
          TextField(
            controller: codeCtl,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(color: Colors.white, fontSize: 18,
                letterSpacing: 4, fontWeight: FontWeight.bold),
            maxLength: 6,
            decoration: InputDecoration(
              hintText: 'XXXXXX',
              hintStyle: TextStyle(color: Colors.grey[700], fontSize: 18,
                  letterSpacing: 4),
              filled: true,
              fillColor: Colors.white.withOpacity(0.06),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              counterText: '',
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[500])),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryA,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Join'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _navigateToRoom(room,
          inviteCode: codeCtl.text.trim().toUpperCase());
    }
  }

  Future<void> _navigateToRoom(FocusRoom room, {String? inviteCode}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FocusRoomSessionPage(
            room: room, inviteCode: inviteCode),
      ),
    );
  }

  // ── Join a private room by entering the code directly ─────────────────────
  void _openJoinByCodeSheet() {
    final codeCtl = TextEditingController();
    bool _searching = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0C1120),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
              )),
              const SizedBox(height: 22),

              // Title
              Row(children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEC4899).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFEC4899).withOpacity(0.4)),
                  ),
                  child: const Icon(Icons.lock_open_rounded,
                      color: Color(0xFFEC4899), size: 18),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Join Private Room',
                        style: TextStyle(color: Colors.white, fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    Text('Enter the 6-character invite code',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ]),
              const SizedBox(height: 28),

              // Code field
              TextField(
                controller: codeCtl,
                textCapitalization: TextCapitalization.characters,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    letterSpacing: 8,
                    fontWeight: FontWeight.bold),
                maxLength: 6,
                decoration: InputDecoration(
                  hintText: 'XXXXXX',
                  hintStyle: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 26,
                      letterSpacing: 8),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                          color: const Color(0xFFEC4899).withOpacity(0.25))),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                          color: Color(0xFFEC4899), width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 18),
                  counterText: '',
                ),
                onChanged: (_) => setSheet(() {}),
              ),
              const SizedBox(height: 24),

              // Join button
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: codeCtl.text.trim().length == 6 && !_searching
                      ? () async {
                          setSheet(() => _searching = true);
                          try {
                            final code = codeCtl.text.trim().toUpperCase();
                            final room = await FocusRoomService.getRoomByCode(code);
                            if (!mounted) return;
                            Navigator.pop(ctx);
                            await _navigateToRoom(room, inviteCode: code);
                            _loadRooms();
                          } catch (e) {
                            setSheet(() => _searching = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('$e'),
                                  backgroundColor: const Color(0xFFEF4444),
                                ),
                              );
                            }
                          }
                        }
                      : null,
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: codeCtl.text.trim().length == 6
                          ? const LinearGradient(
                              colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)])
                          : null,
                      color: codeCtl.text.trim().length != 6
                          ? Colors.white.withOpacity(0.06)
                          : null,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: _searching
                          ? const SizedBox(width: 22, height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5))
                          : Text(
                              'Find & Join Room',
                              style: TextStyle(
                                color: codeCtl.text.trim().length == 6
                                    ? Colors.white
                                    : Colors.grey[600],
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
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

  // ── Delete a room (creator only) ──────────────────────────────────────────
  Future<void> _deleteRoom(FocusRoom room) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0F1624),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 22),
          SizedBox(width: 10),
          Text('Delete Room',
              style: TextStyle(color: Colors.white, fontSize: 18,
                  fontWeight: FontWeight.bold)),
        ]),
        content: Text(
          'Are you sure you want to delete "${room.name}"? '
          'This will remove all messages and cannot be undone.',
          style: TextStyle(color: Colors.grey[400], fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[500])),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await FocusRoomService.deleteRoom(room.id);
        _loadRooms();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e'),
                backgroundColor: const Color(0xFFEF4444)),
          );
        }
      }
    }
  }
}

// ── Room card ─────────────────────────────────────────────────────────────────

class _RoomCard extends StatefulWidget {
  final FocusRoom room;
  final String myUsername;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  const _RoomCard({
    required this.room,
    required this.myUsername,
    required this.onTap,
    this.onDelete,
  });

  @override
  State<_RoomCard> createState() => _RoomCardState();
}

class _RoomCardState extends State<_RoomCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final catColor = categoryColor(room.category);
    final count = room.memberCount;
    final active = count > 0;
    final full = room.isFull;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: full ? null : widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: const Color(0xFF0F1624),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: full
                    ? Colors.white.withOpacity(0.04)
                    : _hovered
                        ? catColor.withOpacity(0.5)
                        : Colors.white.withOpacity(0.07),
                width: _hovered ? 1.5 : 1.0,
              ),
              boxShadow: _hovered && !full
                  ? [BoxShadow(
                      color: catColor.withOpacity(0.15),
                      blurRadius: 24, spreadRadius: 1)]
                  : [],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Column(children: [
                // Category accent bar
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: full
                          ? [Colors.grey[800]!, Colors.grey[700]!]
                          : [catColor, catColor.withOpacity(0.4)]),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // Emoji badge
                      Container(
                        width: 54, height: 54,
                        decoration: BoxDecoration(
                          color: catColor.withOpacity(full ? 0.06 : 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(child: Text(room.emoji,
                            style: TextStyle(fontSize: 26,
                                color: full ? null : null))),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Row(children: [
                          Expanded(
                            child: Text(room.name,
                                style: TextStyle(
                                    color: full ? Colors.grey[500] : Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                          if (room.isPrivate)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Icon(Icons.lock_rounded,
                                  color: Colors.grey[600], size: 14),
                            ),
                          if (full)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('FULL',
                                  style: TextStyle(color: Colors.redAccent,
                                      fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                        ]),
                        const SizedBox(height: 4),
                        // Category chip
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: catColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(categoryEmoji(room.category),
                                style: const TextStyle(fontSize: 10)),
                            const SizedBox(width: 4),
                            Text(room.category,
                                style: TextStyle(
                                    color: catColor, fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ]),
                        ),
                        if (room.description != null &&
                            room.description!.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(room.description!,
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ])),
                    ]),
                    const SizedBox(height: 12),
                    // Bottom row: member count + capacity + delete
                    Row(children: [
                      Container(
                        width: 7, height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: full
                              ? Colors.redAccent
                              : active
                                  ? const Color(0xFF10B981)
                                  : Colors.grey[700],
                          boxShadow: active && !full
                              ? [const BoxShadow(
                                  color: Color(0xFF10B981), blurRadius: 4)]
                              : [],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        full
                            ? 'Room is full'
                            : active
                                ? '$count ${count == 1 ? 'person' : 'people'} focusing'
                                : 'Empty — be the first!',
                        style: TextStyle(
                            color: full
                                ? Colors.redAccent
                                : active
                                    ? const Color(0xFF10B981)
                                    : Colors.grey[600],
                            fontSize: 12),
                      ),
                      const Spacer(),
                      if (widget.onDelete != null) ...[
                        GestureDetector(
                          onTap: widget.onDelete,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withOpacity(0.10),
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(
                                  color: const Color(0xFFEF4444).withOpacity(0.25)),
                            ),
                            child: const Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.delete_outline_rounded,
                                  color: Color(0xFFEF4444), size: 13),
                              SizedBox(width: 3),
                              Text('Delete',
                                  style: TextStyle(
                                      color: Color(0xFFEF4444),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)),
                            ]),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (room.maxMembers > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${room.memberCount} / ${room.maxMembers}',
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 11,
                                fontWeight: FontWeight.w500),
                          ),
                        )
                      else
                        Icon(Icons.arrow_forward_ios_rounded,
                            color: _hovered && !full
                                ? catColor : Colors.grey[700],
                            size: 14),
                    ]),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
