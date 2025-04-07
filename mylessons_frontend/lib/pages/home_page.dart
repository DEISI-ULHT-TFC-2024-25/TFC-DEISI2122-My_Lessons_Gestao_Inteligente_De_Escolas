import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mylessons_frontend/modals/lesson_details_modal.dart';
import 'package:mylessons_frontend/modals/pack_details_modal.dart';
import 'package:mylessons_frontend/modals/schedule_multiple_lessons_modal.dart';
import 'package:mylessons_frontend/providers/pack_details_provider.dart';
import 'package:mylessons_frontend/widgets/handle_lesson_report.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../modals/profile_completion_modal.dart';
import '../services/api_service.dart';
import '../services/profile_service.dart';
import 'profile_page.dart';
import 'package:mylessons_frontend/modals/schedule_lesson_modal.dart';

class HomePage extends StatefulWidget {
  final List<dynamic> newBookedPacks;
  const HomePage({Key? key, this.newBookedPacks = const []}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  final storage = const FlutterSecureStorage();
  String firstName = '';
  String lastName = '';
  String phone = '';
  String countryCode = '';
  int notificationsCount = 0;
  String currentRole = '';
  List<dynamic> upcomingLessons = [];
  List<dynamic> lastLessons = [];
  List<dynamic> activePacks = [];
  List<dynamic> lastPacks = [];
  List<String> unschedulableLessons = [];
  int numberOfActiveStudents = 0;
  double currentBalance = 0.0;
  bool _isLoading = true; // Loading flag
  // State variables for inner toggle buttons.
  int _lessonsActiveTabIndex = 0; // 0 = Active, 1 = History
  int _packsActiveTabIndex = 0; // 0 = Active, 1 = History
  double _headerHeight = 80;

  // Admin Metrics
  int schoolId = 0;
  String schoolName = "";
  int numberOfBookings = 0;
  int numberOfStudents = 0;
  int numberOfInstructors = 0;
  double totalRevenue = 0.0;
  DateTime startDate = DateTime.now();
  DateTime endDate = DateTime.now();

  // ------------------ NEW VARIABLES FOR ANIMATIONS & SCROLL ------------------
  late AnimationController _headerAnimationController;
  // We'll use the controller’s value (0.0–1.0) with two intervals for the two header states.
  // Scroll controllers for lessons and packs lists:
  final ScrollController _lessonsScrollController = ScrollController();
  final ScrollController _packsScrollController = ScrollController();
  // Variables to hide/show the header and the toggle row based on scroll:
  bool _showToggleRow = true;
  bool _showHeader = true;
  // ---------------------------------------------------------------------------

  // Search and filter state for each tab.
  // Lessons
  String upcomingSearchQuery = "";
  List<Map<String, String>> upcomingFilters = []; // For active lessons
  String lastLessonsSearchQuery = "";
  List<Map<String, String>> lastLessonsFilters = [];
  // Packs
  String activePacksSearchQuery = "";
  List<Map<String, String>> activePacksFilters = [];
  String lastPacksSearchQuery = "";
  List<Map<String, String>> lastPacksFilters = [];

  @override
  void initState() {
    super.initState();
    setInitialDate();
    fetchData();
    // Initialize header animation controller.
    _headerAnimationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));

    // After a 2-second delay, start the slide/fade animation.
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _headerAnimationController.forward().then((_) {
          // If there are no notifications, collapse the header (set height to 0).
          // If notifications exist, keep the header height (80) to display them.
          if (notificationsCount == 0) {
            setState(() {
              _headerHeight = 0;
            });
          }
        });
      }
    });

    // Listen to scrolling in lessons tab.
    _lessonsScrollController.addListener(() {
      if (_lessonsScrollController.offset > 50 && _showToggleRow) {
        setState(() {
          _showToggleRow = false;
          _showHeader = false;
        });
      } else if (_lessonsScrollController.offset <= 50 && !_showToggleRow) {
        setState(() {
          _showToggleRow = true;
          _showHeader = true;
        });
      }
    });
    // Listen to scrolling in packs tab.
    _packsScrollController.addListener(() {
      if (_packsScrollController.offset > 50 && _showToggleRow) {
        setState(() {
          _showToggleRow = false;
          _showHeader = false;
        });
      } else if (_packsScrollController.offset <= 50 && !_showToggleRow) {
        setState(() {
          _showToggleRow = true;
          _showHeader = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _headerAnimationController.dispose();
    _lessonsScrollController.dispose();
    _packsScrollController.dispose();
    super.dispose();
  }

  void setInitialDate() {
    final now = DateTime.now();
    startDate = DateTime(now.year, now.month, 1);
    endDate = DateTime(now.year, now.month + 1, 0);
  }

  Future<void> fetchData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final headers = await getAuthHeaders();

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

      final decodedResponse =
          json.decode(utf8.decode(unschedulableLessonsResponse.bodyBytes));

      // Assuming the API returns a map with a key "lesson_ids" that holds the list.
      setState(() {
        unschedulableLessons = List<String>.from(decodedResponse['lesson_ids']);
      });
      print(unschedulableLessons);

      if (profileResponse.statusCode == 200 && roleResponse.statusCode == 200) {
        final decodedProfile = utf8.decode(profileResponse.bodyBytes);
        final decodedRole = utf8.decode(roleResponse.bodyBytes);
        final profileData = json.decode(decodedProfile);
        final roleData = json.decode(decodedRole);

        setState(() {
          firstName = (profileData['first_name'] ?? '').toString();
          lastName = (profileData['last_name'] ?? '').toString();
          phone = (profileData['phone'] ?? '').toString();
          countryCode = (profileData['country_code'] ?? 'PT').toString();
          notificationsCount = int.tryParse(
                  (profileData['notifications_count'] ?? '0').toString()) ??
              0;
          currentRole = roleData['current_role'].toString();
          schoolId = schoolResponse.statusCode == 200
              ? int.tryParse(json
                      .decode(utf8.decode(schoolResponse.bodyBytes))[
                          'current_school_id']
                      .toString()) ??
                  0
              : 0;
          schoolName = schoolResponse.statusCode == 200
              ? json
                  .decode(utf8.decode(schoolResponse.bodyBytes))[
                      'current_school_name']
                  .toString()
              : "";
        });

        // Prompt profile completion if needed.
        if (firstName.isEmpty ||
            lastName.isEmpty ||
            countryCode.isEmpty ||
            phone.isEmpty) {
          _promptProfileCompletion();
        }
      }

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
          setState(() {
            upcomingLessons =
                json.decode(utf8.decode(lessonsResponse.bodyBytes));
          });
        }
        if (activePacksResponse.statusCode == 200) {
          setState(() {
            activePacks =
                json.decode(utf8.decode(activePacksResponse.bodyBytes));
          });
        }
        if (lastPacksResponse.statusCode == 200) {
          setState(() {
            lastPacks = json.decode(utf8.decode(lastPacksResponse.bodyBytes));
          });
        }

        final lastLessonsResponse = await http.get(
          Uri.parse('$baseUrl/api/lessons/last_lessons/'),
          headers: headers,
        );
        if (lastLessonsResponse.statusCode == 200) {
          setState(() {
            lastLessons =
                json.decode(utf8.decode(lastLessonsResponse.bodyBytes));
          });
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
          setState(() {
            numberOfActiveStudents = int.tryParse(json
                    .decode(utf8.decode(activeStudentsResponse.bodyBytes))[
                        'number_of_active_students']
                    .toString()) ??
                0;
          });
        }
        if (balanceResponse.statusCode == 200) {
          setState(() {
            currentBalance = double.tryParse(json
                    .decode(utf8.decode(balanceResponse.bodyBytes))[
                        'current_balance']
                    .toString()) ??
                0.0;
          });
        }
      }

      if (currentRole == "Admin") {
        await fetchAdminMetrics();
      }
    } catch (e) {
      print("Error fetching data: $e");
    }
    setState(() {
      _isLoading = false;
    });
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

    setState(() {
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
                  .decode(
                      utf8.decode(revenueResponse.bodyBytes))['total_revenue']
                  .toString()) ??
              0.0
          : 0.0;
    });
  }

  Future<List<String>> _fetchAvailableTimes(
          int lessonId, DateTime date, int increment) =>
      fetchAvailableTimes(lessonId, date, increment);

  Future<String?> _schedulePrivateLesson(
          int lessonId, DateTime newDate, String newTime) =>
      schedulePrivateLesson(lessonId, newDate, newTime);

  Future<void> _markNotificationsAsRead(List<int> notificationIds) =>
      markNotificationsAsRead(notificationIds);

  Future<void> _promptProfileCompletion() async {
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileCompletionPage(
          initialFirstName: firstName,
          initialLastName: lastName,
          initialPhone: phone,
          initialCountryCode: countryCode,
        ),
      ),
    );

    if (result != null) {
      final payload = {
        'first_name': result['firstName']!,
        'last_name': result['lastName']!,
        'country_code': result['id']!, // ISO country code
        'phone': result['phone']!,
      };

      try {
        final message = await ProfileService.updateProfileData(payload);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
        await fetchData();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error updating profile: $e")),
        );
      }
    }
  }

  // ----------------- Modal Options for Cards -----------------

  void showLessonCardOptions(dynamic lesson) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.calendar_today, color: Colors.orange),
                title: const Text("Schedule Lesson"),
                onTap: () {
                  Navigator.pop(context);
                  if (lesson['type']?.toString().toLowerCase() == 'group') {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text("Scheduling Unavailable"),
                        content: const Text(
                            "To change the schedule of a group lesson, please contact the school."),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text("OK"),
                          )
                        ],
                      ),
                    );
                  } else {
                    showScheduleLessonModal(lesson);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.more_vert, color: Colors.orange),
                title: const Text("View Details"),
                onTap: () {
                  Navigator.pop(context);
                  showLessonDetailsModal(lesson);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPackCardOptions(dynamic pack) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.calendar_today, color: Colors.orange),
                title: const Text("Schedule Lessons"),
                onTap: () {
                  Navigator.pop(context);
                  if (pack['type'].toString().toLowerCase() == 'group') {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text("Scheduling Unavailable"),
                        content: const Text(
                            "To change the schedule of a group lesson, please contact the school."),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text("OK"),
                          )
                        ],
                      ),
                    );
                  } else {
                    _showScheduleMultipleLessonsModal(
                        pack['lessons'], pack["expiration_date"]);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.more_vert, color: Colors.orange),
                title: const Text("View Details"),
                onTap: () {
                  Navigator.pop(context);
                  showPackDetailsModal(pack);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ------------------- Existing Modal Methods -------------------

  showLessonDetailsModal(lesson) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        child: LessonDetailsModal(
          lesson: lesson,
          currentRole: currentRole,
          fetchData: fetchData,
        ),
      ),
    );
  }

  void showPackDetailsModal(dynamic pack) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => ChangeNotifierProvider(
        create: (_) {
          final provider = PackDetailsProvider();
          provider.initialize(
            pack: pack,
            currentRole: currentRole,
            fetchData: fetchData,
            unschedulableLessons: unschedulableLessons,
          );
          return provider;
        },
        child: const PackDetailsModal(),
      ),
    );
  }

  Future<void> _showScheduleMultipleLessonsModal(
      List<dynamic> lessons, String expirationDate) async {
    int schoolScheduleTimeLimit =
        await fetchSchoolScheduleTimeLimit(lessons.first["school"]);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => ScheduleMultipleLessonsModal(
        lessons: lessons,
        unschedulableLessons: unschedulableLessons,
        expirationDate: expirationDate,
        currentRole: currentRole,
        schoolScheduleTimeLimit: schoolScheduleTimeLimit,
        onScheduleConfirmed: () {
          fetchData();
        },
      ),
    );
  }

  Future<void> showScheduleLessonModal(dynamic lesson) async {
    final int lessonId = lesson['id'] ?? lesson['lesson_id'];
    int schoolScheduleTimeLimit =
        await fetchSchoolScheduleTimeLimit(lesson["school"]);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext modalContext) {
        return ScheduleLessonModal(
          lessonId: lessonId,
          expirationDate: lesson['expiration_date'],
          schoolScheduleTimeLimit: schoolScheduleTimeLimit,
          currentRole: currentRole,
          fetchAvailableTimes: _fetchAvailableTimes,
          schedulePrivateLesson: _schedulePrivateLesson,
          onScheduleConfirmed: () {
            fetchData();
          },
        );
      },
    );
  }

  Future<void> _showNotificationsModal() async {
    // Mark notifications as read and collapse the header.
    setState(() {
      notificationsCount = 0;
      // Collapse the header so that the tab bar moves up.
      _headerHeight = 0;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return FutureBuilder<List<dynamic>>(
          future: _fetchNotifications(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Container(
                height: MediaQuery.of(context).size.height * 0.6,
                padding: const EdgeInsets.all(16),
                child: const Center(child: CircularProgressIndicator()),
              );
            }
            final notifications = snapshot.data!;
            return Container(
              height: MediaQuery.of(context).size.height * 0.6,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Notificações",
                    style: GoogleFonts.lato(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: notifications.isEmpty
                        ? Center(
                            child: Text(
                              "Sem notificações novas.",
                              style: GoogleFonts.lato(
                                  fontSize: 16, color: Colors.black54),
                            ),
                          )
                        : ListView.builder(
                            itemCount: notifications.length,
                            itemBuilder: (context, index) {
                              final notification = notifications[index];
                              final formattedDate =
                                  DateFormat("dd MMM yyyy, HH:mm").format(
                                      DateTime.parse(
                                          notification['created_at']));
                              return Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  leading: const Icon(Icons.notifications,
                                      color: Colors.orange),
                                  title: Text(
                                    notification['subject'],
                                    style: GoogleFonts.lato(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(
                                    formattedDate,
                                    style: GoogleFonts.lato(
                                        fontSize: 14, color: Colors.black54),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<List<dynamic>> _fetchNotifications() async {
    final headers = await getAuthHeaders();

    final response = await http.get(
      Uri.parse('$baseUrl/api/notifications/unread/'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final List<dynamic> notifications =
          jsonDecode(utf8.decode(response.bodyBytes));
      List<int> notificationIds =
          notifications.map<int>((n) => n['id']).toList();
      _markNotificationsAsRead(notificationIds);
      return notifications;
    } else {
      return [];
    }
  }

  // Shows a modal bottom sheet to filter lessons.
  void _showLessonFilterModal(bool isUpcoming, List<dynamic> lessons) {
    const options = ['Group', 'Private'];
    // Use upcomingFilters or lastLessonsFilters based on isUpcoming.
    List<Map<String, String>> tempFilters =
        isUpcoming ? List.from(upcomingFilters) : List.from(lastLessonsFilters);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          bool isSelected(String value) {
            return tempFilters
                .any((f) => f['type'] == 'lessonType' && f['value'] == value);
          }

          return Padding(
            padding: MediaQuery.of(context).viewInsets,
            child: Container(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ExpansionTile(
                    title: const Text('Lesson Type'),
                    children: options.map((opt) {
                      return CheckboxListTile(
                        title: Text(opt),
                        value: isSelected(opt),
                        onChanged: (checked) {
                          setModalState(() {
                            if (checked == true) {
                              tempFilters.insert(
                                  0, {'type': 'lessonType', 'value': opt});
                            } else {
                              tempFilters.removeWhere((f) =>
                                  f['type'] == 'lessonType' &&
                                  f['value'] == opt);
                            }
                          });
                          setState(() {
                            if (isUpcoming) {
                              upcomingFilters = List.from(tempFilters);
                            } else {
                              lastLessonsFilters = List.from(tempFilters);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close',
                          style: TextStyle(color: Colors.black)),
                    ),
                  )
                ],
              ),
            ),
          );
        });
      },
    );
  }

// Shows a modal bottom sheet to filter packs.
  void _showPackFilterModal(bool isActive, List<dynamic> packs) {
    const options = ['Group', 'Private'];
    // Use activePacksFilters or lastPacksFilters based on isActive.
    List<Map<String, String>> tempFilters =
        isActive ? List.from(activePacksFilters) : List.from(lastPacksFilters);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          bool isSelected(String value) {
            return tempFilters
                .any((f) => f['type'] == 'packType' && f['value'] == value);
          }

          return Padding(
            padding: MediaQuery.of(context).viewInsets,
            child: Container(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ExpansionTile(
                    title: const Text('Pack Type'),
                    children: options.map((opt) {
                      return CheckboxListTile(
                        title: Text(opt),
                        value: isSelected(opt),
                        onChanged: (checked) {
                          setModalState(() {
                            if (checked == true) {
                              tempFilters.insert(
                                  0, {'type': 'packType', 'value': opt});
                            } else {
                              tempFilters.removeWhere((f) =>
                                  f['type'] == 'packType' && f['value'] == opt);
                            }
                          });
                          setState(() {
                            if (isActive) {
                              activePacksFilters = List.from(tempFilters);
                            } else {
                              lastPacksFilters = List.from(tempFilters);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close',
                          style: TextStyle(color: Colors.black)),
                    ),
                  )
                ],
              ),
            ),
          );
        });
      },
    );
  }

  // ------------------- Filtering Methods -------------------

  List<dynamic> _filterLessons(
      List<dynamic> lessons, String query, List<Map<String, String>> filters) {
    return lessons.where((lesson) {
      final name = lesson['students_name'].toString();
      final matchesQuery =
          query.isEmpty || name.toLowerCase().contains(query.toLowerCase());
      final appliedTypes = filters
          .where((f) => f['type'] == 'lessonType')
          .map((f) => f['value']!.toLowerCase())
          .toList();
      final lessonType = lesson['type']?.toString().toLowerCase() ?? '';
      final matchesFilter =
          appliedTypes.isEmpty || appliedTypes.contains(lessonType);
      return matchesQuery && matchesFilter;
    }).toList();
  }

  List<dynamic> _filterPacks(
      List<dynamic> packs, String query, List<Map<String, String>> filters) {
    return packs.where((pack) {
      final name = pack['students_name'].toString();
      final matchesQuery =
          query.isEmpty || name.toLowerCase().contains(query.toLowerCase());
      final appliedTypes = filters
          .where((f) => f['type'] == 'packType')
          .map((f) => f['value']!.toLowerCase())
          .toList();
      final packType = pack['type']?.toString().toLowerCase() ?? '';
      final matchesFilter =
          appliedTypes.isEmpty || appliedTypes.contains(packType);
      return matchesQuery && matchesFilter;
    }).toList();
  }

  // ------------------- NEW WIDGETS FOR ANIMATED HEADER & TOGGLE/SEARCH ROW -------------------

  Widget _buildHeader() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      height: _headerHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: _headerHeight > 0
          ? Stack(
              alignment: Alignment.center,
              children: [
                // Welcome text and first name slide up and fade out.
                SlideTransition(
                  position: _headerAnimationController.drive(
                    Tween<Offset>(begin: Offset.zero, end: const Offset(0, -1))
                        .chain(CurveTween(curve: const Interval(0.0, 0.5))),
                  ),
                  child: FadeTransition(
                    opacity: _headerAnimationController.drive(
                      Tween<double>(begin: 1.0, end: 0.0)
                          .chain(CurveTween(curve: const Interval(0.0, 0.5))),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Welcome back,",
                          style: GoogleFonts.lato(
                              fontSize: 18, color: Colors.orange),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          firstName,
                          style: GoogleFonts.lato(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                // Notifications row (if any) appears in the second half of the animation.
                if (notificationsCount > 0)
                  SlideTransition(
                    position: _headerAnimationController.drive(
                      Tween<Offset>(
                              begin: const Offset(0, -1), end: Offset.zero)
                          .chain(CurveTween(curve: const Interval(0.5, 1.0))),
                    ),
                    child: FadeTransition(
                      opacity: _headerAnimationController.drive(
                        Tween<double>(begin: 0.0, end: 1.0)
                            .chain(CurveTween(curve: const Interval(0.5, 1.0))),
                      ),
                      child: GestureDetector(
                        onTap: _showNotificationsModal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.notifications_none,
                                size: 28, color: Colors.orange),
                            const SizedBox(width: 8),
                            Text(
                              "$notificationsCount new notifications",
                              style: GoogleFonts.lato(
                                  fontSize: 18, color: Colors.orange),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildToggleRowForLessons() {
    return AnimatedOpacity(
      opacity: _showToggleRow ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.search, color: Colors.orange),
                onPressed: () {
                  // Implement your search functionality here.
                  print("Search pressed in lessons tab");
                },
              ),
            ),
            Center(
              child: ToggleButtons(
                borderRadius: BorderRadius.circular(16),
                isSelected: [
                  _lessonsActiveTabIndex == 0,
                  _lessonsActiveTabIndex == 1,
                ],
                onPressed: (int index) {
                  setState(() {
                    _lessonsActiveTabIndex = index;
                  });
                },
                selectedColor: Colors.white,
                fillColor: Colors.orange,
                color: Colors.orange,
                borderColor: Colors.orange,
                borderWidth: 2.0,
                selectedBorderColor: Colors.orange,
                constraints: const BoxConstraints(minHeight: 32, minWidth: 80),
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_lessonsActiveTabIndex == 0)
                          const Icon(Icons.check,
                              color: Colors.black, size: 16),
                        if (_lessonsActiveTabIndex == 0)
                          const SizedBox(width: 4),
                        const Text(
                          "Active",
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_lessonsActiveTabIndex == 1)
                          const Icon(Icons.check,
                              color: Colors.black, size: 16),
                        if (_lessonsActiveTabIndex == 1)
                          const SizedBox(width: 4),
                        const Text(
                          "History",
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.filter_list, color: Colors.orange),
                onPressed: () {
                  if (_lessonsActiveTabIndex == 0) {
                    _showLessonFilterModal(true, upcomingLessons);
                  } else {
                    _showLessonFilterModal(false, lastLessons);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleRowForPacks() {
    return AnimatedOpacity(
      opacity: _showToggleRow ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
        child: Stack(
          children: [
            // Left: Search Icon
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.search, color: Colors.orange),
                onPressed: () {
                  // Implement search functionality.
                  print("Search pressed in packs tab");
                },
              ),
            ),
            // Center: Toggle Buttons.
            Center(
              child: ToggleButtons(
                borderRadius: BorderRadius.circular(16),
                isSelected: [
                  _packsActiveTabIndex == 0,
                  _packsActiveTabIndex == 1,
                ],
                onPressed: (int index) {
                  setState(() {
                    _packsActiveTabIndex = index;
                  });
                },
                selectedColor: Colors.white,
                fillColor: Colors.orange,
                color: Colors.orange,
                borderColor: Colors.orange,
                borderWidth: 2.0,
                selectedBorderColor: Colors.orange,
                constraints: const BoxConstraints(minHeight: 32, minWidth: 80),
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_packsActiveTabIndex == 0)
                          const Icon(Icons.check,
                              color: Colors.black, size: 16),
                        if (_packsActiveTabIndex == 0) const SizedBox(width: 4),
                        const Text(
                          "Active",
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_packsActiveTabIndex == 1)
                          const Icon(Icons.check,
                              color: Colors.black, size: 16),
                        if (_packsActiveTabIndex == 1) const SizedBox(width: 4),
                        const Text(
                          "History",
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Right: Filter Icon
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.filter_list, color: Colors.orange),
                onPressed: () {
                  if (_packsActiveTabIndex == 0) {
                    _showPackFilterModal(true, activePacks);
                  } else {
                    _showPackFilterModal(false, lastPacks);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(color: Colors.orange),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 16,
                    width: double.infinity,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 14,
                    width: 100,
                    color: Colors.grey[50],
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  // ------------------- Card Builders -------------------

  Widget _buildLessonCard(dynamic lesson, {bool isLastLesson = false}) {
    final isGroup = lesson['type']?.toString().toLowerCase() == 'group';
    return InkWell(
      onTap: () => showLessonCardOptions(lesson),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8),
          child: Row(
            children: [
              const SizedBox(width: 16),
              InkWell(
                onTap: () {
                  if (isLastLesson) {
                    handleLessonReport(context, lesson);
                  } else if (unschedulableLessons
                      .contains(lesson['lesson_id'].toString())) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text("Reschedule Unavailable"),
                        content:
                            const Text("The reschedule period has passed!"),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text("OK"),
                          ),
                        ],
                      ),
                    );
                  } else if (lesson['type']?.toString().toLowerCase() ==
                      'group') {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text("Scheduling Unavailable"),
                        content: const Text(
                            "To change the schedule of a group lesson, please contact the school."),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text("OK"),
                          )
                        ],
                      ),
                    );
                  } else {
                    showScheduleLessonModal(lesson);
                  }
                },
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(
                    isLastLesson ? Icons.article : Icons.calendar_today,
                    size: 28,
                    color: Colors.orange,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson['students_name'],
                      style: GoogleFonts.lato(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${lesson['date']} at ${lesson['start_time']}',
                      style:
                          GoogleFonts.lato(fontSize: 14, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isGroup ? Icons.groups : Icons.person,
                    size: 20,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      showLessonDetailsModal(lesson);
                    },
                    child: const Icon(Icons.more_vert,
                        size: 28, color: Colors.orange),
                  ),
                ],
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPackCard(dynamic pack) {
    final isGroup = pack['type'].toString().toLowerCase() == 'group';
    return InkWell(
      onTap: () => _showPackCardOptions(pack),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8),
          child: Row(
            children: [
              const SizedBox(width: 16),
              InkWell(
                onTap: () {
                  if (pack['type'].toString().toLowerCase() == 'group') {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text("Scheduling Unavailable"),
                        content: const Text(
                            "To change the schedule of a group lesson, please contact the school."),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text("OK"),
                          )
                        ],
                      ),
                    );
                  } else {
                    _showScheduleMultipleLessonsModal(
                        pack['lessons'], pack["expiration_date"]);
                  }
                },
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: const Icon(Icons.calendar_today,
                      size: 28, color: Colors.orange),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pack['students_name'],
                      style: GoogleFonts.lato(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${pack['lessons_remaining']} lessons remaining\n'
                      '${pack['unscheduled_lessons']} unscheduled lessons\n'
                      '${pack['days_until_expiration']} days until expiration',
                      style:
                          GoogleFonts.lato(fontSize: 14, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isGroup ? Icons.groups : Icons.person,
                    size: 20,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      showPackDetailsModal(pack);
                    },
                    child: const Icon(Icons.more_vert,
                        size: 28, color: Colors.orange),
                  ),
                ],
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------- Stats Builders -------------------

  Widget _buildStatsSkeleton() {
    return Column(
      children: List.generate(3, (index) => _buildLoadingCard()),
    );
  }

  Widget _buildAdminStats() {
    final formattedStart = DateFormat('MMM dd, yyyy').format(startDate);
    final formattedEnd = DateFormat('MMM dd, yyyy').format(endDate);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "$formattedStart - $formattedEnd",
                      style: GoogleFonts.lato(
                          fontSize: 16, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    icon:
                        const Icon(Icons.calendar_today, color: Colors.orange),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        builder: (context) {
                          return Container(
                            height: 400,
                            padding: const EdgeInsets.all(16),
                            child: SfDateRangePicker(
                              view: DateRangePickerView.month,
                              selectionMode: DateRangePickerSelectionMode.range,
                              initialSelectedRange:
                                  PickerDateRange(startDate, endDate),
                              showActionButtons: true,
                              onSubmit: (Object? val) {
                                if (val is PickerDateRange) {
                                  setState(() {
                                    startDate = val.startDate!;
                                    endDate = val.endDate ?? val.startDate!;
                                  });
                                  fetchAdminMetrics();
                                }
                                Navigator.pop(context);
                              },
                              onCancel: () => Navigator.pop(context),
                              monthViewSettings:
                                  const DateRangePickerMonthViewSettings(
                                firstDayOfWeek: 1,
                                showTrailingAndLeadingDates: true,
                              ),
                              headerStyle: const DateRangePickerHeaderStyle(
                                textAlign: TextAlign.center,
                                textStyle: TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildStatCard("Lessons", numberOfBookings.toString(),
                    actionLabel: "View lessons",
                    icon: Icons.menu_book,
                    onAction: null),
              ),
              const SizedBox(width: 8.0),
              Expanded(
                child: _buildStatCard("Students", numberOfStudents.toString(),
                    actionLabel: "View students",
                    icon: Icons.people,
                    onAction: null),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                    "Instructors", numberOfInstructors.toString(),
                    actionLabel: "View instructors",
                    icon: Icons.person_outline,
                    onAction: null),
              ),
              const SizedBox(width: 8.0),
              Expanded(
                child: _buildStatCard(
                    "Revenue", totalRevenue.toStringAsFixed(2),
                    actionLabel: "View payments",
                    icon: Icons.payments_outlined,
                    onAction: null),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInstructorStats() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard("Students", numberOfActiveStudents.toString(),
                actionLabel: "View students",
                icon: Icons.people,
                onAction: null),
          ),
          const SizedBox(width: 8.0),
          Expanded(
            child: _buildStatCard("Balance", currentBalance.toStringAsFixed(2),
                actionLabel: "View payments",
                icon: Icons.payments_outlined,
                onAction: null),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value,
      {String? actionLabel, IconData? icon, VoidCallback? onAction}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 80),
          child: Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.lato(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          value,
                          style: GoogleFonts.lato(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(icon, color: Colors.orange),
                    onPressed: onAction,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (actionLabel != null)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                actionLabel,
                style: GoogleFonts.lato(fontSize: 12, color: Colors.orange),
              ),
            ),
          ),
      ],
    );
  }

  // ------------------- Build Method with Nested Tabs -------------------

  @override
  Widget build(BuildContext context) {
    // Build the Lessons tab.
    Widget lessonsTab = Column(
      children: [
        // NEW: Use the new toggle row (with search and filter icons)
        _buildToggleRowForLessons(),
        Expanded(
          child: _lessonsActiveTabIndex == 0
              ? RefreshIndicator(
                  color: Colors.orange,
                  backgroundColor: Colors.white,
                  onRefresh: () async {
                    await fetchData();
                  },
                  child: SingleChildScrollView(
                    controller: _lessonsScrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: _isLoading
                          ? Column(
                              children: List.generate(
                                  3, (index) => _buildLoadingCard()),
                            )
                          : _filterLessons(upcomingLessons, upcomingSearchQuery,
                                      upcomingFilters)
                                  .isNotEmpty
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: _filterLessons(upcomingLessons,
                                          upcomingSearchQuery, upcomingFilters)
                                      .map((lesson) => _buildLessonCard(lesson))
                                      .toList(),
                                )
                              : const Center(child: Text("No active lessons")),
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: Colors.orange,
                  backgroundColor: Colors.white,
                  onRefresh: () async {
                    await fetchData();
                  },
                  child: SingleChildScrollView(
                    controller: _lessonsScrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: _isLoading
                          ? Column(
                              children: List.generate(
                                  3, (index) => _buildLoadingCard()),
                            )
                          : _filterLessons(lastLessons, lastLessonsSearchQuery,
                                      lastLessonsFilters)
                                  .isNotEmpty
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: _filterLessons(
                                          lastLessons,
                                          lastLessonsSearchQuery,
                                          lastLessonsFilters)
                                      .map((lesson) => _buildLessonCard(lesson,
                                          isLastLesson: true))
                                      .toList(),
                                )
                              : const Center(
                                  child: Text("No historical lessons")),
                    ),
                  ),
                ),
        ),
      ],
    );

    // Build the Packs tab.
    Widget packsTab = Column(
      children: [
        _buildToggleRowForPacks(),
        Expanded(
          child: _packsActiveTabIndex == 0
              ? RefreshIndicator(
                  color: Colors.orange,
                  backgroundColor: Colors.white,
                  onRefresh: () async {
                    await fetchData();
                  },
                  child: SingleChildScrollView(
                    controller: _packsScrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: _isLoading
                          ? Column(
                              children: List.generate(
                                  3, (index) => _buildLoadingCard()),
                            )
                          : _filterPacks(activePacks, activePacksSearchQuery,
                                      activePacksFilters)
                                  .isNotEmpty
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: _filterPacks(
                                          activePacks,
                                          activePacksSearchQuery,
                                          activePacksFilters)
                                      .map((pack) => _buildPackCard(pack))
                                      .toList(),
                                )
                              : const Center(child: Text("No active packs")),
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: Colors.orange,
                  backgroundColor: Colors.white,
                  onRefresh: () async {
                    await fetchData();
                  },
                  child: SingleChildScrollView(
                    controller: _packsScrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: _isLoading
                          ? Column(
                              children: List.generate(
                                  3, (index) => _buildLoadingCard()),
                            )
                          : _filterPacks(lastPacks, lastPacksSearchQuery,
                                      lastPacksFilters)
                                  .isNotEmpty
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: _filterPacks(
                                          lastPacks,
                                          lastPacksSearchQuery,
                                          lastPacksFilters)
                                      .map((pack) => _buildPackCard(pack))
                                      .toList(),
                                )
                              : const Center(
                                  child: Text("No historical packs")),
                    ),
                  ),
                ),
        ),
      ],
    );

    // Stats tab remains unchanged.
    Widget statsTab = (currentRole == "Admin" || currentRole == "Instructor")
        ? _isLoading
            ? _buildStatsSkeleton()
            : (currentRole == "Admin"
                ? _buildAdminStats()
                : _buildInstructorStats())
        : _buildNoStats();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            children: [
              // NEW: Use the animated header
              _buildHeader(),
              Expanded(
                child: DefaultTabController(
                  length: 3,
                  child: Column(
                    children: [
                      TabBar(
                        labelColor: Colors.orange,
                        unselectedLabelColor: Colors.grey,
                        tabs: const [
                          Tab(text: "Lessons"),
                          Tab(text: "Packs"),
                          Tab(text: "Stats"),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: TabBarView(
                          children: [
                            lessonsTab,
                            packsTab,
                            statsTab,
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Simple message for roles with no stats.
  Widget _buildNoStats() {
    return const Center(child: Text("No stats available"));
  }
}
