// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'caching_service.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CacheEntryAdapter extends TypeAdapter<CacheEntry> {
  @override
  final int typeId = 2;

  @override
  CacheEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CacheEntry(
      fields[0] as dynamic,
      fields[1] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, CacheEntry obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.data)
      ..writeByte(1)
      ..write(obj.expiryTime);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CacheEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
