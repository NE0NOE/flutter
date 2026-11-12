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
import 'package:wger/features/script_import/models/json_node.dart';
import 'package:wger/features/script_import/models/json_source_parser.dart';

void main() {
  group('JsonSourceParser', () {
    test('parses empty document by throwing ScriptImportParseException at line 1', () {
      expect(
        () => JsonSourceParser.parse('   \n  \t  '),
        throwsA(
          isA<ScriptImportParseException>().having(
            (e) => e.error.line,
            'line',
            equals(1),
          ),
        ),
      );
    });

    test('parses primitive values and tracks line and column accurately', () {
      const json = '''
{
  "name": "Bench Press",
  "sets": 4,
  "weight": 82.5,
  "completed": true,
  "comment": null
}''';
      final root = JsonSourceParser.parse(json);
      expect(root.type, equals(JsonNodeType.object));
      expect(root.line, equals(1));

      final nameNode = root.getProperty('name')!;
      expect(nameNode.type, equals(JsonNodeType.string));
      expect(nameNode.value, equals('Bench Press'));
      expect(nameNode.line, equals(2));

      final setsNode = root.getProperty('sets')!;
      expect(setsNode.type, equals(JsonNodeType.number));
      expect(setsNode.value, equals(4));
      expect(setsNode.line, equals(3));

      final weightNode = root.getProperty('weight')!;
      expect(weightNode.type, equals(JsonNodeType.number));
      expect(weightNode.value, equals(82.5));
      expect(weightNode.line, equals(4));

      final completedNode = root.getProperty('completed')!;
      expect(completedNode.type, equals(JsonNodeType.boolean));
      expect(completedNode.value, isTrue);
      expect(completedNode.line, equals(5));

      final commentNode = root.getProperty('comment')!;
      expect(commentNode.type, equals(JsonNodeType.nullValue));
      expect(commentNode.value, isNull);
      expect(commentNode.line, equals(6));
    });

    test('parses escape sequences and unicode characters in strings', () {
      const json = r'{"escaped": "Line 1\nLine 2\t\"quoted\" \\ \u0041"}';
      final root = JsonSourceParser.parse(json);
      final strNode = root.getProperty('escaped')!;
      expect(strNode.value, equals('Line 1\nLine 2\t"quoted" \\ A'));
    });

    test('parses arrays and computes lines for each element', () {
      const json = '''
[
  "first",
  "second",
  "third"
]''';
      final root = JsonSourceParser.parse(json);
      expect(root.type, equals(JsonNodeType.array));
      expect(root.elements?.length, equals(3));
      expect(root.getElement(0)?.line, equals(2));
      expect(root.getElement(1)?.line, equals(3));
      expect(root.getElement(2)?.line, equals(4));
    });

    test('throws syntax error for unclosed object', () {
      const json = '{\n  "open": true\n';
      expect(
        () => JsonSourceParser.parse(json),
        throwsA(
          isA<ScriptImportParseException>().having(
            (e) => e.error.message,
            'message',
            contains('Unterminated object'),
          ),
        ),
      );
    });

    test('throws syntax error for unclosed array', () {
      const json = '[\n  1,\n  2';
      expect(
        () => JsonSourceParser.parse(json),
        throwsA(
          isA<ScriptImportParseException>().having(
            (e) => e.error.message,
            'message',
            contains('Unterminated array'),
          ),
        ),
      );
    });

    test('throws syntax error for trailing junk after root', () {
      const json = '{"ok": true} extra_data';
      expect(
        () => JsonSourceParser.parse(json),
        throwsA(
          isA<ScriptImportParseException>().having(
            (e) => e.error.message,
            'message',
            contains('Unexpected characters after JSON root element'),
          ),
        ),
      );
    });
  });
}
