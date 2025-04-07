import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/pack_details_provider.dart';
import '../modals/lessons_modal.dart'; // For viewing lessons
import '../pages/pack_progress_records_page.dart';
import '../modals/instructors_modal.dart';
import '../modals/students_modal.dart';
import '../modals/subject_modal.dart';
import 'parents_modal.dart';
// ... import other needed files

class PackDetailsModal extends StatelessWidget {
  const PackDetailsModal({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PackDetailsProvider>(context);
    final packDetailsFuture = provider.packDetailsFuture;

    return FutureBuilder<Map<String, dynamic>?>(
      future: packDetailsFuture,
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
                    child: const Text("Close", selectionColor: Colors.orange),
                  ),
                ),
              ],
            ),
          );
        }

        final details = snapshot.data!;
        // Format date if present.
        if (details.containsKey("date")) {
          details["date"] = provider.formatDate(details["date"].toString());
        }

        // Build your UI just like you did in your original code.
        // The difference is that we read data from provider instead of widget.xxx.
        // e.g., final currentRole = provider.currentRole; final fetchData = provider.fetchData;
        final currentRole = provider.currentRole;
        final fetchData = provider.fetchData;
        final unschedulableLessons = provider.unschedulableLessons;

        // Build your items, icons, etc.
        final gridItems = <Map<String, dynamic>>[];
        final leftIconMapping = <String, IconData>{};
        final labelsWithAction = <String>[];
        final actionIconMapping = <String, IconData>{};
        final actionNoteMapping = <String, String>{};

        // The logic for building gridItems, leftIconMapping, etc. is the same.
        if (currentRole == "Parent") {
          gridItems.addAll([
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
            {
              'label': 'Instructors',
              'value': details['instructors_name'] ?? ''
            },
            {'label': 'Subject', 'value': details['subject'] ?? ''},
          ]);

          leftIconMapping.addAll({
            'Date': Icons.calendar_today,
            'Lessons Remaining': Icons.confirmation_number,
            'Debt': Icons.payments_outlined,
            'Students': Icons.person,
            'Type': Icons.info_outline,
            'Subject': Icons.menu_book,
            'School': Icons.school,
            'Instructors': Icons.person_outline,
          });

          final double debtValue =
              double.tryParse(details['debt']?.toString() ?? '0') ?? 0;
          if (debtValue > 0) {
            labelsWithAction.add('Debt');
          }
          labelsWithAction.addAll(['School', 'Instructors']);

          actionIconMapping.addAll({
            'Debt': Icons.payment,
            'School': Icons.phone,
            'Instructors': Icons.phone,
          });
          actionNoteMapping.addAll({
            'Debt': 'Pay debt',
            'School': 'Contact school',
            'Instructors': 'Contact instructors',
          });
        } else if (currentRole == "Instructor" || currentRole == "Admin") {
          gridItems.addAll([
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
            {
              'label': 'Instructors',
              'value': details['instructors_name'] ?? ''
            },
            {'label': 'Subject', 'value': details['subject'] ?? ''},
          ]);

          leftIconMapping.addAll({
            'Date': Icons.calendar_today,
            'Lessons Remaining': Icons.confirmation_number,
            'Debt': Icons.payments_outlined,
            'Students': Icons.edit,
            'Type': Icons.group,
            'Subject': Icons.edit,
            'School': Icons.phone,
            'Instructors': Icons.edit,
          });

          labelsWithAction
              .addAll(['Debt', 'School', 'Instructors', 'Students', 'Subject']);
          actionIconMapping.addAll({
            'Debt': Icons.payment,
            'Students': Icons.edit,
            'School': Icons.phone,
            'Instructors': Icons.edit,
            'Subject': Icons.edit,
          });
          actionNoteMapping.addAll({
            'Debt': 'Add payment',
            'Students': 'Edit students',
            'School': 'Contact school',
            'Instructors': 'Edit instructors',
            'Subject': 'Edit subject',
          });
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
                  "Pack Details",
                  style: GoogleFonts.lato(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    double spacing = 8.0;
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
                                          icon: provider
                                                      .isActionLoading[label] ==
                                                  true
                                              ? SizedBox(
                                                  width: 24,
                                                  height: 24,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                                Color>(
                                                            Colors.orange),
                                                  ),
                                                )
                                              : Icon(
                                                  actionIconMapping[label] ??
                                                      Icons.arrow_forward,
                                                  color: Colors.orange,
                                                ),
                                          onPressed: () async {
                                            provider.setActionLoading(
                                                label, true);
                                            try {
                                              // Perform your action logic here:
                                              // e.g. editing subject, students, etc.
                                              bool? updated;
                                              if (label == "Debt" &&
                                                  currentRole == "Parent") {
                                                // Example: for parent, open payments tab
                                                Navigator.pop(context);
                                                if (fetchData != null) {
                                                  // Optionally call fetchData or route somewhere
                                                }
                                                return;
                                              } else if (label == "Subject" &&
                                                  currentRole != "Parent") {
                                                updated =
                                                    await showModalBottomSheet<
                                                        bool>(
                                                  context: context,
                                                  isScrollControlled: true,
                                                  shape:
                                                      const RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.vertical(
                                                      top: Radius.circular(16),
                                                    ),
                                                  ),
                                                  builder: (context) =>
                                                      SubjectModal(
                                                    packId: provider
                                                            .pack['pack_id'] ??
                                                        provider.pack['id'],
                                                  ),
                                                );
                                              }
                                              // ... and so on for Students, Instructors, etc.
                                              if (updated == true &&
                                                  fetchData != null) {
                                                await fetchData();
                                                await provider
                                                    .refreshPackDetails();
                                              }
                                            } finally {
                                              provider.setActionLoading(
                                                  label, false);
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
                // Card to view Lessons
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.menu_book, color: Colors.orange),
                    title: Text(
                      "Lessons",
                      style: GoogleFonts.lato(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text("View lessons for this pack"),
                    onTap: () async {
                      await showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        shape: const RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(16)),
                        ),
                        builder: (context) => LessonsModal(
                          lessons: details["lessons"],
                          currentRole: currentRole,
                          fetchData: fetchData ?? () async {},
                          unschedulableLessons: unschedulableLessons,
                        ),
                      );
                      await provider.refreshPackDetails();
                    },
                  ),
                ),
                const SizedBox(height: 16),
                // Card to view Pack Progress
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.dashboard, color: Colors.orange),
                    title: Text(
                      "Pack Progress Records",
                      style: GoogleFonts.lato(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                        "View progress for all students and lessons in this pack"),
                    onTap: () async {
                      // For example, navigate to the pack progress page.
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              PackProgressRecordsPage(pack: provider.pack),
                        ),
                      );
                      await provider.refreshPackDetails();
                    },
                  ),
                ),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.people, color: Colors.orange),
                    title: Text(
                      "View Parents",
                      style: GoogleFonts.lato(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text("View parents for this pack"),
                    onTap: () async {
                      if (details.containsKey("parents") &&
                          details["parents"] is List) {
                        await showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          shape: const RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.vertical(top: Radius.circular(16)),
                          ),
                          builder: (context) => ParentsModal(
                            parents: details["parents"],
                          ),
                        );
                        await provider.refreshPackDetails();
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
