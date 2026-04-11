// ─────────────────────────────────────────────────────────────────────────────
// INTEGRATION GUIDE — how to wire the AI into your existing pages
// ─────────────────────────────────────────────────────────────────────────────

// ══════════════════════════════════════════════════════════════════════════════
// 1. book_detail_page.dart — Snippet comprehension check
//    Find the place where you call markSnippetComplete() or navigate away
//    after the user finishes a snippet. Replace it with this:
// ══════════════════════════════════════════════════════════════════════════════

/*
  // ADD this import at the top of book_detail_page.dart:
  import '../../../features/ai/widgets/snippet_check_sheet.dart';

  // FIND your existing "mark as complete" call (looks something like this):
  //   await BookService.markSnippetComplete(snippet.id);

  // REPLACE it with:
  final passed = await showSnippetCheckSheet(context, snippetId: snippet.id);
  if (passed) {
    // snippet is now marked complete server-side (AiService handles it)
    // just refresh your local state:
    setState(() {
      // mark snippet as completed in your local list
    });
  }
*/


// ══════════════════════════════════════════════════════════════════════════════
// 2. home_page.dart or profile_page.dart — Retention test entry point
//    Add a tappable card that navigates to RetentionTestPage.
//    Suggested: show it after the user has completed 5+ snippets.
// ══════════════════════════════════════════════════════════════════════════════

/*
  // ADD this import:
  import '../../../features/ai/pages/retention_test_page.dart';

  // ADD this widget somewhere in your home/profile page body:
  GestureDetector(
    onTap: () => Navigator.push(context,
        MaterialPageRoute(builder: (_) => const RetentionTestPage())),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1524),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.4)),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)]),
          ),
          child: const Icon(Icons.psychology, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 14),
        const Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Retention Test', style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            SizedBox(height: 2),
            Text('Prove you still remember what you read',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        )),
        const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 14),
      ]),
    ),
  ),
*/


// ══════════════════════════════════════════════════════════════════════════════
// 3. Folder structure — where to put the files
// ══════════════════════════════════════════════════════════════════════════════

/*
  lib/
  └── features/
      └── ai/
          ├── models/
          │   └── ai_question_model.dart
          ├── services/
          │   └── ai_service.dart
          ├── widgets/
          │   └── snippet_check_sheet.dart
          └── pages/
              └── retention_test_page.dart
*/
