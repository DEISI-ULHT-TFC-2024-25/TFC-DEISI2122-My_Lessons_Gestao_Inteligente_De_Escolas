import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:mylessons_frontend/services/profile_service.dart';
import 'package:mylessons_frontend/providers/home_page_provider.dart';

class ProfileProvider extends ChangeNotifier {
  final FlutterSecureStorage storage = const FlutterSecureStorage();

  bool isLoading = true;
  bool isEditingProfile = false;

  // Profile controllers
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController birthdayController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  String phoneCountryCode = 'PT';

  bool hasCalendarToken = false;

  // Roles & Schools
  List<String> availableRoles = [];
  String currentRole = '';
  List<Map<String, dynamic>> availableSchools = [];
  String? currentSchoolId;
  String? currentSchoolName;

  // Associated students
  List<Map<String, dynamic>> associatedStudents = [];

  ProfileProvider() {
    fetchProfileData();
  }

  Future<void> fetchProfileData() async {
    isLoading = true;
    notifyListeners();
    try {
      final profileData = await ProfileService.fetchProfileData();
      firstNameController.text = profileData.firstName;
      lastNameController.text = profileData.lastName;
      emailController.text = profileData.email;
      birthdayController.text = profileData.birthday ?? '';
      phoneController.text = profileData.phone ?? '';
      phoneCountryCode = profileData.countryCode ?? 'PT';

      availableRoles = profileData.availableRoles;
      currentRole = profileData.currentRole;
      availableSchools = profileData.availableSchools;
      currentSchoolId = profileData.currentSchoolId;
      currentSchoolName = profileData.currentSchoolName;
      associatedStudents = profileData.associatedStudents ?? [];
      hasCalendarToken = profileData.hasCalendarToken ?? false;
    } catch (e) {
      debugPrint('Error fetching profile: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void toggleEditing() {
    isEditingProfile = !isEditingProfile;
    notifyListeners();
  }

  Future<void> updateProfile(BuildContext context) async {
    final payload = {
      'first_name': firstNameController.text,
      'last_name': lastNameController.text,
      'email': emailController.text,
      'country_code': phoneCountryCode,
      'phone': phoneController.text,
      'birthday': birthdayController.text,
    };
    try {
      final msg = await ProfileService.updateProfileData(payload);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      isEditingProfile = false;
      notifyListeners();
      await fetchProfileData();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> changeRole(BuildContext context, String newRole) async {
    final msg = await ProfileService.changeRole(newRole);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    Provider.of<HomePageProvider>(context, listen: false).currentRole = newRole;
    Navigator.pushNamedAndRemoveUntil(context, '/main', (r) => false);
  }

  Future<void> changeSchool(BuildContext context, String schoolId) async {
    final msg = await ProfileService.changeSchool(schoolId);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    Navigator.pushNamedAndRemoveUntil(context, '/main', (r) => false);
  }

  Future<void> logout(BuildContext context) async {
    await storage.delete(key: 'auth_token');
    Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
  }
}
