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

import 'package:wger/features/script_import/models/json_node.dart';
import 'package:wger/features/script_import/models/json_source_parser.dart';
import 'package:wger/features/script_import/models/script_import_data.dart';
import 'package:wger/features/script_import/models/script_import_error.dart';

/// The result of validating a script document.
class ScriptValidationResult {
  final List<ScriptImportError> errors;
  final List<String> warnings;
  final ScriptImportPayload? payload;

  const ScriptValidationResult({
    this.errors = const [],
    this.warnings = const [],
    this.payload,
  });

  bool get isValid => errors.isEmpty && payload != null;
}

/// Pure Dart validator for the versioned JSON script import format.
///
/// Produces human-readable errors with exact line and field path for any
/// schema violation.
class ScriptValidator {
  const ScriptValidator();

  static const int currentSupportedSchemaVersion = 1;

  ScriptValidationResult validate(String source) => validateString(source);

  static const _knownTopLevelFields = {
    'schema_version',
    'meta',
    'routines',
    'nutrition_plans',
  };

  /// Parses and validates a raw JSON string into a [ScriptValidationResult].
  static ScriptValidationResult validateString(String source) {
    if (source.trim().isEmpty) {
      return const ScriptValidationResult(
        errors: [
          ScriptImportError(
            line: 1,
            column: 1,
            path: 'root',
            message: 'Input script is empty',
          ),
        ],
      );
    }

    final JsonNode rootNode;
    try {
      rootNode = JsonSourceParser.parse(source);
    } on ScriptImportParseException catch (e) {
      return ScriptValidationResult(errors: [e.error]);
    }

    return validateNode(rootNode);
  }

  /// Validates a parsed [JsonNode] tree against schema rules.
  static ScriptValidationResult validateNode(JsonNode rootNode) {
    final errors = <ScriptImportError>[];
    final warnings = <String>[];

    if (rootNode.type != JsonNodeType.object) {
      errors.add(
        ScriptImportError(
          line: rootNode.line,
          column: rootNode.column,
          path: 'root',
          message: 'Expected a JSON object at root',
        ),
      );
      return ScriptValidationResult(errors: errors);
    }

    final properties = rootNode.properties ?? {};

    // Check unknown top-level fields for forward compatibility warning
    for (final key in properties.keys) {
      if (!_knownTopLevelFields.contains(key)) {
        final keyNode = rootNode.getKeyNode(key);
        warnings.add(
          'Line ${keyNode?.line ?? rootNode.line}: unknown field "$key" will be ignored.',
        );
      }
    }

    // 1. Validate schema_version
    final versionNode = rootNode.getProperty('schema_version');
    if (versionNode == null) {
      errors.add(
        ScriptImportError(
          line: rootNode.line,
          column: rootNode.column,
          path: 'schema_version',
          message: 'Missing required field "schema_version"',
        ),
      );
    } else if (versionNode.type != JsonNodeType.number || versionNode.value is! int) {
      errors.add(
        ScriptImportError(
          line: versionNode.line,
          column: versionNode.column,
          path: 'schema_version',
          message: 'Expected an integer for "schema_version", got ${_typeName(versionNode)}',
        ),
      );
    } else {
      final version = versionNode.value as int;
      if (version > currentSupportedSchemaVersion) {
        errors.add(
          ScriptImportError(
            line: versionNode.line,
            column: versionNode.column,
            path: 'schema_version',
            message:
                'Unsupported schema version $version (maximum supported is $currentSupportedSchemaVersion)',
          ),
        );
      } else if (version < 1) {
        errors.add(
          ScriptImportError(
            line: versionNode.line,
            column: versionNode.column,
            path: 'schema_version',
            message: 'Schema version must be at least 1',
          ),
        );
      }
    }

    // Meta (optional)
    String? metaDesc;
    final metaNode = rootNode.getProperty('meta');
    if (metaNode != null && metaNode.type == JsonNodeType.object) {
      final descNode = metaNode.getProperty('description');
      if (descNode != null && descNode.type == JsonNodeType.string) {
        metaDesc = descNode.value as String;
      }
    }

    // 2. Validate routines
    final routinesList = <RoutineImport>[];
    final routinesNode = rootNode.getProperty('routines');
    if (routinesNode != null) {
      if (routinesNode.type != JsonNodeType.array) {
        errors.add(
          ScriptImportError(
            line: routinesNode.line,
            column: routinesNode.column,
            path: 'routines',
            message: 'Expected an array, got ${_typeName(routinesNode)}',
          ),
        );
      } else {
        final elements = routinesNode.elements ?? [];
        for (var i = 0; i < elements.length; i++) {
          final rNode = elements[i];
          final path = 'routines[$i]';
          _validateRoutine(rNode, path, errors, routinesList);
        }
      }
    }

    // 3. Validate nutrition_plans
    final plansList = <NutritionPlanImport>[];
    final plansNode = rootNode.getProperty('nutrition_plans');
    if (plansNode != null) {
      if (plansNode.type != JsonNodeType.array) {
        errors.add(
          ScriptImportError(
            line: plansNode.line,
            column: plansNode.column,
            path: 'nutrition_plans',
            message: 'Expected an array, got ${_typeName(plansNode)}',
          ),
        );
      } else {
        final elements = plansNode.elements ?? [];
        for (var i = 0; i < elements.length; i++) {
          final pNode = elements[i];
          final path = 'nutrition_plans[$i]';
          _validateNutritionPlan(pNode, path, errors, plansList);
        }
      }
    }

    if (routinesNode == null && plansNode == null) {
      errors.add(
        ScriptImportError(
          line: rootNode.line,
          column: rootNode.column,
          path: 'root',
          message: 'At least one routine or nutrition plan must be provided',
        ),
      );
    } else if (routinesList.isEmpty && plansList.isEmpty && errors.isEmpty) {
      errors.add(
        ScriptImportError(
          line: rootNode.line,
          column: rootNode.column,
          path: 'root',
          message: 'Both "routines" and "nutrition_plans" lists are empty',
        ),
      );
    }

    if (errors.isNotEmpty) {
      return ScriptValidationResult(errors: errors, warnings: warnings);
    }

    final payload = ScriptImportPayload(
      schemaVersion: (versionNode?.value as int?) ?? 1,
      metaDescription: metaDesc,
      routines: routinesList,
      nutritionPlans: plansList,
      warnings: warnings,
    );

    return ScriptValidationResult(
      errors: const [],
      warnings: warnings,
      payload: payload,
    );
  }

  static void _validateRoutine(
    JsonNode node,
    String path,
    List<ScriptImportError> errors,
    List<RoutineImport> outList,
  ) {
    if (node.type != JsonNodeType.object) {
      errors.add(
        ScriptImportError(
          line: node.line,
          column: node.column,
          path: path,
          message: 'Expected an object, got ${_typeName(node)}',
        ),
      );
      return;
    }

    // action
    var action = ScriptAction.create;
    final actionNode = node.getProperty('action');
    if (actionNode != null) {
      if (actionNode.type != JsonNodeType.string) {
        errors.add(
          ScriptImportError(
            line: actionNode.line,
            column: actionNode.column,
            path: '$path.action',
            message: 'Expected a string for "action"',
          ),
        );
      } else {
        final val = actionNode.value as String;
        try {
          action = ScriptAction.fromString(val);
        } catch (_) {
          errors.add(
            ScriptImportError(
              line: actionNode.line,
              column: actionNode.column,
              path: '$path.action',
              message: 'Invalid action "$val", expected "create" or "update"',
            ),
          );
        }
      }
    }

    // id / uuid
    int? routineId;
    final idNode = node.getProperty('id');
    if (idNode != null) {
      if (idNode.type != JsonNodeType.number || idNode.value is! int) {
        errors.add(
          ScriptImportError(
            line: idNode.line,
            column: idNode.column,
            path: '$path.id',
            message: 'Expected an integer, got ${_typeName(idNode)}',
          ),
        );
      } else {
        routineId = idNode.value as int;
      }
    }

    String? uuid;
    final uuidNode = node.getProperty('uuid');
    if (uuidNode != null) {
      if (uuidNode.type != JsonNodeType.string) {
        errors.add(
          ScriptImportError(
            line: uuidNode.line,
            column: uuidNode.column,
            path: '$path.uuid',
            message: 'Expected a string, got ${_typeName(uuidNode)}',
          ),
        );
      } else {
        uuid = uuidNode.value as String;
      }
    }

    // name
    String? name;
    final nameNode = node.getProperty('name');
    if (nameNode == null) {
      errors.add(
        ScriptImportError(
          line: node.line,
          column: node.column,
          path: '$path.name',
          message: 'Missing required field "name"',
        ),
      );
    } else if (nameNode.type != JsonNodeType.string) {
      errors.add(
        ScriptImportError(
          line: nameNode.line,
          column: nameNode.column,
          path: '$path.name',
          message: 'Expected a string, got ${_typeName(nameNode)}',
        ),
      );
    } else {
      name = (nameNode.value as String).trim();
      if (name.isEmpty) {
        errors.add(
          ScriptImportError(
            line: nameNode.line,
            column: nameNode.column,
            path: '$path.name',
            message: 'Routine name cannot be empty',
          ),
        );
      } else if (name.length > 25) {
        errors.add(
          ScriptImportError(
            line: nameNode.line,
            column: nameNode.column,
            path: '$path.name',
            message: 'Routine name must be at most 25 characters',
          ),
        );
      }
    }

    // description
    String desc = '';
    final descNode = node.getProperty('description');
    if (descNode != null) {
      if (descNode.type != JsonNodeType.string) {
        errors.add(
          ScriptImportError(
            line: descNode.line,
            column: descNode.column,
            path: '$path.description',
            message: 'Expected a string, got ${_typeName(descNode)}',
          ),
        );
      } else {
        desc = descNode.value as String;
        if (desc.length > 1000) {
          errors.add(
            ScriptImportError(
              line: descNode.line,
              column: descNode.column,
              path: '$path.description',
              message: 'Routine description must be at most 1000 characters',
            ),
          );
        }
      }
    }

    // start & end dates
    DateTime? startDate;
    final startNode = node.getProperty('start');
    if (startNode != null) {
      if (startNode.type != JsonNodeType.string) {
        errors.add(
          ScriptImportError(
            line: startNode.line,
            column: startNode.column,
            path: '$path.start',
            message: 'Expected date string in format YYYY-MM-DD',
          ),
        );
      } else {
        startDate = DateTime.tryParse(startNode.value as String);
        if (startDate == null) {
          errors.add(
            ScriptImportError(
              line: startNode.line,
              column: startNode.column,
              path: '$path.start',
              message: 'Invalid date format "${startNode.value}", expected YYYY-MM-DD',
            ),
          );
        }
      }
    }

    DateTime? endDate;
    final endNode = node.getProperty('end');
    if (endNode != null) {
      if (endNode.type != JsonNodeType.string) {
        errors.add(
          ScriptImportError(
            line: endNode.line,
            column: endNode.column,
            path: '$path.end',
            message: 'Expected date string in format YYYY-MM-DD',
          ),
        );
      } else {
        endDate = DateTime.tryParse(endNode.value as String);
        if (endDate == null) {
          errors.add(
            ScriptImportError(
              line: endNode.line,
              column: endNode.column,
              path: '$path.end',
              message: 'Invalid date format "${endNode.value}", expected YYYY-MM-DD',
            ),
          );
        }
      }
    }

    // fit_in_week
    var fitInWeek = false;
    final fitNode = node.getProperty('fit_in_week');
    if (fitNode != null) {
      if (fitNode.type != JsonNodeType.boolean) {
        errors.add(
          ScriptImportError(
            line: fitNode.line,
            column: fitNode.column,
            path: '$path.fit_in_week',
            message: 'Expected a boolean',
          ),
        );
      } else {
        fitInWeek = fitNode.value as bool;
      }
    }

    // days
    final daysList = <DayImport>[];
    final daysNode = node.getProperty('days');
    if (action == ScriptAction.create && daysNode == null) {
      errors.add(
        ScriptImportError(
          line: node.line,
          column: node.column,
          path: '$path.days',
          message: 'Missing required field "days"',
        ),
      );
    } else if (daysNode != null) {
      if (daysNode.type != JsonNodeType.array) {
        errors.add(
          ScriptImportError(
            line: daysNode.line,
            column: daysNode.column,
            path: '$path.days',
            message: 'Expected an array, got ${_typeName(daysNode)}',
          ),
        );
      } else {
        final dElements = daysNode.elements ?? [];
        if (action == ScriptAction.create && dElements.isEmpty) {
          errors.add(
            ScriptImportError(
              line: daysNode.line,
              column: daysNode.column,
              path: '$path.days',
              message: 'A routine must have at least one workout day',
            ),
          );
        }
        for (var j = 0; j < dElements.length; j++) {
          final dNode = dElements[j];
          _validateDay(dNode, '$path.days[$j]', errors, daysList, j + 1);
        }
      }
    }

    if (name != null) {
      outList.add(
        RoutineImport(
          action: action,
          id: routineId,
          uuid: uuid,
          name: name,
          description: desc,
          start: startDate,
          end: endDate,
          fitInWeek: fitInWeek,
          days: daysList,
          line: node.line,
        ),
      );
    }
  }

  static void _validateDay(
    JsonNode node,
    String path,
    List<ScriptImportError> errors,
    List<DayImport> outDays,
    int defaultOrder,
  ) {
    if (node.type != JsonNodeType.object) {
      errors.add(
        ScriptImportError(
          line: node.line,
          column: node.column,
          path: path,
          message: 'Expected an object, got ${_typeName(node)}',
        ),
      );
      return;
    }

    // name
    String? dayName;
    final nameNode = node.getProperty('name');
    if (nameNode == null) {
      errors.add(
        ScriptImportError(
          line: node.line,
          column: node.column,
          path: '$path.name',
          message: 'Missing required field "name"',
        ),
      );
    } else if (nameNode.type != JsonNodeType.string) {
      errors.add(
        ScriptImportError(
          line: nameNode.line,
          column: nameNode.column,
          path: '$path.name',
          message: 'Expected a string, got ${_typeName(nameNode)}',
        ),
      );
    } else {
      dayName = (nameNode.value as String).trim();
      if (dayName.isEmpty) {
        errors.add(
          ScriptImportError(
            line: nameNode.line,
            column: nameNode.column,
            path: '$path.name',
            message: 'Day name cannot be empty',
          ),
        );
      } else if (dayName.length > 20) {
        errors.add(
          ScriptImportError(
            line: nameNode.line,
            column: nameNode.column,
            path: '$path.name',
            message: 'Day name must be at most 20 characters',
          ),
        );
      }
    }

    // description
    String dayDesc = '';
    final descNode = node.getProperty('description');
    if (descNode != null && descNode.type == JsonNodeType.string) {
      dayDesc = descNode.value as String;
    }

    // day_type
    var dayType = 'custom';
    final typeNode = node.getProperty('day_type') ?? node.getProperty('type');
    if (typeNode != null && typeNode.type == JsonNodeType.string) {
      dayType = typeNode.value as String;
    }

    // is_rest
    var isRest = false;
    final restNode = node.getProperty('is_rest');
    if (restNode != null && restNode.type == JsonNodeType.boolean) {
      isRest = restNode.value as bool;
    }

    // order
    num order = defaultOrder;
    final orderNode = node.getProperty('order');
    if (orderNode != null && orderNode.type == JsonNodeType.number) {
      order = orderNode.value as num;
    }

    // slots
    final slotsList = <SlotImport>[];
    final slotsNode = node.getProperty('slots');
    if (slotsNode != null) {
      if (slotsNode.type != JsonNodeType.array) {
        errors.add(
          ScriptImportError(
            line: slotsNode.line,
            column: slotsNode.column,
            path: '$path.slots',
            message: 'Expected an array, got ${_typeName(slotsNode)}',
          ),
        );
      } else {
        final sElements = slotsNode.elements ?? [];
        for (var k = 0; k < sElements.length; k++) {
          final sNode = sElements[k];
          _validateSlot(sNode, '$path.slots[$k]', errors, slotsList, k + 1);
        }
      }
    }

    if (dayName != null) {
      outDays.add(
        DayImport(
          name: dayName,
          description: dayDesc,
          dayType: dayType,
          isRest: isRest,
          order: order,
          slots: slotsList,
          line: node.line,
        ),
      );
    }
  }

  static void _validateSlot(
    JsonNode node,
    String path,
    List<ScriptImportError> errors,
    List<SlotImport> outSlots,
    int defaultOrder,
  ) {
    if (node.type != JsonNodeType.object) {
      errors.add(
        ScriptImportError(
          line: node.line,
          column: node.column,
          path: path,
          message: 'Expected an object, got ${_typeName(node)}',
        ),
      );
      return;
    }

    var order = defaultOrder;
    final orderNode = node.getProperty('order');
    if (orderNode != null) {
      if (orderNode.type != JsonNodeType.number || orderNode.value is! int) {
        errors.add(
          ScriptImportError(
            line: orderNode.line,
            column: orderNode.column,
            path: '$path.order',
            message: 'Expected an integer, got ${_typeName(orderNode)}',
          ),
        );
      } else {
        order = orderNode.value as int;
      }
    }

    String comment = '';
    final commentNode = node.getProperty('comment');
    if (commentNode != null && commentNode.type == JsonNodeType.string) {
      comment = commentNode.value as String;
    }

    int? alarm;
    final alarmNode = node.getProperty('alarm') ?? node.getProperty('rest_time');
    if (alarmNode != null && alarmNode.type == JsonNodeType.number && alarmNode.value is int) {
      alarm = alarmNode.value as int;
    }

    final entriesList = <SlotEntryImport>[];
    final entriesNode = node.getProperty('exercises') ?? node.getProperty('entries');
    if (entriesNode == null) {
      errors.add(
        ScriptImportError(
          line: node.line,
          column: node.column,
          path: '$path.exercises',
          message: 'Missing required field "exercises"',
        ),
      );
    } else if (entriesNode.type != JsonNodeType.array) {
      errors.add(
        ScriptImportError(
          line: entriesNode.line,
          column: entriesNode.column,
          path: '$path.exercises',
          message: 'Expected an array, got ${_typeName(entriesNode)}',
        ),
      );
    } else {
      final eElements = entriesNode.elements ?? [];
      for (var m = 0; m < eElements.length; m++) {
        final eNode = eElements[m];
        _validateSlotEntry(eNode, '$path.exercises[$m]', errors, entriesList);
      }
    }

    outSlots.add(
      SlotImport(
        order: order,
        comment: comment,
        alarm: alarm,
        entries: entriesList,
        line: node.line,
      ),
    );
  }

  static void _validateSlotEntry(
    JsonNode node,
    String path,
    List<ScriptImportError> errors,
    List<SlotEntryImport> outEntries,
  ) {
    if (node.type != JsonNodeType.object) {
      errors.add(
        ScriptImportError(
          line: node.line,
          column: node.column,
          path: path,
          message: 'Expected an object, got ${_typeName(node)}',
        ),
      );
      return;
    }

    // exercise (name, id, uuid)
    dynamic exercise;
    final exNode = node.getProperty('exercise');
    if (exNode == null) {
      errors.add(
        ScriptImportError(
          line: node.line,
          column: node.column,
          path: '$path.exercise',
          message: 'Missing required field "exercise"',
        ),
      );
    } else if (exNode.type != JsonNodeType.string && exNode.type != JsonNodeType.number) {
      errors.add(
        ScriptImportError(
          line: exNode.line,
          column: exNode.column,
          path: '$path.exercise',
          message: 'Expected string or integer for exercise identifier',
        ),
      );
    } else {
      exercise = exNode.value;
    }

    // sets
    var sets = 4;
    final setsNode = node.getProperty('sets');
    if (setsNode == null) {
      errors.add(
        ScriptImportError(
          line: node.line,
          column: node.column,
          path: '$path.sets',
          message: 'Missing required field "sets"',
        ),
      );
    } else if (setsNode.type != JsonNodeType.number || setsNode.value is! int) {
      errors.add(
        ScriptImportError(
          line: setsNode.line,
          column: setsNode.column,
          path: '$path.sets',
          message: 'Expected an integer, got ${_typeName(setsNode)}',
        ),
      );
    } else {
      sets = setsNode.value as int;
      if (sets < 1) {
        errors.add(
          ScriptImportError(
            line: setsNode.line,
            column: setsNode.column,
            path: '$path.sets',
            message: 'Sets must be at least 1',
          ),
        );
      }
    }

    // reps / repetitions
    num reps = 10;
    final repsNode = node.getProperty('reps') ?? node.getProperty('repetitions');
    if (repsNode == null) {
      errors.add(
        ScriptImportError(
          line: node.line,
          column: node.column,
          path: '$path.reps',
          message: 'Missing required field "reps"',
        ),
      );
    } else if (repsNode.type != JsonNodeType.number) {
      errors.add(
        ScriptImportError(
          line: repsNode.line,
          column: repsNode.column,
          path: '$path.reps',
          message: 'Expected a number, got ${_typeName(repsNode)}',
        ),
      );
    } else {
      reps = repsNode.value as num;
      if (reps <= 0) {
        errors.add(
          ScriptImportError(
            line: repsNode.line,
            column: repsNode.column,
            path: '$path.reps',
            message: 'Repetitions must be greater than 0',
          ),
        );
      }
    }

    // repetition_unit
    String? repUnit;
    final repUnitNode = node.getProperty('repetition_unit');
    if (repUnitNode != null && repUnitNode.type == JsonNodeType.string) {
      repUnit = repUnitNode.value as String;
    }

    // weight
    num? weight;
    final weightNode = node.getProperty('weight');
    if (weightNode != null) {
      if (weightNode.type != JsonNodeType.number) {
        errors.add(
          ScriptImportError(
            line: weightNode.line,
            column: weightNode.column,
            path: '$path.weight',
            message: 'Expected a number, got ${_typeName(weightNode)}',
          ),
        );
      } else {
        weight = weightNode.value as num;
      }
    }

    // weight_unit
    String? weightUnit;
    final wuNode = node.getProperty('weight_unit');
    if (wuNode != null && wuNode.type == JsonNodeType.string) {
      weightUnit = wuNode.value as String;
    }

    // rest_time
    int? restTime;
    final restNode = node.getProperty('rest_time') ?? node.getProperty('rest');
    if (restNode != null && restNode.type == JsonNodeType.number && restNode.value is int) {
      restTime = restNode.value as int;
    }

    // rir
    num? rir;
    final rirNode = node.getProperty('rir');
    if (rirNode != null && rirNode.type == JsonNodeType.number) {
      rir = rirNode.value as num;
    }

    // entry_type
    var entryType = 'normal';
    final entryTypeNode = node.getProperty('entry_type') ?? node.getProperty('type');
    if (entryTypeNode != null && entryTypeNode.type == JsonNodeType.string) {
      entryType = entryTypeNode.value as String;
    }

    // alarms
    var alarms = false;
    final alarmsNode = node.getProperty('alarms') ?? node.getProperty('alarm');
    if (alarmsNode != null) {
      if (alarmsNode.type == JsonNodeType.boolean) {
        alarms = alarmsNode.value as bool;
      } else if (alarmsNode.type == JsonNodeType.number) {
        alarms = (alarmsNode.value as num) > 0;
      }
    }

    // comment
    String comment = '';
    final commentNode = node.getProperty('comment') ?? node.getProperty('notes');
    if (commentNode != null && commentNode.type == JsonNodeType.string) {
      comment = commentNode.value as String;
    }

    if (exercise != null) {
      outEntries.add(
        SlotEntryImport(
          exercise: exercise,
          comment: comment,
          sets: sets,
          reps: reps,
          repetitionUnit: repUnit,
          weight: weight,
          weightUnit: weightUnit,
          restTime: restTime,
          rir: rir,
          entryType: entryType,
          alarms: alarms,
          line: node.line,
        ),
      );
    }
  }

  static void _validateNutritionPlan(
    JsonNode node,
    String path,
    List<ScriptImportError> errors,
    List<NutritionPlanImport> outPlans,
  ) {
    if (node.type != JsonNodeType.object) {
      errors.add(
        ScriptImportError(
          line: node.line,
          column: node.column,
          path: path,
          message: 'Expected an object, got ${_typeName(node)}',
        ),
      );
      return;
    }

    // action
    var action = ScriptAction.create;
    final actionNode = node.getProperty('action');
    if (actionNode != null && actionNode.type == JsonNodeType.string) {
      try {
        action = ScriptAction.fromString(actionNode.value as String);
      } catch (_) {
        errors.add(
          ScriptImportError(
            line: actionNode.line,
            column: actionNode.column,
            path: '$path.action',
            message: 'Invalid action "${actionNode.value}", expected "create" or "update"',
          ),
        );
      }
    }

    // id (UUID)
    String? planId;
    final idNode = node.getProperty('id');
    if (idNode != null && idNode.type == JsonNodeType.string) {
      planId = idNode.value as String;
    }

    // description
    String? desc;
    final descNode = node.getProperty('description') ?? node.getProperty('name');
    if (descNode == null) {
      errors.add(
        ScriptImportError(
          line: node.line,
          column: node.column,
          path: '$path.description',
          message: 'Missing required field "description"',
        ),
      );
    } else if (descNode.type != JsonNodeType.string) {
      errors.add(
        ScriptImportError(
          line: descNode.line,
          column: descNode.column,
          path: '$path.description',
          message: 'Expected a string, got ${_typeName(descNode)}',
        ),
      );
    } else {
      desc = (descNode.value as String).trim();
      if (desc.isEmpty) {
        errors.add(
          ScriptImportError(
            line: descNode.line,
            column: descNode.column,
            path: '$path.description',
            message: 'Description cannot be empty',
          ),
        );
      }
    }

    // start & end
    DateTime? startDate;
    final startNode = node.getProperty('start');
    if (startNode != null && startNode.type == JsonNodeType.string) {
      startDate = DateTime.tryParse(startNode.value as String);
    }

    DateTime? endDate;
    final endNode = node.getProperty('end');
    if (endNode != null && endNode.type == JsonNodeType.string) {
      endDate = DateTime.tryParse(endNode.value as String);
    }

    // goals
    final goalEnergy = _getIntProperty(node, 'goal_calories') ?? _getIntProperty(node, 'goal_energy');
    final goalProtein = _getIntProperty(node, 'goal_protein');
    final goalCarbs = _getIntProperty(node, 'goal_carbohydrates');
    final goalFat = _getIntProperty(node, 'goal_fat');
    final goalFiber = _getIntProperty(node, 'goal_fiber');

    // meals
    final mealsList = <MealImport>[];
    final mealsNode = node.getProperty('meals');
    if (action == ScriptAction.create && mealsNode == null) {
      errors.add(
        ScriptImportError(
          line: node.line,
          column: node.column,
          path: '$path.meals',
          message: 'Missing required field "meals"',
        ),
      );
    } else if (mealsNode != null) {
      if (mealsNode.type != JsonNodeType.array) {
        errors.add(
          ScriptImportError(
            line: mealsNode.line,
            column: mealsNode.column,
            path: '$path.meals',
            message: 'Expected an array, got ${_typeName(mealsNode)}',
          ),
        );
      } else {
        final mElements = mealsNode.elements ?? [];
        for (var j = 0; j < mElements.length; j++) {
          final mNode = mElements[j];
          _validateMeal(mNode, '$path.meals[$j]', errors, mealsList, j + 1);
        }
      }
    }

    if (desc != null) {
      outPlans.add(
        NutritionPlanImport(
          action: action,
          id: planId,
          description: desc,
          start: startDate,
          end: endDate,
          goalEnergy: goalEnergy,
          goalProtein: goalProtein,
          goalCarbohydrates: goalCarbs,
          goalFat: goalFat,
          goalFiber: goalFiber,
          meals: mealsList,
          line: node.line,
        ),
      );
    }
  }

  static void _validateMeal(
    JsonNode node,
    String path,
    List<ScriptImportError> errors,
    List<MealImport> outMeals,
    int defaultOrder,
  ) {
    if (node.type != JsonNodeType.object) {
      errors.add(
        ScriptImportError(
          line: node.line,
          column: node.column,
          path: path,
          message: 'Expected an object, got ${_typeName(node)}',
        ),
      );
      return;
    }

    String? mealId;
    final idNode = node.getProperty('id');
    if (idNode != null && idNode.type == JsonNodeType.string) {
      mealId = idNode.value as String;
    }

    String? name;
    final nameNode = node.getProperty('name');
    if (nameNode == null) {
      errors.add(
        ScriptImportError(
          line: node.line,
          column: node.column,
          path: '$path.name',
          message: 'Missing required field "name"',
        ),
      );
    } else if (nameNode.type != JsonNodeType.string) {
      errors.add(
        ScriptImportError(
          line: nameNode.line,
          column: nameNode.column,
          path: '$path.name',
          message: 'Expected a string, got ${_typeName(nameNode)}',
        ),
      );
    } else {
      name = (nameNode.value as String).trim();
    }

    String? time;
    final timeNode = node.getProperty('time');
    if (timeNode != null && timeNode.type == JsonNodeType.string) {
      time = timeNode.value as String;
    }

    var order = defaultOrder;
    final orderNode = node.getProperty('order');
    if (orderNode != null && orderNode.type == JsonNodeType.number && orderNode.value is int) {
      order = orderNode.value as int;
    }

    final itemsList = <MealItemImport>[];
    final itemsNode = node.getProperty('items') ?? node.getProperty('ingredients');
    if (itemsNode != null) {
      if (itemsNode.type != JsonNodeType.array) {
        errors.add(
          ScriptImportError(
            line: itemsNode.line,
            column: itemsNode.column,
            path: '$path.items',
            message: 'Expected an array, got ${_typeName(itemsNode)}',
          ),
        );
      } else {
        final iElements = itemsNode.elements ?? [];
        for (var k = 0; k < iElements.length; k++) {
          final iNode = iElements[k];
          _validateMealItem(iNode, '$path.items[$k]', errors, itemsList);
        }
      }
    }

    if (name != null) {
      outMeals.add(
        MealImport(
          id: mealId,
          name: name,
          time: time,
          order: order,
          items: itemsList,
          line: node.line,
        ),
      );
    }
  }

  static void _validateMealItem(
    JsonNode node,
    String path,
    List<ScriptImportError> errors,
    List<MealItemImport> outItems,
  ) {
    if (node.type != JsonNodeType.object) {
      errors.add(
        ScriptImportError(
          line: node.line,
          column: node.column,
          path: path,
          message: 'Expected an object, got ${_typeName(node)}',
        ),
      );
      return;
    }

    String? itemId;
    final idNode = node.getProperty('id');
    if (idNode != null && idNode.type == JsonNodeType.string) {
      itemId = idNode.value as String;
    }

    dynamic ingredient;
    final ingNode = node.getProperty('ingredient');
    if (ingNode == null) {
      errors.add(
        ScriptImportError(
          line: node.line,
          column: node.column,
          path: '$path.ingredient',
          message: 'Missing required field "ingredient"',
        ),
      );
    } else if (ingNode.type != JsonNodeType.string && ingNode.type != JsonNodeType.number) {
      errors.add(
        ScriptImportError(
          line: ingNode.line,
          column: ingNode.column,
          path: '$path.ingredient',
          message: 'Expected string or integer for ingredient identifier',
        ),
      );
    } else {
      ingredient = ingNode.value;
    }

    num? amount;
    final amountNode = node.getProperty('amount');
    if (amountNode == null) {
      errors.add(
        ScriptImportError(
          line: node.line,
          column: node.column,
          path: '$path.amount',
          message: 'Missing required field "amount"',
        ),
      );
    } else if (amountNode.type != JsonNodeType.number) {
      errors.add(
        ScriptImportError(
          line: amountNode.line,
          column: amountNode.column,
          path: '$path.amount',
          message: 'Expected a number, got ${_typeName(amountNode)}',
        ),
      );
    } else {
      amount = amountNode.value as num;
      if (amount <= 0) {
        errors.add(
          ScriptImportError(
            line: amountNode.line,
            column: amountNode.column,
            path: '$path.amount',
            message: 'Amount must be greater than 0',
          ),
        );
      }
    }

    String? unit;
    final unitNode = node.getProperty('unit') ?? node.getProperty('weight_unit');
    if (unitNode != null && unitNode.type == JsonNodeType.string) {
      unit = unitNode.value as String;
    }

    String? comment;
    final commentNode = node.getProperty('comment');
    if (commentNode != null && commentNode.type == JsonNodeType.string) {
      comment = commentNode.value as String;
    }

    if (ingredient != null && amount != null) {
      outItems.add(
        MealItemImport(
          id: itemId,
          ingredient: ingredient,
          amount: amount,
          weightUnit: unit,
          comment: comment,
          line: node.line,
        ),
      );
    }
  }

  static int? _getIntProperty(JsonNode parent, String key) {
    final node = parent.getProperty(key);
    if (node != null && node.type == JsonNodeType.number && node.value is int) {
      return node.value as int;
    }
    return null;
  }

  static String _typeName(JsonNode node) {
    switch (node.type) {
      case JsonNodeType.object:
        return 'object';
      case JsonNodeType.array:
        return 'array';
      case JsonNodeType.string:
        return 'string';
      case JsonNodeType.number:
        return 'number';
      case JsonNodeType.boolean:
        return 'boolean';
      case JsonNodeType.nullValue:
        return 'null';
    }
  }
}
