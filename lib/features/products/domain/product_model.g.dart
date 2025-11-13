// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProductModelAdapter extends TypeAdapter<ProductModel> {
  @override
  final int typeId = 0;

  @override
  ProductModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProductModel(
      id: fields[0] as String,
      name: fields[1] as String,
      description: fields[2] as String?,
      activePrinciple: fields[3] as String?,
      company: fields[4] as String?,
      action: fields[5] as String?,
      package: fields[6] as String?,
      availablePackages: (fields[7] as List).cast<String>(),
      imageUrl: fields[8] as String,
      price: fields[9] as double?,
      distributorId: fields[10] as String?,
      createdAt: fields[11] as DateTime?,
      selectedPackage: fields[12] as String?,
      isFavorite: fields[13] as bool,
      views: fields[14] as int,
      surgicalToolId: fields[15] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ProductModel obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.activePrinciple)
      ..writeByte(4)
      ..write(obj.company)
      ..writeByte(5)
      ..write(obj.action)
      ..writeByte(6)
      ..write(obj.package)
      ..writeByte(7)
      ..write(obj.availablePackages)
      ..writeByte(8)
      ..write(obj.imageUrl)
      ..writeByte(9)
      ..write(obj.price)
      ..writeByte(10)
      ..write(obj.distributorId)
      ..writeByte(11)
      ..write(obj.createdAt)
      ..writeByte(12)
      ..write(obj.selectedPackage)
      ..writeByte(13)
      ..write(obj.isFavorite)
      ..writeByte(14)
      ..write(obj.views)
      ..writeByte(15)
      ..write(obj.surgicalToolId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class OCRProductModelAdapter extends TypeAdapter<OCRProductModel> {
  @override
  final int typeId = 1;

  @override
  OCRProductModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OCRProductModel(
      id: fields[0] as String,
      distributorId: fields[1] as String,
      distributorName: fields[2] as String,
      productName: fields[3] as String,
      productCompany: fields[4] as String,
      activePrinciple: fields[5] as String,
      package: fields[6] as String,
      imageUrl: fields[7] as String,
      createdAt: fields[8] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, OCRProductModel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.distributorId)
      ..writeByte(2)
      ..write(obj.distributorName)
      ..writeByte(3)
      ..write(obj.productName)
      ..writeByte(4)
      ..write(obj.productCompany)
      ..writeByte(5)
      ..write(obj.activePrinciple)
      ..writeByte(6)
      ..write(obj.package)
      ..writeByte(7)
      ..write(obj.imageUrl)
      ..writeByte(8)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OCRProductModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
