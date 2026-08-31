class CurrentUser {
  static String? firstName;
  static String? lastName;
  static String? email;
  static String? adminLevel; // 'owner' o 'staff'
  static int? accountId;

  static String get fullName {
    if (firstName == null && lastName == null) return 'Admin';
    return '${firstName ?? ''} ${lastName ?? ''}'.trim();
  }

  static bool get isOwner => adminLevel == 'owner';
  static bool get isStaff => adminLevel == 'staff';

  static void clear() {
    firstName = null;
    lastName = null;
    email = null;
    adminLevel = null;
    accountId = null;
  }
}