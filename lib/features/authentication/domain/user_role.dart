enum UserRole { doctor, company, distributor }

extension UserRoleExtension on UserRole {
  String get asString {
    switch (this) {
      case UserRole.doctor:
        return 'doctor';
      case UserRole.company:
        return 'company';
      case UserRole.distributor:
        return 'distributor';
    }
  }
}
