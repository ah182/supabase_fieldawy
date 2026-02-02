// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_challenge_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DailyChallengeModelAdapter extends TypeAdapter<DailyChallengeModel> {
  @override
  final int typeId = 20;

  @override
  DailyChallengeModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DailyChallengeModel(
      id: fields[0] as String,
      date: fields[1] as DateTime,
      products: (fields[2] as List).cast<ProductModel>(),
      activePrinciple: fields[3] as String,
      packageType: fields[4] as String,
      isCompleted: fields[5] as bool,
      isDismissedForNow: fields[6] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, DailyChallengeModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.products)
      ..writeByte(3)
      ..write(obj.activePrinciple)
      ..writeByte(4)
      ..write(obj.packageType)
      ..writeByte(5)
      ..write(obj.isCompleted)
      ..writeByte(6)
      ..write(obj.isDismissedForNow);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyChallengeModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
