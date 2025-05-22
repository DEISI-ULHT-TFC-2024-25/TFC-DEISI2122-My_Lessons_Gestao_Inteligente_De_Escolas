import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:mylessons_frontend/pages/student_page.dart';
import 'package:provider/provider.dart';
import '../../services/profile_service.dart';
import '../providers/home_page_provider.dart';
import '../widgets/connect_calendar_button_widget.dart';
import 'manage_school.dart';
import '../../main.dart'; // routeObserver

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with RouteAware {
  final storage = const FlutterSecureStorage();
  bool isLoading = true;
  bool isEditingProfile = false;

  // Profile controllers
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late TextEditingController _birthdayController;
  String _phoneCountryCode = 'PT';
  late TextEditingController _phoneController;
  
  late bool hasCalendarToken = false;

  // Roles & Schools
  List<String> availableRoles = [];
  String currentRole = '';
  List<Map<String, dynamic>> availableSchools = [];
  String? currentSchoolId;
  String? currentSchoolName;

  // Associated students
  List<Map<String, dynamic>> associatedStudents = [];

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
    setState(() => isLoading = true);
    try {
      final profileData = await ProfileService.fetchProfileData();
      setState(() {
        _firstNameController.text = profileData.firstName;
        _lastNameController.text = profileData.lastName;
        _emailController.text = profileData.email;
        _birthdayController.text = profileData.birthday ?? '';
        _phoneController.text = profileData.phone ?? '';
        _phoneCountryCode = profileData.countryCode ?? 'PT';
        availableRoles = profileData.availableRoles;
        currentRole = profileData.currentRole;
        availableSchools = profileData.availableSchools;
        currentSchoolId = profileData.currentSchoolId;
        currentSchoolName = profileData.currentSchoolName;
        associatedStudents = profileData.associatedStudents ?? [];
        hasCalendarToken = profileData.hasCalendarToken ?? false;
      });
    } catch (e) {
      print('Error fetching profile: $e');
    } finally {
      setState(() => isLoading = false);
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
      final msg = await ProfileService.updateProfileData(payload);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      setState(() => isEditingProfile = false);
      await fetchProfileData();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> changeRole(String newRole) async {
    final msg = await ProfileService.changeRole(newRole);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    Provider.of<HomePageProvider>(context, listen: false).currentRole = newRole;
    Navigator.pushNamedAndRemoveUntil(context, '/main', (r) => false);
  }

  Future<void> changeSchool(String schoolId) async {
    final msg = await ProfileService.changeSchool(schoolId);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    Navigator.pushNamedAndRemoveUntil(context, '/main', (r) => false);
  }

  Future<void> logout() async {
    await storage.delete(key: 'auth_token');
    Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
  }

  void _showBirthdayPicker() async {
    DateTime initial = DateTime.now();
    if (_birthdayController.text.isNotEmpty) {
      initial = DateTime.tryParse(_birthdayController.text) ?? DateTime.now();
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      _birthdayController.text = picked.toIso8601String().split('T').first;
    }
  }

  void _openEditStudent(Map<String, dynamic> student) {
    final nameCtrl = TextEditingController(text: student['name']);
    final emailCtrl = TextEditingController(text: student['email']);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Edit Student'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameCtrl,
                decoration: InputDecoration(labelText: 'Name')),
            TextField(
                controller: emailCtrl,
                decoration: InputDecoration(labelText: 'Email')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final payload = {'name': nameCtrl.text, 'email': emailCtrl.text};
              //await ProfileService.updateStudent(student['id'].toString(), payload);
              Navigator.pop(context);
              fetchProfileData();
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = currentRole == 'Admin';
    final tabs = <Tab>[Tab(text: 'Info'), Tab(text: 'Students')];
    if (isAdmin) tabs.add(Tab(text: 'School'));

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Profile'),
          bottom: TabBar(tabs: tabs),
          actions: [IconButton(icon: Icon(Icons.logout), onPressed: logout)],
        ),
        body: isLoading
            ? Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  // Info Tab
                  SingleChildScrollView(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: 16),
                        hasCalendarToken == false ? 
                        ConnectCalendarButton() : SizedBox(height: 0,),
                        SizedBox(height: 16),
                        _buildInput('First Name', _firstNameController,
                            readOnly: !isEditingProfile),
                        _buildInput('Last Name', _lastNameController,
                            readOnly: !isEditingProfile),
                        _buildInput('Email', _emailController,
                            readOnly: !isEditingProfile),
                        SizedBox(height: 8),
                        _buildBirthdayField(),
                        SizedBox(height: 8),
                        buildIntlPhoneField(),
                        if (isEditingProfile) ...[
                          SizedBox(height: 16),
                          ElevatedButton(
                              onPressed: updateProfile,
                              child: Text('Save Profile')),
                        ] else ...{
                          SizedBox(height: 16),
                          ElevatedButton(
                              onPressed: () => setState(
                                  () => isEditingProfile = !isEditingProfile),
                              child: Text('Edit Profile')),
                        },
                      ],
                    ),
                  ),

                  // Students Tab
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: ListView.builder(
                            itemCount: associatedStudents.length,
                            itemBuilder: (ctx, i) {
                              final st = associatedStudents[i];
                              return ListTile(
                                title: Text(
                                    "${st['first_name']} ${st['last_name']}"),
                                subtitle: Text(st['birthday']),
                                trailing: IconButton(
                                  icon: Icon(Icons.info),
                                  onPressed: () {
                                    print("student tapped");
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            StudentPage(studentId: st["id"]),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  // School Tab (Admin)
                  if (isAdmin)
                    Center(
                      child: ElevatedButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SchoolSetupPage(
                              isCreatingSchool: availableSchools.isEmpty,
                              fetchProfileData: fetchProfileData,
                            ),
                          ),
                        ),
                        child: Text(availableSchools.isEmpty
                            ? 'Create School'
                            : 'Manage School'),
                      ),
                    ),
                ],
              ),
        bottomNavigationBar: SafeArea(
          child: SizedBox(
            height: 80, // adjust as needed
            child: Align(
              alignment: Alignment.center,
              child: ToggleButtons(
                isSelected:
                    availableRoles.map((r) => r == currentRole).toList(),
                onPressed: (index) => changeRole(availableRoles[index]),
                borderRadius: BorderRadius.circular(8),
                fillColor: Colors.transparent,
                selectedBorderColor: Theme.of(context).primaryColor,
                children: availableRoles
                    .map((r) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(r),
                        ))
                    .toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController ctrl,
      {bool readOnly = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: ctrl,
        readOnly: readOnly,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  // Replace your existing buildIntlPhoneField with this:

  Widget buildIntlPhoneField() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: IntlPhoneField(
        initialCountryCode: _phoneCountryCode,
        initialValue: _phoneController.text,
        enabled: isEditingProfile,
        decoration: InputDecoration(
          labelText: 'Phone Number',
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(32.0),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(32.0),
            borderSide: BorderSide(color: Colors.orange, width: 2),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(32.0),
            borderSide: BorderSide(color: Colors.orange, width: 2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(32.0),
            borderSide: BorderSide(color: Colors.orange, width: 2),
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

  Widget _buildBirthdayField() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _birthdayController,
            readOnly: true,
            decoration: InputDecoration(
              labelText: 'Birthday',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        IconButton(
            icon: Icon(Icons.calendar_today),
            onPressed: isEditingProfile ? _showBirthdayPicker : null),
      ],
    );
  }
}
