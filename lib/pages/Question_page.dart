import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../utilities/question.dart';
import './homePage.dart';
import '../services/loginservice.dart';

class QuestionPage extends StatefulWidget {
  const QuestionPage({super.key});

  @override
  State<QuestionPage> createState() => _QuestionPageState();
}

class _QuestionPageState extends State<QuestionPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int selectedoption = -1;
  int questionNumber = 0;
  int score = 0;
  int seconds = 10;
  static const String baseUrl = 'http://localhost:8080';
  
  // ADD THIS: Store the timer so we can cancel it
  Timer? _questionTimer;

  final Color primaryA = const Color(0xFF667eea);
  final Color primaryB = const Color(0xFF764ba2);
  final Color accent = const Color(0xFFf093fb);
  final Color softBg = const Color(0xFFF7F8FA);

  List<Question> questions = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _controller.forward();
    getQuestions();
    _setTimer();
  }

  @override
  void dispose() {
    _controller.dispose();
    // IMPORTANT: Cancel timer when widget is disposed
    _questionTimer?.cancel();
    super.dispose();
  }

  Future<void> getQuestions() async {
    final token = await ApiService.getToken();
    if (token == null) {
      print('No auth token found');
      return;
    }

    final url = Uri.parse('$baseUrl/question/test/baseline');
    print('GET $url');

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

      print('Response code: ${resp.statusCode}');
      print('Response body: ${resp.body}');

      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body.trim());

        List<dynamic> rawList;
        if (decoded is List) {
          rawList = decoded;
        } else if (decoded is Map && decoded['questions'] is List) {
          rawList = decoded['questions'];
        } else if (decoded is Map && decoded['data'] is List) {
          rawList = decoded['data'];
        } else {
          rawList = [];
          print('Unexpected questions format: $decoded');
        }

        final fetched = rawList
            .map((e) {
              if (e is Map) {
                final id = int.tryParse(e['id']?.toString() ?? '') ?? 0;
                final text = e['questionText']?.toString() ?? '';
                final a = e['optionA']?.toString() ?? '';
                final b = e['optionB']?.toString() ?? '';
                final c = e['optionC']?.toString() ?? '';
                final d = e['optionD']?.toString() ?? '';
                final options = [a, b, c, d];

                final correctLetter = (e['correctAnswer']?.toString() ?? '')
                    .toUpperCase();
                final letterToIndex = {'A': 0, 'B': 1, 'C': 2, 'D': 3};
                final correctIndex = letterToIndex[correctLetter] ?? 0;

                return Question(
                  id: id,
                  text: text,
                  options: options,
                  correctIndex: correctIndex,
                );
              }
              return null;
            })
            .whereType<Question>()
            .toList();

        setState(() {
          questions = fetched;
          questionNumber = 0;
          selectedoption = -1;
          score = 0;
        });

        print('Loaded ${questions.length} questions');
        for (var q in questions) print('Q: ${q.text} - options: ${q.options}');
      } else {
        print('Failed to load questions: ${resp.statusCode} ${resp.body}');
      }
    } catch (e) {
      print('Error fetching questions: $e');
    }
  }

  Future<void> _nextQuestion() async {
    final token = await ApiService.getToken();
    if (token == null) {
      print('No auth token - cannot submit answer');
      return;
    }
    
    _controller.reverse().then((_) {
      setState(() {
        if (questionNumber < questions.length - 1) {
          questionNumber = questionNumber + 1;
          selectedoption = -1;
          _controller.forward();
        } else {
          // IMPORTANT: Cancel timer when quiz is complete
          _questionTimer?.cancel();
          
          final sendScore = http.post(
            Uri.parse('$baseUrl/question/submit-test/baseline?score=$score'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          );
          _showCompletionDialog();
        }
      });
    });
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            Icon(Icons.celebration, color: Colors.amber, size: 28),
            SizedBox(width: 12),
            Text(
              'Quiz Completed!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Your Score',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [primaryA, primaryB]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${score.toString()} / ${questions.length}',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(height: 12),
            Text(
              questions.isNotEmpty && score >= (questions.length * 0.7).ceil()
                  ? 'Great job!'
                  : 'Keep practicing!',
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => HomeScreen()),
              );
            },
            style: TextButton.styleFrom(foregroundColor: primaryA),
            child: Text('Go to Home Page'),
          ),
        ],
      ),
    );
  }

  Future<bool?> submitAnswer(Question q, int selectedIndex) async {
    final letters = ['A', 'B', 'C', 'D'];
    final answerLetter = (selectedIndex >= 0 && selectedIndex < letters.length)
        ? letters[selectedIndex]
        : 'A';

    final token = await ApiService.getToken();
    if (token == null) {
      print('No auth token - cannot submit answer');
      return null;
    }

    final url = Uri.parse(
      '$baseUrl/question/test-answer/${q.id}?answer=$answerLetter',
    );
    print('Submitting answer to: $url');

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

      print('Answer response: ${resp.statusCode} ${resp.body}');
      if (resp.statusCode == 200) {
        final body = resp.body.trim().toLowerCase();
        final bool correct =
            body == 'true' || body == '"true"' || body.contains('true');
        return correct;
      } else {
        print('Failed to submit answer: ${resp.statusCode} ${resp.body}');
        return null;
      }
    } catch (e) {
      print('Error submitting answer: $e');
      return null;
    }
  }

  // FIXED: Properly cancel old timer before creating new one
  void _setTimer() {
    // Cancel any existing timer first
    _questionTimer?.cancel();
    
    seconds = 10;
    
    _questionTimer = Timer.periodic(Duration(seconds: 1), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      setState(() {
        if (seconds < 1) {
          timer.cancel();
          _nextQuestion().then((_) {
            // Restart timer for next question (only if not finished)
            if (questionNumber < questions.length) {
              _setTimer();
            }
          });
        } else {
          seconds = seconds - 1;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (questions.isEmpty) {
      return Scaffold(
        backgroundColor: softBg,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          automaticallyImplyLeading: false,
          title: Text(
            'Quick Test',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final Question current = questions[questionNumber];
    final options = current.options;
    final int total = questions.length;
    final double progress = total == 0 ? 0.0 : (questionNumber + 1) / total;

    return Scaffold(
      backgroundColor: softBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        title: Text(
          'Quick Test',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _controller,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0.2, 0), end: Offset.zero)
              .animate(
                CurvedAnimation(
                  parent: _controller,
                  curve: Curves.easeOutCubic,
                ),
              ),
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              Container(
                padding: EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Question ${questionNumber + 1} of $total',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${(progress * 100).toInt()}% Complete',
                          style: TextStyle(
                            fontSize: 13,
                            color: primaryA,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(primaryA),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),

              Card(
                elevation: 4,
                shadowColor: Colors.black.withOpacity(0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              primaryA.withOpacity(0.1),
                              primaryB.withOpacity(0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.help_outline_rounded,
                              color: primaryB,
                              size: 28,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'seconds left: $seconds',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: primaryB,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        current.text,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),

              ...List.generate(options.length, (optIndex) {
                bool isSelected = selectedoption == optIndex;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: Card(
                    elevation: isSelected ? 4 : 2,
                    shadowColor: isSelected
                        ? primaryA.withOpacity(0.3)
                        : Colors.black.withOpacity(0.05),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        setState(() {
                          if (selectedoption != optIndex) {
                            selectedoption = optIndex;
                            if (selectedoption == current.correctIndex) {
                              score++;
                            }
                          }
                        });
                      },
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: 200),
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: isSelected
                              ? LinearGradient(colors: [primaryA, primaryB])
                              : null,
                          color: isSelected ? null : Colors.white,
                          border: Border.all(
                            color: isSelected
                                ? Colors.transparent
                                : Colors.grey[300]!,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.transparent,
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey[400]!,
                                  width: 2,
                                ),
                              ),
                              child: isSelected
                                  ? Icon(Icons.check, size: 16, color: primaryA)
                                  : null,
                            ),
                            SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                options[optIndex],
                                style: TextStyle(
                                  fontSize: 15,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey[800],
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),

              SizedBox(height: 20),

              ElevatedButton(
                onPressed: selectedoption == -1
                    ? null
                    : () async {
                        final currentQ = questions[questionNumber];
                        final optIndex = selectedoption;

                        final result = await submitAnswer(currentQ, optIndex);

                        if (result != null) {
                          if (result && !(optIndex == currentQ.correctIndex)) {
                            setState(() {
                              score++;
                            });
                          }
                        } else {
                          print('No server confirmation for answer.');
                        }

                        // Reset and start new timer for next question
                        _setTimer();
                        _nextQuestion();
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryA,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                  disabledBackgroundColor: Colors.grey[300],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      questionNumber < total - 1
                          ? 'Next Question'
                          : 'Finish Quiz',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}














// import 'dart:convert';

// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';
// import '../utilities/question.dart';
// import './homePage.dart';
// import '../services/loginservice.dart';

// class QuestionPage extends StatefulWidget {
//   const QuestionPage({super.key});

//   @override
//   State<QuestionPage> createState() => _QuestionPageState();
// }

// class _QuestionPageState extends State<QuestionPage> {
//   int selectedoption = -1;
//   int questionNumber = 0;
//   int score = 0;
//   static const String baseUrl = 'http://localhost:8080';

//   // questions list is mutable and will be filled from backend
//   List<Question> questions = [];

//   @override
//   void initState() {
//     super.initState();
//     getQuestions();
//   }

//   Future<void> getQuestions() async {
//     final token = await ApiService.getToken();
//     if (token == null) {
//       print('No auth token found');
//       return;
//     }

//     final url = Uri.parse('$baseUrl/question/test/baseline');
//     print('GET $url');

//     try {
//       final resp = await http
//           .get(
//             url,
//             headers: {
//               'Content-Type': 'application/json',
//               'Authorization': 'Bearer $token',
//             },
//           )
//           .timeout(const Duration(seconds: 8));

//       print('Response code: ${resp.statusCode}');
//       print('Response body: ${resp.body}');

//       if (resp.statusCode == 200) {
//         final decoded = jsonDecode(resp.body.trim());

//         // Accept either raw list or wrapped object
//         List<dynamic> rawList;
//         if (decoded is List) {
//           rawList = decoded;
//         } else if (decoded is Map && decoded['questions'] is List) {
//           rawList = decoded['questions'];
//         } else if (decoded is Map && decoded['data'] is List) {
//           rawList = decoded['data'];
//         } else {
//           rawList = [];
//           print('Unexpected questions format: $decoded');
//         }

//         final fetched = rawList
//             .map((e) {
//               if (e is Map) {
//                 final id = int.tryParse(e['id']?.toString() ?? '') ?? 0;
//                 final text = e['questionText']?.toString() ?? '';
//                 final a = e['optionA']?.toString() ?? '';
//                 final b = e['optionB']?.toString() ?? '';
//                 final c = e['optionC']?.toString() ?? '';
//                 final d = e['optionD']?.toString() ?? '';
//                 final options = [a, b, c, d];

//                 final correctLetter = (e['correctAnswer']?.toString() ?? '')
//                     .toUpperCase();
//                 final letterToIndex = {'A': 0, 'B': 1, 'C': 2, 'D': 3};
//                 final correctIndex = letterToIndex[correctLetter] ?? 0;

//                 return Question(
//                   id: id,
//                   text: text,
//                   options: options,
//                   correctIndex: correctIndex,
//                 );
//               }
//               return null;
//             })
//             .whereType<Question>()
//             .toList();

//         setState(() {
//           questions = fetched;
//           questionNumber = 0;
//           selectedoption = -1;
//           score = 0;
//         });

//         print('Loaded ${questions.length} questions');
//       } else {
//         print('Failed to load questions: ${resp.statusCode} ${resp.body}');
//       }
//     } catch (e) {
//       print('Error fetching questions: $e');
//     }
//   }

//   Future<void> _nextQuestion() async {
//     final token = await ApiService.getToken();
//     if (token == null) {
//       print('No auth token - cannot submit answer');
//       return;
//     }

//     setState(() {
//       if (questionNumber < questions.length - 1) {
//         questionNumber = questionNumber + 1;
//         selectedoption = -1;
//       } else {
//         // submit score to backend (fire-and-forget)
//         http
//             .post(
//               Uri.parse('$baseUrl/question/submit-test/baseline?score=$score'),
//               headers: {
//                 'Content-Type': 'application/json',
//                 'Authorization': 'Bearer $token',
//               },
//             )
//             .then((resp) {
//               print('Score submit response: ${resp.statusCode} ${resp.body}');
//             })
//             .catchError((e) {
//               print('Error submitting score: $e');
//             });

//         _showCompletionDialog();
//       }
//     });
//   }

//   void _showCompletionDialog() {
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (context) => AlertDialog(
//         title: Text('Quiz Completed!'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Text('Your Score'),
//             SizedBox(height: 8),
//             Text(
//               '${score.toString()} / ${questions.length}',
//               style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 8),
//             Text(
//               questions.isNotEmpty && score >= (questions.length * 0.7).ceil()
//                   ? 'Great job!'
//                   : 'Keep practicing!',
//             ),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () {
//               Navigator.pushReplacement(
//                 context,
//                 MaterialPageRoute(builder: (context) => const HomeScreen()),
//               );
//             },
//             child: const Text('Go to Home Page'),
//           ),
//         ],
//       ),
//     );
//   }

//   // helper to submit answer to backend
//   Future<bool?> submitAnswer(Question q, int selectedIndex) async {
//     final letters = ['A', 'B', 'C', 'D'];
//     final answerLetter = (selectedIndex >= 0 && selectedIndex < letters.length)
//         ? letters[selectedIndex]
//         : 'A';

//     final token = await ApiService.getToken();
//     if (token == null) {
//       print('No auth token - cannot submit answer');
//       return null;
//     }

//     final url = Uri.parse(
//       '$baseUrl/question/test-answer/${q.id}?answer=$answerLetter',
//     );
//     print('Submitting answer to: $url');

//     try {
//       final resp = await http
//           .get(
//             url,
//             headers: {
//               'Content-Type': 'application/json',
//               'Authorization': 'Bearer $token',
//             },
//           )
//           .timeout(const Duration(seconds: 8));

//       print('Answer response: ${resp.statusCode} ${resp.body}');
//       if (resp.statusCode == 200) {
//         final body = resp.body.trim().toLowerCase();
//         final bool correct =
//             body == 'true' || body == '"true"' || body.contains('true');
//         return correct;
//       } else {
//         print('Failed to submit answer: ${resp.statusCode} ${resp.body}');
//         return null;
//       }
//     } catch (e) {
//       print('Error submitting answer: $e');
//       return null;
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     // If questions haven't been loaded yet, show a simple loader
//     if (questions.isEmpty) {
//       return Scaffold(
//         appBar: AppBar(
//           title: const Text('Quick Test'),
//         ),
//         body: const Center(child: CircularProgressIndicator()),
//       );
//     }

//     // Safe to use questions list now
//     final Question current = questions[questionNumber];
//     final options = current.options;
//     final int total = questions.length;

//     return Scaffold(
//       appBar: AppBar(title: const Text('Quick Test'),automaticallyImplyLeading: false,),
//       body: Padding(
//         padding: const EdgeInsets.all(12.0),        
//         child: Column(
//           children: [
//             // Progress simple text
//             Text('Question ${questionNumber + 1} of $total'),
//             const SizedBox(height: 12),

//             // Question text
//             Text(current.text),

//             const SizedBox(height: 12),

//             // Options list (simple tappable items)
//             ...List.generate(options.length, (optIndex) {
//               final bool isSelected = selectedoption == optIndex;
//               return ListTile(
//                 title: Text(options[optIndex]),
//                 leading: isSelected ? const Icon(Icons.check) : null,
//                 onTap: () {
//                   setState(() {
//                     if (selectedoption != optIndex) {
//                       selectedoption = optIndex;
//                       // local scoring
//                       if (selectedoption == current.correctIndex) {
//                         score++;
//                       }
//                     }
//                   });
//                 },
//               );
//             }),

//             const SizedBox(height: 12),

//             // Next / Finish button
//             ElevatedButton(
//               onPressed: selectedoption == -1
//                   ? null
//                   : () async {
//                       final currentQ = questions[questionNumber];
//                       final optIndex = selectedoption;

//                       // send answer to backend
//                       final result = await submitAnswer(currentQ, optIndex);

//                       // adjust score based on server response if needed
//                       if (result != null) {
//                         if (result && !(optIndex == currentQ.correctIndex)) {
//                           setState(() {
//                             score++;
//                           });
//                         }
//                       } else {
//                         print('No server confirmation for answer.');
//                       }

//                       // move to next question or complete
//                       _nextQuestion();
//                     },
//               child: Text(
//                 questionNumber < total - 1 ? 'Next Question' : 'Finish Quiz',
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
