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

/// Supported mutation actions for entities in the script.
enum ScriptAction {
  create,
  update;

  static ScriptAction fromString(String? value) {
    if (value == null || value.toLowerCase() == 'create') {
      return ScriptAction.create;
    }
    if (value.toLowerCase() == 'update') {
      return ScriptAction.update;
    }
    throw ArgumentError('Invalid action "$value", expected "create" or "update"');
  }
}

/// A parsed routine from an import script.
class RoutineImport {
  final ScriptAction action;
  final int? id;
  final String? uuid;
  final String name;
  final String description;
  final DateTime? start;
  final DateTime? end;
  final bool fitInWeek;
  final List<DayImport> days;
  final int line;

  const RoutineImport({
    this.action = ScriptAction.create,
    this.id,
    this.uuid,
    required this.name,
    this.description = '',
    this.start,
    this.end,
    this.fitInWeek = false,
    this.days = const [],
    required this.line,
  });

  int get totalExercises =>
      days.fold<int>(0, (sum, d) => sum + d.slots.fold<int>(0, (sSum, s) => sSum + s.entries.length));
}

/// A workout day inside a routine.
class DayImport {
  final String name;
  final String description;
  final String dayType;
  final bool isRest;
  final num order;
  final List<SlotImport> slots;
  final int line;

  const DayImport({
    required this.name,
    this.description = '',
    this.dayType = 'custom',
    this.isRest = false,
    this.order = 1,
    this.slots = const [],
    required this.line,
  });
}

/// A slot inside a workout day (represents a single exercise or a superset).
class SlotImport {
  final int order;
  final String comment;
  final int? alarm;
  final List<SlotEntryImport> entries;
  final int line;

  const SlotImport({
    this.order = 1,
    this.comment = '',
    this.alarm,
    this.entries = const [],
    required this.line,
  });
}

/// An exercise configuration inside a slot.
class SlotEntryImport {
  final dynamic exercise; // String (name or UUID) or int (ID)
  final String comment;
  final int sets;
  final num reps;
  final String? repetitionUnit;
  final num? weight;
  final String? weightUnit;
  final int? restTime;
  final num? rir;
  final String entryType;
  final bool alarms;
  final int line;

  int? resolvedExerciseId;

  SlotEntryImport({
    required this.exercise,
    this.comment = '',
    this.sets = 4,
    this.reps = 10,
    this.repetitionUnit,
    this.weight,
    this.weightUnit,
    this.restTime,
    this.rir,
    this.entryType = 'normal',
    this.alarms = false,
    required this.line,
    this.resolvedExerciseId,
  });
}

/// A parsed nutrition plan from an import script.
class NutritionPlanImport {
  final ScriptAction action;
  final String? id; // UUID
  final String description;
  final DateTime? start;
  final DateTime? end;
  final int? goalEnergy;
  final int? goalProtein;
  final int? goalCarbohydrates;
  final int? goalFat;
  final int? goalFiber;
  final List<MealImport> meals;
  final int line;

  const NutritionPlanImport({
    this.action = ScriptAction.create,
    this.id,
    required this.description,
    this.start,
    this.end,
    this.goalEnergy,
    this.goalProtein,
    this.goalCarbohydrates,
    this.goalFat,
    this.goalFiber,
    this.meals = const [],
    required this.line,
  });

  int get totalIngredients =>
      meals.fold<int>(0, (sum, m) => sum + m.items.length);
}

/// A meal inside a nutrition plan.
class MealImport {
  final String? id; // UUID
  final String name;
  final String? time; // "HH:MM" or "HH:MM:SS"
  final int order;
  final List<MealItemImport> items;
  final int line;

  const MealImport({
    this.id,
    required this.name,
    this.time,
    this.order = 1,
    this.items = const [],
    required this.line,
  });
}

/// An ingredient item inside a meal.
class MealItemImport {
  final String? id; // UUID
  final dynamic ingredient; // String (name, UUID, barcode) or int (ID)
  final num amount;
  final String? weightUnit;
  final String? comment;
  final int line;

  int? resolvedIngredientId;

  MealItemImport({
    this.id,
    required this.ingredient,
    required this.amount,
    this.weightUnit,
    this.comment,
    required this.line,
    this.resolvedIngredientId,
  });
}

/// Complete parsed script payload.
class ScriptImportPayload {
  final int schemaVersion;
  final String? metaDescription;
  final List<RoutineImport> routines;
  final List<NutritionPlanImport> nutritionPlans;
  final List<String> warnings;

  const ScriptImportPayload({
    required this.schemaVersion,
    this.metaDescription,
    this.routines = const [],
    this.nutritionPlans = const [],
    this.warnings = const [],
  });

  bool get isEmpty => routines.isEmpty && nutritionPlans.isEmpty;
}
