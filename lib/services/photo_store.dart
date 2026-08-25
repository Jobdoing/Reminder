import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:uuid/uuid.dart';

typedef PhotoCompressor =
    Future<List<int>?> Function(
      String sourcePath, {
      int maxDimension,
      int quality,
    });

class PhotoStore {
  static const _folderName = 'memory_photos';
  static const _uuid = Uuid();
  static final _storedFileName = RegExp(r'^[A-Za-z0-9-]+\.jpg$');
  static const maxDimension = 1600;
  static const jpegQuality = 75;
  static Directory? _documents;

  static void init(Directory documents) {
    _documents = documents;
  }

  static Future<String> importPhoto(String sourcePath) async {
    final root = Directory.fromUri(
      _documentsDirectory.uri.resolve('$_folderName/'),
    );
    final absolutePath = await compressInto(sourcePath, root, _defaultCompress);
    return '$_folderName/${Uri.file(absolutePath).pathSegments.last}';
  }

  static Directory get _documentsDirectory {
    final documents = _documents;
    if (documents == null) {
      throw StateError(
        'PhotoStore.init must be called before using stored photos.',
      );
    }
    return documents;
  }

  static File file(String path) {
    if (path.isEmpty) return File(path);
    return _relativeFile(storagePath(path));
  }

  static String storagePath(String path) {
    if (path.isEmpty || !_isAbsolute(path)) {
      return path.isEmpty ? path : _validatedRelativePath(path);
    }

    final segments = Uri.file(path).pathSegments;
    final folderIndex = segments.lastIndexOf(_folderName);
    if (folderIndex < 0 || folderIndex + 1 != segments.length - 1) {
      throw ArgumentError.value(path, 'path', 'Invalid stored photo path');
    }
    return _validatedRelativePath('$_folderName/${segments.last}');
  }

  static File _relativeFile(String path) =>
      File.fromUri(_documentsDirectory.uri.resolve(path));

  static String _validatedRelativePath(String path) {
    final segments = path.split('/');
    if (segments.length != 2 ||
        segments.first != _folderName ||
        !_storedFileName.hasMatch(segments.last)) {
      throw ArgumentError.value(path, 'path', 'Invalid stored photo path');
    }
    return path;
  }

  static bool _isAbsolute(String path) => path.startsWith('/');

  static Future<List<int>?> _defaultCompress(
    String sourcePath, {
    int maxDimension = maxDimension,
    int quality = jpegQuality,
  }) {
    // NOTE(ceiling): flutter_image_compress minWidth/minHeight bound the
    // shorter side; exact longest-edge sizing is tuned/verified on device
    // (Task 11). Text legibility is the acceptance bar, not exact pixels.
    return FlutterImageCompress.compressWithFile(
      sourcePath,
      minWidth: maxDimension,
      minHeight: maxDimension,
      quality: quality,
      keepExif: false,
    );
  }

  @visibleForTesting
  static Future<String> compressInto(
    String sourcePath,
    Directory root,
    PhotoCompressor compress,
  ) async {
    await root.create(recursive: true);
    final destination = File('${root.path}/${_uuid.v4()}.jpg');
    final bytes = await compress(
      sourcePath,
      maxDimension: maxDimension,
      quality: jpegQuality,
    );
    if (bytes != null) {
      await destination.writeAsBytes(bytes);
    } else {
      // NOTE(ceiling): compression failed (unsupported format, etc.); store
      // the original so a photo is never lost. Larger file beats data loss.
      await File(sourcePath).copy(destination.path);
    }
    return destination.path;
  }

  static Future<void> deleteStoredFile(String path) async {
    if (path.isEmpty) return;
    final file = PhotoStore.file(path);
    if (await file.exists()) await file.delete();
  }

  static Future<void> deleteTemporaryFile(String path) async {
    if (path.isEmpty) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
