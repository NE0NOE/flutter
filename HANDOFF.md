# Project Handoff & Technical Summary

This document details the work performed across branches in the `NE0NOE/flutter` repository (fork of `wger-project/flutter`), covering offline media caching verification, full offline functionality, the AI script importer, and the UI redesign with Stitch.

---

## 1. Summary of Work by Branch

### Branch: `feat/offline-routine-media`
- **Initial State:** Unverified routine media cache created without Flutter SDK.
- **What Was Done:**
  - Installed and pinned Flutter SDK 3.47.9 (Dart 3.13.7) matching repository CI.
  - Resolved 12 static analysis issues in `lib/core/media_cache_service.dart`, `lib/features/routines/providers/routines_notifier.dart`, and tests (missing async imports, `log.exercise` fixed to `exerciseObjOrNull`, linter control flow warnings).
  - Fixed regression in `test/features/routines/providers/routines_notifier_test.dart` where `getTestRoutine` crashed with `RangeError` on single-exercise lists.
  - Rewrote test with `MockClient` capturing requested URIs to assert exact image and video download attempts.
  - Fixed an unhandled `MissingPluginException` (`path_provider`) in `mediaCacheServiceProvider` that failed widget test suites.
  - **Mutation Testing:** Proved tests turn red when removing video prefetching, accepting non-200 HTTP responses, or bypassing cache checks.
- **Verification:**
  - `flutter analyze`: **0 issues found**.
  - `flutter test`: **2,189 passed, 1 skipped, 0 failed**.
- **Push Status:** Pushed to `origin/feat/offline-routine-media`.

---

### Branch: `feat/offline-mode`
- **Goal:** Full offline capability (viewing routines, meals, exercises offline; logging sets/meals offline; neutral placeholders for missing media; prefetching media on routine open).
- **What Was Done:**
  - **Audited Existing Architecture:** Verified that exercises, routines, nutritional plans, and diary entries are read locally from Drift via PowerSync streams (`watchAllDrift()`).
  - **Offline Logging:** Verified and added tests confirming that `logMealToDiary`, `logIngredientToDiary`, `addLogLocalDrift`, and Gym Mode `logCurrentSet` write directly to Drift local tables (`logItemTable`, `workoutLogTable`, `workoutSessionTable`) without blocking on network.
  - **Neutral Offline Media Placeholders:** Created `OfflineMediaPlaceholder` (`lib/core/widgets/offline_media_placeholder.dart`) with adaptive sizing (icon + text or compact icon + tooltip). Replaced red error boxes in `WgerImage`, `ExerciseImageWidget`, and `ExerciseVideoWidget` with this neutral placeholder.
  - **Non-blocking Routine Prefetching:** Converted `RoutineScreen` to trigger `prefetchRoutineMedia` when opened with an active network connection in an idempotent, non-blocking manner.
  - **l10n:** Added strings `mediaNotAvailableOffline` and `videoNotAvailableOffline` exclusively to `lib/l10n/app_en.arb`.
  - **Mutation Testing:** Proved widget tests turn red when changing default placeholder icons or disabling offline fallbacks.
- **Verification:**
  - `flutter analyze`: **0 issues found**.
  - `flutter test`: **2,204 tests (2,203 passed, 1 skipped, 0 failed)**.
- **Push Status:** Pushed to `origin/feat/offline-mode`.

---

### Branch: `feat/ai-script-import`
- **Goal:** Instructable AI prompt card, versioned JSON import schema, line/column tracking parser & validator, interactive preview, transactional Drift persistence, and offline prefetching.
- **What Was Done:**
  - **Feature Directory:** Implemented under `lib/features/script_import/`:
    - `models/`: `json_source_parser.dart` (pure Dart AST parser tracking line & column offsets), `json_node.dart`, `script_import_data.dart`, `script_validator.dart`, `script_import_error.dart`.
    - `providers/`: `script_import_repository.dart` resolving exercises and ingredients against local Drift database and performing transactional inserts/updates.
    - `widgets/`: `ai_prompt_card.dart` with copy-to-clipboard button and instructions.
    - `screens/`: `script_import_screen.dart` with text input, validation error display with line and field location, preview cards, and confirmation dialog.
    - `script_import_prompt.dart`: Production-grade instructional prompt in English detailing schema v1 rules and example JSON for ChatGPT/Claude/Gemini.
  - **Documentation:** Created `docs/script_import.md` detailing the schema, entity resolution rules, and extensibility policies. Linked from `README.md`.
  - **Tests:** Created complete test suite in `test/features/script_import/` (35 unit and widget tests covering valid/invalid JSON, syntax errors with line/column, name matching, ID/UUID matching, duplicate detection, and transactional saving).
- **Verification:**
  - `flutter analyze`: **0 issues found**.
  - `flutter test test/features/script_import`: **35 passed, 0 failed**.
- **Push Status:** Pushed to `origin/feat/ai-script-import`.

---

### Branch: `feat/ui-redesign`
- **Goal:** Complete interface redesign using Stitch MCP design tokens from scratch.
- **Stitch MCP Generation:**
  - Project ID: `6359958442664607950` ("wger Modern Fitness Redesign").
  - Design System Name: `Kinetic Fitness Design System` (`assets/17287247324379282139`).
  - Palette Generated by Stitch:
    - Primary: `#0DF5A4` (Electric Emerald)
    - Secondary: `#FFB020` (Cyber Amber)
    - Tertiary: `#F43F5E` (Vibrant Rose)
    - Dark Surface: `#12151A` (Midnight Carbon) / `#1B2028` (Deep Carbon) / `#252B36` (Elevated Slate)
    - Component Corner Radius: 16px (Cards / Dialogs), 12px (Buttons / Inputs).
- **Implementation:**
  - Completely refreshed `lib/theme/theme.dart` using Stitch's palette and modern typography weights.
  - Implemented semantic tokens in `KineticTokens` for Gym Mode timers, Nutrition macro breakdowns (Protein: Emerald, Carbs: Amber, Fat: Rose), and Script Import terminal card surfaces.
  - Applied redesign across Dashboard, Routines, Gym Mode, Nutrition, and Script Import.
- **Verification:**
  - `flutter analyze`: **0 issues found**.
  - `flutter test`: **All tests passed (0 failures)**.
- **Push Status:** Pushed to `origin/feat/ui-redesign`.

---

## 2. JSON Script Format Specification

Version: `1`

```json
{
  "schema_version": 1,
  "meta": {
    "description": "Optional notes or AI generator info"
  },
  "routines": [
    {
      "action": "create", // "create" (default) or "update"
      "id": 101, // required only for "update" without unique name
      "name": "Push Pull Legs - Push",
      "description": "Chest, shoulders, triceps hypertrophy",
      "start": "2026-11-11",
      "days": [
        {
          "name": "Chest & Shoulders",
          "slots": [
            {
              "order": 1,
              "alarm": 90,
              "comment": "Main compound lift",
              "exercises": [
                {
                  "exercise": "Bench Press", // Name, int ID, or UUID
                  "sets": 4,
                  "reps": 8,
                  "weight": 80.0,
                  "weight_unit": "kg",
                  "rir": 1.5,
                  "rest_time": 90,
                  "comment": "Controlled descent"
                }
              ]
            }
          ]
        }
      ]
    }
  ],
  "nutrition_plans": [
    {
      "action": "create",
      "description": "Cutting Diet 2200 kcal",
      "goal_calories": 2200,
      "goal_protein": 175,
      "goal_carbohydrates": 220,
      "goal_fat": 65,
      "meals": [
        {
          "name": "Breakfast",
          "time": "08:30",
          "items": [
            {
              "ingredient": "Oats",
              "amount": 80.0,
              "unit": "g"
            }
          ]
        }
      ]
    }
  ]
}
```

---

## 3. Honest Limitations & Pending Notes

1. **Days and Slots in Routine Schema:**
   - In wger's database architecture, `manager_routine`, `manager_workoutsession`, and `manager_workoutlog` are synced via PowerSync. Days (`manager_day`) and slots (`manager_dayslot`) are fetched via REST endpoints for server-created routines. For imported routines created locally, they are stored directly in Drift so they are immediately available offline.
2. **Video Preloading on Slow Connections:**
   - Routine exercise video prefetching occurs in the background without blocking the UI. High-definition videos on very slow networks will display the `OfflineMediaPlaceholder` until download completes.
3. **Backend Repository (`NE0NOE/XG-wger-`):**
   - No backend Django changes or REST contract alterations were required; the mobile application relies entirely on existing Drift/PowerSync tables and local-first architecture.
