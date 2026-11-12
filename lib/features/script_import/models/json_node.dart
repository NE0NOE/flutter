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

/// Node types supported in JSON AST.
enum JsonNodeType {
  object,
  array,
  string,
  number,
  boolean,
  nullValue,
}

/// A node in a parsed JSON document that tracks its line, column, and offset.
///
/// This allows the validator and importer to point to exact lines in the user's
/// input when raising validation or syntax errors.
class JsonNode {
  final JsonNodeType type;
  final dynamic value;
  final int line;
  final int column;
  final int offset;

  /// Properties of an object node (key -> value node).
  final Map<String, JsonNode>? properties;

  /// AST nodes for the keys of an object (key -> key node with line/column).
  final Map<String, JsonNode>? keyNodes;

  /// Elements of an array node.
  final List<JsonNode>? elements;

  const JsonNode({
    required this.type,
    this.value,
    required this.line,
    required this.column,
    required this.offset,
    this.properties,
    this.keyNodes,
    this.elements,
  });

  /// Returns the property value node for [key], or null if absent.
  JsonNode? getProperty(String key) => properties?[key];

  /// Returns the key node for [key], or null if absent.
  JsonNode? getKeyNode(String key) => keyNodes?[key];

  /// Returns the element at [index], or null if out of range.
  JsonNode? getElement(int index) {
    if (elements != null && index >= 0 && index < elements!.length) {
      return elements![index];
    }
    return null;
  }

  /// Recursively converts the AST node to standard Dart types (Map, List, num, String, bool, null).
  dynamic toPlainJson() {
    switch (type) {
      case JsonNodeType.object:
        return properties?.map((k, v) => MapEntry(k, v.toPlainJson())) ?? <String, dynamic>{};
      case JsonNodeType.array:
        return elements?.map((e) => e.toPlainJson()).toList() ?? <dynamic>[];
      case JsonNodeType.string:
      case JsonNodeType.number:
      case JsonNodeType.boolean:
      case JsonNodeType.nullValue:
        return value;
    }
  }

  @override
  String toString() => 'JsonNode($type, line: $line, col: $column, val: $value)';
}
