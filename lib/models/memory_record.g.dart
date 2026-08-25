// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'memory_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MemoryRecordAdapter extends TypeAdapter<MemoryRecord> {
  @override
  final int typeId = 0;

  @override
  MemoryRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MemoryRecord(
      id: fields[0] as String,
      photoPath: fields[1] as String,
      text: fields[2] as String,
      createdAt: fields[3] as DateTime,
      isReminder: fields[4] == null ? false : fields[4] as bool,
      reminderAt: fields[5] as DateTime?,
      intent: fields[6] == null ? 'record' : fields[6] as String,
      mentionedContacts:
          fields[7] == null ? [] : (fields[7] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, MemoryRecord obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.photoPath)
      ..writeByte(2)
      ..write(obj.text)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.isReminder)
      ..writeByte(5)
      ..write(obj.reminderAt)
      ..writeByte(6)
      ..write(obj.intent)
      ..writeByte(7)
      ..write(obj.mentionedContacts);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemoryRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
