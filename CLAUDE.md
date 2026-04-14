# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**FocusPro** — a Flutter application for cognitive focus training. Features include cognitive games, daily habits, focus rooms (real-time multiplayer), book reading with AI-generated retention tests, a diagnostic assessment, and a focus score dashboard.

## Commands

```bash
# Run on Chrome (web, fixed port 5000)
flutter run -d chrome --web-port=5000

# Run on a connected Android/iOS device
flutter run

# Build web
flutter build web

# Analyze (lint)
flutter analyze

# Run tests
flutter test

# Run a single test file
flutter test test/widget_test.dart

# Install dependencies
flutter pub get
```

## Design Source

All screen designs are Stitch (PNG frames) located at:
```
../stitch pages/stitch pages/<screen_name>/
```

Available design folders: `add_habit_flow`, `book_detail`, `book_reader`, `color_match`, `create_room_flow`, `dashboard`, `deep_focus`, `diagnostic_attention_task`, `diagnostic_intro`, `diagnostic_results`, `diagnostic_self_report`, `focus_rooms`, `games_hub`, `habits`, `level_roadmap`, `live_session`, `login`, `memory_matrix`, `my_library`, `number_stream`, `onboarding_quiz`, `pattern_trail`, `profile`, `retention_test`, `sign_up`, `speed_match`, `sudoku`, `train_of_thought`.

**When implementing or modifying any screen, read ALL images in the corresponding design folder first.** Match the design exactly — colors, spacing, font sizes, and layout. Extract any new colors into `AppColors` (`core/constants/app_colors.dart`) rather than hardcoding them inline.

## Architecture

### Directory Structure

```
lib/
  main.dart              # App entry point, Provider setup, routing
  core/
    constants/
      app_colors.dart    # Shared color palette
      app_config.dart    # Backend base URL constant
    services/
      auth_service.dart  # JWT storage (SharedPreferences) + login/signup/logout HTTP calls
    utils/
      url_helper.dart    # Conditional export: stub (mobile) or web impl
    widgets/
      auth_background.dart
  features/              # One folder per product feature
    auth/
    books/
    diagnostic/
    focus_session/       # Focus Rooms feature
    games/
    habits/
    home/
    profile/
    question/
    ai_flutter/          # AI-powered retention tests for books
```

Each feature follows a consistent internal layout:
```
feature/
  models/      # Plain Dart data classes with fromJson/toJson
  pages/       # Full-screen widgets (routed to)
  services/    # Static classes that make HTTP calls
  providers/   # ChangeNotifier classes consumed via Provider
  widgets/     # Sub-widgets scoped to this feature (every new widget lives here)
```

### State Management

Provider pattern with two global providers initialized in `main()`:
- `UserProvider` — authentication state, user profile, focus score. Loads from SharedPreferences first (instant), then refreshes from API in background.
- `HabitProvider` — daily habits list with optimistic updates.

Services are stateless static classes; only providers hold mutable state.

### Authentication Flow

1. JWT token stored via `AuthService` in `SharedPreferences` under `auth_token`.
2. All API calls attach `Authorization: Bearer $token` headers.
3. Google OAuth callback is detected in `main.dart` `onGenerateRoute` by inspecting the URL hash/query for `token=` or `/oauth-callback`.
4. On 401/403 from the API, `UserProvider._refreshFromApi()` auto-logs out.

### Backend

- Base URL: `https://focusprobackend.onrender.com` (defined in `core/constants/app_config.dart` and mirrored in `AuthService.baseUrl`).
- REST for all data operations; WebSocket (STOMP over `wss://`) for Focus Rooms real-time events via `stomp_dart_client`.
- WebSocket URL is derived by replacing `https://` with `wss://` and appending `/ws`.

### Games System

`lib/features/games/hub/models/game_registry.dart` is the single source of truth for all games. To add a new game:
1. Append a `GameItem` to `GameRegistry.all`.
2. Add a case in `GameRegistry.pageFor` (and `GameRegistry.levelPageFor` if it has levels).

`GameProgressService` manages level unlocks: SharedPreferences is the local source of truth; backend is synced via `POST /game/result` on each game completion and `GET /game/progress` on login.

Games with a level roadmap (10 levels each): `memory_matrix`, `number_stream`, `pattern_trail`, `train_of_thought`.

### Platform Conditional Code

`url_helper.dart` uses a conditional export to swap implementations:
- `url_helper_stub.dart` — no-op stubs for mobile/desktop
- `url_helper_web.dart` — uses `dart:html` to read `window.location`

Use the same pattern for any `dart:html`-dependent code.

## Implementation Rules

- **Design fidelity**: Always read the Stitch design images before writing any UI code. Match colors, spacing, font sizes, and layout exactly.
- **Colors**: New colors go in `core/constants/app_colors.dart` as static constants — never hardcode hex values inline.
- **State management**: Provider only. Do not introduce Riverpod, Bloc, or GetX.
- **Widget placement**: Every new widget for a screen belongs in that feature's own `widgets/` subfolder.
- **Post-implementation**: Run `flutter analyze` after every screen implementation and fix all warnings before considering the task done.
