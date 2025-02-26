import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final storage = const FlutterSecureStorage();
  List<String> availableRoles = [];
  List<Map<String, dynamic>> availableSchools = [];
  String currentRole = "";
  String? currentSchoolId;
  String? currentSchoolName;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchProfileData();
  }

  Future<Map<String, String>> getAuthHeaders() async {
    String? token = await storage.read(key: 'auth_token');
    if (token == null) {
      throw Exception("No auth token found");
    }
    return {
      'Authorization': 'Token $token',
      'Content-Type': 'application/json',
    };
  }

  Future<void> fetchProfileData() async {
    try {
      final headers = await getAuthHeaders();

      // Fetch Available Roles
      final roleResponse = await http.get(
        Uri.parse('http://127.0.0.1:8000/api/users/available_roles/'),
        headers: headers,
      );

      if (roleResponse.statusCode == 200) {
        final data = json.decode(utf8.decode(roleResponse.bodyBytes));
        setState(() {
          availableRoles = List<String>.from(data['available_roles']);
        });
      } else {
        print("Failed to fetch roles: ${roleResponse.body}");
      }

      // Fetch Current Role
      final currentRoleResponse = await http.get(
        Uri.parse('http://127.0.0.1:8000/api/users/current_role/'),
        headers: headers,
      );

      if (currentRoleResponse.statusCode == 200) {
        final data = json.decode(utf8.decode(currentRoleResponse.bodyBytes));
        setState(() {
          currentRole = data['current_role'];
        });
      } else {
        print("Failed to fetch current role: ${currentRoleResponse.body}");
      }

      // Fetch Available Schools if the user is an Admin
      if (currentRole == "Admin") {
        await fetchAvailableSchools();
        await fetchCurrentSchool();
      }

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching profile data: $e");
    }
  }

  Future<void> fetchAvailableSchools() async {
    try {
      final headers = await getAuthHeaders();
      final response = await http.get(
        Uri.parse('http://127.0.0.1:8000/api/users/available_schools/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          availableSchools = List<Map<String, dynamic>>.from(data['available_schools']);
        });
      } else {
        print("Failed to fetch schools: ${response.body}");
      }
    } catch (e) {
      print("Error fetching available schools: $e");
    }
  }

  Future<void> fetchCurrentSchool() async {
    try {
      final headers = await getAuthHeaders();
      final response = await http.get(
        Uri.parse('http://127.0.0.1:8000/api/users/current_school_id/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          currentSchoolId = data['current_school_id'];
          currentSchoolName = data['current_school_name'];
        });
      } else {
        print("Failed to fetch current school: ${response.body}");
      }
    } catch (e) {
      print("Error fetching current school: $e");
    }
  }

  Future<void> changeRole(String newRole) async {
    try {
      final headers = await getAuthHeaders();
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/api/users/change_role/'),
        headers: headers,
        body: jsonEncode({"new_role": newRole}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'])),
        );

        // Refresh the home page with the new role
        Navigator.pushNamedAndRemoveUntil(context, '/main', (route) => false);
      } else {
        final data = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'])),
        );
      }
    } catch (e) {
      print("Error changing role: $e");
    }
  }

  Future<void> changeSchool(String schoolId) async {
    try {
      final headers = await getAuthHeaders();
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/api/users/change_school_id/'),
        headers: headers,
        body: jsonEncode({"new_school_id": schoolId}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'])),
        );

        // Refresh the home page with the new role
        Navigator.pushNamedAndRemoveUntil(context, '/main', (route) => false);
      } else {
        final data = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'])),
        );
      }
    } catch (e) {
      print("Error changing school: $e");
    }
  }

  Future<void> logout() async {
    await storage.delete(key: 'auth_token');
    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Profile")),
      body: Center(
        child: isLoading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Role Switching Buttons
                  for (String role in availableRoles)
                    ElevatedButton(
                      onPressed: () => changeRole(role),
                      child: Text("Switch to $role"),
                    ),
                  const SizedBox(height: 20),

                  // School Switching Buttons (Only for Admins)
                  if (currentRole == "Admin" && availableSchools.isNotEmpty) ...[
                    Text("Current School: ${currentSchoolName ?? 'Not Set'}",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    for (var school in availableSchools)
                      ElevatedButton(
                        onPressed: () => changeSchool(school['id'].toString()),
                        child: Text("Switch to ${school['name']}"),
                      ),
                    const SizedBox(height: 20),
                  ],

                  // Logout Button
                  ElevatedButton(
                    onPressed: logout,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text("Logout", style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
      ),
    );
  }
}
