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
import 'package:wger/core/error_dialogs.dart';
import 'package:wger/core/media_cache_service.dart';
import 'package:wger/core/network/network_provider.dart';
import 'package:wger/core/network/wger_base.dart';
import 'package:wger/core/widgets/offline_media_placeholder.dart';
import 'package:wger/features/exercises/models/video.dart';
import 'package:wger/features/exercises/widgets/videos.dart';
import 'package:wger/l10n/generated/app_localizations.dart';
import 'package:wger/l10n/localizations_delegates.dart';

void main() {
  late Directory tempDir;
  late MediaCacheService mediaCache;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('exercise_videos_test_');
    mediaCache = MediaCacheService(
      getStorageDir: () async => tempDir,
      initialStorageDir: tempDir,
    );
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
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

  Video makeTestVideo({required String path}) {
    return Video(
      id: 1,
      uuid: 'vid-1',
      exerciseId: 10,
      video: path,
      isMain: true,
      size: 1000,
      duration: 10,
      width: 1920,
      height: 1080,
      codec: 'h264',
      codecLong: 'h264',
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

  testWidgets('shows OfflineMediaPlaceholder when video is not cached and offline', (
    tester,
  ) async {
    final video = makeTestVideo(path: 'exercise-videos/bench.mp4');

    await tester.pumpWidget(
      wrap(
        child: ExerciseVideoWidget(video: video),
        isOnline: false,
      ),
    );
    await tester.pump();

    expect(find.byType(OfflineMediaPlaceholder), findsOneWidget);
    expect(find.byIcon(Icons.videocam_off), findsOneWidget);
    expect(find.text('Video not available offline'), findsOneWidget);
    expect(find.byType(FormHttpErrorsWidget), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
