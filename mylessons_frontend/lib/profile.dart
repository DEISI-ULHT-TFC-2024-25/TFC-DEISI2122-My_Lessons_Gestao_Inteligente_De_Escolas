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
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchAvailableRoles();
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

  Future<void> fetchAvailableRoles() async {
    try {
      final headers = await getAuthHeaders();
      final response = await http.get(
        Uri.parse('http://127.0.0.1:8000/api/users/available_roles/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          availableRoles =
              List<String>.from(data['available_roles']);
          isLoading = false;
        });
      } else {
        print("Failed to fetch roles: ${response.body}");
      }
    } catch (e) {
      print("Error fetching available roles: $e");
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

  Future<void> logout() async {
    await storage.delete(key: 'auth_token');
    Navigator.pushNamedAndRemoveUntil(
        context, '/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Profile")),
      // No bottomNavigationBar here.
      body: Center(
        child: isLoading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  for (String role in availableRoles)
                    ElevatedButton(
                      onPressed: () => changeRole(role),
                      child: Text("Switch to $role"),
                    ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: logout,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red),
                    child: const Text("Logout",
                        style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
      ),
    );
  }
}
