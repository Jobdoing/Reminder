import 'package:hive_flutter/hive_flutter.dart';

part 'memory_record.g.dart';

@HiveType(typeId: 0)
class MemoryRecord extends HiveObject {
  MemoryRecord({
    required this.id,
    required this.photoPath,
    required this.text,
    required this.createdAt,
    this.isReminder = false,
    this.reminderAt,
    this.intent = 'record',
    this.mentionedContacts = const [],
  });

  @HiveField(0)
  String id;

  @HiveField(1)
  String photoPath;

  @HiveField(2)
  String text;

  @HiveField(3)
  DateTime createdAt;

  @HiveField(4, defaultValue: false)
  bool isReminder;

  @HiveField(5)
  DateTime? reminderAt;

  @HiveField(6, defaultValue: 'record')
  String intent;

  @HiveField(7, defaultValue: <String>[])
  List<String> mentionedContacts;
}
