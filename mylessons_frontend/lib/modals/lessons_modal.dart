import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mylessons_frontend/providers/lessons_modal_provider.dart';
import 'package:provider/provider.dart';
import '../modals/lesson_details_modal.dart';
import '../modals/schedule_lesson_modal.dart';
import '../services/api_service.dart';
import '../widgets/handle_lesson_report.dart';

class LessonsModal extends StatefulWidget {
  final List<dynamic> lessons;
  final dynamic unschedulableLessons;

  const LessonsModal({
    Key? key,
    required this.lessons,
    this.unschedulableLessons,
  }) : super(key: key);

  @override
  _LessonsModalState createState() => _LessonsModalState();
}

class _LessonsModalState extends State<LessonsModal> {
  late Future<List<dynamic>> _lessonsFuture;

  @override
  void initState() {
    super.initState();
    // Wrap the provided lessons in a Future so the FutureBuilder resolves immediately.
    _lessonsFuture = Future.value(widget.lessons);
    print(widget.lessons);
  }

  Widget _buildLessonCard(dynamic lesson, {bool isLastLesson = false}) {
    final bool isGroup =
        lesson['type']?.toString().toLowerCase() == 'group';
    return InkWell(
      onTap: () {
        // Call the provider method to show the lesson card options.
        Provider.of<LessonModalProvider>(context, listen: false)
            .showLessonCardOptions(
              context,
              lesson,
            );
      },
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8),
          child: Row(
            children: [
              const SizedBox(width: 16),
              // Icon with scheduling/report functionality.
              InkWell(
                onTap: () {
                  if (isLastLesson) {
                    // Report lesson
                    handleLessonReport(context, lesson);
                  } else if (widget.unschedulableLessons
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
                  } else if (isGroup) {
                    // For group lessons, show alert.
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
                    // Use the provider to show the scheduling modal.
                    Provider.of<LessonModalProvider>(context, listen: false)
                        .showScheduleLessonModal(
                          context,
                          lesson,
                        );
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
                      lesson['students_name'] ?? '',
                      style: GoogleFonts.lato(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${lesson['date']} at ${lesson['start_time']}',
                      style: GoogleFonts.lato(
                          fontSize: 14, color: Colors.black54),
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
                  // Three-dots icon to view lesson details.
                  InkWell(
                    onTap: () {
                      Provider.of<LessonModalProvider>(context, listen: false)
                          .showLessonDetailsModal(
                            context,
                            lesson,
                          );
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _lessonsFuture,
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
                Text("Lessons",
                    style: GoogleFonts.lato(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                const Text("Could not fetch lessons."),
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
        final lessons = snapshot.data!;
        return Container(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Lessons",
                    style: GoogleFonts.lato(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: lessons.length,
                  itemBuilder: (context, index) {
                    final lesson = lessons[index];
                    return _buildLessonCard(lesson,
                        isLastLesson: lesson["is_done"] == true);
                  },
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
