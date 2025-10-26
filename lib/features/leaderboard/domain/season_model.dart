class LeaderboardSeason {
  final int id;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;

  LeaderboardSeason({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.isActive,
  });

  factory LeaderboardSeason.fromMap(Map<String, dynamic> map) {
    return LeaderboardSeason(
      id: map['id'],
      startDate: DateTime.parse(map['start_date']),
      endDate: DateTime.parse(map['end_date']),
      isActive: map['is_active'],
    );
  }
}
