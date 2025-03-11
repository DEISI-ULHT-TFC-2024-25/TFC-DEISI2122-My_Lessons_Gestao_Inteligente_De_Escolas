import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class PackDetailsModal extends StatelessWidget {
  final dynamic pack;
  final String currentRole;

  const PackDetailsModal({
    super.key,
    required this.pack,
    required this.currentRole,
  });

  // Fetch pack details from API.
  Future<Map<String, dynamic>?> _fetchPackDetails(int packId) =>
      fetchPackDetails(packId);

  // Helper: Format keys (e.g. lessons_remaining => LESSONS REMAINING)
  String _formatKey(String key) {
    return key.replaceAll('_', ' ').toUpperCase();
  }

  // Helper: Format a date string to "15 mar 2025"
  String _formatDate(String dateStr) {
    try {
      final DateTime date = DateTime.parse(dateStr);
      return DateFormat('d MMM yyyy').format(date).toLowerCase();
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Extract pack id from the pack.
    final int packId = pack['pack_id'] ?? pack['id'];
    return FutureBuilder<Map<String, dynamic>?>(
      future: _fetchPackDetails(packId),
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
                  "Pack Details",
                  style: GoogleFonts.lato(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text("Could not fetch pack details."),
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

        // Format any date fields if needed.
        if (details.containsKey("date")) {
          details["date"] = _formatDate(details["date"].toString());
        }

        // For both roles, filter out these keys.
        final Set<String> ignoredKeys = {
          "students_ids",
          "instructors_ids",
          "pack_id",
          "id",
          "days_until_expiration",
          "school_id",
          "unscheduled_lessons",
          "is_paid",
        };

        // For Parent role, additionally ignore "is_done" and "is_suspended".
        if (currentRole == "Parent") {
          ignoredKeys.addAll(["is_done", "is_suspended"]);
        }

        // Build grid items based on role using mapping logic.
        List<Map<String, dynamic>> gridItems = [];
        Map<String, IconData> leftIconMapping = {};
        List<String> labelsWithAction = [];
        Map<String, IconData> actionIconMapping = {};
        Map<String, String> actionNoteMapping = {};

        if (currentRole == "Parent") {
          // Define grid items for Parent.
          gridItems = [
            {'label': 'Date', 'value': details['date'] ?? ''},
            {
              'label': 'Lessons Remaining',
              'value':
                  "${details['lessons_remaining'] ?? ''}/${details['number_of_classes'] ?? ''}"
            },
            {'label': 'Debt', 'value': details['debt']?.toString() ?? ''},
            {'label': 'Students', 'value': details['students_name'] ?? ''},
            {'label': 'Type', 'value': details['type'] ?? ''},
            {'label': 'School', 'value': details['school_name'] ?? ''},
            {'label': 'Instructors', 'value': details['instructors_name'] ?? ''},
            {'label': 'Subject', 'value': details['sport'] ?? ''},
          ];

          leftIconMapping = {
            'Date': Icons.calendar_today,
            'Lessons Remaining': Icons.confirmation_number,
            'Debt': Icons.payments_outlined,
            'Students': Icons.person,
            'Type': Icons.info_outline,
            'Subject': Icons.menu_book,
            'School': Icons.school,
            'Instructors': Icons.person_outline,
          };

          // For Parents, only show the "Debt" action if debt > 0.
          final double debtValue =
              double.tryParse(details['debt']?.toString() ?? '0') ?? 0;
          labelsWithAction = [];
          if (debtValue > 0) {
            labelsWithAction.add('Debt');
          }
          // Always allow actions on School and Instructors.
          labelsWithAction.addAll(['School', 'Instructors']);

          actionIconMapping = {
            'Debt': Icons.payment,
            'School': Icons.phone,
            'Instructors': Icons.phone,
          };
          actionNoteMapping = {
            'Debt': 'Pay debt',
            'School': 'Contact school',
            'Instructors': 'Contact instructors',
          };
        } else if (currentRole == "Instructor" || currentRole == "Admin") {
          // Define grid items for Instructor/Admin.
          gridItems = [
            {'label': 'Date', 'value': details['date'] ?? ''},
            {
              'label': 'Lessons Remaining',
              'value':
                  "${details['lessons_remaining'] ?? ''}/${details['number_of_classes'] ?? ''}"
            },
            {'label': 'Debt', 'value': details['debt']?.toString() ?? ''},
            {'label': 'Students', 'value': details['students_name'] ?? ''},
            {'label': 'Type', 'value': details['type'] ?? ''},
            {'label': 'School', 'value': details['school_name'] ?? ''},
            {'label': 'Instructors', 'value': details['instructors_name'] ?? ''},
            {'label': 'Subject', 'value': details['sport'] ?? ''},
          ];

          leftIconMapping = {
            'Date': Icons.calendar_today,
            'Lessons Remaining': Icons.confirmation_number,
            'Debt': Icons.payments_outlined,
            'Students': Icons.people,
            'Type': Icons.group,
            'Subject': Icons.menu_book,
            'School': Icons.school,
            'Instructors': Icons.person_outline,
          };

          // For Instructor/Admin, allow action on Debt, School, Instructors, Students, and Subject.
          labelsWithAction = ['Debt', 'School', 'Instructors', 'Students', 'Subject'];
          actionIconMapping = {
            'Debt': Icons.payment,
            'Students': Icons.edit,
            'School': Icons.phone,
            'Instructors': Icons.edit,
            'Subject': Icons.edit,
          };
          actionNoteMapping = {
            'Debt': 'Add payment',
            'Students': 'Edit students',
            'School': 'Contact school',
            'Instructors': 'Edit instructors',
            'Subject': 'Edit subject',
          };
        }

        // Combine non-action items first, then the ones with actions.
        final nonActionItems =
            gridItems.where((item) => !labelsWithAction.contains(item['label'])).toList();
        final actionItems =
            gridItems.where((item) => labelsWithAction.contains(item['label'])).toList();
        final combinedItems = [...nonActionItems, ...actionItems];

        return Container(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Pack Details",
                  style: GoogleFonts.lato(
                      fontSize: 20, fontWeight: FontWeight.bold),
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
                                            // TODO: Implement the action for "$label"
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
