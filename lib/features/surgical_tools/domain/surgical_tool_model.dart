class SurgicalTool {
  final String id;
  final String toolName;
  final String? company;
  final String? imageUrl;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  SurgicalTool({
    required this.id,
    required this.toolName,
    this.company,
    this.imageUrl,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SurgicalTool.fromJson(Map<String, dynamic> json) {
    return SurgicalTool(
      id: json['id'].toString(),
      toolName: json['tool_name'] as String,
      company: json['company'] as String?,
      imageUrl: json['image_url'] as String?,
      createdBy: json['created_by']?.toString(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tool_name': toolName,
      'company': company,
      'image_url': imageUrl,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class DistributorSurgicalTool {
  final String id;
  final String distributorId;
  final String distributorName;
  final String surgicalToolId;
  final String description;
  final double price;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined data from surgical_tools table
  final String? toolName;
  final String? company;
  final String? imageUrl;

  DistributorSurgicalTool({
    required this.id,
    required this.distributorId,
    required this.distributorName,
    required this.surgicalToolId,
    required this.description,
    required this.price,
    required this.createdAt,
    required this.updatedAt,
    this.toolName,
    this.company,
    this.imageUrl,
  });

  factory DistributorSurgicalTool.fromJson(Map<String, dynamic> json) {
    return DistributorSurgicalTool(
      id: json['id'].toString(),
      distributorId: json['distributor_id'].toString(),
      distributorName: json['distributor_name'] as String,
      surgicalToolId: json['surgical_tool_id'].toString(),
      description: json['description'] as String,
      price: (json['price'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      toolName: json['tool_name'] as String?,
      company: json['company'] as String?,
      imageUrl: json['image_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'distributor_id': distributorId,
      'distributor_name': distributorName,
      'surgical_tool_id': surgicalToolId,
      'description': description,
      'price': price,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (toolName != null) 'tool_name': toolName,
      if (company != null) 'company': company,
      if (imageUrl != null) 'image_url': imageUrl,
    };
  }
}
