import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:mylessons_frontend/modals/lesson_details_modal.dart';
import 'package:mylessons_frontend/modals/schedule_lesson_modal.dart';
import 'package:mylessons_frontend/providers/home_page_provider.dart';
import 'package:mylessons_frontend/services/api_service.dart';
import 'package:mylessons_frontend/widgets/handle_lesson_report.dart';
import 'package:provider/provider.dart';
// Import your modals (replace these with your actual modal implementations)
import '../modals/lessons_modal.dart';

class LessonModalProvider with ChangeNotifier {
  /// Opens the lesson details modal using the provided BuildContext.
  void showLessonDetailsModal(BuildContext context, dynamic lesson) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => LessonDetailsPage(lesson: lesson)),
    );
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

  Future<List<String>> _fetchAvailableTimes(
          int lessonId, DateTime date, int increment) =>
      fetchAvailableTimes(lessonId, date, increment);

  Future<String?> _schedulePrivateLesson(
          int lessonId, DateTime newDate, String newTime) =>
      schedulePrivateLesson(lessonId, newDate, newTime);

  /// Opens the schedule lesson modal.
  Future<void> showScheduleLessonModal(
      BuildContext context, dynamic lesson) async {
    final int lessonId = lesson['id'] ?? lesson['lesson_id'];
    final homeProvider = Provider.of<HomePageProvider>(context, listen: false);
    final currentRole = homeProvider.currentRole;
    // Ensure that fetchData is invoked as a function.
    final Function fetchData = homeProvider.fetchData;
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

  /// Shows available options for a lesson in a modal sheet.
  void showLessonCardOptions(BuildContext context, dynamic lesson) {
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
                    showScheduleLessonModal(context, lesson);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.more_vert, color: Colors.orange),
                title: const Text("View Details"),
                onTap: () {
                  Navigator.pop(context);
                  showLessonDetailsModal(context, lesson);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Builds and returns a card widget representing a lesson.
  Widget buildLessonCard(
      BuildContext context, dynamic lesson, dynamic unschedulableLessons,
      {bool isLastLesson = false}) {
    final bool isGroup = lesson['type']?.toString().toLowerCase() == 'group';

    // Parse the lesson date string. Make sure the format ("dd MMM yyyy") matches your data.
    DateTime? lessonDate;
    try {
      if (lesson['date'] != null) {
        lessonDate = DateFormat("dd MMM yyyy").parse(lesson['date']);
      }
    } catch (e) {
      lessonDate = null;
    }

    // Get today's date (only year, month, day for comparison).
    final now = DateTime.now();
    final todayOnly = DateTime(now.year, now.month, now.day);

    // Determine if the lesson is today, past, or upcoming.
    bool isToday = false;
    bool isPast = false;
    if (lessonDate != null) {
      final lessonOnly =
          DateTime(lessonDate.year, lessonDate.month, lessonDate.day);
      isToday = lessonOnly == todayOnly;
      isPast = lessonOnly.isBefore(todayOnly) && lesson["is_done"] == false;
    }

    // Determine display string and its text color.
    String dateTimeStr = '';
    Color dateTextColor = Colors.black54;
    if (lessonDate != null) {
      if (isPast) {
        dateTimeStr = '${lesson['date']} at ${lesson['start_time']}';
        dateTextColor = Colors.red;
      } else if (isToday) {
        dateTimeStr = 'Today at ${lesson['start_time']}';
        dateTextColor = Colors.orange;
      } else {
        dateTimeStr = '${lesson['date']} at ${lesson['start_time']}';
        dateTextColor = Colors.black54;
      }
    } else {
      dateTimeStr = 'Unknown';
    }

    return InkWell(
      onTap: () => showLessonCardOptions(context, lesson),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8),
          child: Row(
            children: [
              const SizedBox(width: 16),
              // Calendar or report icon.
              InkWell(
                onTap: () {
                  if (isLastLesson) {
                    // Call your lesson report handler.
                    handleLessonReport(context, lesson);
                  } else if ((unschedulableLessons ?? [])
                      .contains(lesson['lesson_id']?.toString() ?? '')) {
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
                    // For group lessons, scheduling might be unavailable.
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
                    showScheduleLessonModal(context, lesson);
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
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (lesson["subject_name"] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        lesson["subject_name"],
                        style: GoogleFonts.lato(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      dateTimeStr,
                      style: GoogleFonts.lato(
                        fontSize: 14,
                        color: dateTextColor,
                        fontWeight: FontWeight.bold,
                      ),
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
                  // Three dots icon to open details.
                  InkWell(
                    onTap: () {
                      showLessonDetailsModal(context, lesson);
                    },
                    child: const Icon(
                      Icons.more_vert,
                      size: 28,
                      color: Colors.orange,
                    ),
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
}
