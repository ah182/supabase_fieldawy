
import 'package:easy_localization/easy_localization.dart';

class DistributorModel {
  final String id;
  final String displayName;
  final String? photoURL;
  final String? email;
  final String? companyName;
  final String? distributorType;
  final int productCount;
  final bool isVerified;
  final DateTime? joinDate;
  final String? whatsappNumber;
  final List<String>? governorates;
  final List<String>? centers;
  final int subscribersCount;
  final String? distributionMethod;

  DistributorModel({
    required this.id,
    required this.displayName,
    this.photoURL,
    this.email,
    this.companyName,
    this.distributorType,
    this.productCount = 0,
    this.isVerified = false,
    this.joinDate,
    this.whatsappNumber,
    this.governorates,
    this.centers,
    this.subscribersCount = 0,
    this.distributionMethod,
  });

  factory DistributorModel.fromMap(Map<String, dynamic> data) {
    return DistributorModel(
      id: data['id'].toString(),
      displayName: data['display_name'] ?? data['displayName'] ?? 'unknownDistributor'.tr(),
      photoURL: data['photo_url'] ?? data['photoURL'],
      email: data['email'],
      companyName: data['company_name'] ?? data['companyName'],
      distributorType: data['distributor_type'] ?? data['distributorType'] ?? 'individual',
      productCount: data['productCount'] ?? 0,
      isVerified: data['is_verified'] ?? data['isVerified'] ?? false,
      joinDate: data['join_date'] != null
          ? DateTime.tryParse(data['join_date'])
          : data['joinDate'] != null
              ? DateTime.tryParse(data['joinDate'])
              : data['created_at'] != null
                  ? DateTime.tryParse(data['created_at'])
                  : null,
      whatsappNumber: data['whatsapp_number'] ?? data['whatsappNumber'],
      governorates: data['governorates'] != null 
          ? List<String>.from(data['governorates']) 
          : null,
      centers: data['centers'] != null 
          ? List<String>.from(data['centers']) 
          : null,
      subscribersCount: data['subscribers_count'] ?? 0,
      distributionMethod: data['distribution_method'] ?? data['distributionMethod'],
    );
  }
}
