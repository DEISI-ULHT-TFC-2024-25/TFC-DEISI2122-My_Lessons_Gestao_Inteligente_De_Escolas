import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../main.dart';
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
  List<dynamic> todayLessons = [];
  List<dynamic> upcomingLessons = [];
  List<dynamic> needRescheduleLessons = [];
  List<dynamic> lastLessons = [];
  List<dynamic> activePacks = [];
  List<dynamic> lastPacks = [];
  List<String> unschedulableLessons = [];

  // pages
  int todayPage = 1, upcomingPage = 1, reschedulePage = 1;
  // flags
  bool hasMoreToday = false, hasMoreUpcoming = false, hasMoreReschedule = false;
  // History lessons
  int lastLessonsPage = 1;
  bool hasMoreLastLessons = false;

  // Packs
  int activePacksPage = 1;
  bool hasMoreActivePacks = false;

  int lastPacksPage = 1;
  bool hasMoreLastPacks = false;

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
    print("🔄 HomePageProvider.fetchData() running!");
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
      if (profileResponse.statusCode == 401) {
        await storage.delete(key: 'auth_token');
        // Use the global navigator key instead of context:
        navigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/',
          (route) => false,
        );

        // Optionally return a default or throw.
        return Future.error('Unauthenticated');
      }
      if (profileResponse.statusCode == 200 && roleResponse.statusCode == 200) {
        final profileData = json.decode(utf8.decode(profileResponse.bodyBytes));
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
          final schoolData = json.decode(utf8.decode(schoolResponse.bodyBytes));
          schoolId =
              int.tryParse(schoolData['current_school_id'].toString()) ?? 0;
          schoolName = schoolData['current_school_name'].toString();
        }
      }

      if (currentRole == "Parent" ||
          currentRole == "Instructor" ||
          currentRole == "Admin") {
        await fetchUpcomingLessons();
        await fetchLastLessons();
        await fetchActivePacks();
        await fetchLastPacks();
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
                  .decode(
                      utf8.decode(balanceResponse.bodyBytes))['current_balance']
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
      Uri.parse(
          '$baseUrl/api/schools/number_of_booked_lessons/$schoolId/$formattedStart/$formattedEnd/'),
      headers: headers,
    );
    final studentsResponse = await http.get(
      Uri.parse(
          '$baseUrl/api/schools/number_of_students/$schoolId/$formattedStart/$formattedEnd/'),
      headers: headers,
    );
    final instructorsResponse = await http.get(
      Uri.parse(
          '$baseUrl/api/schools/number_of_instructors/$schoolId/$formattedStart/$formattedEnd/'),
      headers: headers,
    );
    final revenueResponse = await http.get(
      Uri.parse(
          '$baseUrl/api/schools/school-revenue/$schoolId/$formattedStart/$formattedEnd/'),
      headers: headers,
    );

    numberOfBookings = bookingsResponse.statusCode == 200
        ? int.tryParse(json
                .decode(utf8.decode(bookingsResponse.bodyBytes))[
                    'number_of_lessons_booked']
                .toString()) ??
            0
        : 0;
    numberOfStudents = studentsResponse.statusCode == 200
        ? int.tryParse(json
                .decode(
                    utf8.decode(studentsResponse.bodyBytes))['total_students']
                .toString()) ??
            0
        : 0;
    numberOfInstructors = instructorsResponse.statusCode == 200
        ? int.tryParse(json
                .decode(utf8.decode(instructorsResponse.bodyBytes))[
                    'total_instructors']
                .toString()) ??
            0
        : 0;
    totalRevenue = revenueResponse.statusCode == 200
        ? double.tryParse(json
                .decode(utf8.decode(revenueResponse.bodyBytes))['total_revenue']
                .toString()) ??
            0.0
        : 0.0;
    notifyListeners();
  }

  Future<void> fetchUpcomingLessons({ String? bucket }) async {
    final headers = await getAuthHeaders();

    // On initial load (no bucket), reset everything
    if (bucket == null) {
      todayPage = 1;
      upcomingPage = 1;
      reschedulePage = 1;
      todayLessons = [];
      upcomingLessons = [];
      needRescheduleLessons = [];
    }

    Uri uri = Uri.parse('$baseUrl/api/lessons/upcoming_lessons/');
    // build query params
    final params = <String, String>{};
    if (bucket == 'today') {
      params['today_page'] = todayPage.toString();
    } else if (bucket == 'upcoming') {
      params['upcoming_page'] = upcomingPage.toString();
    } else if (bucket == 'reschedule') {
      params['reschedule_page'] = reschedulePage.toString();
    }
    uri = uri.replace(queryParameters: params);

    final resp = await http.get(uri, headers: headers);
    if (resp.statusCode != 200) return;

    final data = json.decode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;

    // For each list, either assign (initial) or append (load more)
    // and bump page counters & flags.
        {
      final list = List<dynamic>.from(data['today_lessons'] ?? []);
      if (bucket == 'today') todayLessons.addAll(list);
      else todayLessons = list;
      hasMoreToday = data['has_more_today'] as bool? ?? false;
      todayPage++;
    }
    {
      final list = List<dynamic>.from(data['upcoming_lessons'] ?? []);
      if (bucket == 'upcoming') upcomingLessons.addAll(list);
      else upcomingLessons = list;
      hasMoreUpcoming = data['has_more_upcoming'] as bool? ?? false;
      upcomingPage++;
    }
    {
      final list = List<dynamic>.from(data['need_reschedule_lessons'] ?? []);
      if (bucket == 'reschedule') needRescheduleLessons.addAll(list);
      else needRescheduleLessons = list;
      hasMoreReschedule = data['has_more_reschedule'] as bool? ?? false;
      reschedulePage++;
    }

    notifyListeners();
  }

  Future<void> fetchLastLessons({ bool loadMore = false }) async {
    if (!loadMore) {
      lastLessonsPage = 1;
      lastLessons = [];
    }
    final uri = Uri.parse(
        '$baseUrl/api/lessons/last_lessons/?page=$lastLessonsPage'
    );
    final resp = await http.get(uri, headers: await getAuthHeaders());
    if (resp.statusCode != 200) return;

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final pageItems = List<dynamic>.from(data['results'] ?? []);
    lastLessons.addAll(pageItems);

    hasMoreLastLessons = data['has_more'] as bool? ?? false;
    lastLessonsPage++;
    notifyListeners();
  }

  Future<void> fetchActivePacks({ bool loadMore = false }) async {
    if (!loadMore) {
      activePacksPage = 1;
      activePacks = [];
    }
    final uri = Uri.parse(
        '$baseUrl/api/lessons/active_packs/?page=$activePacksPage'
    );
    final resp = await http.get(uri, headers: await getAuthHeaders());
    if (resp.statusCode != 200) return;

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final items = List<dynamic>.from(data['results'] ?? []);
    activePacks.addAll(items);

    hasMoreActivePacks = data['has_more'] as bool? ?? false;
    activePacksPage++;
    notifyListeners();
  }

  Future<void> fetchLastPacks({ bool loadMore = false }) async {
    if (!loadMore) {
      lastPacksPage = 1;
      lastPacks = [];
    }
    final uri = Uri.parse(
        '$baseUrl/api/lessons/last_packs/?page=$lastPacksPage'
    );
    final resp = await http.get(uri, headers: await getAuthHeaders());
    if (resp.statusCode != 200) return;

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final items = List<dynamic>.from(data['results'] ?? []);
    lastPacks.addAll(items);

    hasMoreLastPacks = data['has_more'] as bool? ?? false;
    lastPacksPage++;
    notifyListeners();
  }
}
