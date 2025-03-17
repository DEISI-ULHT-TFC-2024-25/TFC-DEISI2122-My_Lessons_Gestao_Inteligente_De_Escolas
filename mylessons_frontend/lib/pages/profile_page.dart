import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

  // For country picker, we keep a selected Country.
  late Country _selectedCountry = Country(
    countryCode: 'PT',
    phoneCode: '351',
    e164Sc: 0,
    geographic: true,
    level: 1,
    name: 'Portugal',
    displayName: 'Portugal',
    displayNameNoCountryCode: 'Portugal',
    e164Key: '351-PT-0',
    example: '912345678',
  );

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
    // Set a default country.
    _selectedCountry = Country(
      countryCode: 'PT',
      phoneCode: '351',
      e164Sc: 0,
      geographic: true,
      level: 1,
      name: 'Portugal',
      displayName: 'Portugal',
      displayNameNoCountryCode: 'Portugal',
      e164Key: '351-PT-0',
      example: '912345678',
    );
    fetchProfileData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to route changes.
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

  // This method is called when the current route has been popped back to.
  @override
  void didPopNext() {
    // Refresh profile data when coming back to ProfilePage.
    fetchProfileData();
  }

  Future<void> fetchProfileData() async {
    try {
      final profileData = await ProfileService.fetchProfileData();
      setState(() {
        _firstNameController.text = profileData.firstName;
        _lastNameController.text = profileData.lastName;
        _emailController.text = profileData.email;
        _phoneController.text = profileData.phone;
        _birthdayController.text = profileData.birthday ?? '';
        availableRoles = profileData.availableRoles;
        currentRole = profileData.currentRole;
        availableSchools = profileData.availableSchools;
        currentSchoolId = profileData.currentSchoolId;
        currentSchoolName = profileData.currentSchoolName;
        // Update _selectedCountry if countryCode exists.
        if (profileData.countryCode.isNotEmpty) {
          _selectedCountry = Country(
            countryCode: profileData.countryCode,
            phoneCode: "", // update accordingly if needed
            e164Sc: 0,
            geographic: true,
            level: 1,
            name: 'Portugal',
            displayName: 'Portugal',
            displayNameNoCountryCode: 'Portugal',
            e164Key: '351-PT-0',
            example: '912345678',
          );
        }
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching profile data: $e");
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
      'country_code': _selectedCountry.countryCode,
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

  /// Builds a uniform input field using TextFormField.
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

  /// Builds a row for the country code and phone input.
  Widget buildCountryAndPhoneField() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (isEditing) {
                showCountryPicker(
                  context: context,
                  onSelect: (Country country) {
                    setState(() {
                      _selectedCountry = country;
                    });
                  },
                  countryListTheme: CountryListThemeData(
                    flagSize: 25,
                    backgroundColor: Colors.white,
                    textStyle:
                        const TextStyle(fontSize: 16, color: Colors.black),
                    bottomSheetHeight: 500,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20.0),
                      topRight: Radius.circular(20.0),
                    ),
                  ),
                );
              }
            },
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
                color: isEditing ? Colors.white : Colors.grey.shade200,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "${_selectedCountry.flagEmoji} +${_selectedCountry.phoneCode}",
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down, color: Colors.grey),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: _phoneController,
              readOnly: !isEditing,
              decoration: const InputDecoration(
                labelText: "Number",
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              ),
              keyboardType: TextInputType.phone,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a row for the birthday field with a calendar icon.
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
                            // Optionally, you can show the profile photo here.
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
                            buildCountryAndPhoneField(),
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
                          final result = await Navigator.push(
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
