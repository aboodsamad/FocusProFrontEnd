import 'package:shared_preferences/shared_preferences.dart';

/// Calculates and stores the long-term focus score using an
/// Exponential Moving Average (EMA) over daily earned points.
///
/// Formula (active day):
///   ltScore = 0.15 × normalizedDaily + 0.85 × prevLtScore
///   normalizedDaily = clamp(dailyPts / 50, 0, 1) × 100
///
/// Formula (inactive day — no points earned):
///   ltScore = max(0, prevLtScore − 0.5)
///
/// The score is anchored to the diagnostic baseline and evolves
/// only from completed days (yesterday and earlier), never today.
class LongTermScoreService {
  // EMA parameters
  static const double _alpha        = 0.15;   // recency weight
  static const double _perfectDay   = 50.0;   // daily pts = 100 % normalized
  static const double _inactiveDecay = 0.5;   // pts lost per idle day

  // SharedPreferences keys
  static const String _ltScoreKey         = 'lt_ema_score';
  static const String _lastProcessedKey   = 'lt_last_processed_date';
  static const String _ltSnapshotPrefix   = 'lt_snap_'; // + YYYY-MM-DD → snapshot score

  // ── Date helpers ────────────────────────────────────────────────────────────

  static String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime? _parseDate(String? s) {
    if (s == null) return null;
    try {
      final p = s.split('-');
      return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
    } catch (_) { return null; }
  }

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Called once after the diagnostic completes to seed the long-term score.
  /// Safe to call multiple times — only seeds when not yet initialized.
  static Future<void> seedFromDiagnostic(double diagnosticScore) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_ltScoreKey)) return; // already seeded

    final yesterday = _dateOnly(DateTime.now()).subtract(const Duration(days: 1));
    await prefs.setDouble(_ltScoreKey, diagnosticScore);
    await prefs.setString(_lastProcessedKey, _dateStr(yesterday));
    // Store snapshot so trend is meaningful from day 1
    await prefs.setDouble('$_ltSnapshotPrefix${_dateStr(yesterday)}', diagnosticScore);
  }

  /// Returns the current stored long-term score (0–100 integer scale).
  /// Returns null if the diagnostic hasn't been completed yet.
  static Future<double?> getScore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_ltScoreKey);
  }

  /// Processes all unprocessed completed days (yesterday and earlier) via EMA.
  /// Returns the new score if it changed, null if nothing to process or no seed.
  static Future<double?> processPendingDays() async {
    final prefs = await SharedPreferences.getInstance();

    final rawScore = prefs.getDouble(_ltScoreKey);
    if (rawScore == null) return null; // No diagnostic yet

    final lastProcessed = _parseDate(prefs.getString(_lastProcessedKey));
    final today = _dateOnly(DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));

    // Nothing to process
    if (lastProcessed != null && !lastProcessed.isBefore(yesterday)) return null;

    DateTime cursor = lastProcessed != null
        ? lastProcessed.add(const Duration(days: 1))
        : yesterday; // if no lastProcessed somehow, start from yesterday

    double score = rawScore;
    bool changed = false;

    while (!cursor.isAfter(yesterday)) {
      final dailyKey = 'daily_score_${_dateStr(cursor)}';
      final pts = prefs.getDouble(dailyKey) ?? 0.0;

      if (pts > 0) {
        final norm = (pts / _perfectDay).clamp(0.0, 1.0) * 100.0;
        score = _alpha * norm + (1 - _alpha) * score;
      } else {
        score = (score - _inactiveDecay).clamp(0.0, 100.0);
      }

      // Store daily snapshot for trend lookups
      await prefs.setDouble('$_ltSnapshotPrefix${_dateStr(cursor)}', score);
      cursor = cursor.add(const Duration(days: 1));
      changed = true;
    }

    if (changed) {
      score = score.clamp(0.0, 100.0);
      await prefs.setDouble(_ltScoreKey, score);
      await prefs.setString(_lastProcessedKey, _dateStr(yesterday));
      return score;
    }
    return null;
  }

  /// Returns the change in long-term score over the past 7 days.
  /// Positive = improving, negative = declining, null = not enough history.
  static Future<double?> getWeekTrend() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getDouble(_ltScoreKey);
    if (current == null) return null;

    final sevenDaysAgo = _dateOnly(DateTime.now()).subtract(const Duration(days: 7));
    final snapshot = prefs.getDouble('$_ltSnapshotPrefix${_dateStr(sevenDaysAgo)}');
    if (snapshot == null) return null;

    return current - snapshot;
  }
}
