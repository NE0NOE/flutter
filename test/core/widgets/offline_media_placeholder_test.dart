/*
 * This file is part of wger Workout Manager <https://github.com/wger-project>.
 * Copyright (c) 2026 - 2026 wger Team
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
import 'package:material_ui/material_ui.dart';
import 'package:wger/core/widgets/offline_media_placeholder.dart';
import 'package:wger/l10n/generated/app_localizations.dart';
import 'package:wger/l10n/localizations_delegates.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Center(child: child)),
    );
  }

  testWidgets('renders default icon and localized message in standard container', (tester) async {
    await tester.pumpWidget(
      wrap(
        const SizedBox(
          width: 200,
          height: 150,
          child: OfflineMediaPlaceholder(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    expect(find.text('Not available offline'), findsOneWidget);
  });

  testWidgets('renders custom icon and message', (tester) async {
    await tester.pumpWidget(
      wrap(
        const SizedBox(
          width: 200,
          height: 150,
          child: OfflineMediaPlaceholder(
            icon: Icons.videocam_off,
            message: 'Video not available offline',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.videocam_off), findsOneWidget);
    expect(find.text('Video not available offline'), findsOneWidget);
  });

  testWidgets('compact container renders icon with tooltip without overflowing text', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const SizedBox(
          width: 45,
          height: 45,
          child: OfflineMediaPlaceholder(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    expect(find.byType(Tooltip), findsOneWidget);
    expect(find.text('Not available offline'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
