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

/// Represents a syntax, structural, or semantic error found while parsing
/// or validating a script import payload.
class ScriptImportError {
  final int line;
  final int? column;
  final String? path;
  final String message;

  const ScriptImportError({
    required this.line,
    this.column,
    this.path,
    required this.message,
  });

  /// Human-readable error description, including line and field path if available.
  /// Example: 'Line 12, field "days[0].slots[1].sets": expected an integer'
  String get formattedMessage {
    final buffer = StringBuffer('Line $line');
    if (path != null && path!.isNotEmpty) {
      buffer.write(', field "$path"');
    }
    buffer.write(': $message');
    return buffer.toString();
  }

  @override
  String toString() => formattedMessage;
}
