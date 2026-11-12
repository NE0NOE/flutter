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
import 'package:wger/features/script_import/models/script_import_error.dart';

void main() {
  group('ScriptImportError', () {
    test('formattedMessage includes line, field path, and message', () {
      const error = ScriptImportError(
        line: 14,
        column: 5,
        path: 'routines[0].days[0].slots[1].sets',
        message: 'expected an integer',
      );

      expect(
        error.formattedMessage,
        equals('Line 14, field "routines[0].days[0].slots[1].sets": expected an integer'),
      );
      expect(error.toString(), equals(error.formattedMessage));
    });

    test('formattedMessage without path omits field part', () {
      const error = ScriptImportError(
        line: 1,
        column: 1,
        message: 'Empty JSON document',
      );

      expect(error.formattedMessage, equals('Line 1: Empty JSON document'));
    });
  });
}
