import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:reminder/services/contact_store.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp();
    Hive.init(dir.path);
    await ContactStore.init();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('names round-trip and dedup/trim', () async {
    await ContactStore.setNames(['  王小明 ', '王小明', '陳美玲']);
    expect(ContactStore.names().toSet(), {'王小明', '陳美玲'});
  });
}
