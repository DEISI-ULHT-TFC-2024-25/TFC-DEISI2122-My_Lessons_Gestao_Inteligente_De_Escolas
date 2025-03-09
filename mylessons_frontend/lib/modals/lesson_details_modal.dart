import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class LessonDetailsModal extends StatelessWidget {
  final dynamic lesson;
  final String currentRole;

  const LessonDetailsModal({
    Key? key,
    required this.lesson,
    required this.currentRole,
  }) : super(key: key);

  // These API functions are now moved to services/api_service.dart.
  Future<Map<String, dynamic>?> _fetchLessonDetails(int lessonId) =>
      fetchLessonDetails(lessonId);

  // Helper method to format keys.
  String _formatKey(String key) {
    return key.replaceAll('_', ' ').toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final int lessonId = lesson['id'] ?? lesson['lesson_id'];
    return FutureBuilder<Map<String, dynamic>?>(
      future: _fetchLessonDetails(lessonId),
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
                    child:
                        const Text("Close", selectionColor: Colors.orange),
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
        final location = details['location'] ?? '';
        final activity = details['sport'] ?? '';
        final isDone = details['is_done'] ?? null;

        List<Map<String, dynamic>> gridItems = [];
        Map<String, IconData> leftIconMapping = {};
        List<String> labelsWithAction = [];
        Map<String, IconData> actionIconMapping = {};
        Map<String, String> actionNoteMapping = {};

        if (currentRole == "Parent") {
          // Define grid items with simplified labels.
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

          // Only these labels get an action button and note.
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
        } else if (currentRole == "Instructor" || currentRole == "Admin") {
          // Define grid items with simplified labels.
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
            'is Done': Icons.check_box,
            'Students': Icons.people,
            'Type': Icons.groups,
            'Subject': Icons.menu_book,
            'Extras': Icons.star,
            'Instructors': Icons.person_outline,
            'School': Icons.school,
            'Location': Icons.location_on,
          };

          // Only these labels get an action button and note.
          labelsWithAction = [
            'Date',
            'Time',
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
            'School': Icons.contact_mail,
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

        // Separate non-action and action cards.
        final nonActionItems =
            gridItems.where((item) => !labelsWithAction.contains(item['label'])).toList();
        final actionItems =
            gridItems.where((item) => labelsWithAction.contains(item['label'])).toList();
        // Combine both groups with non-action items first.
        final combinedItems = [...nonActionItems, ...actionItems];

        return Container(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Lesson Details",
                  style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    double spacing = 8.0;
                    // Two cards per row.
                    double itemWidth = (constraints.maxWidth - spacing) / 2;

                    // Function to build a card.
                    Widget buildCard(Map<String, dynamic> item, {bool withAction = false}) {
                      final String label = item['label'];
                      final String value = item['value'].toString();
                      return Container(
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
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Icon(
                                        leftIconMapping[label] ?? Icons.info_outline,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              label,
                                              style: GoogleFonts.lato(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14),
                                            ),
                                            Text(
                                              value,
                                              style: GoogleFonts.lato(fontSize: 12),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (withAction)
                                        IconButton(
                                          icon: Icon(
                                            actionIconMapping[label] ?? Icons.arrow_forward,
                                            color: Colors.orange,
                                          ),
                                          onPressed: () {
                                            // TODO: Add your action for "$label" here.
                                            debugPrint("Action pressed for $label");
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
                                  style: GoogleFonts.lato(fontSize: 12, color: Colors.orange),
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
                        final bool withAction = labelsWithAction.contains(item['label']);
                        return buildCard(item, withAction: withAction);
                      }).toList(),
                    );
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
