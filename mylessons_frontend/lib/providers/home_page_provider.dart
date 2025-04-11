import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_service.dart';
import '../services/profile_service.dart';

class HomePageProvider extends ChangeNotifier {
  // Secure storage instance.
  final FlutterSecureStorage storage = const FlutterSecureStorage();

  // Profile Data.
  String firstName = '';
  String lastName = '';
  String phone = '';
  String countryCode = '';
  int notificationsCount = 0;
  String currentRole = '';

  // Lessons and Packs.
  List<dynamic> upcomingLessons = [];
  List<dynamic> lastLessons = [];
  List<dynamic> activePacks = [];
  List<dynamic> lastPacks = [];
  List<String> unschedulableLessons = [];

  // Instructor metrics.
  int numberOfActiveStudents = 0;
  double currentBalance = 0.0;

  // Admin Metrics.
  int schoolId = 0;
  String schoolName = "";
  int numberOfBookings = 0;
  int numberOfStudents = 0;
  int numberOfInstructors = 0;
  double totalRevenue = 0.0;
  DateTime startDate = DateTime.now();
  DateTime endDate = DateTime.now();

  // Loading flag.
  bool isLoading = true;

  HomePageProvider() {
    setInitialDate();
    fetchData();
  }

  void setInitialDate() {
    final now = DateTime.now();
    startDate = DateTime(now.year, now.month, 1);
    endDate = DateTime(now.year, now.month + 1, 0);
  }

  Future<void> fetchData() async {
    isLoading = true;
    notifyListeners();
    try {
      final headers = await getAuthHeaders();

      // Fetch profile, role, and school data.
      final profileResponse = await http.get(
        Uri.parse('$baseUrl/api/users/profile/'),
        headers: headers,
      );
      final roleResponse = await http.get(
        Uri.parse('$baseUrl/api/users/current_role/'),
        headers: headers,
      );
      final schoolResponse = await http.get(
        Uri.parse('$baseUrl/api/users/current_school_id/'),
        headers: headers,
      );
      final unschedulableLessonsResponse = await http.get(
        Uri.parse('$baseUrl/api/lessons/unschedulable_lessons/'),
        headers: headers,
      );

      final decodedUnschedulable =
          json.decode(utf8.decode(unschedulableLessonsResponse.bodyBytes));
      unschedulableLessons =
          List<String>.from(decodedUnschedulable['lesson_ids']);

      if (profileResponse.statusCode == 200 && roleResponse.statusCode == 200) {
        final profileData =
            json.decode(utf8.decode(profileResponse.bodyBytes));
        final roleData = json.decode(utf8.decode(roleResponse.bodyBytes));

        firstName = (profileData['first_name'] ?? '').toString();
        lastName = (profileData['last_name'] ?? '').toString();
        phone = (profileData['phone'] ?? '').toString();
        countryCode = (profileData['country_code'] ?? 'PT').toString();
        notificationsCount = int.tryParse(
                (profileData['notifications_count'] ?? '0').toString()) ??
            0;
        // Ensure a trimmed and non-empty current role.
        currentRole = (roleData['current_role']?.toString() ?? "").trim();
        if (currentRole.isEmpty) {
          currentRole = "Parent";
        }

        if (schoolResponse.statusCode == 200) {
          final schoolData =
              json.decode(utf8.decode(schoolResponse.bodyBytes));
          schoolId = int.tryParse(schoolData['current_school_id'].toString()) ??
              0;
          schoolName = schoolData['current_school_name'].toString();
        }
      }

      // Depending on role, fetch lessons and packs.
      if (currentRole == "Parent" ||
          currentRole == "Instructor" ||
          currentRole == "Admin") {
        final lessonsResponse = await http.get(
          Uri.parse('$baseUrl/api/lessons/upcoming_lessons/'),
          headers: headers,
        );
        final activePacksResponse = await http.get(
          Uri.parse('$baseUrl/api/lessons/active_packs/'),
          headers: headers,
        );
        final lastPacksResponse = await http.get(
          Uri.parse('$baseUrl/api/lessons/last_packs/'),
          headers: headers,
        );
        if (lessonsResponse.statusCode == 200) {
          upcomingLessons =
              json.decode(utf8.decode(lessonsResponse.bodyBytes));
        }
        if (activePacksResponse.statusCode == 200) {
          activePacks =
              json.decode(utf8.decode(activePacksResponse.bodyBytes));
        }
        if (lastPacksResponse.statusCode == 200) {
          lastPacks = json.decode(utf8.decode(lastPacksResponse.bodyBytes));
        }
        final lastLessonsResponse = await http.get(
          Uri.parse('$baseUrl/api/lessons/last_lessons/'),
          headers: headers,
        );
        if (lastLessonsResponse.statusCode == 200) {
          lastLessons =
              json.decode(utf8.decode(lastLessonsResponse.bodyBytes));
        }
      }

      if (currentRole == "Instructor") {
        final activeStudentsResponse = await http.get(
          Uri.parse('$baseUrl/api/users/number_of_active_students/'),
          headers: headers,
        );
        final balanceResponse = await http.get(
          Uri.parse('$baseUrl/api/users/current_balance/'),
          headers: headers,
        );
        if (activeStudentsResponse.statusCode == 200) {
          numberOfActiveStudents = int.tryParse(json
                  .decode(utf8.decode(activeStudentsResponse.bodyBytes))[
              'number_of_active_students']
              .toString()) ??
              0;
        }
        if (balanceResponse.statusCode == 200) {
          currentBalance = double.tryParse(json
                  .decode(utf8.decode(balanceResponse.bodyBytes))['current_balance']
                  .toString()) ??
              0.0;
        }
      }

      if (currentRole == "Admin") {
        await fetchAdminMetrics();
      }
    } catch (e) {
      // Handle errors if needed.
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> fetchAdminMetrics() async {
    final headers = await getAuthHeaders();
    final formattedStart = DateFormat('yyyy-MM-dd').format(startDate);
    final formattedEnd = DateFormat('yyyy-MM-dd').format(endDate);

    final bookingsResponse = await http.get(
      Uri.parse('$baseUrl/api/schools/number_of_booked_lessons/$schoolId/$formattedStart/$formattedEnd/'),
      headers: headers,
    );
    final studentsResponse = await http.get(
      Uri.parse('$baseUrl/api/schools/number_of_students/$schoolId/$formattedStart/$formattedEnd/'),
      headers: headers,
    );
    final instructorsResponse = await http.get(
      Uri.parse('$baseUrl/api/schools/number_of_instructors/$schoolId/$formattedStart/$formattedEnd/'),
      headers: headers,
    );
    final revenueResponse = await http.get(
      Uri.parse('$baseUrl/api/schools/school-revenue/$schoolId/$formattedStart/$formattedEnd/'),
      headers: headers,
    );

    numberOfBookings = bookingsResponse.statusCode == 200
        ? int.tryParse(
                json.decode(utf8.decode(bookingsResponse.bodyBytes))['number_of_lessons_booked']
                    .toString()) ??
            0
        : 0;
    numberOfStudents = studentsResponse.statusCode == 200
        ? int.tryParse(
                json.decode(utf8.decode(studentsResponse.bodyBytes))['total_students']
                    .toString()) ??
            0
        : 0;
    numberOfInstructors = instructorsResponse.statusCode == 200
        ? int.tryParse(
                json.decode(utf8.decode(instructorsResponse.bodyBytes))['total_instructors']
                    .toString()) ??
            0
        : 0;
    totalRevenue = revenueResponse.statusCode == 200
        ? double.tryParse(
                json.decode(utf8.decode(revenueResponse.bodyBytes))['total_revenue']
                    .toString()) ??
            0.0
        : 0.0;
    notifyListeners();
  }
}
