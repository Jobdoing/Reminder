import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:reminder/services/photo_store.dart';

void main() {
  late Directory documents;

  setUp(() async {
    documents = await Directory.systemTemp.createTemp('photostore_documents');
    PhotoStore.init(documents);
  });

  tearDown(() async {
    await documents.delete(recursive: true);
  });

  test(
    'compressInto writes compressed bytes and keeps source for retry',
    () async {
      final tmp = await Directory.systemTemp.createTemp('photostore');
      final src = File('${tmp.path}/src.jpg')
        ..writeAsBytesSync(List.filled(9999, 7));
      final root = Directory('${tmp.path}/store');

      Future<List<int>?> fakeCompress(
        String path, {
        int maxDimension = 0,
        int quality = 0,
      }) async {
        expect(path, src.path);
        return [1, 2, 3];
      }

      final dest = await PhotoStore.compressInto(src.path, root, fakeCompress);

      expect(File(dest).readAsBytesSync(), [1, 2, 3]);
      expect(src.existsSync(), isTrue);
      expect(dest.endsWith('.jpg'), isTrue);
      await tmp.delete(recursive: true);
    },
  );

  test(
    'compressInto copies the original when compressor returns null',
    () async {
      final tmp = await Directory.systemTemp.createTemp('photostore');
      final src = File('${tmp.path}/src.jpg')..writeAsBytesSync([9, 9, 9]);
      final root = Directory('${tmp.path}/store');

      Future<List<int>?> failCompress(
        String path, {
        int maxDimension = 0,
        int quality = 0,
      }) async => null;

      final dest = await PhotoStore.compressInto(src.path, root, failCompress);

      expect(File(dest).readAsBytesSync(), [9, 9, 9]);
      expect(src.existsSync(), isTrue);
      await tmp.delete(recursive: true);
    },
  );

  test('deleteTemporaryFile removes an existing camera file', () async {
    final tmp = await Directory.systemTemp.createTemp('photostore');
    final f = File('${tmp.path}/x.jpg')..writeAsBytesSync([9]);
    await PhotoStore.deleteTemporaryFile(f.path);
    expect(f.existsSync(), isFalse);
    await tmp.delete(recursive: true);
  });

  test('stored paths stay valid when the app container changes', () {
    final current = File('${documents.path}/memory_photos/x.jpg')
      ..createSync(recursive: true)
      ..writeAsBytesSync([1]);
    const legacy = '/old/app/container/Documents/memory_photos/x.jpg';

    expect(PhotoStore.storagePath(legacy), 'memory_photos/x.jpg');
    expect(PhotoStore.file(legacy).path, current.path);
    expect(PhotoStore.file('memory_photos/x.jpg').path, current.path);
  });

  test('stored relative paths cannot leave the photo directory', () {
    expect(
      () => PhotoStore.file('memory_photos/../private.txt'),
      throwsArgumentError,
    );
    expect(() => PhotoStore.file('memory_photos/%2e%2e'), throwsArgumentError);
    expect(
      () => PhotoStore.file('${documents.path}/outside.jpg'),
      throwsArgumentError,
    );
  });

  test('deleteStoredFile resolves a stored relative path', () async {
    final photo = File('${documents.path}/memory_photos/x.jpg')
      ..createSync(recursive: true)
      ..writeAsBytesSync([1]);

    await PhotoStore.deleteStoredFile('memory_photos/x.jpg');

    expect(photo.existsSync(), isFalse);
  });
}
