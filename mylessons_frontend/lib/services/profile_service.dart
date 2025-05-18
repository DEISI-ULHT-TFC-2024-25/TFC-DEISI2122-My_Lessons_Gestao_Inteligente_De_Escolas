import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'api_service.dart';

class ProfileData {
  final String firstName;
  final String lastName;
  final String email;
  final String countryCode;
  final String phone;
  final String? birthday;
  final String? photo;
  final List<String> availableRoles;
  final String currentRole;
  final List<Map<String, dynamic>> availableSchools;
  final List<Map<String, dynamic>>? associatedStudents;
  final String? currentSchoolId;
  final String? currentSchoolName;

  ProfileData(
      {required this.firstName,
      required this.lastName,
      required this.email,
      required this.countryCode,
      required this.phone,
      required this.birthday,
      required this.photo,
      required this.availableRoles,
      required this.currentRole,
      required this.availableSchools,
      this.currentSchoolId,
      this.currentSchoolName,
      this.associatedStudents});

  factory ProfileData.fromJson(Map<String, dynamic> json) {
    return ProfileData(
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      countryCode: json['country_code']?.toString() ?? 'PT',
      phone: json['phone']?.toString() ?? '',
      birthday: json['birthday']?.toString(),
      photo: json['photo']?.toString(),
      availableRoles: (json['available_roles'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      currentRole: json['current_role']?.toString() ?? '',
      availableSchools: (json['available_schools'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [],
      associatedStudents: (json['associated_students'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [],
      currentSchoolId: json['current_school_id']?.toString(),
      currentSchoolName: json['current_school_name']?.toString() ?? '',
    );
  }
}

class ProfileService {
  static final _storage = const FlutterSecureStorage();

  static Future<Map<String, String>> getAuthHeaders() async {
    final token = await _storage.read(key: 'auth_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Token $token',
    };
  }

  // Fetch profile data including basic profile fields plus extra info
  /// for role/school switching.
  static Future<ProfileData> fetchProfileData() async {
    final headers = await getAuthHeaders();

    // Fetch available roles.
    final roleResponse = await http.get(
      Uri.parse('$baseUrl/api/users/available_roles/'),
      headers: headers,
    );
    List<String> availableRoles = [];
    if (roleResponse.statusCode == 200) {
      final data = json.decode(utf8.decode(roleResponse.bodyBytes));
      availableRoles = (data['available_roles'] as List<dynamic>)
          .map((e) => e.toString())
          .toList();
    } else {
      print("Failed to fetch roles: ${roleResponse.body}");
    }

    // Fetch current role.
    String currentRole = "";
    final currentRoleResponse = await http.get(
      Uri.parse('$baseUrl/api/users/current_role/'),
      headers: headers,
    );
    if (currentRoleResponse.statusCode == 200) {
      final data = json.decode(utf8.decode(currentRoleResponse.bodyBytes));
      currentRole = data['current_role'];
    } else {
      print("Failed to fetch current role: ${currentRoleResponse.body}");
    }

    List<Map<String, dynamic>> availableSchools = [];
    List<Map<String, dynamic>> associatedStudents = [];

    String? currentSchoolId;
    String? currentSchoolName;
    if (currentRole == "Admin") {
      // Fetch available schools.
      final schoolsResponse = await http.get(
        Uri.parse('$baseUrl/api/users/available_schools/'),
        headers: headers,
      );
      if (schoolsResponse.statusCode == 200) {
        final data = json.decode(utf8.decode(schoolsResponse.bodyBytes));
        availableSchools =
            List<Map<String, dynamic>>.from(data['available_schools']);
      } else {
        print("Failed to fetch schools: ${schoolsResponse.body}");
      }

      // Fetch current school.
      final currentSchoolResponse = await http.get(
        Uri.parse('$baseUrl/api/users/current_school_id/'),
        headers: headers,
      );
      if (currentSchoolResponse.statusCode == 200) {
        final data = json.decode(utf8.decode(currentSchoolResponse.bodyBytes));
        currentSchoolId = data['current_school_id'];
        currentSchoolName = data['current_school_name'];
      } else {
        print("Failed to fetch current school: ${currentSchoolResponse.body}");
      }
    } else if (currentRole == "Parent") {
      final studentsResponse = await http.get(
        Uri.parse('$baseUrl/api/users/students/'),
        headers: headers,
      );
      if (studentsResponse.statusCode == 200) {
        final data = json.decode(utf8.decode(studentsResponse.bodyBytes));
        associatedStudents =
            List<Map<String, dynamic>>.from(data['associated_students']);
      } else {
        print("Failed to fetch students: ${studentsResponse.body}");
      }
    }

    final profileResponse = await http.get(
      Uri.parse('$baseUrl/api/users/profile_data/'),
      headers: headers,
    );
    Map<String, dynamic> profileJson = {};
    if (profileResponse.statusCode == 200) {
      profileJson = json.decode(utf8.decode(profileResponse.bodyBytes));
    } else {
      print("Failed to fetch basic profile info: ${profileResponse.body}");
    }
    // Merge additional info
    final mergedJson = {
      ...profileJson,
      'available_roles': availableRoles,
      'current_role': currentRole,
      'available_schools': availableSchools,
      'current_school_id': currentSchoolId,
      'current_school_name': currentSchoolName,
      'associated_students': associatedStudents,
    };
    return ProfileData.fromJson(mergedJson);
  }

  /// Update profile data (first name, last name, email, country code, phone, birthday, photo).
  static Future<String> updateProfileData(Map<String, dynamic> data) async {
    final headers = await getAuthHeaders();
    final url = Uri.parse('$baseUrl/api/users/profile_data/');
    final response =
        await http.put(url, headers: headers, body: jsonEncode(data));
    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
      return jsonResponse['message'] ?? 'Profile updated successfully';
    } else {
      final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
      throw Exception(jsonResponse['error'] ?? 'Failed to update profile');
    }
  }

  /// Change the user's role.
  static Future<String> changeRole(String newRole) async {
    final headers = await getAuthHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/users/change_role/'),
      headers: headers,
      body: jsonEncode({"new_role": newRole}),
    );
    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      return data['message'];
    } else {
      final data = json.decode(utf8.decode(response.bodyBytes));
      throw Exception(data['error']);
    }
  }

  /// Change the current school.
  static Future<String> changeSchool(String schoolId) async {
    final headers = await getAuthHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/users/change_school_id/'),
      headers: headers,
      body: jsonEncode({"new_school_id": schoolId}),
    );
    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      return data['message'];
    } else {
      final data = json.decode(utf8.decode(response.bodyBytes));
      throw Exception(data['error']);
    }
  }
}
