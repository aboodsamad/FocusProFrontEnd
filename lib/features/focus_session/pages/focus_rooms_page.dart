import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../features/home/providers/user_provider.dart';
import '../models/focus_room.dart';
import '../services/focus_room_service.dart';
import 'focus_room_session_page.dart';
import 'smart_match_page.dart';

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
    setState(() {
      _loading = true;
      _error = null;
    });
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
    String selectedEmoji = '🌲';
    String selectedCategory = 'Study';
    int maxMembers = 0;
    bool isPrivate = false;

    const emojis = [
      '🌲', '📚', '🎨', '☕', '🧘', '💻', '🎧', '🌱',
      '🔥', '🌊', '⛰️', '💤', '⚡', '✨', '🌙', '⏳'
    ];
    const capacities = [
      {'label': '2', 'value': 2},
      {'label': '4', 'value': 4},
      {'label': '8', 'value': 8},
      {'label': '16', 'value': 16},
      {'label': '∞', 'value': 0},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
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
                left: 24,
                right: 24,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Create New Room',
                          style: TextStyle(
                            color: AppColors.onSurface,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLow,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded,
                              color: AppColors.onSurfaceVariant, size: 18),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Two-column top row: emoji grid + name/description ──────
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // LEFT: emoji grid
                        SizedBox(
                          width: 130,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sheetLabel('ICON'),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 148,
                                child: GridView.count(
                                  crossAxisCount: 4,
                                  crossAxisSpacing: 6,
                                  mainAxisSpacing: 6,
                                  physics: const NeverScrollableScrollPhysics(),
                                  children: emojis.take(16).map((e) {
                                    final sel = e == selectedEmoji;
                                    return GestureDetector(
                                      onTap: () =>
                                          setSheet(() => selectedEmoji = e),
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 150),
                                        decoration: BoxDecoration(
                                          color: sel
                                              ? AppColors.secondaryContainer
                                              : AppColors.surfaceContainerLow,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                            color: sel
                                                ? AppColors.secondary
                                                : AppColors.outlineVariant,
                                            width: sel ? 1.5 : 1.0,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(e,
                                              style: const TextStyle(
                                                  fontSize: 18)),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),

                        // RIGHT: room name + description
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sheetLabel('ROOM NAME'),
                              const SizedBox(height: 8),
                              _sheetField(nameCtl, 'e.g. Deep Work Session'),
                              const SizedBox(height: 14),
                              _sheetLabel('DESCRIPTION'),
                              const SizedBox(height: 8),
                              TextField(
                                controller: descCtl,
                                style: const TextStyle(
                                    color: AppColors.onSurface, fontSize: 13),
                                maxLines: 3,
                                decoration: InputDecoration(
                                  hintText:
                                      'What will people work on here?',
                                  hintStyle: TextStyle(
                                      color: AppColors.onSurfaceVariant
                                          .withOpacity(0.6),
                                      fontSize: 12),
                                  filled: true,
                                  fillColor: AppColors.surfaceContainerHigh,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Category ─────────────────────────────────────────────
                  _sheetLabel('CATEGORY'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: kCategories.map((cat) {
                      final name = cat['name'] as String;
                      final emoji = cat['emoji'] as String;
                      final sel = name == selectedCategory;
                      return GestureDetector(
                        onTap: () =>
                            setSheet(() => selectedCategory = name),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: sel
                                ? AppColors.primary
                                : AppColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: sel
                                  ? AppColors.primary
                                  : AppColors.outlineVariant,
                              width: sel ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(emoji,
                                  style: const TextStyle(fontSize: 14)),
                              const SizedBox(width: 6),
                              Text(name,
                                  style: TextStyle(
                                    color: sel
                                        ? AppColors.onPrimary
                                        : AppColors.onSurfaceVariant,
                                    fontSize: 13,
                                    fontWeight: sel
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  )),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // ── Capacity ─────────────────────────────────────────────
                  _sheetLabel('CAPACITY'),
                  const SizedBox(height: 12),
                  Row(
                    children: capacities.map((cap) {
                      final label = cap['label'] as String;
                      final value = cap['value'] as int;
                      final sel = maxMembers == value;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              setSheet(() => maxMembers = value),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.only(right: 6),
                            padding:
                                const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: sel
                                  ? AppColors.primary
                                  : AppColors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: sel
                                    ? AppColors.primary
                                    : AppColors.outlineVariant,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                label,
                                style: TextStyle(
                                  color: sel
                                      ? AppColors.onPrimary
                                      : AppColors.onSurfaceVariant,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // ── Privacy ──────────────────────────────────────────────
                  _sheetLabel('PRIVACY'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Public
                      Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              setSheet(() => isPrivate = false),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                vertical: 12),
                            decoration: BoxDecoration(
                              color: !isPrivate
                                  ? AppColors.primary
                                  : AppColors.surfaceContainerLow,
                              borderRadius: const BorderRadius.horizontal(
                                left: Radius.circular(12),
                              ),
                              border: Border.all(
                                color: !isPrivate
                                    ? AppColors.primary
                                    : AppColors.outlineVariant,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Icon(Icons.lock_open_rounded,
                                    color: !isPrivate
                                        ? AppColors.onPrimary
                                        : AppColors.onSurfaceVariant,
                                    size: 16),
                                const SizedBox(width: 6),
                                Text('Public',
                                    style: TextStyle(
                                      color: !isPrivate
                                          ? AppColors.onPrimary
                                          : AppColors.onSurfaceVariant,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    )),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Private
                      Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              setSheet(() => isPrivate = true),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                vertical: 12),
                            decoration: BoxDecoration(
                              color: isPrivate
                                  ? AppColors.primary
                                  : AppColors.surfaceContainerLow,
                              borderRadius: const BorderRadius.horizontal(
                                right: Radius.circular(12),
                              ),
                              border: Border.all(
                                color: isPrivate
                                    ? AppColors.primary
                                    : AppColors.outlineVariant,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Icon(Icons.lock_rounded,
                                    color: isPrivate
                                        ? AppColors.onPrimary
                                        : AppColors.onSurfaceVariant,
                                    size: 16),
                                const SizedBox(width: 6),
                                Text('Private',
                                    style: TextStyle(
                                      color: isPrivate
                                          ? AppColors.onPrimary
                                          : AppColors.onSurfaceVariant,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    )),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // ── Create button ─────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        shape: const StadiumBorder(),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        final name = nameCtl.text.trim();
                        if (name.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Please enter a room name')),
                          );
                          return;
                        }
                        Navigator.pop(ctx);
                        try {
                          final room =
                              await FocusRoomService.createRoom(
                            name: name,
                            emoji: selectedEmoji,
                            category: selectedCategory,
                            description:
                                descCtl.text.trim().isEmpty
                                    ? null
                                    : descCtl.text.trim(),
                            maxMembers: maxMembers,
                            isPrivate: isPrivate,
                          );
                          await _loadRooms();
                          if (mounted &&
                              room.isPrivate &&
                              room.inviteCode != null) {
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
                      child: const Text(
                        'Create Room →',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
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
        backgroundColor: AppColors.surfaceContainerLowest,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Text('🔒', style: TextStyle(fontSize: 24)),
          SizedBox(width: 10),
          Text(
            'Room Created!',
            style: TextStyle(
                color: AppColors.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold),
          ),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            'Share this invite code with people you want to join:',
            style: TextStyle(
                color: AppColors.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: room.inviteCode!));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Invite code copied!')),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(
                  room.inviteCode!,
                  style: const TextStyle(
                      color: AppColors.onPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 6),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.copy_rounded,
                    color: AppColors.onPrimary, size: 18),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          Text('Tap to copy',
              style: TextStyle(
                  color: AppColors.onSurfaceVariant.withOpacity(0.6),
                  fontSize: 11)),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it',
                style: TextStyle(color: AppColors.secondary)),
          ),
        ],
      ),
    );
  }

  Widget _sheetLabel(String text) => Text(
        text,
        style: const TextStyle(
          color: AppColors.onSurfaceVariant,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      );

  Widget _sheetField(TextEditingController ctl, String hint) => TextField(
        controller: ctl,
        style:
            const TextStyle(color: AppColors.onSurface, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
              color: AppColors.onSurfaceVariant.withOpacity(0.5),
              fontSize: 13),
          filled: true,
          fillColor: AppColors.surfaceContainerHigh,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(children: [
          _buildAppBar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadRooms,
              color: AppColors.secondary,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Page title
                          const Text(
                            'Focus Rooms',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Join a curated space designed for collective deep work and shared accountability.',
                            style: TextStyle(
                              color: AppColors.onSurfaceVariant,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Create room button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: AppColors.onPrimary,
                                shape: const StadiumBorder(),
                                elevation: 0,
                              ),
                              onPressed: _openCreateSheet,
                              icon: const Icon(Icons.add_rounded,
                                  size: 20),
                              label: const Text(
                                '+ Create Room',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),

                  // Filter chip row
                  SliverToBoxAdapter(child: _buildCategoryBar()),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),

                  // Body
                  _buildBodySliver(),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        RichText(
          text: const TextSpan(
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5),
            children: [
              TextSpan(text: 'Locked', style: TextStyle(color: AppColors.primary)),
              TextSpan(text: 'In', style: TextStyle(color: AppColors.secondary)),
            ],
          ),
        ),
        const Spacer(),
        // Smart Match
        GestureDetector(
          onTap: () async {
            final result = await Navigator.push<String>(
              context,
              MaterialPageRoute(builder: (_) => const SmartMatchPage()),
            );
            _loadRooms();
            if (result == 'create' && mounted) {
              _openCreateSheet();
            }
          },
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primary),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: const [
              Icon(Icons.auto_awesome_rounded,
                  color: AppColors.primary, size: 15),
              SizedBox(width: 4),
              Text(
                'Smart Match',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(width: 8),
        // Join with code
        GestureDetector(
          onTap: _openJoinByCodeSheet,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: const Icon(Icons.vpn_key_rounded,
                color: AppColors.secondary, size: 17),
          ),
        ),
        const SizedBox(width: 8),
        // Sort
        PopupMenuButton<String>(
          color: AppColors.surfaceContainerLowest,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          onSelected: (v) => setState(() => _sortBy = v),
          itemBuilder: (_) => [
            _sortItem('active', '🔥 Most Active'),
            _sortItem('az', '🔤 A–Z'),
            _sortItem('empty', '🌙 Emptiest First'),
          ],
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: const Icon(Icons.sort_rounded,
                color: AppColors.onSurfaceVariant, size: 18),
          ),
        ),
        const SizedBox(width: 8),
        // Settings
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: const Icon(Icons.settings_outlined,
              color: AppColors.onSurfaceVariant, size: 18),
        ),
      ]),
    );
  }

  PopupMenuItem<String> _sortItem(String value, String label) =>
      PopupMenuItem(
        value: value,
        child: Text(label,
            style: TextStyle(
                color: _sortBy == value
                    ? AppColors.secondary
                    : AppColors.onSurface,
                fontWeight: _sortBy == value
                    ? FontWeight.bold
                    : FontWeight.normal)),
      );

  Widget _buildCategoryBar() {
    final filters = [
      'All',
      ...kCategories.map((c) => c['name'] as String)
    ];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final name = filters[i];
          final sel = _selectedCategory == name;
          final isAll = name == 'All';
          final emoji = isAll ? null : categoryEmoji(name);
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = name),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: sel
                    ? AppColors.primary
                    : AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: sel
                      ? AppColors.primary
                      : AppColors.outlineVariant,
                  width: sel ? 1.5 : 1.0,
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (emoji != null) ...[
                  Text(emoji,
                      style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 5),
                ],
                Text(
                  name,
                  style: TextStyle(
                    color: sel
                        ? AppColors.onPrimary
                        : AppColors.onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: sel
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBodySliver() {
    if (_loading) {
      return const SliverFillRemaining(
        child: Center(
          child: CircularProgressIndicator(color: AppColors.secondary),
        ),
      );
    }
    if (_error != null) {
      return SliverFillRemaining(
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.wifi_off_rounded,
                color: AppColors.outlineVariant, size: 48),
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 13)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _loadRooms,
              child: const Text('Retry',
                  style: TextStyle(color: AppColors.secondary)),
            ),
          ]),
        ),
      );
    }

    final rooms = _filteredRooms;

    if (rooms.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('🏠', style: TextStyle(fontSize: 52)),
            const SizedBox(height: 16),
            Text(
              _selectedCategory == 'All'
                  ? 'No rooms yet'
                  : 'No $_selectedCategory rooms',
              style: const TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              _selectedCategory == 'All'
                  ? 'Be the first to create one!'
                  : 'Create the first $_selectedCategory room!',
              style: const TextStyle(
                  color: AppColors.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                shape: const StadiumBorder(),
                elevation: 0,
              ),
              onPressed: _openCreateSheet,
              child: const Text('Create Room'),
            ),
          ]),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (ctx, i) {
          if (i == rooms.length) {
            // "Feeling Adventurous?" card
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              child: _AdventureCard(onExplore: _loadRooms),
            );
          }
          final myUsername =
              ctx.read<UserProvider>().username ?? '';
          return Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: _RoomCard(
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
            ),
          );
        },
        childCount: rooms.length + 1,
      ),
    );
  }

  Future<void> _handlePrivateRoomJoin(
      FocusRoom room, String myUsername) async {
    if (room.createdBy == myUsername) {
      await _navigateToRoom(room);
      return;
    }

    final codeCtl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Text('🔒', style: TextStyle(fontSize: 22)),
          SizedBox(width: 10),
          Text('Private Room',
              style: TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 17,
                  fontWeight: FontWeight.bold)),
        ]),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Enter the invite code to join "${room.name}":',
                  style: const TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 13)),
              const SizedBox(height: 14),
              TextField(
                controller: codeCtl,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 18,
                    letterSpacing: 4,
                    fontWeight: FontWeight.bold),
                maxLength: 6,
                decoration: InputDecoration(
                  hintText: 'XXXXXX',
                  hintStyle: TextStyle(
                      color: AppColors.onSurfaceVariant
                          .withOpacity(0.4),
                      fontSize: 18,
                      letterSpacing: 4),
                  filled: true,
                  fillColor: AppColors.surfaceContainerHigh,
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
            child: const Text('Cancel',
                style:
                    TextStyle(color: AppColors.onSurfaceVariant)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              shape: const StadiumBorder(),
              elevation: 0,
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

  Future<void> _navigateToRoom(FocusRoom room,
      {String? inviteCode}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            FocusRoomSessionPage(room: room, inviteCode: inviteCode),
      ),
    );
  }

  // ── Join a private room by entering the code directly ─────────────────────
  void _openJoinByCodeSheet() {
    final codeCtl = TextEditingController();
    bool searching = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 22),

              Row(children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.secondaryContainer,
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: AppColors.secondary.withOpacity(0.4)),
                  ),
                  child: const Icon(Icons.lock_open_rounded,
                      color: AppColors.secondary, size: 18),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Join Private Room',
                        style: TextStyle(
                            color: AppColors.onSurface,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    Text('Enter the 6-character invite code',
                        style: TextStyle(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 12)),
                  ],
                ),
              ]),
              const SizedBox(height: 28),

              TextField(
                controller: codeCtl,
                textCapitalization: TextCapitalization.characters,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 26,
                    letterSpacing: 8,
                    fontWeight: FontWeight.bold),
                maxLength: 6,
                decoration: InputDecoration(
                  hintText: 'XXXXXX',
                  hintStyle: TextStyle(
                      color: AppColors.onSurfaceVariant.withOpacity(0.4),
                      fontSize: 26,
                      letterSpacing: 8),
                  filled: true,
                  fillColor: AppColors.surfaceContainerHigh,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                          color: AppColors.outlineVariant)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                          color: AppColors.secondary, width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 18),
                  counterText: '',
                ),
                onChanged: (_) => setSheet(() {}),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        codeCtl.text.trim().length == 6
                            ? AppColors.primary
                            : AppColors.surfaceContainerLow,
                    foregroundColor:
                        codeCtl.text.trim().length == 6
                            ? AppColors.onPrimary
                            : AppColors.onSurfaceVariant,
                    shape: const StadiumBorder(),
                    elevation: 0,
                  ),
                  onPressed:
                      codeCtl.text.trim().length == 6 && !searching
                          ? () async {
                              setSheet(() => searching = true);
                              try {
                                final code =
                                    codeCtl.text.trim().toUpperCase();
                                final room = await FocusRoomService
                                    .getRoomByCode(code);
                                if (!mounted) return;
                                Navigator.pop(ctx);
                                await _navigateToRoom(room,
                                    inviteCode: code);
                                _loadRooms();
                              } catch (e) {
                                setSheet(() => searching = false);
                                if (mounted) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(
                                    content: Text('$e'),
                                    backgroundColor: AppColors.error,
                                  ));
                                }
                              }
                            }
                          : null,
                  child: searching
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: AppColors.onPrimary,
                              strokeWidth: 2.5),
                        )
                      : const Text('Find & Join Room',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
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
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(Icons.delete_outline_rounded,
              color: AppColors.error, size: 22),
          const SizedBox(width: 10),
          const Text('Delete Room',
              style: TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
        ]),
        content: Text(
          'Are you sure you want to delete "${room.name}"? '
          'This will remove all messages and cannot be undone.',
          style: const TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 13,
              height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style:
                    TextStyle(color: AppColors.onSurfaceVariant)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.onError,
              shape: const StadiumBorder(),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
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
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Failed to delete: $e'),
              backgroundColor: AppColors.error));
        }
      }
    }
  }
}

// ── "Feeling Adventurous?" card ───────────────────────────────────────────────

class _AdventureCard extends StatelessWidget {
  final VoidCallback onExplore;
  const _AdventureCard({required this.onExplore});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.outlineVariant,
          width: 1.5,
          // Dashed border approximated via custom painter
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.secondaryContainer,
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Text('🧭', style: TextStyle(fontSize: 26)),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Feeling Adventurous?',
          style: TextStyle(
            color: AppColors.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Discover rooms from all categories\nand find your focus tribe.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.onSurfaceVariant,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: onExplore,
          child: const Text(
            'Explore More',
            style: TextStyle(
              color: AppColors.secondary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Room card ─────────────────────────────────────────────────────────────────

class _RoomCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final catColor = categoryColor(room.category);
    final count = room.memberCount;
    final full = room.isFull;

    return GestureDetector(
      onTap: full ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: full
                ? AppColors.outlineVariant.withOpacity(0.5)
                : AppColors.outlineVariant,
          ),
        ),
        child: Column(children: [
          // Top row: category badge | member count
          Row(children: [
            // Category badge
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: catColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(categoryEmoji(room.category),
                    style: const TextStyle(fontSize: 11)),
                const SizedBox(width: 4),
                Text(
                  room.category,
                  style: TextStyle(
                    color: catColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ]),
            ),
            if (room.isPrivate) ...[
              const SizedBox(width: 6),
              Icon(Icons.lock_rounded,
                  color: AppColors.onSurfaceVariant, size: 13),
            ],
            const Spacer(),
            // Member count
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '👥 $count${room.maxMembers > 0 ? '/${room.maxMembers}' : ''}',
                style: const TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (full) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.errorContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('FULL',
                    style: TextStyle(
                        color: AppColors.onErrorContainer,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ]),
          const SizedBox(height: 12),

          // Room name + emoji
          Row(children: [
            Text(room.emoji,
                style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                room.name,
                style: TextStyle(
                  color: full
                      ? AppColors.onSurfaceVariant
                      : AppColors.primary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),

          // Description
          if (room.description != null && room.description!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                room.description!,
                style: const TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 13,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],

          const SizedBox(height: 14),

          // Bottom row: overlapping avatars | Join button
          Row(children: [
            // Overlapping member avatars (show up to 3 + overflow)
            if (count > 0) ...[
              SizedBox(
                height: 28,
                width: _avatarRowWidth(count),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (int i = 0;
                        i < count.clamp(0, 3);
                        i++)
                      Positioned(
                        left: i * 18.0,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color:
                                _avatarColor(i),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppColors
                                    .surfaceContainerLowest,
                                width: 1.5),
                          ),
                          child: Center(
                            child: Text(
                              String.fromCharCode(65 + i),
                              style: const TextStyle(
                                  color: AppColors.onPrimary,
                                  fontSize: 11,
                                  fontWeight:
                                      FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                    if (count > 3)
                      Positioned(
                        left: 3 * 18.0,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerHigh,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppColors
                                    .surfaceContainerLowest,
                                width: 1.5),
                          ),
                          child: Center(
                            child: Text(
                              '+${count - 3}',
                              style: const TextStyle(
                                  color:
                                      AppColors.onSurfaceVariant,
                                  fontSize: 9,
                                  fontWeight:
                                      FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
            ],

            const Spacer(),

            // Delete button (creator only)
            if (onDelete != null) ...[
              GestureDetector(
                onTap: onDelete,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.errorContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete_outline_rounded,
                            color: AppColors.onErrorContainer,
                            size: 13),
                        const SizedBox(width: 3),
                        Text('Delete',
                            style: TextStyle(
                                color:
                                    AppColors.onErrorContainer,
                                fontSize: 11,
                                fontWeight:
                                    FontWeight.w600)),
                      ]),
                ),
              ),
              const SizedBox(width: 8),
            ],

            // Join pill button
            GestureDetector(
              onTap: full ? null : onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: full
                      ? AppColors.surfaceContainerLow
                      : AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  full ? 'Full' : 'Join',
                  style: TextStyle(
                    color: full
                        ? AppColors.onSurfaceVariant
                        : AppColors.onPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  double _avatarRowWidth(int count) {
    final visible = count.clamp(0, count > 3 ? 4 : count);
    return 28.0 + (visible - 1) * 18.0;
  }

  Color _avatarColor(int index) {
    const colors = [
      AppColors.primary,
      AppColors.secondary,
      AppColors.primaryContainer,
    ];
    return colors[index % colors.length];
  }
}
