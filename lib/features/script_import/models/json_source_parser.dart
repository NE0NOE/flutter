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
import 'package:wger/features/script_import/models/script_import_error.dart';

/// Exception thrown when the JSON source cannot be syntactically parsed.
class ScriptImportParseException implements Exception {
  final ScriptImportError error;

  ScriptImportParseException(this.error);

  @override
  String toString() => error.formattedMessage;
}

/// Pure Dart recursive descent JSON parser that tracks exact lines and columns
/// for every node in the AST.
class JsonSourceParser {
  final String _source;
  int _index = 0;
  int _line = 1;
  int _column = 1;

  JsonSourceParser(this._source);

  /// Parses the input string into a root [JsonNode].
  ///
  /// Throws [ScriptImportParseException] if the input has syntax errors.
  static JsonNode parse(String source) {
    final parser = JsonSourceParser(source);
    return parser._parseDocument();
  }

  JsonNode _parseDocument() {
    _skipWhitespace();
    if (_isAtEnd()) {
      throw ScriptImportParseException(
        const ScriptImportError(
          line: 1,
          column: 1,
          message: 'Empty JSON document',
        ),
      );
    }
    final root = _parseValue();
    _skipWhitespace();
    if (!_isAtEnd()) {
      throw ScriptImportParseException(
        ScriptImportError(
          line: _line,
          column: _column,
          message: 'Unexpected characters after JSON root element',
        ),
      );
    }
    return root;
  }

  JsonNode _parseValue() {
    _skipWhitespace();
    if (_isAtEnd()) {
      throw ScriptImportParseException(
        ScriptImportError(
          line: _line,
          column: _column,
          message: 'Unexpected end of input while expecting JSON value',
        ),
      );
    }

    final ch = _peek();
    if (ch == '{') {
      return _parseObject();
    } else if (ch == '[') {
      return _parseArray();
    } else if (ch == '"') {
      return _parseStringNode();
    } else if (ch == '-' || (ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57)) {
      return _parseNumberNode();
    } else if (ch == 't' || ch == 'f') {
      return _parseBooleanNode();
    } else if (ch == 'n') {
      return _parseNullNode();
    } else {
      throw ScriptImportParseException(
        ScriptImportError(
          line: _line,
          column: _column,
          message: 'Unexpected character "$ch"',
        ),
      );
    }
  }

  JsonNode _parseObject() {
    final startLine = _line;
    final startColumn = _column;
    final startOffset = _index;

    _consume('{');
    _skipWhitespace();

    final properties = <String, JsonNode>{};
    final keyNodes = <String, JsonNode>{};

    if (!_isAtEnd() && _peek() == '}') {
      _consume('}');
      return JsonNode(
        type: JsonNodeType.object,
        line: startLine,
        column: startColumn,
        offset: startOffset,
        properties: properties,
        keyNodes: keyNodes,
      );
    }

    while (true) {
      _skipWhitespace();
      if (_isAtEnd()) {
        throw ScriptImportParseException(
          ScriptImportError(
            line: _line,
            column: _column,
            message: 'Unterminated object, expected string key or "}"',
          ),
        );
      }

      if (_peek() != '"') {
        throw ScriptImportParseException(
          ScriptImportError(
            line: _line,
            column: _column,
            message: 'Expected string key in object',
          ),
        );
      }

      final keyNode = _parseStringNode();
      final key = keyNode.value as String;

      _skipWhitespace();
      if (_isAtEnd() || _peek() != ':') {
        throw ScriptImportParseException(
          ScriptImportError(
            line: _line,
            column: _column,
            message: 'Expected ":" after key "$key"',
          ),
        );
      }
      _consume(':');

      final valueNode = _parseValue();
      properties[key] = valueNode;
      keyNodes[key] = keyNode;

      _skipWhitespace();
      if (_isAtEnd()) {
        throw ScriptImportParseException(
          ScriptImportError(
            line: _line,
            column: _column,
            message: 'Unterminated object, expected "," or "}"',
          ),
        );
      }

      final next = _peek();
      if (next == '}') {
        _consume('}');
        break;
      } else if (next == ',') {
        _consume(',');
      } else {
        throw ScriptImportParseException(
          ScriptImportError(
            line: _line,
            column: _column,
            message: 'Expected "," or "}" after object property',
          ),
        );
      }
    }

    return JsonNode(
      type: JsonNodeType.object,
      line: startLine,
      column: startColumn,
      offset: startOffset,
      properties: properties,
      keyNodes: keyNodes,
    );
  }

  JsonNode _parseArray() {
    final startLine = _line;
    final startColumn = _column;
    final startOffset = _index;

    _consume('[');
    _skipWhitespace();

    final elements = <JsonNode>[];

    if (!_isAtEnd() && _peek() == ']') {
      _consume(']');
      return JsonNode(
        type: JsonNodeType.array,
        line: startLine,
        column: startColumn,
        offset: startOffset,
        elements: elements,
      );
    }

    while (true) {
      final elem = _parseValue();
      elements.add(elem);

      _skipWhitespace();
      if (_isAtEnd()) {
        throw ScriptImportParseException(
          ScriptImportError(
            line: _line,
            column: _column,
            message: 'Unterminated array, expected "," or "]"',
          ),
        );
      }

      final next = _peek();
      if (next == ']') {
        _consume(']');
        break;
      } else if (next == ',') {
        _consume(',');
      } else {
        throw ScriptImportParseException(
          ScriptImportError(
            line: _line,
            column: _column,
            message: 'Expected "," or "]" after array element',
          ),
        );
      }
    }

    return JsonNode(
      type: JsonNodeType.array,
      line: startLine,
      column: startColumn,
      offset: startOffset,
      elements: elements,
    );
  }

  JsonNode _parseStringNode() {
    final startLine = _line;
    final startColumn = _column;
    final startOffset = _index;

    _consume('"');
    final buffer = StringBuffer();

    while (true) {
      if (_isAtEnd()) {
        throw ScriptImportParseException(
          ScriptImportError(
            line: _line,
            column: _column,
            message: 'Unterminated string literal',
          ),
        );
      }

      final ch = _advance();
      if (ch == '"') {
        break;
      } else if (ch == r'\') {
        if (_isAtEnd()) {
          throw ScriptImportParseException(
            ScriptImportError(
              line: _line,
              column: _column,
              message: 'Unterminated escape sequence in string',
            ),
          );
        }
        final escaped = _advance();
        switch (escaped) {
          case '"':
            buffer.write('"');
            break;
          case r'\':
            buffer.write(r'\');
            break;
          case '/':
            buffer.write('/');
            break;
          case 'b':
            buffer.write('\b');
            break;
          case 'f':
            buffer.write('\f');
            break;
          case 'n':
            buffer.write('\n');
            break;
          case 'r':
            buffer.write('\r');
            break;
          case 't':
            buffer.write('\t');
            break;
          case 'u':
            buffer.write(_parseUnicodeEscape());
            break;
          default:
            throw ScriptImportParseException(
              ScriptImportError(
                line: _line,
                column: _column,
                message: 'Invalid escape sequence "\\$escaped"',
              ),
            );
        }
      } else {
        buffer.write(ch);
      }
    }

    return JsonNode(
      type: JsonNodeType.string,
      value: buffer.toString(),
      line: startLine,
      column: startColumn,
      offset: startOffset,
    );
  }

  String _parseUnicodeEscape() {
    final hexChars = StringBuffer();
    for (var i = 0; i < 4; i++) {
      if (_isAtEnd()) {
        throw ScriptImportParseException(
          ScriptImportError(
            line: _line,
            column: _column,
            message: 'Incomplete unicode escape sequence',
          ),
        );
      }
      hexChars.write(_advance());
    }
    final code = int.tryParse(hexChars.toString(), radix: 16);
    if (code == null) {
      throw ScriptImportParseException(
        ScriptImportError(
          line: _line,
          column: _column,
          message: 'Invalid unicode escape "\\u$hexChars"',
        ),
      );
    }
    return String.fromCharCode(code);
  }

  JsonNode _parseNumberNode() {
    final startLine = _line;
    final startColumn = _column;
    final startOffset = _index;

    final numStr = StringBuffer();
    if (_peek() == '-') {
      numStr.write(_advance());
    }

    while (!_isAtEnd()) {
      final ch = _peek();
      final code = ch.codeUnitAt(0);
      if ((code >= 48 && code <= 57) || ch == '.' || ch == 'e' || ch == 'E' || ch == '+' || ch == '-') {
        numStr.write(_advance());
      } else {
        break;
      }
    }

    final raw = numStr.toString();
    final parsedNum = num.tryParse(raw);
    if (parsedNum == null) {
      throw ScriptImportParseException(
        ScriptImportError(
          line: startLine,
          column: startColumn,
          message: 'Invalid number format "$raw"',
        ),
      );
    }

    return JsonNode(
      type: JsonNodeType.number,
      value: parsedNum,
      line: startLine,
      column: startColumn,
      offset: startOffset,
    );
  }

  JsonNode _parseBooleanNode() {
    final startLine = _line;
    final startColumn = _column;
    final startOffset = _index;

    if (_peek() == 't') {
      _matchLiteral('true');
      return JsonNode(
        type: JsonNodeType.boolean,
        value: true,
        line: startLine,
        column: startColumn,
        offset: startOffset,
      );
    } else {
      _matchLiteral('false');
      return JsonNode(
        type: JsonNodeType.boolean,
        value: false,
        line: startLine,
        column: startColumn,
        offset: startOffset,
      );
    }
  }

  JsonNode _parseNullNode() {
    final startLine = _line;
    final startColumn = _column;
    final startOffset = _index;

    _matchLiteral('null');
    return JsonNode(
      type: JsonNodeType.nullValue,
      value: null,
      line: startLine,
      column: startColumn,
      offset: startOffset,
    );
  }

  void _matchLiteral(String literal) {
    for (var i = 0; i < literal.length; i++) {
      if (_isAtEnd() || _peek() != literal[i]) {
        throw ScriptImportParseException(
          ScriptImportError(
            line: _line,
            column: _column,
            message: 'Unexpected token, expected "$literal"',
          ),
        );
      }
      _advance();
    }
  }

  void _skipWhitespace() {
    while (!_isAtEnd()) {
      final ch = _peek();
      if (ch == ' ' || ch == '\t' || ch == '\r' || ch == '\n') {
        _advance();
      } else {
        break;
      }
    }
  }

  bool _isAtEnd() => _index >= _source.length;

  String _peek() => _source[_index];

  String _advance() {
    final ch = _source[_index++];
    if (ch == '\r') {
      if (!_isAtEnd() && _source[_index] == '\n') {
        _index++;
      }
      _line++;
      _column = 1;
    } else if (ch == '\n') {
      _line++;
      _column = 1;
    } else {
      _column++;
    }
    return ch;
  }

  void _consume(String expected) {
    if (_isAtEnd() || _peek() != expected) {
      throw ScriptImportParseException(
        ScriptImportError(
          line: _line,
          column: _column,
          message: 'Expected "$expected"',
        ),
      );
    }
    _advance();
  }
}
