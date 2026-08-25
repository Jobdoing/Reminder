import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:reminder/semantic/note_analysis.dart';
import 'package:reminder/services/part_of_day_store.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp();
    Hive.init(dir.path);
    await PartOfDayStore.init();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('defaults match the part-of-day table', () {
    expect(PartOfDayStore.timeFor(DayPart.morning), (8, 0));
    expect(PartOfDayStore.timeFor(DayPart.noon), (12, 0));
    expect(PartOfDayStore.timeFor(DayPart.afternoon), (14, 0));
    expect(PartOfDayStore.timeFor(DayPart.dusk), (17, 0));
    expect(PartOfDayStore.timeFor(DayPart.evening), (20, 0));
  });

  test('a learned time overrides the default for that part only', () async {
    await PartOfDayStore.setTimeFor(DayPart.morning, 9, 0);
    expect(PartOfDayStore.timeFor(DayPart.morning), (9, 0));
    // Other parts keep their defaults.
    expect(PartOfDayStore.timeFor(DayPart.evening), (20, 0));
  });

  test('learned time survives reopening the box', () async {
    await PartOfDayStore.setTimeFor(DayPart.evening, 21, 30);
    await Hive.close();
    await PartOfDayStore.init();
    expect(PartOfDayStore.timeFor(DayPart.evening), (21, 30));
  });
}
