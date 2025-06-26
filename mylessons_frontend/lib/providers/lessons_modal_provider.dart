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

  Future<void> showScheduleLessonModal(
      BuildContext context,
      dynamic lesson,
      ) async {
    // … your ID logic stays the same …
    final rawId = lesson['id'] ?? lesson['lesson_id'];
    final int lessonId = rawId is int
        ? rawId
        : int.parse(rawId.toString());

    // coalesce expiration date
    final rawExp = lesson['expiration_date'];
    final String expirationDate = (rawExp == null || rawExp == 'None')
        ? 'None'
        : rawExp as String;

    final homeProvider = Provider.of<HomePageProvider>(context, listen: false);
    final currentRole = homeProvider.currentRole;
    final fetchData = homeProvider.fetchData;
    final schoolScheduleTimeLimit =
    await fetchSchoolScheduleTimeLimit(lesson["school"]);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (modalContext) {
        return ScheduleLessonModal(
          lessonId: lessonId,
          expirationDate: expirationDate,
          schoolScheduleTimeLimit: schoolScheduleTimeLimit,
          currentRole: currentRole,
          fetchAvailableTimes: _fetchAvailableTimes,
          schedulePrivateLesson: _schedulePrivateLesson,
          onScheduleConfirmed: fetchData,
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
/// Builds and returns a card widget representing a lesson.
Widget buildLessonCard(
    BuildContext context,
    dynamic lesson,
    dynamic unschedulableLessons, {
    bool isLastLesson = false,
  }) {
  // Determine whether this is a group lesson.
  final bool isGroup = lesson['type']?.toString().toLowerCase() == 'group';

  // Safely extract all potentially-null fields as strings.
  final String studentName = lesson['students_name']?.toString() ?? 'Unknown student';
  final String subjectName = lesson['subject_name']?.toString()  ?? '';
  final String dateRaw     = lesson['date']?.toString()          ?? '';
  final String startRaw    = lesson['start_time']?.toString()    ?? '';
  final String endRaw      = lesson['end_time']?.toString()      ?? '';

  // Attempt to parse the date string, trying ISO first then fallback.
  DateTime? lessonDate;
  if (dateRaw.isNotEmpty) {
    lessonDate = DateTime.tryParse(dateRaw);
    if (lessonDate == null) {
      try {
        lessonDate = DateFormat('dd MMM yyyy').parse(dateRaw);
      } catch (_) {
        lessonDate = null;
      }
    }
  }

  // Determine whether the lesson is today, in the past, or upcoming.
  final DateTime now       = DateTime.now();
  final DateTime todayOnly = DateTime(now.year, now.month, now.day);
  bool isToday = false;
  bool isPast  = false;
  if (lessonDate != null) {
    final DateTime lessonOnly = DateTime(lessonDate.year, lessonDate.month, lessonDate.day);
    isToday = lessonOnly == todayOnly;
    isPast  = lessonOnly.isBefore(todayOnly) && lesson["is_done"] == false;
  }

  // Build a display string for the date/time, with color coding.
  String dateTimeStr;
  Color dateTextColor = Colors.black54;
  if (lessonDate != null) {
    if (isPast) {
      dateTimeStr    = '$dateRaw at ${startRaw.isNotEmpty ? startRaw : 'TBD'}';
      dateTextColor = Colors.red;
    } else if (isToday) {
      dateTimeStr    = 'Today at ${startRaw.isNotEmpty ? startRaw : 'TBD'}';
      dateTextColor = Colors.orange;
    } else {
      dateTimeStr    = '$dateRaw at ${startRaw.isNotEmpty ? startRaw : 'TBD'}';
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
                  handleLessonReport(context, lesson);
                } else if ((unschedulableLessons ?? [])
                    .contains(lesson['lesson_id']?.toString() ?? '')) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text("Reschedule Unavailable"),
                      content: const Text("The reschedule period has passed!"),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text("OK"),
                        ),
                      ],
                    ),
                  );
                } else if (isGroup) {
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

            // Main column with text info.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    studentName,
                    style: GoogleFonts.lato(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (subjectName.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subjectName,
                      style: GoogleFonts.lato(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
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

            // Group/person icon and details button.
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
                  onTap: () => showLessonDetailsModal(context, lesson),
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
}}