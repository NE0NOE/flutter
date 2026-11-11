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

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wger/core/media_cache_service.dart';

void main() {
  late Directory tempDir;
  late MediaCacheService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('wger_media_cache_test_');
    service = MediaCacheService(
      getStorageDir: () async => tempDir,
      initialStorageDir: tempDir,
    );
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('MediaCacheService', () {
    test('getFileForPath creates correct relative path hierarchy', () {
      final file = service.getFileForPath('exercise-images/1/test.png');
      expect(file.path, equals('${tempDir.path}/exercise-images/1/test.png'));
    });

    test('getFileForPath strips leading slashes, query parameters, and URLs', () {
      final file1 = service.getFileForPath('/exercise-images/1/test.png?v=123');
      expect(file1.path, equals('${tempDir.path}/exercise-images/1/test.png'));

      final file2 = service.getFileForPath(
        'https://example.com/media/exercise-videos/42/video.mp4',
      );
      expect(file2.path, equals('${tempDir.path}/media/exercise-videos/42/video.mp4'));
    });

    test('getCachedFile returns null when file does not exist or is empty', () async {
      expect(service.getCachedFile('exercise-images/1/notfound.png'), isNull);
      expect(service.getCachedFile(null), isNull);
      expect(service.getCachedFile(''), isNull);

      final emptyFile = service.getFileForPath('exercise-images/1/empty.png');
      await emptyFile.parent.create(recursive: true);
      await emptyFile.writeAsBytes([]);
      expect(service.getCachedFile('exercise-images/1/empty.png'), isNull);
    });

    test('getCachedFile returns existing non-empty file', () async {
      final file = service.getFileForPath('exercise-images/1/test.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes([1, 2, 3, 4]);

      final cached = service.getCachedFile('exercise-images/1/test.png');
      expect(cached, isNotNull);
      expect(cached!.existsSync(), isTrue);
      expect(cached.lengthSync(), equals(4));
    });

    test('downloadMedia downloads bytes and writes atomically to storage', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('sample.jpg')) {
          return http.Response.bytes([10, 20, 30, 40, 50], 200);
        }
        return http.Response('Not found', 404);
      });

      final testService = MediaCacheService(
        client: mockClient,
        getStorageDir: () async => tempDir,
        initialStorageDir: tempDir,
      );

      final downloaded = await testService.downloadMedia(
        'exercise-images/99/sample.jpg',
        Uri.parse('https://example.com/media/exercise-images/99/sample.jpg'),
      );

      expect(downloaded, isNotNull);
      expect(downloaded!.existsSync(), isTrue);
      expect(downloaded.readAsBytesSync(), equals([10, 20, 30, 40, 50]));

      // Calling again returns cached file without new network request
      final cachedAgain = await testService.downloadMedia(
        'exercise-images/99/sample.jpg',
        Uri.parse('https://example.com/media/exercise-images/99/sample.jpg'),
      );
      expect(cachedAgain!.path, equals(downloaded.path));
    });

    test('downloadMedia handles HTTP failure gracefully', () async {
      final mockClient = MockClient((request) async => http.Response('Error', 500));

      final testService = MediaCacheService(
        client: mockClient,
        getStorageDir: () async => tempDir,
        initialStorageDir: tempDir,
      );

      final downloaded = await testService.downloadMedia(
        'exercise-images/99/fail.jpg',
        Uri.parse('https://example.com/media/exercise-images/99/fail.jpg'),
      );

      expect(downloaded, isNull);
      expect(testService.getCachedFile('exercise-images/99/fail.jpg'), isNull);
    });

    test('prefetchMediaPaths downloads multiple media items skipping existing ones', () async {
      int requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount++;
        return http.Response.bytes([1, 2, 3], 200);
      });

      final testService = MediaCacheService(
        client: mockClient,
        getStorageDir: () async => tempDir,
        initialStorageDir: tempDir,
      );

      // Pre-seed item 1
      final preSeeded = testService.getFileForPath('item1.png');
      await preSeeded.parent.create(recursive: true);
      await preSeeded.writeAsBytes([9, 9, 9]);

      final mediaPaths = ['item1.png', 'item2.png', 'item3.mp4'];
      await testService.prefetchMediaPaths(
        mediaPaths,
        (path) => Uri.parse('https://example.com/media/$path'),
      );

      // Only item2.png and item3.mp4 should have triggered HTTP requests
      expect(requestCount, equals(2));
      expect(testService.getCachedFile('item1.png'), isNotNull);
      expect(testService.getCachedFile('item2.png'), isNotNull);
      expect(testService.getCachedFile('item3.mp4'), isNotNull);
    });
  });
}
