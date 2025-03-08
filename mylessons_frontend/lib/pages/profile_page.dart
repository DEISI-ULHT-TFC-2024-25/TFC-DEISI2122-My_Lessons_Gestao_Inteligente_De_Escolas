import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../services/profile_service.dart';
import 'school_setup_page.dart';

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
    fetchProfileData().then((_) {
      setState(() {
        isLoading = false;
      });
    });
  }

  Future<void> fetchProfileData() async {
    try {
      final profileData = await ProfileService.fetchProfileData();
      setState(() {
        availableRoles = profileData.availableRoles;
        currentRole = profileData.currentRole;
        availableSchools = profileData.availableSchools;
        currentSchoolId = profileData.currentSchoolId;
        currentSchoolName = profileData.currentSchoolName;
      });
    } catch (e) {
      print("Error fetching profile data: $e");
    }
  }

  Future<void> changeRole(String newRole) async {
    try {
      final message = await ProfileService.changeRole(newRole);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      // Refresh the home page with the new role.
      Navigator.pushNamedAndRemoveUntil(context, '/main', (route) => false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> changeSchool(String schoolId) async {
    try {
      final message = await ProfileService.changeSchool(schoolId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      // Refresh the home page with the new school.
      Navigator.pushNamedAndRemoveUntil(context, '/main', (route) => false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
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
                  // Role Switching Buttons.
                  for (String role in availableRoles)
                    ElevatedButton(
                      onPressed: () => changeRole(role),
                      child: Text("Switch to $role"),
                    ),
                  const SizedBox(height: 20),

                  // School Switching Buttons (only for Admin).
                  if (currentRole == "Admin" &&
                      availableSchools.isNotEmpty) ...[
                    Text(
                      "Current School: ${currentSchoolName ?? 'Not Set'}",
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    for (var school in availableSchools)
                      ElevatedButton(
                        onPressed: () => changeSchool(school['id'].toString()),
                        child: Text("Switch to ${school['name']}"),
                      ),
                    const SizedBox(height: 20),
                  ],
                  if (currentRole == "Admin")
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const SchoolSetupPage()),
                        );
                      },
                      child: const Text("Manage School"),
                    ),
                  // Logout Button.
                  ElevatedButton(
                    onPressed: logout,
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text("Logout",
                        style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
      ),
    );
  }
}
