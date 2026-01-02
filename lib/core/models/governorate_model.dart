class GovernorateModel {
  final int id;
  final String name;
  final List<String> centers;

  GovernorateModel({
    required this.id,
    required this.name,
    required this.centers,
  });

  factory GovernorateModel.fromJson(Map<String, dynamic> json) {
    return GovernorateModel(
      id: json['id'],
      name: json['governorate'],
      centers: List<String>.from(json['centers']),
    );
  }
}
