import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../services/user_service.dart';
import '../widgets/focus_circle.dart';
import '../widgets/component_bar.dart';
import '../widgets/action_card.dart';
import '../widgets/score_breakdown_sheet.dart';
import '../../question/pages/question_page.dart';
import '../../games/sudoku/pages/sudoku_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  String _name = 'User';
  double _focusScore = 0.0;
  Map<String, double> _components = {'T': 0, 'G': 0, 'S': 0, 'H': 0};
  int _distractingMinutes = 0;
  List<Map<String, dynamic>> _habits = [];
  List<Map<String, dynamic>> _recentGames = [];
  String _recommendation = '';

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
      lowerBound: 0.0,
      upperBound: 0.06,
    )..repeat(reverse: true);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final token = await AuthService.getToken();
    if (token != null) {
      await UserService.fetchAndSaveProfile(token);
    }

    final storedProfile = await UserService.getStoredProfile();
    if (storedProfile != null) {
      _name       = storedProfile['name'] ?? 'User';
      _focusScore = (storedProfile['focusScore'] ?? 0.0).toDouble();
    }

    final data = await _fetchHomeData();
    setState(() {
      if (_name == 'User') _name = data['name'] ?? _name;
      if (_focusScore == 0.0) {
        _focusScore = (data['focusScore'] as num).toDouble();
      }
      _components         = Map<String, double>.from(data['components']);
      _distractingMinutes = data['distractingMinutesToday'] ?? 0;
      _habits             = List<Map<String, dynamic>>.from(data['habitList']);
      _recentGames        = List<Map<String, dynamic>>.from(data['recentGames']);
      _recommendation     = data['recommendation'] ?? '';
      _loading            = false;
    });
  }

  // Mock data — will be replaced with a real API call later
  Future<Map<String, dynamic>> _fetchHomeData() async {
    await Future.delayed(const Duration(milliseconds: 300));
    final focusScore = await UserService.getStoredFocusScore() ?? 0.0;
    final name       = await UserService.getStoredName() ?? 'Abd';
    return {
      'name':       name,
      'focusScore': focusScore,
      'components': {'T': 70.0, 'G': 60.0, 'S': 70.0, 'H': 80.0},
      'distractingMinutesToday': 42,
      'habitList': [
        {'id': 'h1', 'title': 'Morning 10-min reading',  'done': true,  'streak': 3},
        {'id': 'h2', 'title': 'Daily reaction game',     'done': false, 'streak': 1},
        {'id': 'h3', 'title': 'No social before 9AM',    'done': false, 'streak': 7},
      ],
      'recentGames': [
        {'game': 'Reaction', 'score': 78, 'time': '10m'},
        {'game': 'N-back',   'score': 62, 'time': '6m'},
      ],
      'recommendation':
          'Do 2 reaction tasks + 10m TTS for 3 days to boost score by ~5 pts.',
    };
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // ── Navigation helpers ─────────────────────────────────────────────────────

  void _openTest() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Open Test (TODO)')),
    );
  }

  void _openGames() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SudokuApp()),
    );
  }

  void _openReader() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Open Reader (TODO)')),
    );
  }

  // ── Habit actions ──────────────────────────────────────────────────────────

  void _toggleHabitDone(int index) {
    setState(() {
      _habits[index]['done'] = !_habits[index]['done'];
      if (_habits[index]['done']) {
        _habits[index]['streak'] = (_habits[index]['streak'] ?? 0) + 1;
      } else {
        _habits[index]['streak'] = 0;
      }
    });
  }

  void _manualUsageEntry() {
    showDialog<int>(
      context: context,
      builder: (context) {
        final ctl = TextEditingController();
        return AlertDialog(
          title: const Text('Manual usage minutes'),
          content: TextField(
            controller: ctl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'Enter minutes spent on distracting apps',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final val = int.tryParse(ctl.text) ?? 0;
                Navigator.pop(context, val);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    ).then((minutes) {
      if (minutes != null) {
        setState(() => _distractingMinutes = minutes);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved $minutes minutes')),
        );
      }
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softBg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 86,
        title: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.primaryA, AppColors.primaryB],
                ),
              ),
              child: CircleAvatar(
                radius: 26,
                backgroundColor: Colors.transparent,
                child: Text(
                  _name.isNotEmpty ? _name[0].toUpperCase() : 'U',
                  style: const TextStyle(color: Colors.white, fontSize: 20),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Good day,', style: TextStyle(color: Colors.grey[700], fontSize: 14)),
                  Text(
                    _name,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Settings',
              icon: Icon(Icons.settings_outlined, color: Colors.grey[700]),
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Open Settings (TODO)')),
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [

                  // ── Focus Score Card ───────────────────────────────────
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 6,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          FocusCircle(
                            score:           _focusScore,
                            pulseController: _pulseController,
                            primaryA:        AppColors.primaryA,
                            primaryB:        AppColors.primaryB,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Weekly FocusScore',
                                    style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                                const SizedBox(height: 8),
                                Text('Your explainable attention metric',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    ComponentBar(label: 'Test',   value: _components['T'] ?? 0, primaryA: AppColors.primaryA, primaryB: AppColors.primaryB),
                                    const SizedBox(width: 8),
                                    ComponentBar(label: 'Games',  value: _components['G'] ?? 0, primaryA: AppColors.primaryA, primaryB: AppColors.primaryB),
                                    const SizedBox(width: 8),
                                    ComponentBar(label: 'Screen', value: _components['S'] ?? 0, primaryA: AppColors.primaryA, primaryB: AppColors.primaryB),
                                    const SizedBox(width: 8),
                                    ComponentBar(label: 'Habits', value: _components['H'] ?? 0, primaryA: AppColors.primaryA, primaryB: AppColors.primaryB),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.analytics_outlined),
                                      label: const Text('Details'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primaryA,
                                      ),
                                      onPressed: () => showModalBottomSheet(
                                        context: context,
                                        builder: (_) => ScoreBreakdownSheet(
                                          components: _components,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    OutlinedButton(
                                      onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const QuestionPage(),
                                        ),
                                      ),
                                      child: const Text('Quick Test'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Quick Actions ──────────────────────────────────────
                  Row(
                    children: [
                      Expanded(child: ActionCard(icon: Icons.assessment_outlined,     title: 'Start Test', subtitle: '5-8 min',  onTap: _openTest,   primaryB: AppColors.primaryB)),
                      const SizedBox(width: 10),
                      Expanded(child: ActionCard(icon: Icons.videogame_asset_outlined, title: 'Play Game', subtitle: '2-6 min',  onTap: _openGames,  primaryB: AppColors.primaryB)),
                      const SizedBox(width: 10),
                      Expanded(child: ActionCard(icon: Icons.menu_book_outlined,       title: 'Reader',    subtitle: 'TTS/Text', onTap: _openReader, primaryB: AppColors.primaryB)),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ── Habits + Usage ─────────────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Habits', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                ..._habits.asMap().entries.map((e) {
                                  final idx = e.key;
                                  final h   = e.value;
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Checkbox(
                                      value: h['done'] as bool,
                                      onChanged: (_) => _toggleHabitDone(idx),
                                      activeColor: AppColors.primaryA,
                                    ),
                                    title:    Text(h['title']),
                                    subtitle: Text('Streak: ${h['streak']}'),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Habit: ${h['title']} (TODO)')),
                                    ),
                                  );
                                }).toList(),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Open Habits (TODO)')),
                                    ),
                                    child: const Text('Manage Habits'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Usage Today', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    const Icon(Icons.watch_later_outlined, color: AppColors.primaryB),
                                    const SizedBox(width: 8),
                                    const Expanded(child: Text('Distracting minutes:')),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '$_distractingMinutes min',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed: _manualUsageEntry,
                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryB),
                                  child: const Text('Edit'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ── Recent Games ───────────────────────────────────────
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('Recent Games', style: TextStyle(fontWeight: FontWeight.bold)),
                              const Spacer(),
                              TextButton(onPressed: _openGames, child: const Text('See all')),
                            ],
                          ),
                          ..._recentGames.map((g) {
                            return ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.videogame_asset_outlined),
                              ),
                              title:    Text(g['game']),
                              subtitle: Text('${g['score']} pts • ${g['time']}'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Open game session (TODO)')),
                              ),
                            );
                          }).toList(),
                          const Divider(),
                          ListTile(
                            leading: const Icon(Icons.psychology_outlined),
                            title:    const Text('Mini IQ Practice'),
                            subtitle: const Text('Short pattern & verbal tasks'),
                            trailing: ElevatedButton(
                              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Open Mini IQ (TODO)')),
                              ),
                              child: const Text('Start'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Recommendation ─────────────────────────────────────
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Recommendation', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(_recommendation, style: TextStyle(color: Colors.grey[800])),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              ElevatedButton.icon(
                                icon: const Icon(Icons.play_arrow),
                                label: const Text('Auto-plan'),
                                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Plan applied (TODO)')),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const QuestionPage()),
                                ),
                                child: const Text('Quick Test'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }
}
