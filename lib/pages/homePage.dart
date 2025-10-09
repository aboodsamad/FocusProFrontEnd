// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';
// import 'dart:math' as math;

// const String baseUrl = 'http://localhost:8080';

// class HomeScreen extends StatefulWidget {
//   const HomeScreen({Key? key}) : super(key: key);
  
//   @override
//   State<HomeScreen> createState() => _HomeScreenState();
// }

// class _HomeScreenState extends State<HomeScreen> {
//   // ========== STATE VARIABLES ==========
//   bool isLoading = true;
//   String userName = 'User';
//   double focusScore = 0.0;
//   Map<String, double> components = {
//     'T': 0.0,  // Test score
//     'G': 0.0,  // Games score
//     'S': 0.0,  // Screen time score
//     'H': 0.0,  // Habits score
//   };

//   // ========== COLORS ==========
//   final Color primaryA = const Color(0xFF667eea);
//   final Color primaryB = const Color(0xFF764ba2);
//   final Color softBg = const Color(0xFFF7F8FA);

//   // ========== LIFECYCLE ==========
//   @override
//   void initState() {
//     super.initState();
    
//     // Load data
//     loadHomeData();
//   }

//   @override
//   void dispose() {
//     super.dispose();
//   }

//   // ========== DATA LOADING ==========
//   Future<void> loadHomeData() async {
//     setState(() => isLoading = true);

//     // Get auth token
//     final token = await getToken();
    
//     if (token != null) {
//       // Fetch user profile from backend
//       await fetchAndSaveProfile(token);
//     }

//     // Load user info from storage
//     userName = await getStoredName() ?? 'User';
//     focusScore = await getStoredFocusScore() ?? 0.0;

//     // TODO: Load components from backend (hardcoded for now)
//     components = {
//       'T': 70.0,
//       'G': 60.0,
//       'S': 70.0,
//       'H': 80.0,
//     };

//     setState(() => isLoading = false);
//   }

//   // ========== API HELPERS ==========
//   Future<String?> getToken() async {
//     final prefs = await SharedPreferences.getInstance();
//     return prefs.getString('auth_token');
//   }

//   Future<bool> fetchAndSaveProfile(String token) async {
//     final url = Uri.parse('$baseUrl/user/profile');
    
//     try {
//       final response = await http.get(
//         url,
//         headers: {
//           'Content-Type': 'application/json',
//           'Authorization': 'Bearer $token',
//         },
//       ).timeout(Duration(seconds: 8));

//       if (response.statusCode != 200) return false;

//       final profile = jsonDecode(response.body) as Map<String, dynamic>;
      
//       // Save to local storage
//       final prefs = await SharedPreferences.getInstance();
      
//       if (profile['name'] != null) {
//         prefs.setString('name', profile['name'].toString());
//       }
      
//       if (profile['focusScore'] != null) {
//         prefs.setDouble('focus_score', double.parse(profile['focusScore'].toString()));
//       }

//       return true;
//     } catch (e) {
//       print('Error fetching profile: $e');
//       return false;
//     }
//   }

//   Future<String?> getStoredName() async {
//     final prefs = await SharedPreferences.getInstance();
//     return prefs.getString('name');
//   }

//   Future<double?> getStoredFocusScore() async {
//     final prefs = await SharedPreferences.getInstance();
//     return prefs.getDouble('focus_score');
//   }

//   // ========== UI BUILDERS ==========
  
//   // Build the pulsing focus score circle
//   Widget buildFocusCircle() {
//     return Stack(
//         alignment: Alignment.center,
//         children: [
//           // Ring
//           SizedBox(
//             width: 140,
//             height: 140,
//             child: CustomPaint(
//               painter: RingPainter(
//                 progress: focusScore / 100,
//                 colorA: primaryA,
//                 colorB: primaryB,
//               ),
//             ),
//           ),
//           // Score text
//           Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Text(
//                 focusScore.toStringAsFixed(0),
//                 style: TextStyle(
//                   fontSize: 34,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.black87,
//                 ),
//               ),
//               Text(
//                 'Focus',
//                 style: TextStyle(fontSize: 14, color: Colors.black54),
//               ),
//             ],
//           ),
//         ],
      
//     );
//   }

//   // Build a component bar (T, G, S, H)
//   Widget buildComponentBar(String key, double value) {
//     final labels = {
//       'T': 'Test',
//       'G': 'Games',
//       'S': 'Screen',
//       'H': 'Habits',
//     };
    
//     final label = labels[key] ?? key;
//     final barWidth = (value / 100) * MediaQuery.of(context).size.width * 0.18;

//     return Expanded(
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Label
//           Text(
//             label,
//             style: TextStyle(fontSize: 12, color: Colors.grey[700]),
//           ),
//           SizedBox(height: 6),
          
//           // Bar background
//           Stack(
//             children: [
//               Container(
//                 height: 8,
//                 decoration: BoxDecoration(
//                   color: Colors.grey[200],
//                   borderRadius: BorderRadius.circular(6),
//                 ),
//               ),
//               // Bar fill
//               Container(
//                 height: 8,
//                 width: barWidth,
//                 decoration: BoxDecoration(
//                   gradient: LinearGradient(colors: [primaryA, primaryB]),
//                   borderRadius: BorderRadius.circular(6),
//                 ),
//               ),
//             ],
//           ),
//           SizedBox(height: 6),
          
//           // Value
//           Text(
//             value.toStringAsFixed(0),
//             style: TextStyle(fontSize: 12, color: Colors.grey[800]),
//           ),
//         ],
//       ),
//     );
//   }

//   // Show score breakdown dialog
//   void showScoreBreakdown() {
//     showModalBottomSheet(
//       context: context,
//       builder: (context) => Container(
//         padding: EdgeInsets.all(16),
//         height: 300,
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'FocusScore Breakdown',
//               style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
//             ),
//             SizedBox(height: 10),
//             buildBreakdownRow('Test (T)', components['T']!, 0.40),
//             buildBreakdownRow('Games (G)', components['G']!, 0.30),
//             buildBreakdownRow('Screen (S)', components['S']!, 0.20),
//             buildBreakdownRow('Habits (H)', components['H']!, 0.10),
//             SizedBox(height: 12),
//             Text(
//               'Formula: 0.40*T + 0.30*G + 0.20*S + 0.10*H',
//               style: TextStyle(color: Colors.grey[700]),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget buildBreakdownRow(String label, double value, double weight) {
//     final contribution = value * weight;
    
//     return Padding(
//       padding: EdgeInsets.symmetric(vertical: 6),
//       child: Row(
//         children: [
//           Expanded(flex: 3, child: Text(label)),
//           Expanded(
//             flex: 2,
//             child: Text(
//               value.toStringAsFixed(0),
//               textAlign: TextAlign.right,
//             ),
//           ),
//           SizedBox(width: 12),
//           Expanded(
//             flex: 3,
//             child: Text(
//               contribution.toStringAsFixed(1),
//               textAlign: TextAlign.right,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // ========== MAIN BUILD ==========
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: softBg,
      
//       // ========== APP BAR ==========
//       appBar: AppBar(
//         automaticallyImplyLeading: false,
//         backgroundColor: Colors.transparent,
//         elevation: 0,
//         toolbarHeight: 86,
//         title: Row(
//           children: [
//             // User avatar
//             Container(
//               width: 52,
//               height: 52,
//               decoration: BoxDecoration(
//                 shape: BoxShape.circle,
//                 gradient: LinearGradient(colors: [primaryA, primaryB]),
//               ),
//               child: CircleAvatar(
//                 radius: 26,
//                 backgroundColor: Colors.transparent,
//                 child: Text(
//                   userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
//                   style: TextStyle(color: Colors.white, fontSize: 20),
//                 ),
//               ),
//             ),
//             SizedBox(width: 12),
            
//             // Greeting
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     'Good day,',
//                     style: TextStyle(color: Colors.grey[700], fontSize: 14),
//                   ),
//                   Text(
//                     userName,
//                     style: TextStyle(
//                       color: Colors.black87,
//                       fontSize: 18,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
            
//             // Settings button
//             IconButton(
//               tooltip: 'Settings',
//               icon: Icon(Icons.settings_outlined, color: Colors.grey[700]),
//               onPressed: () {
//                 // TODO: Navigate to settings
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   SnackBar(content: Text('Settings (TODO)')),
//                 );
//               },
//             ),
//           ],
//         ),
//       ),

//       // ========== BODY ==========
//       body: isLoading
//           ? Center(child: CircularProgressIndicator())
//           : RefreshIndicator(
//               onRefresh: loadHomeData,
//               child: ListView(
//                 padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//                 children: [
//                   // ========== WEEKLY FOCUS SCORE CARD ==========
//                   Card(
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(14),
//                     ),
//                     elevation: 6,
//                     child: Padding(
//                       padding: EdgeInsets.all(14),
//                       child: Row(
//                         children: [
//                           // Left: Focus circle
//                           buildFocusCircle(),
//                           SizedBox(width: 14),
                          
//                           // Right: Details and components
//                           Expanded(
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 // Title
//                                 Text(
//                                   'Weekly FocusScore',
//                                   style: TextStyle(
//                                     fontSize: 14,
//                                     color: Colors.grey[700],
//                                   ),
//                                 ),
//                                 SizedBox(height: 8),
                                
//                                 // Subtitle
//                                 Text(
//                                   'Your explainable attention metric',
//                                   style: TextStyle(
//                                     fontSize: 12,
//                                     color: Colors.grey[600],
//                                   ),
//                                 ),
//                                 SizedBox(height: 12),
                                
//                                 // Component bars (T, G, S, H)
//                                 Row(
//                                   children: [
//                                     buildComponentBar('T', components['T']!),
//                                     SizedBox(width: 8),
//                                     buildComponentBar('G', components['G']!),
//                                     SizedBox(width: 8),
//                                     buildComponentBar('S', components['S']!),
//                                     SizedBox(width: 8),
//                                     buildComponentBar('H', components['H']!),
//                                   ],
//                                 ),
//                                 SizedBox(height: 12),
                                
//                                 // Buttons
//                                 Row(
//                                   children: [
//                                     // Details button
//                                     ElevatedButton.icon(
//                                       icon: Icon(Icons.analytics_outlined),
//                                       label: Text('Details'),
//                                       style: ElevatedButton.styleFrom(
//                                         backgroundColor: primaryA,
//                                       ),
//                                       onPressed: showScoreBreakdown,
//                                     ),
//                                     SizedBox(width: 10),
                                    
//                                     // Quick test button
//                                     OutlinedButton(
//                                       onPressed: () {
//                                         // TODO: Navigate to QuestionPage
//                                         ScaffoldMessenger.of(context).showSnackBar(
//                                           SnackBar(content: Text('Quick Test (TODO)')),
//                                         );
//                                       },
//                                       child: Text('Quick Test'),
//                                     ),
//                                   ],
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
                  
//                   // Add more sections here later...
//                 ],
//               ),
//             ),
//     );
//   }
// }

// // ========== CUSTOM PAINTER FOR RING ==========
// class RingPainter extends CustomPainter {
//   final double progress;  // 0.0 to 1.0
//   final Color colorA;
//   final Color colorB;

//   RingPainter({
//     required this.progress,
//     required this.colorA,
//     required this.colorB,
//   });

//   @override
//   void paint(Canvas canvas, Size size) {
//     final strokeWidth = 14.0;
//     final center = Offset(size.width / 2, size.height / 2);
//     final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

//     // Draw background ring (gray)
//     final bgPaint = Paint()
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = strokeWidth
//       ..color = Colors.grey.shade200;
//     canvas.drawCircle(center, radius, bgPaint);

//     // Draw progress ring (gradient)
//     final startAngle = -math.pi / 2;
//     final sweepAngle = 2 * math.pi * progress;

//     final gradient = SweepGradient(
//       startAngle: startAngle,
//       endAngle: startAngle + sweepAngle,
//       colors: [colorA, colorB],
//     );

//     final paint = Paint()
//       ..shader = gradient.createShader(
//         Rect.fromCircle(center: center, radius: radius),
//       )
//       ..style = PaintingStyle.stroke
//       ..strokeCap = StrokeCap.round
//       ..strokeWidth = strokeWidth;

//     canvas.drawArc(
//       Rect.fromCircle(center: center, radius: radius),
//       startAngle,
//       sweepAngle,
//       false,
//       paint,
//     );
//   }

//   @override
//   bool shouldRepaint(RingPainter oldDelegate) {
//     return oldDelegate.progress != progress;
//   }
// }

































































































// lib/screens/home_page.dart
import 'dart:convert';

import 'package:capstone_front_end/pages/Question_page.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;
import './Question_page.dart';

const String _baseUrl = 'http://localhost:8080';


class MockApi {
  static Future<Map<String, dynamic>> fetchHomeData() async {
    await Future.delayed(Duration(milliseconds: 300));
    final focusScore = await getStoredFocusScore() ?? 0.0;
    final name = await getStoredName() ?? 'Abd';
    return {
      'name': name,
      'focusScore': focusScore,
      'components': {'T': 70.0, 'G': 60.0, 'S': 70.0, 'H': 80.0},
      'distractingMinutesToday': 42,
      'habitList': [
        {
          'id': 'h1',
          'title': 'Morning 10-min reading',
          'done': true,
          'streak': 3,
        },
        {
          'id': 'h2',
          'title': 'Daily reaction game',
          'done': false,
          'streak': 1,
        },
        {
          'id': 'h3',
          'title': 'No social before 9AM',
          'done': false,
          'streak': 7,
        },
      ],
      'recentGames': [
        {'game': 'Reaction', 'score': 78, 'time': '10m'},
        {'game': 'N-back', 'score': 62, 'time': '6m'},
      ],
      'recommendation':
          'Do 2 reaction tasks + 10m TTS for 3 days to boost score by ~5 pts.',
    };
  }
}

Future<String?> getToken() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('auth_token');
}

// get the user info
Future<bool> fetchAndSaveProfile(String token) async {
  final url = Uri.parse('$_baseUrl/user/profile');
  try {
    final resp = await http
        .get(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(Duration(seconds: 8));

    if (resp.statusCode != 200) return false;

    final Map<String, dynamic> profile = jsonDecode(resp.body);

    final prefs = await SharedPreferences.getInstance();
    // Save simple fields
    if (profile['id'] != null)
      prefs.setInt('user_id', int.parse(profile['id'].toString()));
    if (profile['username'] != null)
      prefs.setString('username', profile['username'].toString());
    if (profile['email'] != null)
      prefs.setString('email', profile['email'].toString());
    if (profile['name'] != null)
      prefs.setString('name', profile['name'].toString());
    if (profile['dob'] != null)
      prefs.setString('dob', profile['dob'].toString());
    if (profile['focusScore'] != null)
      prefs.setDouble(
        'focus_score',
        double.parse(profile['focusScore'].toString()),
      );

    // role (string) and authorities (save as JSON string)
    final roleName = profile['role'] is Map
        ? profile['role']['name']?.toString()
        : null;
    if (roleName != null) prefs.setString('role_name', roleName);
    if (profile['authorities'] != null)
      prefs.setString('authorities', jsonEncode(profile['authorities']));

    // Save raw profile if you want full access later (optional)
    prefs.setString('profile_json', jsonEncode(profile));

    return true;
  } catch (e) {
    print('fetchAndSaveProfile error: $e');
    return false;
  }
}

// Helper: return the whole stored profile as Map (or null)
Future<Map<String, dynamic>?> getStoredProfile() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString('profile_json');
  if (raw == null) return null;
  try {
    return jsonDecode(raw) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}

// Small getters you can call from anywhere
Future<int?> getStoredUserId() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt('user_id');
}

Future<String?> getStoredUsername() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('username');
}

Future<String?> getStoredEmail() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('email');
}

Future<String?> getStoredName() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('name');
}

Future<String?> getStoredDob() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('dob');
}

Future<double?> getStoredFocusScore() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getDouble('focus_score');
}

Future<String?> getStoredRoleName() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('role_name');
}

Future<List<dynamic>> getStoredAuthorities() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString('authorities');
  if (raw == null) return [];
  try {
    return jsonDecode(raw) as List<dynamic>;
  } catch (_) {
    return [];
  }
}

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
      duration: Duration(milliseconds: 1400),
      lowerBound: 0.0,
      upperBound: 0.06,
    )..repeat(reverse: true);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    // First, try to fetch fresh profile from API
    final token = await getToken();
    print('Token: $token'); // Debug
    
    if (token != null) {
      final success = await fetchAndSaveProfile(token);
      print('Profile fetch success: $success'); // Debug
      if (!success) {
        print('Failed to fetch profile from API, using stored data');
      }
    }

    // Load stored profile (either freshly fetched or previously stored)
    final storedProfile = await getStoredProfile();
    print('Stored profile: $storedProfile'); // Debug
    
    if (storedProfile != null) {
      _name = storedProfile['name'] ?? 'User';
      _focusScore = (storedProfile['focusScore'] ?? 0.0).toDouble();
      print('Loaded name: $_name, focusScore: $_focusScore'); // Debug
    }

    // Fetch home data / other API calls
    final data = await MockApi.fetchHomeData();
    setState(() {
      // Don't overwrite name and focusScore if we already loaded them from profile
      if (_name == 'User') {
        _name = data['name'] ?? _name;
      }
      if (_focusScore == 0.0) {
        _focusScore = (data['focusScore'] as num).toDouble();
      }
      _components = Map<String, double>.from(data['components']);
      _distractingMinutes = data['distractingMinutesToday'] ?? 0;
      _habits = List<Map<String, dynamic>>.from(data['habitList']);
      _recentGames = List<Map<String, dynamic>>.from(data['recentGames']);
      _recommendation = data['recommendation'] ?? '';
      _loading = false;
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // UI Colors (match signup/login theme)
  final Color primaryA = const Color(0xFF667eea);
  final Color primaryB = const Color(0xFF764ba2);
  final Color accent = const Color(0xFFf093fb);
  final Color softBg = const Color(0xFFF7F8FA);

  void _openTest() {
    // TODO: Replace with navigation to actual test screen
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Open Test (TODO)')));
  }

  void _openGames() {
    // TODO: Replace with navigation to games list
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Open Games (TODO)')));
  }

  void _openReader() {
    // TODO: Replace with text reader
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Open Reader (TODO)')));
  }

  void _toggleHabitDone(int index) {
    setState(() {
      _habits[index]['done'] = !_habits[index]['done'];
      if (_habits[index]['done']) {
        _habits[index]['streak'] = (_habits[index]['streak'] ?? 0) + 1;
      } else {
        _habits[index]['streak'] = 0;
      }
      // In real app: persist change via API / local DB and recompute FocusScore
    });
  }

  void _manualUsageEntry() {
    // Simple dialog to let the user enter minutes manually
    showDialog<int>(
      context: context,
      builder: (context) {
        final ctl = TextEditingController();
        return AlertDialog(
          title: Text('Manual usage minutes'),
          content: TextField(
            controller: ctl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Enter minutes spent on distracting apps',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final val = int.tryParse(ctl.text) ?? 0;
                Navigator.pop(context, val);
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    ).then((minutes) {
      if (minutes != null) {
        setState(() {
          _distractingMinutes = minutes;
          // In real app: re-calc and persist usage_summary, recompute FocusScore
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Saved $minutes minutes')));
      }
    });
  }

  Widget _buildFocusCircle(double score) {
    // Simple circular score with pulsing ring
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulse = (1 + _pulseController.value);
        return Transform.scale(scale: pulse, child: child);
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 140,
            height: 140,
            child: CustomPaint(
              painter: _RingPainter(score / 100, primaryA, primaryB),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                score.toStringAsFixed(0),
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                'Focus',
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _componentBar(String key, double value) {
    final label =
        {'T': 'Test', 'G': 'Games', 'S': 'Screen', 'H': 'Habits'}[key] ?? key;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          SizedBox(height: 6),
          Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              Container(
                height: 8,
                width: (value / 100) * MediaQuery.of(context).size.width * 0.18,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [primaryA, primaryB]),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            '${value.toStringAsFixed(0)}',
            style: TextStyle(fontSize: 12, color: Colors.grey[800]),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: softBg,
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
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [primaryA, primaryB]),
              ),
              child: CircleAvatar(
                radius: 26,
                backgroundColor: Colors.transparent,
                child: Text(
                  _name.isNotEmpty ? _name[0].toUpperCase() : 'U',
                  style: TextStyle(color: Colors.white, fontSize: 20),
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Good day,',
                    style: TextStyle(color: Colors.grey[700], fontSize: 14),
                  ),
                  Text(
                    _name,
                    style: TextStyle(
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
              onPressed: () {
                // TODO: go to settings
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Open Settings (TODO)')));
              },
            ),
          ],
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  // Top cards row
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 6,
                    child: Padding(
                      padding: EdgeInsets.all(14),
                      child: Row(
                        children: [
                          _buildFocusCircle(_focusScore),
                          SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Weekly FocusScore',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Your explainable attention metric',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                SizedBox(height: 12),
                                Row(
                                  children: [
                                    _componentBar('T', _components['T'] ?? 0),
                                    SizedBox(width: 8),
                                    _componentBar('G', _components['G'] ?? 0),
                                    SizedBox(width: 8),
                                    _componentBar('S', _components['S'] ?? 0),
                                    SizedBox(width: 8),
                                    _componentBar('H', _components['H'] ?? 0),
                                  ],
                                ),
                                SizedBox(height: 12),
                                Row(
                                  children: [
                                    ElevatedButton.icon(
                                      icon: Icon(Icons.analytics_outlined),
                                      label: Text('Details'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryA,
                                      ),
                                      onPressed: () {
                                        // show breakdown modal
                                        showModalBottomSheet(
                                          context: context,
                                          builder: (_) =>
                                              _scoreBreakdownSheet(),
                                        );
                                      },
                                    ),
                                    SizedBox(width: 10),
                                    OutlinedButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const QuestionPage(),
                                          ),
                                        );
                                      },
                                      child: Text('Quick Test'),
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

                  SizedBox(height: 12),

                  // Quick actions
                  Row(
                    children: [
                      Expanded(
                        child: _actionCard(
                          Icons.assessment_outlined,
                          'Start Test',
                          '5-8 min',
                          _openTest,
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: _actionCard(
                          Icons.videogame_asset_outlined,
                          'Play Game',
                          '2-6 min',
                          _openGames,
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: _actionCard(
                          Icons.menu_book_outlined,
                          'Reader',
                          'TTS/Text',
                          _openReader,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 12),

                  // Habits + usage
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
                            padding: EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Habits',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                SizedBox(height: 8),
                                ..._habits.asMap().entries.map((e) {
                                  final idx = e.key;
                                  final h = e.value;
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Checkbox(
                                      value: h['done'] as bool,
                                      onChanged: (_) => _toggleHabitDone(idx),
                                      activeColor: primaryA,
                                    ),
                                    title: Text(h['title']),
                                    subtitle: Text('Streak: ${h['streak']}'),
                                    trailing: Icon(Icons.chevron_right),
                                    onTap: () {
                                      // open habit details
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Habit: ${h['title']} (TODO)',
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                }).toList(),
                                SizedBox(height: 6),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () {
                                      // open full habits screen
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text('Open Habits (TODO)'),
                                        ),
                                      );
                                    },
                                    child: Text('Manage Habits'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Usage Today',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                SizedBox(height: 10),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.watch_later_outlined,
                                      color: primaryB,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text('Distracting minutes:'),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Text(
                                  '$_distractingMinutes min',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed: _manualUsageEntry,
                                  child: Text('Edit'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryB,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 12),

                  // Recent games + mini IQ
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Recent Games',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Spacer(),
                              TextButton(
                                onPressed: _openGames,
                                child: Text('See all'),
                              ),
                            ],
                          ),
                          ..._recentGames.map((g) {
                            return ListTile(
                              leading: CircleAvatar(
                                child: Icon(Icons.videogame_asset_outlined),
                              ),
                              title: Text(g['game']),
                              subtitle: Text(
                                '${g['score']} pts • ${g['time']}',
                              ),
                              trailing: Icon(Icons.chevron_right),
                              onTap: () =>
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Open game session (TODO)'),
                                    ),
                                  ),
                            );
                          }).toList(),
                          Divider(),
                          ListTile(
                            leading: Icon(Icons.psychology_outlined),
                            title: Text('Mini IQ Practice'),
                            subtitle: Text('Short pattern & verbal tasks'),
                            trailing: ElevatedButton(
                              onPressed: () {
                                // TODO: Navigate to mini IQ
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Open Mini IQ (TODO)'),
                                  ),
                                );
                              },
                              child: Text('Start'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 12),

                  // Recommendation
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    color: Colors.white,
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recommendation',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 8),
                          Text(
                            _recommendation,
                            style: TextStyle(color: Colors.grey[800]),
                          ),
                          SizedBox(height: 10),
                          Row(
                            children: [
                              ElevatedButton.icon(
                                icon: Icon(Icons.play_arrow),
                                label: Text('Auto-plan'),
                                onPressed: () =>
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Plan applied (TODO)'),
                                      ),
                                    ),
                              ),
                              SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const QuestionPage(),
                                    ),
                                  );
                                },
                                child: const Text('Quick Test'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  Widget _actionCard(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          child: Column(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: primaryB.withOpacity(0.12),
                child: Icon(icon, color: primaryB),
              ),
              SizedBox(height: 10),
              Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scoreBreakdownSheet() {
    return Container(
      padding: EdgeInsets.all(16),
      height: 300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FocusScore Breakdown',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          SizedBox(height: 10),
          _breakdownRow('Test (T)', _components['T'] ?? 0, 0.40),
          _breakdownRow('Games (G)', _components['G'] ?? 0, 0.30),
          _breakdownRow('Screen (S)', _components['S'] ?? 0, 0.20),
          _breakdownRow('Habits (H)', _components['H'] ?? 0, 0.10),
          SizedBox(height: 12),
          Text(
            'Formula: 0.40*T + 0.30*G + 0.20*S + 0.10*H',
            style: TextStyle(color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  Widget _breakdownRow(String label, double value, double weight) {
    final contribution = value * weight;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(label)),
          Expanded(
            flex: 2,
            child: Text(
              '${value.toStringAsFixed(0)}',
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              '${contribution.toStringAsFixed(1)}',
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double pct;
  final Color a;
  final Color b;
  _RingPainter(this.pct, this.a, this.b);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = 14.0;
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (math.min(size.width, size.height) - stroke) / 2;
    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = Colors.grey.shade200;
    canvas.drawCircle(center, radius, bgPaint);

    final gradient = SweepGradient(
      startAngle: -math.pi / 2,
      endAngle: -math.pi / 2 + 2 * math.pi * pct,
      colors: [a, b],
    );

    final paint = Paint()
      ..shader = gradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      )
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;

    final start = -math.pi / 2;
    final sweep = 2 * math.pi * pct;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.pct != pct;
}