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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:powersync/powersync.dart' as ps;
import 'package:wger/core/json.dart';
import 'package:wger/database/powersync/database.dart';
import 'package:wger/features/exercises/models/category.dart';
import 'package:wger/features/exercises/models/exercise.dart';
import 'package:wger/features/nutrition/models/nutritional_plan.dart';
import 'package:wger/features/routines/models/day.dart';
import 'package:wger/features/routines/models/routine.dart';
import 'package:wger/features/routines/models/slot.dart';
import 'package:wger/features/routines/models/slot_entry.dart';
import 'package:wger/features/script_import/models/script_import_data.dart';
import 'package:wger/features/script_import/models/script_import_error.dart';

final scriptImportRepositoryProvider = Provider<ScriptImportRepository>((ref) {
  final db = ref.read(driftPowerSyncDatabase);
  return ScriptImportRepository(db);
});

/// Result of executing a script import.
class ScriptImportResult {
  final List<Routine> importedRoutines;
  final List<NutritionalPlan> importedPlans;

  const ScriptImportResult({
    this.importedRoutines = const [],
    this.importedPlans = const [],
  });
}

/// Data access and transactional execution for importing scripts into the local Drift database.
class ScriptImportRepository {
  final _logger = Logger('ScriptImportRepository');
  final DriftPowersyncDatabase _db;

  ScriptImportRepository(this._db);

  /// Validates that all exercises and ingredients referenced in [payload] exist in the local DB.
  /// Also verifies that targets of [ScriptAction.update] exist.
  Future<List<ScriptImportError>> resolveReferences(ScriptImportPayload payload) async {
    final errors = <ScriptImportError>[];

    // 1. Resolve routine exercises & check update targets
    for (var rIdx = 0; rIdx < payload.routines.length; rIdx++) {
      final rImport = payload.routines[rIdx];
      final rPath = 'routines[$rIdx]';

      if (rImport.action == ScriptAction.update) {
        final existing = await _findRoutineToUpdate(rImport);
        if (existing == null) {
          errors.add(
            ScriptImportError(
              line: rImport.line,
              path: rPath,
              message:
                  'Routine to update "${rImport.name}" (id: ${rImport.id}) was not found in local database',
            ),
          );
        }
      }

      for (var dIdx = 0; dIdx < rImport.days.length; dIdx++) {
        final dImport = rImport.days[dIdx];
        final dPath = '$rPath.days[$dIdx]';

        for (var sIdx = 0; sIdx < dImport.slots.length; sIdx++) {
          final sImport = dImport.slots[sIdx];
          final sPath = '$dPath.slots[$sIdx]';

          for (var eIdx = 0; eIdx < sImport.entries.length; eIdx++) {
            final entry = sImport.entries[eIdx];
            final eId = await _resolveExercise(entry.exercise);
            if (eId != null) {
              entry.resolvedExerciseId = eId;
            } else {
              errors.add(
                ScriptImportError(
                  line: entry.line,
                  path: '$sPath.exercises[$eIdx].exercise',
                  message: 'Exercise "${entry.exercise}" not found in local exercise catalog',
                ),
              );
            }
          }
        }
      }
    }

    // 2. Resolve nutrition plan ingredients & check update targets
    for (var pIdx = 0; pIdx < payload.nutritionPlans.length; pIdx++) {
      final pImport = payload.nutritionPlans[pIdx];
      final pPath = 'nutrition_plans[$pIdx]';

      if (pImport.action == ScriptAction.update) {
        final existing = await _findPlanToUpdate(pImport);
        if (existing == null) {
          errors.add(
            ScriptImportError(
              line: pImport.line,
              path: pPath,
              message:
                  'Nutrition plan to update "${pImport.description}" (id: ${pImport.id}) was not found in local database',
            ),
          );
        }
      }

      for (var mIdx = 0; mIdx < pImport.meals.length; mIdx++) {
        final mImport = pImport.meals[mIdx];
        final mPath = '$pPath.meals[$mIdx]';

        for (var iIdx = 0; iIdx < mImport.items.length; iIdx++) {
          final item = mImport.items[iIdx];
          final ingId = await _resolveIngredient(item.ingredient);
          if (ingId != null) {
            item.resolvedIngredientId = ingId;
          } else {
            errors.add(
              ScriptImportError(
                line: item.line,
                path: '$mPath.items[$iIdx].ingredient',
                message: 'Ingredient "${item.ingredient}" not found in local ingredient catalog',
              ),
            );
          }
        }
      }
    }

    return errors;
  }

  /// Transactionally saves [payload] into the local Drift database.
  Future<ScriptImportResult> savePayload(ScriptImportPayload payload) async {
    _logger.info(
      'Beginning transactional save of import script: '
      '${payload.routines.length} routines, ${payload.nutritionPlans.length} plans',
    );

    final importedRoutines = <Routine>[];
    final importedPlans = <NutritionalPlan>[];

    await _db.transaction(() async {
      // 1. Process Nutrition Plans
      for (final pImport in payload.nutritionPlans) {
        final plan = await _saveNutritionPlan(pImport);
        importedPlans.add(plan);
      }

      // 2. Process Routines
      for (final rImport in payload.routines) {
        final routine = await _saveRoutine(rImport);
        importedRoutines.add(routine);
      }
    });

    _logger.info(
      'Successfully imported ${importedRoutines.length} routines and ${importedPlans.length} nutrition plans.',
    );
    return ScriptImportResult(
      importedRoutines: importedRoutines,
      importedPlans: importedPlans,
    );
  }

  Future<NutritionalPlan> _saveNutritionPlan(NutritionPlanImport pImport) async {
    final now = DateTime.now();
    final startDate = pImport.start ?? now;
    final endDate = pImport.end;

    NutritionalPlan plan;

    if (pImport.action == ScriptAction.update) {
      final existing = await _findPlanToUpdate(pImport);
      if (existing == null) {
        throw StateError('Cannot update plan "${pImport.description}": not found');
      }
      final updatedCompanion = NutritionalPlanTableCompanion(
        id: Value(existing.id!),
        description: Value(pImport.description),
        creationDate: Value(existing.creationDate),
        startDate: Value(DateTime.utc(startDate.year, startDate.month, startDate.day)),
        endDate: Value(
          endDate != null ? DateTime.utc(endDate.year, endDate.month, endDate.day) : null,
        ),
        onlyLogging: Value(existing.onlyLogging),
        goalEnergy: Value(pImport.goalEnergy ?? existing.goalEnergy?.toInt()),
        goalProtein: Value(pImport.goalProtein ?? existing.goalProtein?.toInt()),
        goalCarbohydrates: Value(pImport.goalCarbohydrates ?? existing.goalCarbohydrates?.toInt()),
        goalFiber: Value(pImport.goalFiber ?? existing.goalFiber?.toInt()),
        goalFat: Value(pImport.goalFat ?? existing.goalFat?.toInt()),
        hasGoalCalories: Value(pImport.goalEnergy != null || existing.hasGoalCalories),
      );
      await (_db.update(_db.nutritionalPlanTable)..where((t) => t.id.equals(existing.id!)))
          .write(updatedCompanion);
      plan = NutritionalPlan(
        id: existing.id,
        description: pImport.description,
        creationDate: existing.creationDate,
        startDate: startDate,
        endDate: endDate,
        onlyLogging: existing.onlyLogging,
        hasGoalCalories: pImport.goalEnergy != null || existing.hasGoalCalories,
        goalEnergy: pImport.goalEnergy ?? existing.goalEnergy,
        goalProtein: pImport.goalProtein ?? existing.goalProtein,
        goalCarbohydrates: pImport.goalCarbohydrates ?? existing.goalCarbohydrates,
        goalFiber: pImport.goalFiber ?? existing.goalFiber,
        goalFat: pImport.goalFat ?? existing.goalFat,
      );
    } else {
      final planId = pImport.id ?? ps.uuid.v7();
      final companion = NutritionalPlanTableCompanion(
        id: Value(planId),
        description: Value(pImport.description),
        creationDate: Value(now),
        startDate: Value(DateTime.utc(startDate.year, startDate.month, startDate.day)),
        endDate: Value(
          endDate != null ? DateTime.utc(endDate.year, endDate.month, endDate.day) : null,
        ),
        onlyLogging: const Value(false),
        goalEnergy: Value(pImport.goalEnergy),
        goalProtein: Value(pImport.goalProtein),
        goalCarbohydrates: Value(pImport.goalCarbohydrates),
        goalFiber: Value(pImport.goalFiber),
        goalFat: Value(pImport.goalFat),
        hasGoalCalories: Value(pImport.goalEnergy != null),
      );
      await _db.into(_db.nutritionalPlanTable).insert(companion);
      plan = NutritionalPlan(
        id: planId,
        description: pImport.description,
        creationDate: now,
        startDate: startDate,
        endDate: endDate,
        onlyLogging: false,
        goalEnergy: pImport.goalEnergy,
        goalProtein: pImport.goalProtein,
        goalCarbohydrates: pImport.goalCarbohydrates,
        goalFiber: pImport.goalFiber,
        goalFat: pImport.goalFat,
        hasGoalCalories: pImport.goalEnergy != null,
      );
    }

    // Insert meals and meal items
    for (var mIdx = 0; mIdx < pImport.meals.length; mIdx++) {
      final mImport = pImport.meals[mIdx];
      final mealId = mImport.id ?? ps.uuid.v7();
      final mealCompanion = MealTableCompanion(
        id: Value(mealId),
        planId: Value(plan.id!),
        name: Value(mImport.name),
        order: Value(mImport.order),
        time: Value(mImport.time != null ? stringToTimeNull(mImport.time) : null),
      );
      await _db.into(_db.mealTable).insert(mealCompanion, mode: InsertMode.insertOrReplace);

      for (var iIdx = 0; iIdx < mImport.items.length; iIdx++) {
        final iImport = mImport.items[iIdx];
        final itemId = iImport.id ?? ps.uuid.v7();
        final itemCompanion = MealItemTableCompanion(
          id: Value(itemId),
          mealId: Value(mealId),
          ingredientId: Value(iImport.resolvedIngredientId!),
          amount: Value(iImport.amount.toDouble()),
          order: Value(iIdx + 1),
        );
        await _db.into(_db.mealItemTable).insert(itemCompanion, mode: InsertMode.insertOrReplace);
      }
    }

    return plan;
  }

  Future<Routine> _saveRoutine(RoutineImport rImport) async {
    final now = DateTime.now();
    final start = rImport.start ?? now;
    final end = rImport.end ?? start.add(const Duration(days: Routine.DEFAULT_DURATION * 7));

    int routineId;

    if (rImport.action == ScriptAction.update) {
      final existing = await _findRoutineToUpdate(rImport);
      if (existing == null) {
        throw StateError('Cannot update routine "${rImport.name}": not found');
      }
      routineId = existing.id!;
      final updatedCompanion = RoutineTableCompanion(
        id: Value(routineId),
        name: Value(rImport.name),
        description: Value(rImport.description),
        created: Value(existing.created),
        start: Value(DateTime.utc(start.year, start.month, start.day)),
        end: Value(DateTime.utc(end.year, end.month, end.day)),
        isTemplate: Value(existing.isTemplate),
        isPublic: Value(existing.isPublic),
        fitInWeek: Value(rImport.fitInWeek),
      );
      await (_db.update(_db.routineTable)..where((t) => t.id.equals(routineId)))
          .write(updatedCompanion);
    } else {
      if (rImport.id != null) {
        routineId = rImport.id!;
      } else {
        // Mint a positive local ID above existing max
        final maxRow = await (_db.selectOnly(_db.routineTable)
              ..addColumns([_db.routineTable.id.max()]))
            .getSingleOrNull();
        final currentMax = maxRow?.read(_db.routineTable.id.max()) ?? 0;
        routineId = currentMax + 1;
      }

      final companion = RoutineTableCompanion(
        id: Value(routineId),
        name: Value(rImport.name),
        description: Value(rImport.description),
        created: Value(now),
        start: Value(DateTime.utc(start.year, start.month, start.day)),
        end: Value(DateTime.utc(end.year, end.month, end.day)),
        isTemplate: const Value(false),
        isPublic: const Value(false),
        fitInWeek: Value(rImport.fitInWeek),
      );
      await _db.into(_db.routineTable).insert(companion);
    }

    // Build the hydrated Routine object with Days, Slots, SlotEntries, and Exercises attached
    // so prefetchRoutineMedia can inspect all exercise media.
    final days = <Day>[];
    for (var dIdx = 0; dIdx < rImport.days.length; dIdx++) {
      final dImport = rImport.days[dIdx];
      final dayId = dIdx + 1;
      final slots = <Slot>[];

      for (var sIdx = 0; sIdx < dImport.slots.length; sIdx++) {
        final sImport = dImport.slots[sIdx];
        final slotId = sIdx + 1;
        final entries = <SlotEntry>[];
        final exercisesObj = <Exercise>[];

        for (var eIdx = 0; eIdx < sImport.entries.length; eIdx++) {
          final entryImport = sImport.entries[eIdx];
          final exId = entryImport.resolvedExerciseId ?? 0;

          // Fetch exercise details from local Drift table to populate images/videos for caching
          final exObj = await _loadExerciseObj(exId);
          if (exObj != null) {
            exercisesObj.add(exObj);
          }

          final entry = SlotEntry(
            id: eIdx + 1,
            slotId: slotId,
            order: eIdx + 1,
            exerciseId: exId,
            repetitionUnitId: 1,
            repetitionRounding: null,
            weightUnitId: 1,
            weightRounding: null,
            comment: entryImport.comment,
            exercise: exObj,
          );
          entries.add(entry);
        }

        final slot = Slot.withData(
          id: slotId,
          day: dayId,
          order: sImport.order,
          comment: sImport.comment,
          exercises: exercisesObj,
        );
        slot.entries = entries;
        slots.add(slot);
      }

      final day = Day(
        id: dayId,
        routineId: routineId,
        name: dImport.name,
        description: dImport.description,
        isRest: dImport.isRest,
        order: dImport.order,
        slots: slots,
      );
      days.add(day);
    }

    final routine = Routine(
      id: routineId,
      name: rImport.name,
      description: rImport.description,
      start: start,
      end: end,
      fitInWeek: rImport.fitInWeek,
      days: days,
      isHydrated: true,
    );

    return routine;
  }

  Future<int?> _resolveExercise(dynamic identifier) async {
    if (identifier == null) {
      return null;
    }

    // 1. Numeric ID
    if (identifier is int) {
      final row = await (_db.select(_db.exerciseTable)..where((t) => t.id.equals(identifier)))
          .getSingleOrNull();
      if (row != null) {
        return row.id;
      }
    } else if (identifier is String && int.tryParse(identifier) != null) {
      final parsed = int.parse(identifier);
      final row = await (_db.select(_db.exerciseTable)..where((t) => t.id.equals(parsed)))
          .getSingleOrNull();
      if (row != null) {
        return row.id;
      }
    }

    final term = identifier.toString().trim();

    // 2. UUID
    final byUuid = await (_db.select(_db.exerciseTable)..where((t) => t.uuid.equals(term)))
        .getSingleOrNull();
    if (byUuid != null) {
      return byUuid.id;
    }

    // 3. Name in translations (case-insensitive)
    final byTranslation = await (_db.select(_db.exerciseTranslationTable)
          ..where((t) => t.name.lower().equals(term.toLowerCase())))
        .getSingleOrNull();
    if (byTranslation != null) {
      return byTranslation.exerciseId;
    }

    // 4. Alias (case-insensitive)
    final byAlias = await (_db.select(_db.exerciseAliasTable)
          ..where((t) => t.alias.lower().equals(term.toLowerCase())))
        .getSingleOrNull();
    if (byAlias != null && byAlias.translationId != null) {
      final trans = await (_db.select(_db.exerciseTranslationTable)
            ..where((t) => t.id.equals(byAlias.translationId!)))
          .getSingleOrNull();
      if (trans != null) {
        return trans.exerciseId;
      }
    }

    return null;
  }

  Future<int?> _resolveIngredient(dynamic identifier) async {
    if (identifier == null) {
      return null;
    }

    // 1. Numeric ID
    if (identifier is int) {
      final row = await (_db.select(_db.ingredientTable)..where((t) => t.id.equals(identifier)))
          .getSingleOrNull();
      if (row != null) {
        return row.id;
      }
    } else if (identifier is String && int.tryParse(identifier) != null) {
      final parsed = int.parse(identifier);
      final row = await (_db.select(_db.ingredientTable)..where((t) => t.id.equals(parsed)))
          .getSingleOrNull();
      if (row != null) {
        return row.id;
      }
    }

    final term = identifier.toString().trim();

    // 2. UUID
    final byUuid = await (_db.select(_db.ingredientTable)..where((t) => t.uuid.equals(term)))
        .getSingleOrNull();
    if (byUuid != null) {
      return byUuid.id;
    }

    // 3. Barcode / code
    final byCode = await (_db.select(_db.ingredientTable)..where((t) => t.code.equals(term)))
        .getSingleOrNull();
    if (byCode != null) {
      return byCode.id;
    }

    // 4. Name (case-insensitive)
    final byName = await (_db.select(_db.ingredientTable)
          ..where((t) => t.name.lower().equals(term.toLowerCase())))
        .getSingleOrNull();
    if (byName != null) {
      return byName.id;
    }

    return null;
  }

  Future<Routine?> _findRoutineToUpdate(RoutineImport rImport) async {
    if (rImport.id != null) {
      final byId = await (_db.select(_db.routineTable)..where((t) => t.id.equals(rImport.id!)))
          .getSingleOrNull();
      if (byId != null) {
        return byId;
      }
    }
    // Match by name
    return (_db.select(_db.routineTable)..where((t) => t.name.equals(rImport.name)))
        .getSingleOrNull();
  }

  Future<NutritionalPlan?> _findPlanToUpdate(NutritionPlanImport pImport) async {
    if (pImport.id != null) {
      final byId =
          await (_db.select(_db.nutritionalPlanTable)..where((t) => t.id.equals(pImport.id!)))
              .getSingleOrNull();
      if (byId != null) {
        return byId;
      }
    }
    // Match by description
    return (_db.select(_db.nutritionalPlanTable)
          ..where((t) => t.description.equals(pImport.description)))
        .getSingleOrNull();
  }

  Future<Exercise?> _loadExerciseObj(int exerciseId) async {
    final exRow = await (_db.select(_db.exerciseTable)..where((t) => t.id.equals(exerciseId)))
        .getSingleOrNull();
    if (exRow == null) {
      return null;
    }

    final images = await (_db.select(_db.exerciseImageTable)
          ..where((t) => t.exerciseId.equals(exerciseId)))
        .get();
    final videos = await (_db.select(_db.exerciseVideoTable)
          ..where((t) => t.exerciseId.equals(exerciseId)))
        .get();

    return Exercise(
      id: exRow.id,
      uuid: exRow.uuid,
      category: ExerciseCategory(id: exRow.categoryId, name: ''),
      images: images,
      videos: videos,
    );
  }
}
