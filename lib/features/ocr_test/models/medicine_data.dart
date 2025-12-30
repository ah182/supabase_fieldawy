class MedicineData {
  final String? name;
  final String? activeIngredient;
  final String? company;
  final String? packageSize;
  final String? rawResponse;

  MedicineData({
    this.name,
    this.activeIngredient,
    this.company,
    this.packageSize,
    this.rawResponse,
  });

  factory MedicineData.fromJson(Map<String, dynamic> json) {
    return MedicineData(
      name: json['name'] as String?,
      activeIngredient: json['active_ingredient'] as String?,
      company: json['company'] as String?,
      packageSize: json['package_size'] as String?,
      rawResponse: json.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'active_ingredient': activeIngredient,
      'company': company,
      'package_size': packageSize,
    };
  }
}
