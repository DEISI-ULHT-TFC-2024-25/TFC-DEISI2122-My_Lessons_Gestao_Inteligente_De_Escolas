import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mylessons_frontend/modals/lesson_details_modal.dart';
import 'package:mylessons_frontend/modals/pack_details_modal.dart';
import 'package:mylessons_frontend/modals/schedule_multiple_lessons_modal.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_service.dart';
import 'lesson_report_page.dart'; // Import our API services

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final storage = const FlutterSecureStorage();
  String firstName = '';
  int notificationsCount = 0;
  String currentRole = '';
  List<dynamic> upcomingLessons = [];
  List<dynamic> lastLessons = [];
  List<dynamic> activePacks = [];
  List<dynamic> lastPacks = [];
  int numberOfActiveStudents = 0;
  double currentBalance = 0.0;
  bool _isLoading = true; // New loading flag

  // Admin Metrics
  int schoolId = 0;
  String schoolName = "";
  int numberOfBookings = 0;
  int numberOfStudents = 0;
  int numberOfInstructors = 0;
  double totalRevenue = 0.0;
  DateTime startDate = DateTime.now();
  DateTime endDate = DateTime.now();

  // Search and filter state for each tab.
  String upcomingSearchQuery = "";
  List<Map<String, String>> upcomingFilters = []; // e.g., lessonType filters
  String lastLessonsSearchQuery = "";
  List<Map<String, String>> lastLessonsFilters = [];
  String activePacksSearchQuery = "";
  List<Map<String, String>> activePacksFilters = [];
  String lastPacksSearchQuery = "";
  List<Map<String, String>> lastPacksFilters = [];

  @override
  void initState() {
    super.initState();
    setInitialDate();
    fetchData();
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

      if (profileResponse.statusCode == 200 && roleResponse.statusCode == 200) {
        final profileData = json.decode(utf8.decode(profileResponse.bodyBytes));
        final roleData = json.decode(utf8.decode(roleResponse.bodyBytes));

        setState(() {
          firstName = profileData['first_name'];
          notificationsCount =
              int.tryParse(profileData['notifications_count'].toString()) ?? 0;
          currentRole = roleData['current_role'];
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

  _showLessonDetailsModal(lesson) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => LessonDetailsModal(
        lesson: lesson,
        currentRole: currentRole,
        fetchData: fetchData,
      ),
    );
  }

  void _showPackDetailsModal(dynamic pack) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => PackDetailsModal(
        pack: pack,
        currentRole: currentRole,
        fetchData: fetchData,
      ),
    );
  }

  void _showScheduleMultipleLessonsModal(List<dynamic> lessons) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => ScheduleMultipleLessonsModal(
        lessons: lessons,
        onScheduleConfirmed: () {
          fetchData();
        },
      ),
    );
  }

  void _showScheduleLessonModal(dynamic lesson) {
    final int lessonId = lesson['id'] ?? lesson['lesson_id'];
    DateTime? selectedDate;
    int increment = 60;
    List<String> availableTimes = [];
    bool isLoading = false;
    bool isScheduling = false;

    final parentContext = context;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext modalContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8.0),
                        child: SfDateRangePicker(
                          view: DateRangePickerView.month,
                          todayHighlightColor: Colors.orange,
                          selectionColor: Colors.orange,
                          rangeSelectionColor: Colors.orange,
                          startRangeSelectionColor: const Color(0xFFFF9800),
                          endRangeSelectionColor: Colors.orange,
                          selectionMode: DateRangePickerSelectionMode.single,
                          showActionButtons: true,
                          initialDisplayDate: DateTime.now(),
                          minDate: DateTime.now(),
                          maxDate: lesson['expiration_date'] != "None"
                              ? DateTime.parse(lesson['expiration_date'])
                              : null,
                          onSelectionChanged:
                              (DateRangePickerSelectionChangedArgs args) {
                            if (args.value is DateTime) {
                              setModalState(() {
                                selectedDate = args.value;
                                availableTimes = [];
                                isLoading = true;
                              });
                              _fetchAvailableTimes(
                                      lessonId, selectedDate!, increment)
                                  .then((times) {
                                setModalState(() {
                                  availableTimes = times;
                                  isLoading = false;
                                });
                              });
                            }
                          },
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
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          children: [
                            const Text("Increment: "),
                            DropdownButton<int>(
                              value: increment,
                              items: [15, 30, 60].map((value) {
                                return DropdownMenuItem<int>(
                                  value: value,
                                  child: Text("$value minutes"),
                                );
                              }).toList(),
                              onChanged: (newValue) {
                                if (newValue != null) {
                                  setModalState(() {
                                    increment = newValue;
                                    if (selectedDate != null) {
                                      isLoading = true;
                                      availableTimes = [];
                                    }
                                  });
                                  if (selectedDate != null) {
                                    _fetchAvailableTimes(
                                            lessonId, selectedDate!, increment)
                                        .then((times) {
                                      setModalState(() {
                                        availableTimes = times;
                                        isLoading = false;
                                      });
                                    });
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      if (isLoading) const CircularProgressIndicator(),
                      if (!isLoading && availableTimes.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              childAspectRatio: 2,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                            itemCount: availableTimes.length,
                            itemBuilder: (context, index) {
                              String timeStr = availableTimes[index];
                              return InkWell(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (BuildContext dialogContext) {
                                      return StatefulBuilder(
                                        builder: (BuildContext dialogContext,
                                            StateSetter setDialogState) {
                                          return AlertDialog(
                                            title: const Text(
                                                "Confirm Reschedule"),
                                            content: SizedBox(
                                              height: 80,
                                              child: Center(
                                                child: isScheduling
                                                    ? const CircularProgressIndicator()
                                                    : Text(
                                                        "Reschedule lesson to ${DateFormat('d MMM yyyy').format(selectedDate!).toLowerCase()} at $timeStr?",
                                                      ),
                                              ),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: isScheduling
                                                    ? null
                                                    : () => Navigator.of(
                                                            dialogContext)
                                                        .pop(),
                                                child: const Text("Cancel"),
                                              ),
                                              TextButton(
                                                onPressed: isScheduling
                                                    ? null
                                                    : () {
                                                        setDialogState(() {
                                                          isScheduling = true;
                                                        });
                                                        _schedulePrivateLesson(
                                                                lessonId,
                                                                selectedDate!,
                                                                timeStr)
                                                            .then(
                                                                (errorMessage) {
                                                          setDialogState(() {
                                                            isScheduling =
                                                                false;
                                                          });
                                                          if (errorMessage ==
                                                              null) {
                                                            Navigator.of(
                                                                    dialogContext)
                                                                .pop();
                                                            Navigator.of(
                                                                    context)
                                                                .pop();
                                                            fetchData();
                                                            ScaffoldMessenger.of(
                                                                    parentContext)
                                                                .showSnackBar(
                                                                    const SnackBar(
                                                                        content:
                                                                            Text("Lesson successfully scheduled")));
                                                          } else {
                                                            Navigator.of(
                                                                    dialogContext)
                                                                .pop();
                                                            ScaffoldMessenger.of(
                                                                    parentContext)
                                                                .showSnackBar(
                                                                    SnackBar(
                                                                        content:
                                                                            Text(errorMessage)));
                                                          }
                                                        });
                                                      },
                                                child: isScheduling
                                                    ? const SizedBox(
                                                        width: 20,
                                                        height: 20,
                                                        child:
                                                            CircularProgressIndicator(
                                                                strokeWidth: 2),
                                                      )
                                                    : const Text("Confirm"),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    },
                                  );
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    timeStr,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ));
          },
        );
      },
    );
  }

  Future<void> _showNotificationsModal() async {
    setState(() {
      notificationsCount = 0; // remove badge
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
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

  // ------------------- Filtering Bar Widget -------------------

  Widget _buildSearchFilterBar({
    required String hint,
    required String query,
    required Function(String) onQueryChanged,
    required VoidCallback onFilterPressed,
    required List<Map<String, String>> filters,
    required VoidCallback onClearFilters,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
          child: TextField(
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
            onChanged: onQueryChanged,
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              TextButton.icon(
                onPressed: onFilterPressed,
                icon: const Icon(Icons.filter_list, color: Colors.black),
                label: const Text('Filters',
                    style: TextStyle(color: Colors.black)),
              ),
              const SizedBox(width: 4),
              ...filters.map((filter) => Padding(
                    padding: const EdgeInsets.only(right: 2.0),
                    child: Chip(
                      label: Text(filter['value']!),
                      deleteIcon: const Icon(Icons.close, color: Colors.black),
                      onDeleted: onClearFilters,
                      backgroundColor: Colors.transparent,
                      side: const BorderSide(color: Colors.transparent),
                      labelStyle: const TextStyle(color: Colors.black),
                    ),
                  )),
            ],
          ),
        ),
      ],
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
                    color: Colors.grey[300],
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  // ------------------- Tab Views -------------------

  @override
  Widget build(BuildContext context) {
    final tabs = const [
      Tab(text: "Next Lessons"),
      Tab(text: "Last Lessons"),
      Tab(text: "Active Packs"),
      Tab(text: "Last Packs"),
      Tab(text: "Stats"),
    ];

    final tabViews = [
      // Upcoming Lessons Tab
      RefreshIndicator(
        onRefresh: () async {
          await fetchData();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildSearchFilterBar(
                hint: "Search lessons...",
                query: upcomingSearchQuery,
                onQueryChanged: (q) {
                  setState(() {
                    upcomingSearchQuery = q;
                  });
                },
                onFilterPressed: () =>
                    _showLessonFilterModal(true, upcomingLessons),
                filters: upcomingFilters,
                onClearFilters: () {
                  setState(() {
                    upcomingFilters.clear();
                  });
                },
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: _isLoading
                    ? Column(
                        children:
                            List.generate(3, (index) => _buildLoadingCard()),
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
                        : const Center(child: Text("No upcoming lessons")),
              ),
            ],
          ),
        ),
      ),
      // Last Lessons Tab
      RefreshIndicator(
        onRefresh: () async {
          await fetchData();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildSearchFilterBar(
                hint: "Search lessons...",
                query: lastLessonsSearchQuery,
                onQueryChanged: (q) {
                  setState(() {
                    lastLessonsSearchQuery = q;
                  });
                },
                onFilterPressed: () =>
                    _showLessonFilterModal(false, lastLessons),
                filters: lastLessonsFilters,
                onClearFilters: () {
                  setState(() {
                    lastLessonsFilters.clear();
                  });
                },
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: _isLoading
                    ? Column(
                        children:
                            List.generate(3, (index) => _buildLoadingCard()),
                      )
                    : _filterLessons(lastLessons, lastLessonsSearchQuery,
                                lastLessonsFilters)
                            .isNotEmpty
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: _filterLessons(lastLessons,
                                    lastLessonsSearchQuery, lastLessonsFilters)
                                .map((lesson) => _buildLessonCard(lesson,
                                    isLastLesson: true))
                                .toList(),
                          )
                        : const Center(child: Text("No last lessons")),
              ),
            ],
          ),
        ),
      ),
      // Active Packs Tab
      RefreshIndicator(
        onRefresh: () async {
          await fetchData();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildSearchFilterBar(
                hint: "Search packs...",
                query: activePacksSearchQuery,
                onQueryChanged: (q) {
                  setState(() {
                    activePacksSearchQuery = q;
                  });
                },
                onFilterPressed: () => _showPackFilterModal(true, activePacks),
                filters: activePacksFilters,
                onClearFilters: () {
                  setState(() {
                    activePacksFilters.clear();
                  });
                },
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: _isLoading
                    ? Column(
                        children:
                            List.generate(3, (index) => _buildLoadingCard()),
                      )
                    : _filterPacks(activePacks, activePacksSearchQuery,
                                activePacksFilters)
                            .isNotEmpty
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: _filterPacks(activePacks,
                                    activePacksSearchQuery, activePacksFilters)
                                .map((pack) => _buildPackCard(pack))
                                .toList(),
                          )
                        : const Center(child: Text("No active packs")),
              ),
            ],
          ),
        ),
      ),
      // Last Packs Tab
      RefreshIndicator(
        onRefresh: () async {
          await fetchData();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildSearchFilterBar(
                hint: "Search packs...",
                query: lastPacksSearchQuery,
                onQueryChanged: (q) {
                  setState(() {
                    lastPacksSearchQuery = q;
                  });
                },
                onFilterPressed: () => _showPackFilterModal(false, lastPacks),
                filters: lastPacksFilters,
                onClearFilters: () {
                  setState(() {
                    lastPacksFilters.clear();
                  });
                },
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: _isLoading
                    ? Column(
                        children:
                            List.generate(3, (index) => _buildLoadingCard()),
                      )
                    : _filterPacks(lastPacks, lastPacksSearchQuery,
                                lastPacksFilters)
                            .isNotEmpty
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: _filterPacks(lastPacks,
                                    lastPacksSearchQuery, lastPacksFilters)
                                .map((pack) => _buildPackCard(pack))
                                .toList(),
                          )
                        : const Center(child: Text("No last packs")),
              ),
            ],
          ),
        ),
      ),
      // Stats Tab remains as-is.
      currentRole == "Admin" || currentRole == "Instructor"
          ? _isLoading
              ? _buildStatsSkeleton()
              : (currentRole == "Admin"
                  ? _buildAdminStats()
                  : _buildInstructorStats())
          : _buildNoStats(),
    ];

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: DefaultTabController(
                  length: tabs.length,
                  child: Column(
                    children: [
                      TabBar(
                        labelColor: Colors.orange,
                        unselectedLabelColor: Colors.grey,
                        isScrollable: true,
                        tabs: tabs,
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: TabBarView(
                          children: tabViews,
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

  // ------------------- Card Builders -------------------

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

  void _showLessonFilterModal(bool isUpcoming, List<dynamic> lessons) {
    const options = ['Group', 'Private'];
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

  void _showPackFilterModal(bool isActive, List<dynamic> packs) {
    const options = ['Group', 'Private'];
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

  Widget _buildHeader() {
    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 150, height: 18, color: Colors.grey[300]),
                const Spacer(),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(width: 100, height: 28, color: Colors.grey[300]),
            const SizedBox(height: 20),
          ],
        ),
      );
    } else {
      String welcomeText = currentRole == "Admin"
          ? 'Welcome back to $schoolName,'
          : 'Welcome back,';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    welcomeText,
                    style: GoogleFonts.lato(fontSize: 18, color: Colors.grey),
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _showNotificationsModal,
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Icon(Icons.notifications_none,
                            size: 28, color: Colors.orange),
                        if (notificationsCount > 0)
                          Positioned(
                            right: 10,
                            top: 10,
                            child: CircleAvatar(
                                radius: 8, backgroundColor: Colors.red),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Text(
              firstName,
              style: GoogleFonts.lato(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey),
            ),
            const SizedBox(height: 20),
          ],
        ),
      );
    }
  }

  Widget _buildLessonCard(dynamic lesson, {bool isLastLesson = false}) {
    final isGroup = lesson['type']?.toString().toLowerCase() == 'group';
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8),
        child: Row(
          children: [
            const SizedBox(width: 16),
            SizedBox(
              width: 40,
              height: 40,
              child: IconButton(
                icon: Icon(
                  isLastLesson ? Icons.article : Icons.calendar_today,
                  size: 28,
                  color: Colors.orange,
                ),
                onPressed: () {
                  if (isLastLesson) {
                    if (currentRole == "Parent") {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              LessonReportPage(lesson: lesson, mode: 'view'),
                        ),
                      );
                    } else if (currentRole == "Instructor" ||
                        currentRole == "Admin") {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              LessonReportPage(lesson: lesson, mode: 'edit'),
                        ),
                      );
                    }
                  } else {
                    if (isGroup) {
                      showDialog(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            title: const Text("Scheduling Unavailable"),
                            content: const Text(
                              "To change the schedule of a group lesson, please contact the school.",
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text("OK"),
                              )
                            ],
                          );
                        },
                      );
                    } else {
                      _showScheduleLessonModal(lesson);
                    }
                  }
                },
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
                IconButton(
                  icon: const Icon(Icons.more_vert,
                      size: 28, color: Colors.orange),
                  onPressed: () {
                    _showLessonDetailsModal(lesson);
                  },
                ),
              ],
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildPackCard(dynamic pack) {
    final isGroup = pack['type'].toString().toLowerCase() == 'group';
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8),
        child: Row(
          children: [
            const SizedBox(width: 16),
            SizedBox(
              width: 40,
              height: 40,
              child: IconButton(
                icon: const Icon(Icons.calendar_today,
                    size: 28, color: Colors.orange),
                onPressed: () {
                  if (isGroup) {
                    showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: const Text("Scheduling Unavailable"),
                          content: const Text(
                            "To change the schedule of a group lesson, please contact the school.",
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text("OK"),
                            )
                          ],
                        );
                      },
                    );
                  } else {
                    _showScheduleMultipleLessonsModal(pack['lessons']);
                  }
                },
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
                IconButton(
                  icon: const Icon(Icons.more_vert,
                      size: 28, color: Colors.orange),
                  onPressed: () {
                    _showPackDetailsModal(pack,);
                  },
                ),
              ],
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

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
}
