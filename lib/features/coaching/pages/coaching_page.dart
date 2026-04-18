import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../models/coaching_message.dart';
import '../models/daily_goal_model.dart';
import '../services/coaching_service.dart';

class CoachingPage extends StatefulWidget {
  const CoachingPage({super.key});

  @override
  State<CoachingPage> createState() => _CoachingPageState();
}

class _CoachingPageState extends State<CoachingPage> {
  // ── State ─────────────────────────────────────────────────────────────────
  List<DailyGoalModel> _goals = [];
  List<CoachingMessage> _messages = [];
  int? _sessionId;
  bool _loading = true;
  bool _sending = false;
  bool _settingGoals = false; // true = showing goal-setting UI

  // Goal setup state
  final List<TextEditingController> _goalControllers = [TextEditingController()];

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  // Evening banner
  bool get _showEveningBanner {
    final hour = DateTime.now().hour;
    return hour >= 20 && _goals.any((g) => g.status != 'DONE' && g.status != 'SKIPPED');
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  String get _todayKey {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  Future<void> _init() async {
    final token = await AuthService.getToken() ?? '';

    final prefs = await SharedPreferences.getInstance();
    _pruneStaleDays(prefs);

    final goals = await CoachingService.getTodayGoals(token);
    if (!mounted) return;

    if (goals.isNotEmpty) {
      // Always restore session from the backend — this survives logout/login
      // because the session is tied to the user account, not the local token.
      final session = await CoachingService.getTodaySession(token);
      if (!mounted) return;

      if (session != null && session.sessionId > 0) {
        final messages = session.messages ?? [];
        setState(() {
          _goals = goals;
          _sessionId = session.sessionId;
          _messages = messages;
          _settingGoals = false;
          _loading = false;
        });
        // Keep SharedPreferences in sync so re-entry is instant next time
        _persistMessages();
        if (messages.isNotEmpty) _scrollToBottom();
        return;
      }

      // Backend unreachable — fall back to SharedPreferences cache
      final savedSession = prefs.getInt('coaching_session_$_todayKey');
      final savedMessages = _loadSavedMessages(prefs);
      setState(() {
        _goals = goals;
        _sessionId = savedSession;
        _messages = savedMessages;
        _settingGoals = false;
        _loading = false;
      });
      if (savedMessages.isNotEmpty) _scrollToBottom();
      return;
    }

    // No goals yet — show goal-setup screen
    setState(() {
      _goals = goals;
      _settingGoals = true;
      _loading = false;
    });
  }

  void _pruneStaleDays(SharedPreferences prefs) {
    final today = DateTime.now();
    for (int i = 1; i <= 7; i++) {
      final past = today.subtract(Duration(days: i));
      final key = '${past.year}-${past.month}-${past.day}';
      prefs.remove('coaching_messages_$key');
      prefs.remove('coaching_session_$key');
    }
  }

  List<CoachingMessage> _loadSavedMessages(SharedPreferences prefs) {
    final raw = prefs.getString('coaching_messages_$_todayKey');
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) {
        final m = e as Map<String, dynamic>;
        return CoachingMessage(
          role: m['role'] as String,
          content: m['content'] as String,
          timestamp: DateTime.parse(m['timestamp'] as String),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _persistMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_messages.map((m) => {
          'role': m.role,
          'content': m.content,
          'timestamp': m.timestamp.toIso8601String(),
        }).toList());
    await prefs.setString('coaching_messages_$_todayKey', encoded);
    if (_sessionId != null) {
      await prefs.setInt('coaching_session_$_todayKey', _sessionId!);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    for (final c in _goalControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Goal setup flow ───────────────────────────────────────────────────────

  Future<void> _submitGoals() async {
    final texts = _goalControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    if (texts.isEmpty) return;

    setState(() => _sending = true);
    final token = await AuthService.getToken() ?? '';
    final response = await CoachingService.setDailyGoals(token, texts);
    if (!mounted) return;

    if (response != null) {
      setState(() {
        _goals = response.updatedGoals;
        _sessionId = response.sessionId;
        _messages = [
          CoachingMessage(
            role: 'ai',
            content: response.reply,
            timestamp: DateTime.now(),
          )
        ];
        _settingGoals = false;
        _sending = false;
      });
      _persistMessages();
      _scrollToBottom();
    } else {
      setState(() => _sending = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not connect. Please try again.')),
        );
      }
    }
  }

  void _addGoalField() {
    if (_goalControllers.length >= 3) return;
    setState(() => _goalControllers.add(TextEditingController()));
  }

  void _removeGoalField(int index) {
    if (_goalControllers.length <= 1) return;
    setState(() {
      _goalControllers[index].dispose();
      _goalControllers.removeAt(index);
    });
  }

  // ── Chat flow ─────────────────────────────────────────────────────────────

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sessionId == null) return;

    _messageController.clear();
    _focusNode.requestFocus();
    setState(() {
      _messages.add(CoachingMessage(
          role: 'user', content: text, timestamp: DateTime.now()));
      _sending = true;
    });
    _scrollToBottom();

    final token = await AuthService.getToken() ?? '';
    final response = await CoachingService.sendMessage(token, _sessionId!, text);
    if (!mounted) return;

    if (response != null) {
      setState(() {
        _goals = response.updatedGoals;
        _messages.add(CoachingMessage(
            role: 'ai',
            content: response.reply,
            timestamp: DateTime.now()));
        _sending = false;
      });
      _persistMessages();
    } else {
      // Remove the optimistically-added user message and show error
      setState(() {
        _messages.removeLast();
        _sending = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message failed to send. Please try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Restore the text so the user doesn't lose what they typed
        _messageController.text = text;
      }
    }
    _scrollToBottom();
  }

  Future<void> _startEvening() async {
    setState(() => _sending = true);
    final token = await AuthService.getToken() ?? '';
    final response = await CoachingService.startEvening(token);
    if (!mounted) return;

    if (response != null) {
      setState(() {
        _sessionId = response.sessionId;
        _goals = response.updatedGoals;
        _messages.add(CoachingMessage(
            role: 'ai',
            content: response.reply,
            timestamp: DateTime.now()));
        _sending = false;
      });
      _persistMessages();
      _scrollToBottom();
    } else {
      setState(() => _sending = false);
    }
  }

  // ── Add Reminder bottom sheet ─────────────────────────────────────────────

  Future<void> _showReminderSheet() async {
    TimeOfDay selectedTime = TimeOfDay(
      hour: (DateTime.now().hour + 1) % 24,
      minute: 0,
    );
    final titleController = TextEditingController();
    bool saving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
          return Padding(
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
                const Text(
                  'Add Reminder',
                  style: TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                // Time picker row
                const Text('Time',
                    style: TextStyle(
                        color: AppColors.onSurfaceVariant, fontSize: 13)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: ctx,
                      initialTime: selectedTime,
                      builder: (c, child) => Theme(
                        data: Theme.of(c).copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: AppColors.primary,
                            onSurface: AppColors.onSurface,
                            surface: AppColors.surfaceContainerHigh,
                          ),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) setSheet(() => selectedTime = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.4)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.access_time_rounded,
                          color: AppColors.primary, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        selectedTime.format(ctx),
                        style: const TextStyle(
                            color: AppColors.onSurface,
                            fontSize: 18,
                            fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      const Icon(Icons.edit_outlined,
                          color: AppColors.onSurfaceVariant, size: 16),
                    ]),
                  ),
                ),
                const SizedBox(height: 20),
                // Optional title
                const Text('Message (optional)',
                    style: TextStyle(
                        color: AppColors.onSurfaceVariant, fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: titleController,
                  style: const TextStyle(color: AppColors.onSurface),
                  maxLength: 80,
                  decoration: InputDecoration(
                    hintText: 'e.g. Time to work out!',
                    hintStyle:
                        const TextStyle(color: AppColors.onSurfaceVariant),
                    filled: true,
                    fillColor: AppColors.surfaceContainerHigh,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    counterStyle:
                        const TextStyle(color: AppColors.onSurfaceVariant),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: saving
                        ? null
                        : () async {
                            setSheet(() => saving = true);
                            final token =
                                await AuthService.getToken() ?? '';
                            final msg = titleController.text.trim();
                            final ok = await CoachingService.addReminder(
                              token,
                              'FocusPro Reminder',
                              msg.isEmpty ? 'Time to check your goals!' : msg,
                              selectedTime,
                            );
                            if (!mounted) return;
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(ok
                                    ? 'Reminder set for ${selectedTime.format(context)}'
                                    : 'Could not save reminder. Try again.'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryContainer,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('Set Reminder',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
    titleController.dispose();
  }

  // ── Goal status bottom sheet ──────────────────────────────────────────────

  void _showGoalStatusSheet(DailyGoalModel goal) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                goal.goalText,
                style: const TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...['PENDING', 'IN_PROGRESS', 'DONE', 'SKIPPED'].map((s) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(_statusIcon(s), color: _statusColor(s)),
                  title: Text(_statusLabel(s),
                      style: TextStyle(
                          color: goal.status == s
                              ? _statusColor(s)
                              : AppColors.onSurface,
                          fontWeight: goal.status == s
                              ? FontWeight.bold
                              : FontWeight.normal)),
                  onTap: () async {
                    Navigator.pop(context);
                    final token = await AuthService.getToken() ?? '';
                    final updated =
                        await CoachingService.updateGoalStatus(token, goal.id, s);
                    if (!mounted) return;
                    if (updated != null) {
                      setState(() {
                        final idx = _goals.indexWhere((g) => g.id == goal.id);
                        if (idx != -1) _goals[idx] = updated;
                      });
                    }
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.primaryContainer,
        foregroundColor: Colors.white,
        title: const Text('Daily Coach',
            style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          if (!_settingGoals && !_loading)
            IconButton(
              onPressed: _showReminderSheet,
              tooltip: 'Add Reminder',
              icon: const Icon(Icons.alarm_add_rounded, color: Colors.white),
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _settingGoals
              ? _buildGoalSetupScreen()
              : _buildChatScreen(),
    );
  }

  // ── Goal setup screen ─────────────────────────────────────────────────────

  Widget _buildGoalSetupScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Text(
            'Set your goals for today',
            style: TextStyle(
                color: AppColors.primary,
                fontSize: 26,
                fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            'Add 1–3 goals. Your coach will check in with you throughout the day.',
            style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 14),
          ),
          const SizedBox(height: 28),
          ...List.generate(_goalControllers.length, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _goalControllers[i],
                    style: const TextStyle(color: AppColors.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Goal ${i + 1}',
                      hintStyle:
                          const TextStyle(color: AppColors.onSurfaceVariant),
                      filled: true,
                      fillColor: AppColors.surfaceContainerHigh,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                if (_goalControllers.length > 1) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _removeGoalField(i),
                    icon: const Icon(Icons.remove_circle_outline,
                        color: AppColors.error),
                  ),
                ],
              ]),
            );
          }),
          if (_goalControllers.length < 3)
            TextButton.icon(
              onPressed: _addGoalField,
              icon: const Icon(Icons.add, color: AppColors.secondary),
              label: const Text('Add another goal',
                  style: TextStyle(color: AppColors.secondary)),
            ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _sending ? null : _submitGoals,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryContainer,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _sending
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Start my day',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Chat screen ───────────────────────────────────────────────────────────

  Widget _buildChatScreen() {
    return Column(
      children: [
        // Evening banner
        if (_showEveningBanner) _buildEveningBanner(),
        // Goals row
        _buildGoalsRow(),
        // Chat messages
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Text(
                    'Your coach is ready. Start chatting!',
                    style: TextStyle(color: AppColors.onSurfaceVariant),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: _messages.length + (_sending ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i == _messages.length) {
                      return _buildTypingIndicator();
                    }
                    return _buildMessageBubble(_messages[i]);
                  },
                ),
        ),
        // Input bar
        _buildInputBar(),
      ],
    );
  }

  Widget _buildEveningBanner() {
    return Container(
      color: AppColors.tertiaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        const Icon(Icons.nights_stay_outlined,
            color: AppColors.onTertiaryContainer, size: 20),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'Evening check-in ready',
            style: TextStyle(
                color: AppColors.onTertiaryContainer,
                fontWeight: FontWeight.w600),
          ),
        ),
        TextButton(
          onPressed: _sending ? null : _startEvening,
          child: const Text('Reflect',
              style: TextStyle(
                  color: AppColors.primaryFixed, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }

  Widget _buildGoalsRow() {
    if (_goals.isEmpty) return const SizedBox.shrink();
    return Container(
      height: 72,
      color: AppColors.surfaceContainerLow,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        itemCount: _goals.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => _buildGoalChip(_goals[i]),
      ),
    );
  }

  Widget _buildGoalChip(DailyGoalModel goal) {
    final color = _statusColor(goal.status);
    return GestureDetector(
      onTap: () => _showGoalStatusSheet(goal),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(_statusIcon(goal.status), color: color, size: 14),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              goal.goalText,
              style: TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildMessageBubble(CoachingMessage msg) {
    final isAi = msg.role == 'ai';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isAi ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (isAi) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primaryContainer,
              child: const Icon(Icons.smart_toy_outlined,
                  size: 16, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isAi
                    ? AppColors.primaryFixed.withValues(alpha: 0.3)
                    : AppColors.primaryContainer,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isAi ? 4 : 16),
                  bottomRight: Radius.circular(isAi ? 16 : 4),
                ),
              ),
              child: Text(
                msg.content,
                style: TextStyle(
                  color: isAi ? AppColors.onSurface : Colors.white,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (!isAi) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: AppColors.primaryContainer,
          child:
              const Icon(Icons.smart_toy_outlined, size: 16, color: Colors.white),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primaryFixed.withValues(alpha: 0.3),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(16),
            ),
          ),
          child: const SizedBox(
            width: 40,
            height: 16,
            child: _DotsIndicator(),
          ),
        ),
      ]),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, -2)),
        ],
      ),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _messageController,
            focusNode: _focusNode,
            style: const TextStyle(color: AppColors.onSurface),
            decoration: InputDecoration(
              hintText: 'Message your coach…',
              hintStyle: const TextStyle(color: AppColors.onSurfaceVariant),
              filled: true,
              fillColor: AppColors.surfaceContainerHigh,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onSubmitted: (_) => _sendMessage(),
            textInputAction: TextInputAction.send,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _sending ? null : _sendMessage,
          icon: Icon(
            Icons.send_rounded,
            color: _sending ? AppColors.onSurfaceVariant : AppColors.primary,
          ),
        ),
      ]),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Color _statusColor(String status) {
    switch (status) {
      case 'DONE':
        return AppColors.secondary;
      case 'IN_PROGRESS':
        return const Color(0xFFE6B800);
      case 'SKIPPED':
        return AppColors.onSurfaceVariant;
      default:
        return AppColors.outline;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'DONE':
        return Icons.check_circle_rounded;
      case 'IN_PROGRESS':
        return Icons.timelapse_rounded;
      case 'SKIPPED':
        return Icons.cancel_outlined;
      default:
        return Icons.radio_button_unchecked;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'DONE':
        return 'Done';
      case 'IN_PROGRESS':
        return 'In Progress';
      case 'SKIPPED':
        return 'Skipped';
      default:
        return 'Pending';
    }
  }
}

// ── Typing dots indicator ─────────────────────────────────────────────────
class _DotsIndicator extends StatefulWidget {
  const _DotsIndicator();

  @override
  State<_DotsIndicator> createState() => _DotsIndicatorState();
}

class _DotsIndicatorState extends State<_DotsIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final phase = ((_ctrl.value * 3) - i).clamp(0.0, 1.0);
            final opacity = (phase < 0.5 ? phase * 2 : (1 - phase) * 2).clamp(0.3, 1.0);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Opacity(
                opacity: opacity,
                child: const CircleAvatar(
                    radius: 4, backgroundColor: AppColors.primary),
              ),
            );
          }),
        );
      },
    );
  }
}
