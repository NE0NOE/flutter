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

void main() {
  group('JsonNode', () {
    test('properties and keyNodes retrieval on object node', () {
      const keyNode = JsonNode(
        type: JsonNodeType.string,
        value: 'title',
        line: 1,
        column: 3,
        offset: 2,
      );
      const valueNode = JsonNode(
        type: JsonNodeType.string,
        value: 'Bench Press',
        line: 1,
        column: 11,
        offset: 10,
      );

      const objNode = JsonNode(
        type: JsonNodeType.object,
        line: 1,
        column: 1,
        offset: 0,
        properties: {'title': valueNode},
        keyNodes: {'title': keyNode},
      );

      expect(objNode.getProperty('title'), equals(valueNode));
      expect(objNode.getProperty('missing'), isNull);
      expect(objNode.getKeyNode('title'), equals(keyNode));
      expect(objNode.getKeyNode('missing'), isNull);
    });

    test('getElement handles in-bounds and out-of-bounds indices', () {
      const elem1 = JsonNode(type: JsonNodeType.number, value: 42, line: 2, column: 5, offset: 10);
      const elem2 = JsonNode(
        type: JsonNodeType.string,
        value: 'test',
        line: 2,
        column: 9,
        offset: 14,
      );

      const arrayNode = JsonNode(
        type: JsonNodeType.array,
        line: 2,
        column: 1,
        offset: 6,
        elements: [elem1, elem2],
      );

      expect(arrayNode.getElement(0), equals(elem1));
      expect(arrayNode.getElement(1), equals(elem2));
      expect(arrayNode.getElement(-1), isNull);
      expect(arrayNode.getElement(2), isNull);
    });

    test('toPlainJson recursively converts AST to plain Dart maps and lists', () {
      const node = JsonNode(
        type: JsonNodeType.object,
        line: 1,
        column: 1,
        offset: 0,
        properties: {
          'count': JsonNode(type: JsonNodeType.number, value: 5, line: 2, column: 10, offset: 12),
          'active': JsonNode(
            type: JsonNodeType.boolean,
            value: true,
            line: 3,
            column: 11,
            offset: 25,
          ),
          'tags': JsonNode(
            type: JsonNodeType.array,
            line: 4,
            column: 9,
            offset: 40,
            elements: [
              JsonNode(
                type: JsonNodeType.string,
                value: 'strength',
                line: 4,
                column: 10,
                offset: 41,
              ),
              JsonNode(type: JsonNodeType.nullValue, value: null, line: 4, column: 22, offset: 53),
            ],
          ),
        },
      );

      final plain = node.toPlainJson() as Map<String, dynamic>;
      expect(plain['count'], equals(5));
      expect(plain['active'], isTrue);
      expect(plain['tags'], equals(const ['strength', null]));
    });
  });
}
