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

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wger/database/powersync/database.dart';
import 'package:wger/features/script_import/models/script_import_data.dart';
import 'package:wger/features/script_import/providers/script_import_repository.dart';

import '../../../../test/helpers/in_memory_drift.dart';

void main() {
  late DriftPowersyncDatabase db;
  late ScriptImportRepository repo;

  setUp(() async {
    db = await openTestDatabase();
    repo = ScriptImportRepository(db);

    final now = DateTime.now();

    // Seed test category
    await db
        .into(db.exerciseCategoryTable)
        .insert(
          ExerciseCategoryTableCompanion.insert(id: 1, name: 'Chest'),
        );

    // Seed test exercise
    await db
        .into(db.exerciseTable)
        .insert(
          ExerciseTableCompanion.insert(
            id: 10,
            uuid: 'bench-uuid-123',
            categoryId: 1,
            created: now,
            lastUpdate: now,
          ),
        );

    // Seed exercise translation (Bench Press)
    await db
        .into(db.exerciseTranslationTable)
        .insert(
          ExerciseTranslationTableCompanion.insert(
            id: 1,
            uuid: 'trans-uuid-123',
            exerciseId: 10,
            languageId: 1,
            name: 'Bench Press',
            description: 'Barbell bench press',
            created: now,
            lastUpdate: now,
          ),
        );

    // Seed exercise alias
    await db
        .into(db.exerciseAliasTable)
        .insert(
          ExerciseAliasTableCompanion.insert(
            id: 1,
            uuid: 'alias-uuid-123',
            translationId: 1,
            alias: 'Flat Bench',
          ),
        );

    // Seed ingredient (Oats)
    await db
        .into(db.ingredientTable)
        .insert(
          IngredientTableCompanion(
            id: const Value(5),
            uuid: const Value('oats-uuid-123'),
            languageId: const Value(1),
            name: const Value('Oats'),
            code: const Value('400840012345'),
            created: Value(now),
            energy: const Value(360),
            carbohydrates: const Value(60.0),
            protein: const Value(12.0),
            fat: const Value(7.0),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('ScriptImportRepository reference resolution', () {
    test('resolves exercises by name, ID, UUID, and alias', () async {
      final payload = ScriptImportPayload(
        schemaVersion: 1,
        routines: [
          RoutineImport(
            name: 'Chest Routine',
            line: 1,
            days: [
              DayImport(
                name: 'Chest Day',
                line: 2,
                slots: [
                  SlotImport(
                    line: 3,
                    entries: [
                      SlotEntryImport(exercise: 'Bench Press', line: 4),
                      SlotEntryImport(exercise: 10, line: 5),
                      SlotEntryImport(exercise: 'bench-uuid-123', line: 6),
                      SlotEntryImport(exercise: 'Flat Bench', line: 7),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      final errors = await repo.resolveReferences(payload);
      expect(errors, isEmpty);

      final entries = payload.routines.first.days.first.slots.first.entries;
      expect(entries[0].resolvedExerciseId, equals(10));
      expect(entries[1].resolvedExerciseId, equals(10));
      expect(entries[2].resolvedExerciseId, equals(10));
      expect(entries[3].resolvedExerciseId, equals(10));
    });

    test('resolves ingredients by name, ID, UUID, and barcode', () async {
      final payload = ScriptImportPayload(
        schemaVersion: 1,
        nutritionPlans: [
          NutritionPlanImport(
            description: 'Diet',
            line: 1,
            meals: [
              MealImport(
                name: 'Breakfast',
                line: 2,
                items: [
                  MealItemImport(ingredient: 'Oats', amount: 100, line: 3),
                  MealItemImport(ingredient: 5, amount: 80, line: 4),
                  MealItemImport(ingredient: 'oats-uuid-123', amount: 60, line: 5),
                  MealItemImport(ingredient: '400840012345', amount: 50, line: 6),
                ],
              ),
            ],
          ),
        ],
      );

      final errors = await repo.resolveReferences(payload);
      expect(errors, isEmpty);

      final items = payload.nutritionPlans.first.meals.first.items;
      expect(items[0].resolvedIngredientId, equals(5));
      expect(items[1].resolvedIngredientId, equals(5));
      expect(items[2].resolvedIngredientId, equals(5));
      expect(items[3].resolvedIngredientId, equals(5));
    });

    test('reports missing exercise with exact line and field path', () async {
      final payload = ScriptImportPayload(
        schemaVersion: 1,
        routines: [
          RoutineImport(
            name: 'Routine',
            line: 1,
            days: [
              DayImport(
                name: 'Day',
                line: 2,
                slots: [
                  SlotImport(
                    line: 3,
                    entries: [
                      SlotEntryImport(exercise: 'Nonexistent Lift', line: 18),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      final errors = await repo.resolveReferences(payload);
      expect(errors.length, equals(1));
      expect(errors.first.line, equals(18));
      expect(errors.first.path, equals('routines[0].days[0].slots[0].exercises[0].exercise'));
      expect(errors.first.message, contains('Exercise "Nonexistent Lift" not found'));
    });

    test('reports missing ingredient with exact line and field path', () async {
      final payload = ScriptImportPayload(
        schemaVersion: 1,
        nutritionPlans: [
          NutritionPlanImport(
            description: 'Diet Plan',
            line: 1,
            meals: [
              MealImport(
                name: 'Lunch',
                line: 2,
                items: [
                  MealItemImport(ingredient: 'Unknown Shake', amount: 300, line: 27),
                ],
              ),
            ],
          ),
        ],
      );

      final errors = await repo.resolveReferences(payload);
      expect(errors.length, equals(1));
      expect(errors.first.line, equals(27));
      expect(errors.first.path, equals('nutrition_plans[0].meals[0].items[0].ingredient'));
      expect(errors.first.message, contains('Ingredient "Unknown Shake" not found'));
    });

    test('reports error when updating a non-existent routine', () async {
      const payload = ScriptImportPayload(
        schemaVersion: 1,
        routines: [
          RoutineImport(
            action: ScriptAction.update,
            id: 9999,
            name: 'Missing Routine',
            line: 5,
          ),
        ],
      );

      final errors = await repo.resolveReferences(payload);
      expect(errors.length, equals(1));
      expect(errors.first.line, equals(5));
      expect(errors.first.path, equals('routines[0]'));
      expect(errors.first.message, contains('was not found in local database'));
    });
  });

  group('ScriptImportRepository savePayload', () {
    test('transactionally creates routine and nutrition plan in Drift tables', () async {
      final payload = ScriptImportPayload(
        schemaVersion: 1,
        routines: [
          RoutineImport(
            name: 'Imported Routine',
            description: 'Created via script',
            line: 1,
            days: [
              DayImport(
                name: 'Legs',
                line: 2,
                slots: [
                  SlotImport(
                    order: 1,
                    line: 3,
                    entries: [
                      SlotEntryImport(
                        exercise: 'Bench Press',
                        resolvedExerciseId: 10,
                        sets: 4,
                        reps: 8,
                        weight: 75.0,
                        line: 4,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
        nutritionPlans: [
          NutritionPlanImport(
            description: 'Imported Diet',
            goalEnergy: 2200,
            goalProtein: 150,
            line: 5,
            meals: [
              MealImport(
                name: 'Breakfast',
                time: '08:00',
                order: 1,
                line: 6,
                items: [
                  MealItemImport(
                    ingredient: 'Oats',
                    resolvedIngredientId: 5,
                    amount: 80,
                    line: 7,
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      final result = await repo.savePayload(payload);
      expect(result.importedRoutines.length, equals(1));
      expect(result.importedPlans.length, equals(1));

      // Verify Routine in Drift
      final routinesInDb = await db.select(db.routineTable).get();
      expect(routinesInDb.length, equals(1));
      expect(routinesInDb.first.name, equals('Imported Routine'));
      expect(routinesInDb.first.description, equals('Created via script'));

      // Verify returned hydrated Routine has days and exercises for prefetchRoutineMedia
      final hydratedRoutine = result.importedRoutines.first;
      expect(hydratedRoutine.days.length, equals(1));
      expect(hydratedRoutine.days.first.slots.first.entries.first.exerciseId, equals(10));

      // Verify NutritionPlan in Drift
      final plansInDb = await db.select(db.nutritionalPlanTable).get();
      expect(plansInDb.length, equals(1));
      expect(plansInDb.first.description, equals('Imported Diet'));
      expect(plansInDb.first.goalEnergy, equals(2200));

      // Verify Meal and MealItem in Drift
      final mealsInDb = await db.select(db.mealTable).get();
      expect(mealsInDb.length, equals(1));
      expect(mealsInDb.first.name, equals('Breakfast'));

      final itemsInDb = await db.select(db.mealItemTable).get();
      expect(itemsInDb.length, equals(1));
      expect(itemsInDb.first.ingredientId, equals(5));
      expect(itemsInDb.first.amount, equals(80.0));
    });

    test('updates existing routine and plan when action is update', () async {
      // First insert an existing routine and plan
      final now = DateTime.now();
      await db
          .into(db.routineTable)
          .insert(
            RoutineTableCompanion.insert(
              id: 42,
              name: 'Old Routine Name',
              description: 'Old description',
              created: now,
              start: DateTime.utc(2026, 1, 1),
              end: DateTime.utc(2026, 3, 1),
              isTemplate: false,
              isPublic: false,
              fitInWeek: false,
            ),
          );

      await db
          .into(db.nutritionalPlanTable)
          .insert(
            NutritionalPlanTableCompanion.insert(
              id: const Value('plan-uuid-existing'),
              description: 'Old Plan Name',
              creationDate: now,
              startDate: DateTime.utc(2026, 1, 1),
              onlyLogging: false,
              hasGoalCalories: false,
            ),
          );

      const payload = ScriptImportPayload(
        schemaVersion: 1,
        routines: [
          RoutineImport(
            action: ScriptAction.update,
            id: 42,
            name: 'Updated Routine Name',
            description: 'Updated description',
            line: 1,
          ),
        ],
        nutritionPlans: [
          NutritionPlanImport(
            action: ScriptAction.update,
            id: 'plan-uuid-existing',
            description: 'Updated Plan Name',
            goalEnergy: 2400,
            line: 2,
          ),
        ],
      );

      await repo.savePayload(payload);

      final updatedRoutine = await (db.select(
        db.routineTable,
      )..where((t) => t.id.equals(42))).getSingle();
      expect(updatedRoutine.name, equals('Updated Routine Name'));
      expect(updatedRoutine.description, equals('Updated description'));

      final updatedPlan = await (db.select(
        db.nutritionalPlanTable,
      )..where((t) => t.id.equals('plan-uuid-existing'))).getSingle();
      expect(updatedPlan.description, equals('Updated Plan Name'));
      expect(updatedPlan.goalEnergy, equals(2400));
    });
  });
}
