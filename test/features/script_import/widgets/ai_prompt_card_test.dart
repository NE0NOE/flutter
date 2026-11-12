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

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wger/features/script_import/script_import_prompt.dart';
import 'package:wger/features/script_import/widgets/ai_prompt_card.dart';
import 'package:wger/l10n/generated/app_localizations.dart';
import 'package:wger/l10n/localizations_delegates.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );

  testWidgets('renders AI prompt card and copies prompt to clipboard on tap', (tester) async {
    String? copiedClipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall methodCall) async {
        if (methodCall.method == 'Clipboard.setData') {
          final args = methodCall.arguments as Map?;
          copiedClipboardText = args?['text'] as String?;
        }
        return null;
      },
    );

    await tester.pumpWidget(wrap(const AiPromptCard()));
    await tester.pumpAndSettle();

    expect(find.text('Generate with AI'), findsOneWidget);
    expect(find.byKey(const Key('copy_ai_prompt_button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('copy_ai_prompt_button')));
    await tester.pumpAndSettle();

    expect(copiedClipboardText, equals(aiScriptImportPrompt));
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('AI prompt copied to clipboard'), findsOneWidget);
  });
}
