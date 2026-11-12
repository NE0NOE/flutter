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

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:wger/core/network/auth_http_client.dart';

/// Persistent on-disk cache for routine exercise media (images, GIFs, videos).
///
/// Unlike the temporary extended_image cache which is swept on startup and subject
/// to OS cache eviction, this service persists media files under the application
/// support directory so that they remain available offline indefinitely.
class MediaCacheService {
  static final _logger = Logger('MediaCacheService');

  /// Global storage directory pre-warmed during app initialization.
  static Directory? cachedStorageDir;

  final http.Client _client;
  final Future<Directory> Function() _getStorageDir;
  Directory? _storageDir;

  MediaCacheService({
    http.Client? client,
    Future<Directory> Function()? getStorageDir,
    Directory? initialStorageDir,
  }) : _client = client ?? http.Client(),
       _getStorageDir = getStorageDir ?? _defaultStorageDir,
       _storageDir = initialStorageDir ?? cachedStorageDir;

  static Future<Directory> _defaultStorageDir() async {
    final supportDir = await getApplicationSupportDirectory();
    return Directory(p.join(supportDir.path, 'routine_media'));
  }

  /// Ensures the storage directory exists and returns it.
  Future<Directory> init() async {
    if (_storageDir != null) {
      if (!_storageDir!.existsSync()) {
        await _storageDir!.create(recursive: true);
      }
      return _storageDir!;
    }
    if (kIsWeb) {
      throw UnsupportedError('MediaCacheService is not supported on web');
    }
    final dir = await _getStorageDir();
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    _storageDir = dir;
    cachedStorageDir = dir;
    return dir;
  }

  Directory? get storageDir => _storageDir ?? cachedStorageDir;

  /// Resolves the local file for [mediaPath] in [dir].
  File getFileForPath(String mediaPath, {Directory? dir}) {
    final base = dir ?? storageDir;
    if (base == null) {
      throw StateError('Storage directory is not initialized');
    }
    var clean = mediaPath.trim();
    if (clean.contains('?')) {
      clean = clean.split('?').first;
    }
    final uri = Uri.tryParse(clean);
    if (uri != null && uri.hasScheme) {
      clean = uri.path;
    }
    if (clean.startsWith('/')) {
      clean = clean.substring(1);
    }
    return File(p.join(base.path, clean));
  }

  /// Returns the cached [File] for [mediaPath] if it exists on disk, null otherwise.
  File? getCachedFile(String? mediaPath) {
    if (mediaPath == null || mediaPath.trim().isEmpty || kIsWeb) {
      return null;
    }
    final dir = storageDir;
    if (dir == null) {
      return null;
    }
    try {
      final file = getFileForPath(mediaPath, dir: dir);
      if (file.existsSync() && file.lengthSync() > 0) {
        return file;
      }
    } catch (e) {
      _logger.fine('Could not check cached file for $mediaPath: $e');
    }
    return null;
  }

  /// Downloads [url] and stores it under [mediaPath] in persistent storage.
  ///
  /// Writes atomically to a `.tmp` file first to prevent partial downloads.
  Future<File?> downloadMedia(String mediaPath, Uri url) async {
    if (kIsWeb || mediaPath.trim().isEmpty) {
      return null;
    }
    try {
      final dir = await init();
      final target = getFileForPath(mediaPath, dir: dir);
      if (target.existsSync() && target.lengthSync() > 0) {
        return target;
      }

      final response = await _client.get(url);
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        if (!target.parent.existsSync()) {
          await target.parent.create(recursive: true);
        }
        final tempFile = File('${target.path}.tmp');
        await tempFile.writeAsBytes(response.bodyBytes, flush: true);
        await tempFile.rename(target.path);
        _logger.fine('Downloaded and cached routine media: $mediaPath');
        return target;
      } else {
        _logger.warning('Failed to download $url: HTTP ${response.statusCode}');
      }
    } catch (e, st) {
      _logger.warning('Error downloading $url: $e', e, st);
    }
    return null;
  }

  /// Downloads all [mediaPaths] in parallel, skipping already cached entries.
  Future<void> prefetchMediaPaths(
    Iterable<String> mediaPaths,
    Uri? Function(String? path) urlBuilder,
  ) async {
    if (kIsWeb) {
      return;
    }
    final uniquePaths = mediaPaths.where((p) => p.trim().isNotEmpty).toSet();
    final toDownload = <String, Uri>{};
    for (final path in uniquePaths) {
      if (getCachedFile(path) != null) {
        continue;
      }
      final url = urlBuilder(path);
      if (url != null) {
        toDownload[path] = url;
      }
    }

    if (toDownload.isEmpty) {
      return;
    }

    await Future.wait(
      toDownload.entries.map((entry) => downloadMedia(entry.key, entry.value)),
    );
  }
}

/// Global warm-up called during `main` before `runApp`.
Future<void> initMediaCache() async {
  if (kIsWeb) {
    return;
  }
  try {
    final supportDir = await getApplicationSupportDirectory();
    final dir = Directory(p.join(supportDir.path, 'routine_media'));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    MediaCacheService.cachedStorageDir = dir;
  } catch (e) {
    // Non-fatal, lazy initialization in MediaCacheService will retry.
  }
}

final mediaCacheServiceProvider = Provider<MediaCacheService>((ref) {
  final client = ref.watch(authenticatedHttpClientProvider);
  final service = MediaCacheService(client: client);
  // Warm the directory in production; in widget tests without path_provider mocks,
  // skip the unawaited channel call so pending timers don't leak.
  if (!Platform.environment.containsKey('FLUTTER_TEST')) {
    service.init().then((_) {}, onError: (Object _) {});
  }
  return service;
});
