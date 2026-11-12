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
import 'package:wger/features/script_import/models/script_validator.dart';

void main() {
  group('ScriptValidator', () {
    test('reports error for empty input', () {
      final result = ScriptValidator.validateString('   ');
      expect(result.isValid, isFalse);
      expect(result.errors.length, equals(1));
      expect(result.errors.first.line, equals(1));
      expect(result.errors.first.path, equals('root'));
      expect(result.errors.first.message, contains('empty'));
    });

    test('asserts missing schema_version with line and path', () {
      const json = '''
{
  "routines": [
    {
      "name": "Full Body",
      "days": []
    }
  ]
}''';
      final result = ScriptValidator.validateString(json);
      expect(result.isValid, isFalse);
      final err = result.errors.firstWhere((e) => e.path == 'schema_version');
      expect(err.line, equals(1));
      expect(err.message, contains('Missing required field "schema_version"'));
    });

    test('asserts unsupported schema_version with exact line, field, and message', () {
      const json = '''
{
  "schema_version": 99,
  "routines": [
    {
      "name": "Full Body",
      "days": []
    }
  ]
}''';
      final result = ScriptValidator.validateString(json);
      expect(result.isValid, isFalse);
      final err = result.errors.firstWhere((e) => e.path == 'schema_version');
      expect(err.line, equals(2));
      expect(err.message, contains('Unsupported schema version 99'));
    });

    test('asserts non-integer schema_version with line and path', () {
      const json = '''
{
  "schema_version": "v1",
  "routines": []
}''';
      final result = ScriptValidator.validateString(json);
      expect(result.isValid, isFalse);
      final err = result.errors.firstWhere((e) => e.path == 'schema_version');
      expect(err.line, equals(2));
      expect(err.message, contains('Expected an integer for "schema_version"'));
    });

    test('asserts invalid type for sets with exact line and field path', () {
      const json = '''
{
  "schema_version": 1,
  "routines": [
    {
      "name": "Leg Day",
      "days": [
        {
          "name": "Quads",
          "slots": [
            {
              "order": 1,
              "exercises": [
                {
                  "exercise": "Squat",
                  "sets": "four",
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
      final result = ScriptValidator.validateString(json);
      expect(result.isValid, isFalse);
      final err = result.errors.firstWhere(
        (e) => e.path == 'routines[0].days[0].slots[0].exercises[0].sets',
      );
      expect(err.line, equals(15));
      expect(err.message, contains('Expected an integer, got string'));
      expect(
        err.formattedMessage,
        equals(
          'Line 15, field "routines[0].days[0].slots[0].exercises[0].sets": Expected an integer, got string',
        ),
      );
    });

    test('asserts routine name length limit > 25 characters', () {
      const json = '''
{
  "schema_version": 1,
  "routines": [
    {
      "name": "This is a super long routine name exceeding 25 chars",
      "days": []
    }
  ]
}''';
      final result = ScriptValidator.validateString(json);
      expect(result.isValid, isFalse);
      final err = result.errors.firstWhere((e) => e.path == 'routines[0].name');
      expect(err.line, equals(5));
      expect(err.message, contains('at most 25 characters'));
    });

    test('unknown top-level fields generate warnings and do not fail validation', () {
      const json = '''
{
  "schema_version": 1,
  "author_name": "Coach John",
  "experimental_flag": true,
  "routines": [
    {
      "name": "Push Day",
      "days": [
        {
          "name": "Push",
          "slots": [
            {
              "exercises": [
                {
                  "exercise": "Push-up",
                  "sets": 3,
                  "reps": 15
                }
              ]
            }
          ]
        }
      ]
    }
  ]
}''';
      final result = ScriptValidator.validateString(json);
      expect(result.isValid, isTrue);
      expect(result.warnings.length, equals(2));
      expect(result.warnings.any((w) => w.contains('author_name')), isTrue);
      expect(result.warnings.any((w) => w.contains('experimental_flag')), isTrue);
    });

    test('parses full valid routine and nutrition plan script', () {
      const json = '''
{
  "schema_version": 1,
  "meta": {
    "description": "Complete fitness and diet protocol"
  },
  "routines": [
    {
      "action": "create",
      "name": "Upper Lower",
      "description": "Hypertrophy routine",
      "start": "2026-11-15",
      "end": "2027-02-15",
      "fit_in_week": true,
      "days": [
        {
          "name": "Upper A",
          "description": "Chest and back",
          "day_type": "custom",
          "order": 1,
          "slots": [
            {
              "order": 1,
              "comment": "Main lift",
              "alarm": 90,
              "exercises": [
                {
                  "exercise": "Bench Press",
                  "sets": 4,
                  "reps": 8,
                  "repetition_unit": "reps",
                  "weight": 80.0,
                  "weight_unit": "kg",
                  "rest_time": 90,
                  "rir": 1.5,
                  "comment": "Pause at chest"
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
      "action": "update",
      "id": "018e4b85-0000-7000-8000-000000000001",
      "description": "Cutting 2000 kcal",
      "goal_calories": 2000,
      "goal_protein": 160,
      "meals": [
        {
          "name": "Breakfast",
          "time": "08:30",
          "items": [
            {
              "ingredient": "Rolled Oats",
              "amount": 80.0,
              "unit": "g"
            }
          ]
        }
      ]
    }
  ]
}''';
      final result = ScriptValidator.validateString(json);
      expect(result.isValid, isTrue);

      final payload = result.payload!;
      expect(payload.schemaVersion, equals(1));
      expect(payload.metaDescription, equals('Complete fitness and diet protocol'));

      // Routine checks
      expect(payload.routines.length, equals(1));
      final routine = payload.routines.first;
      expect(routine.name, equals('Upper Lower'));
      expect(routine.action, equals(ScriptAction.create));
      expect(routine.days.length, equals(1));
      final day = routine.days.first;
      expect(day.name, equals('Upper A'));
      expect(day.slots.length, equals(1));
      final slot = day.slots.first;
      expect(slot.alarm, equals(90));
      expect(slot.entries.length, equals(1));
      final entry = slot.entries.first;
      expect(entry.exercise, equals('Bench Press'));
      expect(entry.sets, equals(4));
      expect(entry.reps, equals(8));
      expect(entry.weight, equals(80.0));
      expect(entry.weightUnit, equals('kg'));
      expect(entry.rir, equals(1.5));

      // Nutrition plan checks
      expect(payload.nutritionPlans.length, equals(1));
      final plan = payload.nutritionPlans.first;
      expect(plan.action, equals(ScriptAction.update));
      expect(plan.id, equals('018e4b85-0000-7000-8000-000000000001'));
      expect(plan.description, equals('Cutting 2000 kcal'));
      expect(plan.goalEnergy, equals(2000));
      expect(plan.goalProtein, equals(160));
      expect(plan.meals.length, equals(1));
      final meal = plan.meals.first;
      expect(meal.name, equals('Breakfast'));
      expect(meal.time, equals('08:30'));
      expect(meal.items.length, equals(1));
      final item = meal.items.first;
      expect(item.ingredient, equals('Rolled Oats'));
      expect(item.amount, equals(80.0));
    });
  });
}
