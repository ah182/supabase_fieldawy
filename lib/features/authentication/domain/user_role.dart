enum UserRole { doctor, company, distributor, viewer }

extension UserRoleExtension on UserRole {
  String get asString {
    switch (this) {
      case UserRole.doctor:
        return 'doctor';
      case UserRole.company:
        return 'company';
      case UserRole.distributor:
        return 'distributor';
      case UserRole.viewer:
        return 'viewer';
    }
  }
}

class UserRoleHelper {
  static UserRole fromString(String role) {
    switch (role) {
      case 'doctor':
        return UserRole.doctor;
      case 'company':
        return UserRole.company;
      case 'distributor':
        return UserRole.distributor;
      case 'viewer':
        return UserRole.viewer;
      default:
        return UserRole.viewer;
    }
  }
}
