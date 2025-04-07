import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mylessons_frontend/modals/lesson_details_modal.dart';
import 'package:mylessons_frontend/modals/schedule_lesson_modal.dart';
import 'package:mylessons_frontend/services/api_service.dart';
import 'package:mylessons_frontend/widgets/handle_lesson_report.dart';
// Import your modals (replace these with your actual modal implementations)
import '../modals/lessons_modal.dart';

class LessonModalProvider with ChangeNotifier {
  showLessonDetailsModal(BuildContext context, lesson, currentRole, fetchData) {
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

  Future<List<String>> _fetchAvailableTimes(
          int lessonId, DateTime date, int increment) =>
      fetchAvailableTimes(lessonId, date, increment);

  Future<String?> _schedulePrivateLesson(
          int lessonId, DateTime newDate, String newTime) =>
      schedulePrivateLesson(lessonId, newDate, newTime);


  Future<void> showScheduleLessonModal(BuildContext context, dynamic lesson, currentRole, fetchData) async {
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
  
  void showLessonCardOptions(BuildContext context, dynamic lesson, currentRole, fetchData) {
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
                    showScheduleLessonModal(context, lesson, currentRole, fetchData);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.more_vert, color: Colors.orange),
                title: const Text("View Details"),
                onTap: () {
                  Navigator.pop(context);
                  showLessonDetailsModal(context, lesson, currentRole, fetchData);
                },
              ),
            ],
          ),
        );
      },
    );
  }


  Widget _buildLessonCard(BuildContext context, dynamic lesson, currentRole, fetchData, unschedulableLessons, {bool isLastLesson = false}) {
    final isGroup = lesson['type']?.toString().toLowerCase() == 'group';
    return InkWell(
      onTap: () => showLessonCardOptions(context, lesson, currentRole, fetchData),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8),
          child: Row(
            children: [
              const SizedBox(width: 16),
              // Wrap the calendar icon in its own InkWell.
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
                  } else
                  // Shortcut directly to scheduling modal.
                  if (lesson['type']?.toString().toLowerCase() == 'group') {
                    // For group lessons, show an alert if scheduling is unavailable.
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
                    showScheduleLessonModal(context, lesson, currentRole, fetchData);
                  }
                },
                // Use InkWell to provide ripple feedback.
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
                  // Wrap the three dots icon in its own InkWell.
                  InkWell(
                    onTap: () {
                      showLessonDetailsModal(lesson, context, currentRole, fetchData);
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

}
