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

import 'package:flutter_test/flutter_test.dart';
import 'package:wger/features/script_import/models/script_import_data.dart';

void main() {
  group('ScriptImportData models', () {
    test('ScriptAction parses valid strings and throws on invalid', () {
      expect(ScriptAction.fromString(null), equals(ScriptAction.create));
      expect(ScriptAction.fromString('create'), equals(ScriptAction.create));
      expect(ScriptAction.fromString('CREATE'), equals(ScriptAction.create));
      expect(ScriptAction.fromString('update'), equals(ScriptAction.update));
      expect(ScriptAction.fromString('UPDATE'), equals(ScriptAction.update));
      expect(() => ScriptAction.fromString('delete'), throwsArgumentError);
    });

    test('RoutineImport computes totalExercises across days and slots', () {
      final routine = RoutineImport(
        name: 'Split',
        line: 1,
        days: [
          DayImport(
            name: 'Day 1',
            line: 2,
            slots: [
              SlotImport(
                line: 3,
                entries: [
                  SlotEntryImport(exercise: 'Bench', line: 4),
                  SlotEntryImport(exercise: 'Incline Bench', line: 5),
                ],
              ),
              SlotImport(
                line: 6,
                entries: [
                  SlotEntryImport(exercise: 'Triceps Pushdown', line: 7),
                ],
              ),
            ],
          ),
          DayImport(
            name: 'Day 2',
            line: 8,
            slots: [
              SlotImport(
                line: 9,
                entries: [
                  SlotEntryImport(exercise: 'Squat', line: 10),
                ],
              ),
            ],
          ),
        ],
      );

      expect(routine.totalExercises, equals(4));
    });

    test('NutritionPlanImport computes totalIngredients across meals', () {
      final plan = NutritionPlanImport(
        description: 'Bulking',
        line: 1,
        meals: [
          MealImport(
            name: 'Breakfast',
            line: 2,
            items: [
              MealItemImport(ingredient: 'Oats', amount: 100, line: 3),
              MealItemImport(ingredient: 'Milk', amount: 200, line: 4),
            ],
          ),
          MealImport(
            name: 'Lunch',
            line: 5,
            items: [
              MealItemImport(ingredient: 'Chicken', amount: 200, line: 6),
            ],
          ),
        ],
      );

      expect(plan.totalIngredients, equals(3));
    });

    test('ScriptImportPayload isEmpty reflects presence of routines and plans', () {
      const emptyPayload = ScriptImportPayload(schemaVersion: 1);
      expect(emptyPayload.isEmpty, isTrue);

      const withRoutine = ScriptImportPayload(
        schemaVersion: 1,
        routines: [RoutineImport(name: 'Test', line: 2)],
      );
      expect(withRoutine.isEmpty, isFalse);
    });
  });
}
