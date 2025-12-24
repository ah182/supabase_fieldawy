import 'package:equatable/equatable.dart';

// The original model for the 'clinics' table
class ClinicModel extends Equatable {
  final String id;
  final String userId;
  final String clinicName;
  final double latitude;
  final double longitude;
  final String? address;
  final String? phoneNumber;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ClinicModel({
    required this.id,
    required this.userId,
    required this.clinicName,
    required this.latitude,
    required this.longitude,
    this.address,
    this.phoneNumber,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ClinicModel.fromMap(Map<String, dynamic> map) {
    return ClinicModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      clinicName: map['clinic_name'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      address: map['address'] as String?,
      phoneNumber: map['phone_number'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  @override
  List<Object?> get props => [id, userId, clinicName, latitude, longitude, address, phoneNumber, createdAt, updatedAt];
}

// New model for the 'clinics_with_doctor_info' view
class ClinicWithDoctorInfo extends Equatable {
  final String clinicId;
  final String clinicName;
  final double latitude;
  final double longitude;
  final String? address;
  final String? clinicPhoneNumber;
  final String? clinicCode; // جديد
  final DateTime createdAt;
  final DateTime updatedAt;
  final String userId;
  final String doctorName;
  final String? doctorWhatsappNumber;
  final String? doctorPhotoUrl;

  const ClinicWithDoctorInfo({
    required this.clinicId,
    required this.clinicName,
    required this.latitude,
    required this.longitude,
    this.address,
    this.clinicPhoneNumber,
    this.clinicCode,
    required this.createdAt,
    required this.updatedAt,
    required this.userId,
    required this.doctorName,
    this.doctorWhatsappNumber,
    this.doctorPhotoUrl,
  });

  factory ClinicWithDoctorInfo.fromMap(Map<String, dynamic> map) {
    return ClinicWithDoctorInfo(
      clinicId: map['clinic_id'] as String,
      clinicName: map['clinic_name'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      address: map['address'] as String?,
      clinicPhoneNumber: map['clinic_phone_number'] as String?,
      clinicCode: map['clinic_code'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      userId: map['user_id'] as String,
      doctorName: map['doctor_name'] as String,
      doctorWhatsappNumber: map['doctor_whatsapp_number'] as String?,
      doctorPhotoUrl: map['doctor_photo_url'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        clinicId, clinicName, latitude, longitude, address, clinicPhoneNumber,
        clinicCode, createdAt, updatedAt, userId, doctorName, doctorWhatsappNumber, doctorPhotoUrl,
      ];
}