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

import 'dart:io';

import 'package:extended_image/extended_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wger/core/media_cache_service.dart';
import 'package:wger/core/network/network_provider.dart';
import 'package:wger/core/network/wger_base.dart';
import 'package:wger/core/widgets/offline_media_placeholder.dart';
import 'package:wger/core/widgets/wger_image.dart';
import 'package:wger/l10n/generated/app_localizations.dart';
import 'package:wger/l10n/localizations_delegates.dart';

void main() {
  late Directory tempDir;
  late MediaCacheService mediaCache;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('wger_image_test_');
    mediaCache = MediaCacheService(
      getStorageDir: () async => tempDir,
      initialStorageDir: tempDir,
    );
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  Widget wrap({
    required Widget child,
    bool isOnline = true,
    MediaCacheService? cacheService,
  }) {
    return ProviderScope(
      overrides: [
        networkStatusProvider.overrideWithValue(isOnline),
        mediaCacheServiceProvider.overrideWithValue(cacheService ?? mediaCache),
        mediaUrlBuilderProvider.overrideWithValue(
          (path) => path != null ? Uri.parse('https://example.test/media/$path') : null,
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: Center(child: child)),
      ),
    );
  }

  testWidgets('renders local file directly when cached on disk', (tester) async {
    final localFile = mediaCache.getFileForPath('exercises/bench.png');
    localFile.parent.createSync(recursive: true);
    localFile.writeAsStringSync('fake image');

    await tester.pumpWidget(
      wrap(
        child: const WgerImage(
          mediaPath: 'exercises/bench.png',
          placeholder: SizedBox.shrink(),
        ),
        isOnline: false,
      ),
    );

    expect(find.byType(ExtendedImage), findsOneWidget);
    expect(find.byType(OfflineMediaPlaceholder), findsNothing);
  });

  testWidgets('shows OfflineMediaPlaceholder when not cached and offline', (tester) async {
    await tester.pumpWidget(
      wrap(
        child: const WgerImage(
          mediaPath: 'exercises/squat.png',
          width: 150,
          height: 150,
        ),
        isOnline: false,
      ),
    );
    await tester.pump();

    expect(find.byType(OfflineMediaPlaceholder), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    expect(find.text('Not available offline'), findsOneWidget);
  });

  testWidgets('renders custom errorWidget when mediaPath is null', (tester) async {
    const errorKey = ValueKey('custom-error');
    await tester.pumpWidget(
      wrap(
        child: const WgerImage(
          mediaPath: null,
          errorWidget: SizedBox(key: errorKey),
        ),
        isOnline: false,
      ),
    );
    await tester.pump();

    expect(find.byKey(errorKey), findsOneWidget);
    expect(find.byType(OfflineMediaPlaceholder), findsNothing);
  });
}
