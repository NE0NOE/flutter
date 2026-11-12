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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wger/core/media_cache_service.dart';
import 'package:wger/core/network/network_provider.dart';
import 'package:wger/core/network/wger_base.dart';
import 'package:wger/core/widgets/offline_media_placeholder.dart';
import 'package:wger/features/exercises/models/image.dart';
import 'package:wger/features/exercises/widgets/images.dart';
import 'package:wger/l10n/generated/app_localizations.dart';
import 'package:wger/l10n/localizations_delegates.dart';

void main() {
  late Directory tempDir;
  late MediaCacheService mediaCache;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('exercise_images_test_');
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
  }) {
    return ProviderScope(
      overrides: [
        networkStatusProvider.overrideWithValue(isOnline),
        mediaCacheServiceProvider.overrideWithValue(mediaCache),
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

  ExerciseImage makeTestImage({required String path}) {
    return ExerciseImage(
      id: 1,
      uuid: 'img-1',
      exerciseId: 10,
      image: path,
      isMain: true,
      isAiGenerated: false,
      style: ExerciseImageStyle.photo,
      width: 100,
      height: 100,
      created: DateTime.now(),
      lastUpdate: DateTime.now(),
      licenseId: 1,
      licenseTitle: 'CC',
      licenseObjectUrl: '',
      licenseAuthor: 'wger',
      licenseAuthorUrl: '',
      licenseDerivativeSourceUrl: '',
    );
  }

  testWidgets('shows OfflineMediaPlaceholder when exercise has image but not cached and offline', (
    tester,
  ) async {
    final image = makeTestImage(path: 'exercises/bench.png');

    await tester.pumpWidget(
      wrap(
        child: ExerciseImageWidget(image: image, height: 100),
        isOnline: false,
      ),
    );
    await tester.pump();

    expect(find.byType(OfflineMediaPlaceholder), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off), findsOneWidget);
  });

  testWidgets('shows default asset placeholder when exercise has no image', (tester) async {
    await tester.pumpWidget(
      wrap(
        child: const ExerciseImageWidget(image: null, height: 100),
        isOnline: false,
      ),
    );
    await tester.pump();

    expect(find.byType(OfflineMediaPlaceholder), findsNothing);
    expect(find.byType(Image), findsOneWidget);
  });
}
