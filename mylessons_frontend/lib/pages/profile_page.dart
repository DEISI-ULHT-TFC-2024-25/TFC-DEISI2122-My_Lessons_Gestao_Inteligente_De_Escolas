import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import '../../services/profile_service.dart';
import 'school_setup_page.dart';
import '../../main.dart'; // Ensure this imports your global routeObserver

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with RouteAware {
  final storage = const FlutterSecureStorage();
  bool isLoading = true;
  bool isEditing = false;

  // Controllers for profile fields.
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _birthdayController;

  // New variable to store the selected phone country code.
  String _phoneCountryCode = 'PT';

  // Extra fields for role/school switching.
  List<String> availableRoles = [];
  List<Map<String, dynamic>> availableSchools = [];
  String currentRole = "";
  String? currentSchoolId;
  String? currentSchoolName;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _birthdayController = TextEditingController();
    fetchProfileData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ModalRoute? route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _birthdayController.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    fetchProfileData();
  }

  Future<void> fetchProfileData() async {
    try {
      final profileData = await ProfileService.fetchProfileData();
      setState(() {
        _firstNameController.text = profileData.firstName;
        _lastNameController.text = profileData.lastName;
        _emailController.text = profileData.email;
        // Print the type of phone

        _phoneController.text = profileData.phone?.toString() ?? '';
        _birthdayController.text = profileData.birthday ?? '';
        availableRoles = profileData.availableRoles;
        currentRole = profileData.currentRole;
        availableSchools = profileData.availableSchools;
        currentSchoolId = profileData.currentSchoolId;
        currentSchoolName = profileData.currentSchoolName;
        if (profileData.countryCode != null &&
            profileData.countryCode.toString().isNotEmpty) {
          _phoneCountryCode = profileData.countryCode.toString();
        }
        isLoading = false;
      });
    } catch (e, stackTrace) {
      print("Error fetching profile data: $e");
      print("StackTrace: $stackTrace");
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> updateProfile() async {
    final payload = {
      'first_name': _firstNameController.text,
      'last_name': _lastNameController.text,
      'email': _emailController.text,
      'country_code': _phoneCountryCode,
      'phone': _phoneController.text,
      'birthday': _birthdayController.text,
    };

    try {
      final message = await ProfileService.updateProfileData(payload);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      setState(() {
        isEditing = false;
      });
      await fetchProfileData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error updating profile: $e")),
      );
    }
  }

  Future<void> changeRole(String newRole) async {
    try {
      final message = await ProfileService.changeRole(newRole);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      Navigator.pushNamedAndRemoveUntil(context, '/main', (route) => false);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> changeSchool(String schoolId) async {
    try {
      final message = await ProfileService.changeSchool(schoolId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      Navigator.pushNamedAndRemoveUntil(context, '/main', (route) => false);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> logout() async {
    await storage.delete(key: 'auth_token');
    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }

  Widget buildProfileInputField(
      String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        readOnly: !isEditing,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        ),
        style: const TextStyle(fontSize: 16),
      ),
    );
  }

  /// Uses IntlPhoneField to show phone and country.
  Widget buildIntlPhoneField() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: IntlPhoneField(
        initialCountryCode: _phoneCountryCode,
        initialValue: _phoneController.text,
        enabled: isEditing,
        decoration: InputDecoration(
          labelText: 'Phone Number',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        ),
        onCountryChanged: (country) {
          setState(() {
            _phoneCountryCode = country.code;
          });
        },
        onChanged: (phone) {
          setState(() {
            _phoneController.text = phone.number;
          });
        },
      ),
    );
  }

  Widget buildBirthdayField() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _birthdayController,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: "Birthday",
                border: OutlineInputBorder(),
                hintText: "Select a date",
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              ),
              style: const TextStyle(fontSize: 16),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: isEditing ? _showBirthdayPicker : null,
          ),
        ],
      ),
    );
  }

  Future<void> _showBirthdayPicker() async {
    DateTime initialDate = DateTime.now();
    try {
      if (_birthdayController.text.isNotEmpty) {
        initialDate = DateTime.parse(_birthdayController.text);
      }
    } catch (e) {
      // fallback to now
    }
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (pickedDate != null) {
      setState(() {
        _birthdayController.text = pickedDate.toIso8601String().split('T')[0];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Profile")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              color: Colors.orange,
              backgroundColor: Colors.white,
              onRefresh: fetchProfileData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Profile Info Card
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "Profile Info",
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold),
                                ),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      isEditing = !isEditing;
                                    });
                                  },
                                  child: Text(isEditing ? "Cancel" : "Edit"),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            buildProfileInputField(
                                "First Name", _firstNameController),
                            buildProfileInputField(
                                "Last Name", _lastNameController),
                            buildProfileInputField("Email", _emailController),
                            buildBirthdayField(),
                            // Use the updated IntlPhoneField widget.
                            buildIntlPhoneField(),
                            if (isEditing)
                              Padding(
                                padding: const EdgeInsets.only(top: 16.0),
                                child: ElevatedButton(
                                  onPressed: updateProfile,
                                  child: const Text("Save Profile"),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Role Switching Buttons.
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: availableRoles.map((role) {
                        return ElevatedButton(
                          onPressed: () => changeRole(role),
                          child: Text("Switch to $role"),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    // School Switching Buttons (only for Admin if more than one school).
                    if (currentRole == "Admin" &&
                        availableSchools.length > 1) ...[
                      Text(
                        "Current School: ${currentSchoolName ?? 'Not Set'}",
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: availableSchools
                            .where((school) =>
                                school['id'].toString() != currentSchoolId)
                            .map((school) => ElevatedButton(
                                  onPressed: () =>
                                      changeSchool(school['id'].toString()),
                                  child: Text("Switch to ${school['name']}"),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 20),
                    ],
                    // Manage School / Create School button (for Admin).
                    if (currentRole == "Admin")
                      ElevatedButton(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SchoolSetupPage(
                                isCreatingSchool: availableSchools.isEmpty,
                                fetchProfileData: fetchProfileData,
                              ),
                            ),
                          );
                        },
                        child: Text(availableSchools.isEmpty
                            ? "Create School"
                            : "Manage School"),
                      ),
                    const SizedBox(height: 20),
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
            ),
    );
  }
}
