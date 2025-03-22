class ProfileData {
  final String id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String countryCode; // This corresponds to backend's country_code.
  final String phone;
  final String? birthday;
  final String? photo;
  final List<String> availableRoles;
  final String currentRole;
  final List<Map<String, dynamic>> availableSchools;
  final String? currentSchoolId;
  final String? currentSchoolName;

  ProfileData({
    required this.id,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.countryCode,
    required this.phone,
    this.birthday,
    this.photo,
    required this.availableRoles,
    required this.currentRole,
    required this.availableSchools,
    this.currentSchoolId,
    this.currentSchoolName,
  });

  factory ProfileData.fromJson(Map<String, dynamic> json) {
    return ProfileData(
      id: json['id'].toString(),
      username: json['username'],
      email: json['email'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      countryCode: json['country_code'] ?? '',
      phone: json['phone']?.toString() ?? '',
      birthday: json['birthday'],
      photo: json['photo'],
      availableRoles: List<String>.from(json['available_roles'] ?? []),
      currentRole: json['current_role'] ?? '',
      availableSchools: List<Map<String, dynamic>>.from(json['available_schools'] ?? []),
      currentSchoolId: json['current_school_id']?.toString(),
      currentSchoolName: json['current_school_name'],
    );
  }
}
