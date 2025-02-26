import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:mylessons_frontend/collapsibleSection.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

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
  int numberOfActiveStudents = 0;
  double currentBalance = 0.0;

  // Admin Metrics
  int schoolId = 0;
  String schoolName = "";
  int numberOfBookings = 0;
  int numberOfStudents = 0;
  int numberOfInstructors = 0;
  double totalRevenue = 0.0;
  DateTime startDate = DateTime.now();
  DateTime endDate = DateTime.now();

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

  Future<void> fetchData() async {
    try {
      final headers = await getAuthHeaders();
      final profileResponse = await http.get(
        Uri.parse('http://127.0.0.1:8000/api/users/profile/'),
        headers: headers,
      );
      final roleResponse = await http.get(
        Uri.parse('http://127.0.0.1:8000/api/users/current_role/'),
        headers: headers,
      );
      final schoolResponse = await http.get(
        Uri.parse('http://127.0.0.1:8000/api/users/current_school_id/'),
        headers: headers,
      );

      if (profileResponse.statusCode == 200 && roleResponse.statusCode == 200) {
        final profileData =
            json.decode(utf8.decode(profileResponse.bodyBytes));
        final roleData = json.decode(utf8.decode(roleResponse.bodyBytes));

        setState(() {
          firstName = profileData['first_name'];
          notificationsCount =
              int.tryParse(profileData['notifications_count'].toString()) ?? 0;
          currentRole = roleData['current_role'];
          schoolId = schoolResponse.statusCode == 200
              ? int.tryParse(json.decode(utf8.decode(schoolResponse.bodyBytes))[
                          'current_school_id']
                      .toString()) ??
                  0
              : 0;
          schoolName = schoolResponse.statusCode == 200
              ? json
                  .decode(utf8.decode(schoolResponse.bodyBytes))['current_school_name']
                  .toString()
              : "";
        });
      }

      if (currentRole == "Parent" ||
          currentRole == "Instructor" ||
          currentRole == "Admin") {
        final lessonsResponse = await http.get(
          Uri.parse('http://127.0.0.1:8000/api/lessons/upcoming_lessons/'),
          headers: headers,
        );
        final activePacksResponse = await http.get(
          Uri.parse('http://127.0.0.1:8000/api/lessons/active_packs/'),
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
      }

      if (currentRole == "Parent") {
        final lastLessonsResponse = await http.get(
          Uri.parse('http://127.0.0.1:8000/api/lessons/last_lessons/'),
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
          Uri.parse('http://127.0.0.1:8000/api/users/number_of_active_students/'),
          headers: headers,
        );
        final balanceResponse = await http.get(
          Uri.parse('http://127.0.0.1:8000/api/users/current_balance/'),
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
  }

  Future<void> fetchAdminMetrics() async {
    final headers = await getAuthHeaders();
    final formattedStart = DateFormat('yyyy-MM-dd').format(startDate);
    final formattedEnd = DateFormat('yyyy-MM-dd').format(endDate);

    final bookingsResponse = await http.get(
      Uri.parse(
          'http://127.0.0.1:8000/api/schools/number_of_booked_lessons/$schoolId/$formattedStart/$formattedEnd/'),
      headers: headers,
    );
    final studentsResponse = await http.get(
      Uri.parse(
          'http://127.0.0.1:8000/api/schools/number_of_students/$schoolId/$formattedStart/$formattedEnd/'),
      headers: headers,
    );
    final instructorsResponse = await http.get(
      Uri.parse(
          'http://127.0.0.1:8000/api/schools/number_of_instructors/$schoolId/$formattedStart/$formattedEnd/'),
      headers: headers,
    );
    final revenueResponse = await http.get(
      Uri.parse(
          'http://127.0.0.1:8000/api/schools/school-revenue/$schoolId/$formattedStart/$formattedEnd/'),
      headers: headers,
    );

    setState(() {
      numberOfBookings = bookingsResponse.statusCode == 200
          ? int.tryParse(json
                  .decode(utf8.decode(bookingsResponse.bodyBytes))['number_of_lessons_booked']
                  .toString()) ??
              0
          : 0;
      numberOfStudents = studentsResponse.statusCode == 200
          ? int.tryParse(json
                  .decode(utf8.decode(studentsResponse.bodyBytes))['total_students']
                  .toString()) ??
              0
          : 0;
      numberOfInstructors = instructorsResponse.statusCode == 200
          ? int.tryParse(json
                  .decode(utf8.decode(instructorsResponse.bodyBytes))['total_instructors']
                  .toString()) ??
              0
          : 0;
      totalRevenue = revenueResponse.statusCode == 200
          ? double.tryParse(json
                  .decode(utf8.decode(revenueResponse.bodyBytes))['total_revenue']
                  .toString()) ??
              0.0
          : 0.0;
    });
  }

  // NEW: Function to fetch available times for a given lesson/date/increment.
  Future<List<String>> _fetchAvailableTimes(
      int lessonId, DateTime date, int increment) async {
    final headers = await getAuthHeaders();
    final response = await http.post(
      Uri.parse('http://127.0.0.1:8000/api/lessons/available_lesson_times/'),
      headers: headers,
      body: jsonEncode({
        "lesson_id": lessonId,
        "date": DateFormat('yyyy-MM-dd').format(date),
        "increment": increment,
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return List<String>.from(data['available_times']);
    } else {
      return [];
    }
  }

  Future<bool> _canStillReschedule(int lessonId) async {
    final headers = await getAuthHeaders();
    final response = await http.get(
      Uri.parse('http://127.0.0.1:8000/api/lessons/can_still_reschedule/$lessonId/'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      // Assuming the API returns a JSON boolean (true/false)
      return data;
    } else {
      // In case of error, assume scheduling is not allowed.
      return false;
    }
  }


  Future<String?> _schedulePrivateLesson(int lessonId, DateTime newDate, String newTime) async {
    final headers = await getAuthHeaders();
    final newDateStr = DateFormat('yyyy-MM-dd').format(newDate);
    final payload = {
      "lesson_id": lessonId,
      "new_date": newDateStr,
      "new_time": newTime,
    };
    print("Scheduling payload: $payload");
    
    final response = await http.post(
      Uri.parse('http://127.0.0.1:8000/api/lessons/schedule_private_lesson/'),
      headers: headers,
      body: jsonEncode(payload),
    );
    print("Response: ${response.statusCode} ${response.body}");
    
    if (response.statusCode == 200) {
      return null;
    } else {
      // Extract the error message from the response.
      final data = jsonDecode(response.body);
      return data['error'] ?? "Failed to schedule lesson";
    }
  }

  void _showScheduleLessonModal(dynamic lesson) {
    final int lessonId = lesson['id'] ?? lesson['lesson_id'];

    DateTime? selectedDate;
    int increment = 60;
    List<String> availableTimes = [];
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Calendar Picker with past dates disabled.
                    Container(
                      padding: const EdgeInsets.all(8.0),
                      child: SfDateRangePicker(
                        view: DateRangePickerView.month,
                        selectionMode: DateRangePickerSelectionMode.single,
                        initialDisplayDate: DateTime.now(),
                        minDate: DateTime.now(),
                        maxDate: lesson['expiration_date'] != "None" 
                            ? DateTime.parse(lesson['expiration_date']) 
                            : null,
                        onSelectionChanged: (DateRangePickerSelectionChangedArgs args) {
                          if (args.value is DateTime) {
                            setModalState(() {
                              selectedDate = args.value;
                              availableTimes = [];
                              isLoading = true;
                            });
                            _fetchAvailableTimes(lessonId, selectedDate!, increment)
                                .then((times) {
                              setModalState(() {
                                availableTimes = times;
                                isLoading = false;
                              });
                            });
                          }
                        },
                        monthViewSettings: const DateRangePickerMonthViewSettings(
                          firstDayOfWeek: 1,
                          showTrailingAndLeadingDates: true,
                        ),
                        headerStyle: const DateRangePickerHeaderStyle(
                          textAlign: TextAlign.center,
                          textStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    // Dropdown to change increment value.
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
                                  _fetchAvailableTimes(lessonId, selectedDate!, increment)
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
                    // Loading indicator.
                    if (isLoading) const CircularProgressIndicator(),
                    // Grid view of available times.
                    if (!isLoading && availableTimes.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      title: const Text("Confirm Reschedule"),
                                      content: Text(
                                        "Reschedule lesson to ${DateFormat('d MMM yyyy').format(selectedDate!).toLowerCase()} at $timeStr?",
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(context).pop(),
                                          child: const Text("Cancel"),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.of(context).pop(); // Dismiss confirmation.
                                            _schedulePrivateLesson(lessonId, selectedDate!, timeStr)
                                                .then((errorMessage) {
                                              if (errorMessage == null) {
                                                Navigator.of(context).pop(); // Dismiss modal.
                                                fetchData(); // Refresh upcoming lessons.
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(
                                                    content: Text("Lesson successfully rescheduled"),
                                                  ),
                                                );
                                              } else {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text(errorMessage),
                                                  ),
                                                );
                                              }
                                            });
                                          },
                                          child: const Text("Confirm"),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  timeStr,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Header widget.
  Widget _buildHeader() {
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
              Text(
                welcomeText,
                style: GoogleFonts.lato(fontSize: 18, color: Colors.black54),
              ),
              Stack(
                children: [
                  const Icon(Icons.notifications_none, size: 28),
                  if (notificationsCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: CircleAvatar(
                        radius: 8,
                        backgroundColor: Colors.red,
                        child: Text(
                          '$notificationsCount',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    )
                ],
              ),
            ],
          ),
          Text(
            firstName,
            style: GoogleFonts.lato(
                fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // Build Admin UI.
  Widget _buildAdmin() {
    final formattedStart = DateFormat('MMM dd, yyyy').format(startDate);
    final formattedEnd = DateFormat('MMM dd, yyyy').format(endDate);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CollapsibleSection(
          title: 'Stats',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12.0, vertical: 8.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
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
                        icon: const Icon(Icons.calendar_today),
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            builder: (context) {
                              return Container(
                                height: 400,
                                padding: const EdgeInsets.all(16),
                                child: SfDateRangePicker(
                                  view: DateRangePickerView.month,
                                  selectionMode:
                                      DateRangePickerSelectionMode.range,
                                  initialSelectedRange:
                                      PickerDateRange(startDate, endDate),
                                  showActionButtons: true,
                                  onSubmit: (Object? val) {
                                    if (val is PickerDateRange) {
                                      setState(() {
                                        startDate = val.startDate!;
                                        endDate =
                                            val.endDate ?? val.startDate!;
                                      });
                                      fetchAdminMetrics();
                                    }
                                    Navigator.pop(context);
                                  },
                                  onCancel: () {
                                    Navigator.pop(context);
                                  },
                                  monthViewSettings:
                                      const DateRangePickerMonthViewSettings(
                                    firstDayOfWeek: 1,
                                    showTrailingAndLeadingDates: true,
                                  ),
                                  headerStyle: const DateRangePickerHeaderStyle(
                                    textAlign: TextAlign.center,
                                    textStyle: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold),
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
                    child: _buildStatCard("Booked Lessons",
                        numberOfBookings.toString()),
                  ),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: _buildStatCard(
                        "Active Students", numberOfStudents.toString()),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard("Active Instructors",
                        numberOfInstructors.toString()),
                  ),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: _buildStatCard("Total Revenue",
                        "€${totalRevenue.toStringAsFixed(2)}"),
                  ),
                ],
              ),
            ],
          ),
        ),
        CollapsibleSection(
          title: 'Upcoming Lessons',
          child: Column(
            children: upcomingLessons
                .map<Widget>((lesson) => _buildLessonCard(lesson))
                .toList(),
          ),
        ),
        CollapsibleSection(
          title: 'Active Packs',
          child: Column(
            children: activePacks
                .map<Widget>((pack) => _buildPackCard(pack))
                .toList(),
          ),
        ),
      ],
    );
  }

  // Build Instructor UI.
  Widget _buildInstructor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CollapsibleSection(
          title: 'Stats',
          child: Row(
            children: [
              Expanded(
                child:
                    _buildStatCard("Active Students", numberOfActiveStudents.toString()),
              ),
              const SizedBox(width: 8.0),
              Expanded(
                child: _buildStatCard(
                    "Current Balance", "€${currentBalance.toStringAsFixed(2)}"),
              ),
            ],
          ),
        ),
        CollapsibleSection(
          title: 'Upcoming Lessons',
          child: Column(
            children: upcomingLessons
                .map<Widget>((lesson) => _buildLessonCard(lesson))
                .toList(),
          ),
        ),
        CollapsibleSection(
          title: 'Active Packs',
          child: Column(
            children: activePacks
                .map<Widget>((pack) => _buildPackCard(pack))
                .toList(),
          ),
        ),
      ],
    );
  }

  // Parent UI
  Widget _buildParent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CollapsibleSection(
          title: 'Upcoming Lessons',
          child: Column(
            children: upcomingLessons
                .map<Widget>((lesson) => _buildLessonCard(lesson))
                .toList(),
          ),
        ),
        CollapsibleSection(
          title: 'Last Lessons',
          child: Column(
            // Pass isLastLesson: true so that the calendar icon is omitted.
            children: lastLessons
                .map<Widget>((lesson) => _buildLessonCard(lesson, isLastLesson: true))
                .toList(),
          ),
        ),
        CollapsibleSection(
          title: 'Active Packs',
          child: Column(
            children: activePacks.map<Widget>((pack) => _buildPackCard(pack)).toList(),
          ),
        ),
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                if (currentRole == "Admin")
                  _buildAdmin()
                else if (currentRole == "Instructor")
                  _buildInstructor()
                else if (currentRole == "Parent")
                  _buildParent(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLessonCard(dynamic lesson, {bool isLastLesson = false}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        // For last lessons, no calendar icon is shown.
        leading: isLastLesson
            ? null
            : IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: () async {
                  final int lessonId = lesson['id'] ?? lesson['lesson_id'];
                  if (lesson['type'] != "private") {
                    // Group lesson: show warning dialog.
                    showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: const Text("Cannot Reschedule Group Lesson"),
                          content: const Text(
                            "To reschedule a group lesson, please contact the school or instructor.",
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text("OK"),
                            ),
                          ],
                        );
                      },
                    );
                  } else {
                    // For private lessons, first check if rescheduling is still allowed.
                    bool canReschedule = await _canStillReschedule(lessonId);
                    if (!canReschedule) {
                      showDialog(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            title: const Text("Cannot Reschedule"),
                            content: const Text(
                              "The reschedule period has already passed. Please contact the school or instructor.",
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text("OK"),
                              ),
                            ],
                          );
                        },
                      );
                    } else {
                      // If allowed, show the scheduling modal.
                      _showScheduleLessonModal(lesson);
                    }
                  }
                },
              ),
        title: Text(
          lesson['students_name'],
          style: GoogleFonts.lato(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${lesson['date']} at ${lesson['start_time']}',
          style: GoogleFonts.lato(fontSize: 14, color: Colors.black54),
        ),
        trailing: const Icon(Icons.more_vert, color: Colors.black54),
      ),
    );
  }



  Widget _buildPackCard(dynamic pack) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: IconButton(
          icon: const Icon(Icons.calendar_today),
          onPressed: () {
            // Add similar scheduling logic for packs if needed.
          },
        ),
        title: Text(
          pack['students_name'],
          style: GoogleFonts.lato(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${pack['lessons_remaining']} lessons remaining\n${pack['unscheduled_lessons']} unscheduled lessons\n${pack['days_until_expiration']} days until expiration',
          style: GoogleFonts.lato(fontSize: 14, color: Colors.black54),
        ),
        trailing: const Icon(Icons.more_vert, color: Colors.black54),
      ),
    );
  }

  Widget _buildStatCard(String title, String value) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(value, style: GoogleFonts.lato(fontSize: 20, color: Colors.black)),
          ],
        ),
      ),
    );
  }
}
