import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  // ── KEEP THIS IN SYNC with your GitHub release tag (without the "v") ───────
  // Rule: before building an APK, bump this + pubspec version + GitHub tag
  // Example: release "v1.2" on GitHub → set this to '1.2'
  static const String _currentVersion = '1.2';

  static const String _owner = 'aboodsamad';
  static const String _repo  = 'FocusProFrontEnd';

  static const String _apiUrl =
      'https://api.github.com/repos/$_owner/$_repo/releases/latest';

  /// Checks GitHub for the latest release. Only shows a dialog if a version
  /// strictly newer than [_currentVersion] exists AND has an attached .apk.
  static Future<void> checkForUpdate(BuildContext context) async {
    try {
      final resp = await http
          .get(Uri.parse(_apiUrl),
              headers: {'Accept': 'application/vnd.github+json'})
          .timeout(const Duration(seconds: 8));

      if (resp.statusCode != 200) return;

      final data = jsonDecode(resp.body) as Map<String, dynamic>;

      // Strip the leading "v" from the tag (e.g. "v1.2" → "1.2")
      final latestTag =
          (data['tag_name'] as String? ?? '').replaceFirst('v', '').trim();

      final downloadUrl = _extractApkUrl(data);

      // Only show dialog if GitHub has something strictly NEWER
      if (!_isNewer(latestTag, _currentVersion)) return;

      // Only show dialog if there is actually an APK attached to the release
      if (downloadUrl == null || downloadUrl.isEmpty) return;

      if (context.mounted) {
        _showUpdateDialog(context, latestTag, downloadUrl);
      }
    } catch (_) {
      // Silent fail — never crash the app because of an update check
    }
  }

  /// Returns true only if [latest] is strictly greater than [current].
  static bool _isNewer(String latest, String current) {
    if (latest.isEmpty || current.isEmpty) return false;
    final l = _toInts(latest);
    final c = _toInts(current);
    for (int i = 0; i < l.length || i < c.length; i++) {
      final lv = i < l.length ? l[i] : 0;
      final cv = i < c.length ? c[i] : 0;
      if (lv > cv) return true;
      if (lv < cv) return false;
    }
    return false; // equal → not newer
  }

  static List<int> _toInts(String v) =>
      v.split('.').map((s) => int.tryParse(s.trim()) ?? 0).toList();

  /// Finds the first .apk asset URL in the release.
  static String? _extractApkUrl(Map<String, dynamic> data) {
    final assets = data['assets'] as List<dynamic>? ?? [];
    for (final asset in assets) {
      final name = (asset['name'] as String? ?? '').toLowerCase();
      if (name.endsWith('.apk')) {
        return asset['browser_download_url'] as String?;
      }
    }
    return null;
  }

  static void _showUpdateDialog(
      BuildContext context, String version, String downloadUrl) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.system_update_rounded,
                  color: Color(0xFF10B981), size: 22),
            ),
            const SizedBox(width: 12),
            const Text(
              'Update Available',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'FocusPro v$version is ready to install with new features and fixes.\n\nTap Update to download the new APK.',
          style: const TextStyle(
              color: Color(0xFF9CA3AF), fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Later',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.download_rounded, size: 16),
            label: const Text('Update',
                style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () async {
              Navigator.of(context).pop();
              // Skip canLaunchUrl — it fails silently on Android for https
              // when the query isn't whitelisted. Just launch directly.
              try {
                await launchUrl(
                  Uri.parse(downloadUrl),
                  mode: LaunchMode.externalApplication,
                );
              } catch (_) {}
            },
          ),
        ],
      ),
    );
  }
}
