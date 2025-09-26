import 'package:hive/hive.dart';

part 'user_model.g.dart';

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

  UserModel({
    required this.id,
    this.displayName,
    this.email,
    this.photoUrl,
    required this.role,
    required this.accountStatus,
    required this.isProfileComplete,
    // إضافة الحقول الجديدة للـ constructor
    this.documentUrl,
    this.whatsappNumber,
    this.governorates,
    this.centers,
    required this.createdAt,
  });

  // 3. استبدال fromFirestore بـ fromMap للتعامل مع بيانات Supabase
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'],
      displayName: map['display_name'], // 4. مطابقة أسماء الأعمدة (snake_case)
      email: map['email'],
      photoUrl: map['photo_url'],
      role: map['role'] ?? 'viewer', // قيم افتراضية للحماية
      accountStatus: map['account_status'] ?? 'pending_review',
      isProfileComplete: map['is_profile_complete'] ?? false,
      documentUrl: map['document_url'],
      whatsappNumber: map['whatsapp_number'],
      governorates: List<String>.from(map['governorates'] ?? []),
      centers: List<String>.from(map['centers'] ?? []),
      // 5. تحويل التاريخ من نص إلى كائن DateTime
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  // 6. (نصيحة إضافية) دالة لتحويل الكائن إلى Map لإرساله إلى Supabase
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
    );
  }
}
