// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserModelAdapter extends TypeAdapter<UserModel> {
  @override
  final int typeId = 3;

  @override
  UserModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserModel(
      id: fields[0] as String,
      displayName: fields[1] as String?,
      email: fields[2] as String?,
      photoUrl: fields[3] as String?,
      role: fields[4] as String,
      accountStatus: fields[5] as String,
      isProfileComplete: fields[6] as bool,
      documentUrl: fields[7] as String?,
      whatsappNumber: fields[8] as String?,
      governorates: (fields[9] as List?)?.cast<String>(),
      centers: (fields[10] as List?)?.cast<String>(),
      createdAt: fields[11] as DateTime,
      lastLatitude: fields[12] as double?,
      lastLongitude: fields[13] as double?,
      lastLocationUpdate: fields[14] as DateTime?,
      referralCode: fields[15] as String?,
      points: fields[16] as int?,
      rank: fields[17] as int?,
      distributionMethod: fields[18] as String?,
      subscribersCount: fields[19] as int?,
      rejectionReason: fields[20] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, UserModel obj) {
    writer
      ..writeByte(21)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.displayName)
      ..writeByte(2)
      ..write(obj.email)
      ..writeByte(3)
      ..write(obj.photoUrl)
      ..writeByte(4)
      ..write(obj.role)
      ..writeByte(5)
      ..write(obj.accountStatus)
      ..writeByte(6)
      ..write(obj.isProfileComplete)
      ..writeByte(7)
      ..write(obj.documentUrl)
      ..writeByte(8)
      ..write(obj.whatsappNumber)
      ..writeByte(9)
      ..write(obj.governorates)
      ..writeByte(10)
      ..write(obj.centers)
      ..writeByte(11)
      ..write(obj.createdAt)
      ..writeByte(12)
      ..write(obj.lastLatitude)
      ..writeByte(13)
      ..write(obj.lastLongitude)
      ..writeByte(14)
      ..write(obj.lastLocationUpdate)
      ..writeByte(15)
      ..write(obj.referralCode)
      ..writeByte(16)
      ..write(obj.points)
      ..writeByte(17)
      ..write(obj.rank)
      ..writeByte(18)
      ..write(obj.distributionMethod)
      ..writeByte(19)
      ..write(obj.subscribersCount)
      ..writeByte(20)
      ..write(obj.rejectionReason);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
