class SurgicalToolModel {
  final String id;
  final String toolName;
  final String? company;
  final String? imageUrl;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // معلومات الموزع (من جدول distributor_surgical_tools)
  final String? description;        // الوصف من الموزع (كل موزع له وصفه الخاص)
  final double? price;              // السعر من الموزع
  final String? distributorName;    // اسم الموزع

  SurgicalToolModel({
    required this.id,
    required this.toolName,
    this.company,
    this.imageUrl,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.description,
    this.price,
    this.distributorName,
  });

  factory SurgicalToolModel.fromMap(Map<String, dynamic> map) {
    return SurgicalToolModel(
      id: map['id']?.toString() ?? '',
      toolName: map['tool_name']?.toString() ?? '',
      company: map['company']?.toString(),
      imageUrl: map['image_url']?.toString(),
      createdBy: map['created_by']?.toString(),
      createdAt: map['created_at'] != null 
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
      description: map['description']?.toString(),
      price: (map['price'] as num?)?.toDouble(),
      distributorName: map['distributor_name']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tool_name': toolName,
      if (company != null) 'company': company,
      if (imageUrl != null) 'image_url': imageUrl,
      if (createdBy != null) 'created_by': createdBy,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      if (description != null) 'description': description,
      if (price != null) 'price': price,
      if (distributorName != null) 'distributor_name': distributorName,
    };
  }

  SurgicalToolModel copyWith({
    String? id,
    String? toolName,
    String? company,
    String? imageUrl,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? description,
    double? price,
    String? distributorName,
  }) {
    return SurgicalToolModel(
      id: id ?? this.id,
      toolName: toolName ?? this.toolName,
      company: company ?? this.company,
      imageUrl: imageUrl ?? this.imageUrl,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      description: description ?? this.description,
      price: price ?? this.price,
      distributorName: distributorName ?? this.distributorName,
    );
  }
}
