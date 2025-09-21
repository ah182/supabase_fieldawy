// لم نعد بحاجة إلى cloud_firestore
// import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  // 1. تغيير uid إلى id ليتوافق مع Supabase
  final String id;
  final String? displayName;
  final String? email;
  final String? photoUrl; // تم تغيير photoURL إلى photoUrl (camelCase)
  final String role;
  final String accountStatus;
  final bool isProfileComplete;

  // 2. إضافة الحقول الجديدة لتكون متوافقة مع UserRepository
  final String? documentUrl;
  final String? whatsappNumber;
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
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
