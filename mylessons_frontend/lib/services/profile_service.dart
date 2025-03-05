import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

const String _baseUrl = 'http://127.0.0.1:8000';

class ProfileData {
  final List<String> availableRoles;
  final String currentRole;
  final List<Map<String, dynamic>> availableSchools;
  final String? currentSchoolId;
  final String? currentSchoolName;

  ProfileData({
    required this.availableRoles,
    required this.currentRole,
    required this.availableSchools,
    this.currentSchoolId,
    this.currentSchoolName,
  });
}

class ProfileService {
  static final _storage = const FlutterSecureStorage();

  static Future<Map<String, String>> getAuthHeaders() async {
    String? token = await _storage.read(key: 'auth_token');
    if (token == null) {
      throw Exception("No auth token found");
    }
    return {
      'Authorization': 'Token $token',
      'Content-Type': 'application/json',
    };
  }

  /// Fetch profile data including available roles, current role,
  /// available schools (if Admin), and current school info.
  static Future<ProfileData> fetchProfileData() async {
    final headers = await getAuthHeaders();

    // Fetch available roles.
    final roleResponse = await http.get(
      Uri.parse('$_baseUrl/api/users/available_roles/'),
      headers: headers,
    );
    List<String> availableRoles = [];
    if (roleResponse.statusCode == 200) {
      final data = json.decode(utf8.decode(roleResponse.bodyBytes));
      availableRoles = List<String>.from(data['available_roles']);
    } else {
      print("Failed to fetch roles: ${roleResponse.body}");
    }

    // Fetch current role.
    String currentRole = "";
    final currentRoleResponse = await http.get(
      Uri.parse('$_baseUrl/api/users/current_role/'),
      headers: headers,
    );
    if (currentRoleResponse.statusCode == 200) {
      final data = json.decode(utf8.decode(currentRoleResponse.bodyBytes));
      currentRole = data['current_role'];
    } else {
      print("Failed to fetch current role: ${currentRoleResponse.body}");
    }

    List<Map<String, dynamic>> availableSchools = [];
    String? currentSchoolId;
    String? currentSchoolName;
    if (currentRole == "Admin") {
      // Fetch available schools.
      final schoolsResponse = await http.get(
        Uri.parse('$_baseUrl/api/users/available_schools/'),
        headers: headers,
      );
      if (schoolsResponse.statusCode == 200) {
        final data = json.decode(utf8.decode(schoolsResponse.bodyBytes));
        availableSchools = List<Map<String, dynamic>>.from(data['available_schools']);
      } else {
        print("Failed to fetch schools: ${schoolsResponse.body}");
      }

      // Fetch current school.
      final currentSchoolResponse = await http.get(
        Uri.parse('$_baseUrl/api/users/current_school_id/'),
        headers: headers,
      );
      if (currentSchoolResponse.statusCode == 200) {
        final data = json.decode(currentSchoolResponse.body);
        currentSchoolId = data['current_school_id'];
        currentSchoolName = data['current_school_name'];
      } else {
        print("Failed to fetch current school: ${currentSchoolResponse.body}");
      }
    }

    return ProfileData(
      availableRoles: availableRoles,
      currentRole: currentRole,
      availableSchools: availableSchools,
      currentSchoolId: currentSchoolId,
      currentSchoolName: currentSchoolName,
    );
  }

  /// Change the user's role.
  static Future<String> changeRole(String newRole) async {
    final headers = await getAuthHeaders();
    final response = await http.post(
      Uri.parse('$_baseUrl/api/users/change_role/'),
      headers: headers,
      body: jsonEncode({"new_role": newRole}),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['message'];
    } else {
      final data = json.decode(response.body);
      throw Exception(data['error']);
    }
  }

  /// Change the current school.
  static Future<String> changeSchool(String schoolId) async {
    final headers = await getAuthHeaders();
    final response = await http.post(
      Uri.parse('$_baseUrl/api/users/change_school_id/'),
      headers: headers,
      body: jsonEncode({"new_school_id": schoolId}),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['message'];
    } else {
      final data = json.decode(response.body);
      throw Exception(data['error']);
    }
  }
}
