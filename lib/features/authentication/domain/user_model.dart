import 'package:hive/hive.dart';

part 'user_model.g.dart';

// IMPORTANT: After modifying this file, run the following command:
// flutter pub run build_runner build --delete-conflicting-outputs

@HiveType(typeId: 3)
class UserModel {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String? displayName;

  @HiveField(2)
  final String? email;

  @HiveField(3)
  final String? photoUrl;

  @HiveField(4)
  final String role;

  @HiveField(5)
  final String accountStatus;

  @HiveField(6)
  final bool isProfileComplete;

  @HiveField(7)
  final String? documentUrl;

  @HiveField(8)
  final String? whatsappNumber;

  @HiveField(9)
  final List<String>? governorates;

  @HiveField(10)
  final List<String>? centers;

  @HiveField(11)
  final DateTime createdAt;

  @HiveField(12)
  final double? lastLatitude;

  @HiveField(13)
  final double? lastLongitude;

  @HiveField(14)
  final DateTime? lastLocationUpdate;

  @HiveField(15)
  final String? referralCode;

  @HiveField(16)
  final int? points;

  @HiveField(17)
  final int? rank;

  @HiveField(18)
  final String? distributionMethod;

  @HiveField(19)
  final int? subscribersCount;

  UserModel({
    required this.id,
    this.displayName,
    this.email,
    this.photoUrl,
    required this.role,
    required this.accountStatus,
    required this.isProfileComplete,
    this.documentUrl,
    this.whatsappNumber,
    this.governorates,
    this.centers,
    required this.createdAt,
    this.lastLatitude,
    this.lastLongitude,
    this.lastLocationUpdate,
    this.referralCode,
    this.points,
    this.rank,
    this.distributionMethod,
    this.subscribersCount,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'],
      displayName: map['display_name'],
      email: map['email'],
      photoUrl: map['photo_url'],
      role: map['role'] ?? 'viewer',
      accountStatus: map['account_status'] ?? 'pending_review',
      isProfileComplete: map['is_profile_complete'] ?? false,
      documentUrl: map['document_url'],
      whatsappNumber: map['whatsapp_number'],
      governorates: List<String>.from(map['governorates'] ?? []),
      centers: List<String>.from(map['centers'] ?? []),
      createdAt: DateTime.parse(map['created_at']),
      lastLatitude: map['last_latitude'] != null ? (map['last_latitude'] as num).toDouble() : null,
      lastLongitude: map['last_longitude'] != null ? (map['last_longitude'] as num).toDouble() : null,
      lastLocationUpdate: map['last_location_update'] != null 
          ? DateTime.parse(map['last_location_update']) 
          : null,
      referralCode: map['referral_code'],
      points: map['points'] ?? 0,
      rank: map['rank'],
      distributionMethod: map['distribution_method'],
      subscribersCount: map['subscribers_count'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'display_name': displayName,
      'email': email,
      'photo_url': photoUrl,
      'role': role,
      'account_status': accountStatus,
      'is_profile_complete': isProfileComplete,
      'document_url': documentUrl,
      'whatsapp_number': whatsappNumber,
      'governorates': governorates,
      'centers': centers,
      'created_at': createdAt.toIso8601String(),
      'last_latitude': lastLatitude,
      'last_longitude': lastLongitude,
      'last_location_update': lastLocationUpdate?.toIso8601String(),
      'referral_code': referralCode,
      'points': points ?? 0,
      'rank': rank,
      'distribution_method': distributionMethod,
      'subscribers_count': subscribersCount ?? 0,
    };
  }

  UserModel copyWith({
    String? id,
    String? displayName,
    String? email,
    String? photoUrl,
    String? role,
    String? accountStatus,
    bool? isProfileComplete,
    String? documentUrl,
    String? whatsappNumber,
    List<String>? governorates,
    List<String>? centers,
    DateTime? createdAt,
    double? lastLatitude,
    double? lastLongitude,
    DateTime? lastLocationUpdate,
    String? referralCode,
    int? points,
    int? rank,
    String? distributionMethod,
    int? subscribersCount,
  }) {
    return UserModel(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      accountStatus: accountStatus ?? this.accountStatus,
      isProfileComplete: isProfileComplete ?? this.isProfileComplete,
      documentUrl: documentUrl ?? this.documentUrl,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      governorates: governorates ?? this.governorates,
      centers: centers ?? this.centers,
      createdAt: createdAt ?? this.createdAt,
      lastLatitude: lastLatitude ?? this.lastLatitude,
      lastLongitude: lastLongitude ?? this.lastLongitude,
      lastLocationUpdate: lastLocationUpdate ?? this.lastLocationUpdate,
      referralCode: referralCode ?? this.referralCode,
      points: points ?? this.points,
      rank: rank ?? this.rank,
      distributionMethod: distributionMethod ?? this.distributionMethod,
      subscribersCount: subscribersCount ?? this.subscribersCount,
    );
  }
}
