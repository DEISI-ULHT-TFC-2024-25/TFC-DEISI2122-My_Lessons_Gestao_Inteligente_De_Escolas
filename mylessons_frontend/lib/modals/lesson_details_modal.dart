// File: lib/modals/lesson_details_modal.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:mylessons_frontend/modals/instructors_modal.dart';
import '../services/api_service.dart';
import 'students_modal.dart';
import 'subject_modal.dart'; // Make sure this file exports SubjectModal
import 'location_modal.dart'; // Make sure this file exports LocationModal
import 'package:mylessons_frontend/pages/progress_hub_page.dart'; // NEW: Import the Progress Hub Page
import 'package:mylessons_frontend/modals/student_selection_modal.dart'; // NEW: Import the Student Selection Modal

class LessonDetailsModal extends StatefulWidget {
  final dynamic lesson;
  final String currentRole;
  final Future<void> Function()
      fetchData; // Callback to refresh the whole home page

  const LessonDetailsModal({
    super.key,
    required this.lesson,
    required this.currentRole,
    required this.fetchData,
  });

  @override
  _LessonDetailsModalState createState() => _LessonDetailsModalState();
}

class _LessonDetailsModalState extends State<LessonDetailsModal> {
  late Future<Map<String, dynamic>?> _lessonDetailsFuture;
  late final int lessonId;

  @override
  void initState() {
    super.initState();
    lessonId = widget.lesson['id'] ?? widget.lesson['lesson_id'];
    _refreshLessonDetails();
  }

  /// Refresh the modal's lesson details.
  void _refreshLessonDetails() {
    setState(() {
      _lessonDetailsFuture = fetchLessonDetails(lessonId);
    });
  }

  Future<Map<String, dynamic>?> toggleLessonCompletion(int lessonId) async {
    final url = Uri.parse("$baseUrl/api/lessons/toggle_lesson_completion/");
    final response = await http.post(
      url,
      headers: await getAuthHeaders(),
      body: jsonEncode({'lesson_id': lessonId}),
    );
    final decodedResponse = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200) {
      return decodedResponse;
    } else {
      return {
        "error": "Failed to toggle completion",
        "details": decodedResponse
      };
    }
  }

  // Helper method to format keys.
  String _formatKey(String key) {
    return key.replaceAll('_', ' ').toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _lessonDetailsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 300,
            padding: const EdgeInsets.all(16),
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData || snapshot.data == null) {
          return Container(
            height: 300,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  "Lesson Details",
                  style: GoogleFonts.lato(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text("Could not fetch lesson details."),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Close", selectionColor: Colors.orange),
                  ),
                ),
              ],
            ),
          );
        }
        final details = snapshot.data!;

        // Compute merged/simplified values.
        final date = details['date'] ?? '';
        final startTime = details['start_time'] ?? '';
        final endTime = details['end_time'] ?? '';
        final time = startTime.isNotEmpty && endTime.isNotEmpty
            ? '$startTime - $endTime'
            : (startTime.isNotEmpty ? startTime : endTime);
        final lessonNum = details['lesson_number']?.toString() ?? '';
        final numLessons = details['number_of_lessons']?.toString() ?? '';
        final lessonValue = (lessonNum.isNotEmpty && numLessons.isNotEmpty)
            ? '$lessonNum / $numLessons'
            : (lessonNum.isNotEmpty ? lessonNum : numLessons);
        final extras = details['extras'] ?? '';
        final students = details['students_name'] ?? '';
        final type = details['type'] ?? '';
        final instructors = details['instructors_name'] ?? '';
        final school = details['school_name'] ?? '';
        final location = details['location_name'] ?? '';
        final activity = details['subject'] ?? '';
        final isDone = details['is_done'];
        final lesson = details;

        List<Map<String, dynamic>> gridItems = [];
        Map<String, IconData> leftIconMapping = {};
        List<String> labelsWithAction = [];
        Map<String, IconData> actionIconMapping = {};
        Map<String, String> actionNoteMapping = {};

        if (widget.currentRole == "Parent") {
          gridItems = [
            {'label': 'Date', 'value': date},
            {'label': 'Time', 'value': time},
            {'label': 'Lesson', 'value': lessonValue},
            {'label': 'Subject', 'value': activity},
            {'label': 'Type', 'value': type},
            {'label': 'Students', 'value': students},
            {'label': 'Extras', 'value': extras},
            {'label': 'Instructors', 'value': instructors},
            {'label': 'School', 'value': school},
            {'label': 'Location', 'value': location},
          ];

          leftIconMapping = {
            'Date': Icons.calendar_today,
            'Time': Icons.access_time,
            'Lesson': Icons.confirmation_number,
            'Students': Icons.people,
            'Type': Icons.groups,
            'Subject': Icons.menu_book,
            'Extras': Icons.star,
            'Instructors': Icons.person_outline,
            'School': Icons.school,
            'Location': Icons.location_on,
          };

          labelsWithAction = ['Extras', 'Instructors', 'School', 'Location'];
          actionIconMapping = {
            'Extras': Icons.edit,
            'Instructors': Icons.phone,
            'School': Icons.phone,
            'Location': Icons.directions,
          };
          actionNoteMapping = {
            'Extras': 'Update extras',
            'Instructors': 'Contact instructor',
            'School': 'Contact school',
            'Location': 'Get directions',
          };
        } else if (widget.currentRole == "Instructor" ||
            widget.currentRole == "Admin") {
          gridItems = [
            {'label': 'Date', 'value': date},
            {'label': 'Time', 'value': time},
            {'label': 'Is Done', 'value': isDone},
            {'label': 'Lesson', 'value': lessonValue},
            {'label': 'Subject', 'value': activity},
            {'label': 'Type', 'value': type},
            {'label': 'Students', 'value': students},
            {'label': 'Extras', 'value': extras},
            {'label': 'Instructors', 'value': instructors},
            {'label': 'School', 'value': school},
            {'label': 'Location', 'value': location},
          ];

          leftIconMapping = {
            'Date': Icons.calendar_today,
            'Time': Icons.access_time,
            'Lesson': Icons.confirmation_number,
            'Is Done': Icons.check_box,
            'Students': Icons.people,
            'Type': Icons.groups,
            'Subject': Icons.menu_book,
            'Extras': Icons.star,
            'Instructors': Icons.person_outline,
            'School': Icons.school,
            'Location': Icons.location_on,
          };

          labelsWithAction = [
            'Is Done',
            'Students',
            'Subject',
            'Extras',
            'Instructors',
            'School',
            'Location'
          ];
          actionIconMapping = {
            'Date': Icons.edit,
            'Time': Icons.edit,
            'Is Done': Icons.check_circle,
            'Students': Icons.edit,
            'Subject': Icons.edit,
            'Extras': Icons.edit,
            'Instructors': Icons.edit,
            'School': Icons.phone,
            'Location': Icons.edit,
          };

          actionNoteMapping = {
            'Date': 'Edit date',
            'Time': 'Edit time',
            'Is Done': 'Toggle completion',
            'Students': 'Edit students',
            'Subject': 'Edit subject',
            'Extras': 'Update extras',
            'Instructors': 'Edit Instructors',
            'School': 'Contact school',
            'Location': 'Edit Location',
          };
        }

        final nonActionItems = gridItems
            .where((item) => !labelsWithAction.contains(item['label']))
            .toList();
        final actionItems = gridItems
            .where((item) => labelsWithAction.contains(item['label']))
            .toList();
        final combinedItems = [...nonActionItems, ...actionItems];

        return Container(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Lesson Details",
                  style: GoogleFonts.lato(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    double spacing = 8.0;
                    // Two cards per row.
                    double itemWidth = (constraints.maxWidth - spacing) / 2;
                    Widget buildCard(Map<String, dynamic> item,
                        {bool withAction = false}) {
                      final String label = item['label'];
                      final String value = item['value'].toString();
                      return SizedBox(
                        width: itemWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 80),
                              child: Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Icon(
                                        leftIconMapping[label] ??
                                            Icons.info_outline,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              label,
                                              style: GoogleFonts.lato(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14),
                                            ),
                                            Text(
                                              value,
                                              style: GoogleFonts.lato(
                                                  fontSize: 12),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (withAction)
                                        IconButton(
                                          icon: Icon(
                                            actionIconMapping[label] ??
                                                Icons.arrow_forward,
                                            color: Colors.orange,
                                          ),
                                          onPressed: () async {
                                            if (label == "Is Done") {
                                              final result =
                                                  await toggleLessonCompletion(
                                                      lessonId);
                                              if (result != null &&
                                                  result
                                                      .containsKey("status")) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                      content: Text(
                                                          result["status"])),
                                                );
                                                // Refresh the entire home page...
                                                await widget.fetchData();
                                                // ...and refresh the modal's data.
                                                _refreshLessonDetails();
                                              } else {
                                                showDialog(
                                                  context: context,
                                                  builder: (context) {
                                                    return AlertDialog(
                                                      content: const Text(
                                                          "To complete a lesson make sure the schedule has passed"),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                  context),
                                                          child:
                                                              const Text("OK"),
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                );
                                              }
                                            } else if (label == "Subject" &&
                                                widget.currentRole !=
                                                    "Parent") {
                                              bool? updated =
                                                  await showModalBottomSheet<
                                                      bool>(
                                                context: context,
                                                isScrollControlled: true,
                                                shape:
                                                    const RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.vertical(
                                                          top: Radius.circular(
                                                              16)),
                                                ),
                                                builder: (context) =>
                                                    SubjectModal(
                                                        lessonId: lessonId),
                                              );
                                              if (updated == true) {
                                                await widget.fetchData();
                                                _refreshLessonDetails();
                                              } else {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  const SnackBar(
                                                      content: Text("Error")),
                                                );
                                              }
                                            } else if (label == "Location" &&
                                                widget.currentRole !=
                                                    "Parent") {
                                              bool? updated =
                                                  await showModalBottomSheet<
                                                      bool>(
                                                context: context,
                                                isScrollControlled: true,
                                                shape:
                                                    const RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.vertical(
                                                          top: Radius.circular(
                                                              16)),
                                                ),
                                                builder: (context) =>
                                                    LocationModal(
                                                        lessonId: lessonId),
                                              );
                                              if (updated == true) {
                                                await widget.fetchData();
                                                _refreshLessonDetails();
                                              }
                                            } else if (label == "Students" &&
                                                widget.currentRole !=
                                                    "Parent") {
                                              bool? updated =
                                                  await showModalBottomSheet<
                                                      bool>(
                                                context: context,
                                                isScrollControlled: true,
                                                shape:
                                                    const RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.vertical(
                                                          top: Radius.circular(
                                                              16)),
                                                ),
                                                builder: (context) =>
                                                    StudentsModal(
                                                        lessonId: lessonId),
                                              );
                                              if (updated == true) {
                                                await widget.fetchData();
                                                _refreshLessonDetails();
                                              }
                                            } else if (label == "Instructors" &&
                                                widget.currentRole !=
                                                    "Parent") {
                                              bool? updated =
                                                  await showModalBottomSheet<
                                                      bool>(
                                                context: context,
                                                isScrollControlled: true,
                                                shape:
                                                    const RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.vertical(
                                                          top: Radius.circular(
                                                              16)),
                                                ),
                                                builder: (context) =>
                                                    InstructorsModal(
                                                        lessonId: lessonId),
                                              );
                                              if (updated == true) {
                                                await widget.fetchData();
                                                _refreshLessonDetails();
                                              }
                                            }
                                          },
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (withAction)
                              Align(
                                alignment: Alignment.bottomRight,
                                child: Text(
                                  actionNoteMapping[label] ?? "",
                                  style: GoogleFonts.lato(
                                      fontSize: 12, color: Colors.orange),
                                ),
                              ),
                          ],
                        ),
                      );
                    }

                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: combinedItems.map((item) {
                        final bool withAction =
                            labelsWithAction.contains(item['label']);
                        return buildCard(item, withAction: withAction);
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 16),
                // NEW: Manage Progress Card with new student selection modal
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.dashboard, color: Colors.orange),
                    title: Text(
                      "Manage Progress",
                      style: GoogleFonts.lato(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text("Update progress, skills, and goals"),
                    onTap: () async {
                      // Retrieve a list of students from the lesson details.
                      // Here we assume details has a field 'students_list'.
                      List<dynamic> studentsList =
                          details['students_list'] ?? [];
                      if (studentsList.isEmpty) {
                        // If no proper list, fallback to use the 'students' string.
                        studentsList = [
                          {'id': 1, 'name': students.toString()}
                        ];
                      }
                      dynamic selectedStudent = await showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (context) => StudentsModal(
                          lessonId: widget.lesson["lesson_id"],
                          manageProgress: true,
                        ),
                      );
                      if (selectedStudent != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProgressHubPage(
                              student: selectedStudent,
                              lesson: lesson,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Close", selectionColor: Colors.orange),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
