/*
 * This file is part of wger Workout Manager <https://github.com/wger-project>.
 * Copyright (c) 2026 wger Team
 *
 * wger Workout Manager is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wger/database/powersync/database.dart';
import 'package:wger/features/script_import/providers/script_import_repository.dart';
import 'package:wger/features/script_import/screens/script_import_screen.dart';
import 'package:wger/features/script_import/widgets/ai_prompt_card.dart';
import 'package:wger/l10n/generated/app_localizations.dart';
import 'package:wger/l10n/localizations_delegates.dart';

import '../../../../test/helpers/in_memory_drift.dart';

void main() {
  late DriftPowersyncDatabase db;
  late ScriptImportRepository repo;

  setUp(() async {
    db = await openTestDatabase();
    repo = ScriptImportRepository(db);

    final now = DateTime.now();
    await db
        .into(db.exerciseCategoryTable)
        .insert(
          ExerciseCategoryTableCompanion.insert(id: 1, name: 'Chest'),
        );
    await db
        .into(db.exerciseTable)
        .insert(
          ExerciseTableCompanion.insert(
            id: 1,
            uuid: 'bench-uuid',
            categoryId: 1,
            created: now,
            lastUpdate: now,
          ),
        );
    await db
        .into(db.exerciseTranslationTable)
        .insert(
          ExerciseTranslationTableCompanion.insert(
            id: 1,
            uuid: 'trans-uuid',
            exerciseId: 1,
            languageId: 1,
            name: 'Bench Press',
            description: 'Barbell Bench Press',
            created: now,
            lastUpdate: now,
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  Widget wrap(Widget child) => ProviderScope(
    overrides: [
      scriptImportRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );

  testWidgets('renders input field, AI card, and validates invalid script displaying errors', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const ScriptImportScreen()));
    await tester.pumpAndSettle();

    expect(find.byType(AiPromptCard), findsOneWidget);
    expect(find.byKey(const Key('script_input_field')), findsOneWidget);
    expect(find.byKey(const Key('validate_script_button')), findsOneWidget);

    // Enter invalid JSON (unsupported schema version)
    await tester.enterText(
      find.byKey(const Key('script_input_field')),
      '{\n  "schema_version": 99,\n  "routines": []\n}',
    );
    await tester.tap(find.byKey(const Key('validate_script_button')));
    await tester.pumpAndSettle();

    // Error card should appear
    expect(find.textContaining('Unsupported schema version 99'), findsOneWidget);
  });

  testWidgets('validates valid script and allows opening confirmation dialog', (tester) async {
    await tester.pumpWidget(wrap(const ScriptImportScreen()));
    await tester.pumpAndSettle();

    const validJson = '''
{
  "schema_version": 1,
  "routines": [
    {
      "name": "Upper Split",
      "days": [
        {
          "name": "Day 1",
          "slots": [
            {
              "exercises": [
                {
                  "exercise": "Bench Press",
                  "sets": 3,
                  "reps": 10
                }
              ]
            }
          ]
        }
      ]
    }
  ]
}''';

    await tester.enterText(find.byKey(const Key('script_input_field')), validJson);
    await tester.tap(find.byKey(const Key('validate_script_button')));
    await tester.pumpAndSettle();

    // Preview card should appear
    expect(find.text('Import preview'), findsOneWidget);
    expect(find.textContaining('Upper Split'), findsNWidgets(2));
    expect(find.byKey(const Key('save_imported_script_button')), findsOneWidget);

    // Scroll until visible and tap save button -> confirmation dialog should open
    await tester.ensureVisible(find.byKey(const Key('save_imported_script_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save_imported_script_button')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Confirm Import'),
      ),
      findsWidgets,
    );
  });
}
