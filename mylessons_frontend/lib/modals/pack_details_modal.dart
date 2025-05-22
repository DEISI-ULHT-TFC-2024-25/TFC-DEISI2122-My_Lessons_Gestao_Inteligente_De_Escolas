import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/home_page_provider.dart';
import '../providers/pack_details_provider.dart';
import '../modals/lessons_modal.dart';
import '../pages/pack_progress_records_page.dart';
import '../modals/subject_modal.dart';
import '../providers/school_provider.dart';
import '../widgets/contact_school_widget.dart';
import 'parents_modal.dart';

/// AnimatedGridItem: Animates each grid item with a fade and slide-in effect.
class AnimatedGridItem extends StatefulWidget {
  final Widget child;
  final Duration delay;
  const AnimatedGridItem({Key? key, required this.child, required this.delay})
      : super(key: key);

  @override
  _AnimatedGridItemState createState() => _AnimatedGridItemState();
}

class _AnimatedGridItemState extends State<AnimatedGridItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _slideAnimation = Tween<Offset>(
            begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}

class PackDetailsPage extends StatelessWidget {
  final dynamic pack;

  const PackDetailsPage({Key? key, required this.pack}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Provide a PackDetailsProvider instance so that the content below can use it.
    return ChangeNotifierProvider(
      create: (_) {
        final provider = PackDetailsProvider();
        provider.initialize(
          pack: pack,
          currentRole:
              Provider.of<HomePageProvider>(context, listen: false).currentRole,
          fetchData: () =>
              Provider.of<HomePageProvider>(context, listen: false).fetchData(),
          unschedulableLessons:
              Provider.of<HomePageProvider>(context, listen: false)
                  .unschedulableLessons,
        );
        return provider;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text("Pack Details"),
        ),
        body: const PackDetailsContent(),
      ),
    );
  }
}

class PackDetailsContent extends StatelessWidget {
  const PackDetailsContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PackDetailsProvider>(context);
    final packDetailsFuture = provider.packDetailsFuture;

    // Wrap with AnimatedSwitcher to show a loader until data is loaded.
    return AnimatedSwitcher(
      duration: Duration(milliseconds: 300),
      child: FutureBuilder<Map<String, dynamic>?>(
        key: ValueKey(packDetailsFuture.hashCode),
        future: packDetailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Pack Details",
                      style: GoogleFonts.lato(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
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
              ),
            );
          }

          final details = snapshot.data!;
          if (details.containsKey("date")) {
            details["date"] = provider.formatDate(details["date"].toString());
          }

          // Instead of relying solely on provider.currentRole,
          // read currentRole from HomePageProvider (so updates are reflected).
          final currentRole =
              Provider.of<HomePageProvider>(context).currentRole;
          final fetchData = provider.fetchData;
          final unschedulableLessons = provider.unschedulableLessons;

          // Build grid items.
          final gridItems = <Map<String, dynamic>>[];
          final leftIconMapping = <String, IconData>{};
          final labelsWithAction = <String>[];
          final actionIconMapping = <String, IconData>{};
          final actionNoteMapping = <String, String>{};

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

            labelsWithAction.addAll(
                ['Debt', 'School', 'Instructors', 'Students', 'Subject']);
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

          return SingleChildScrollView(
            key: ValueKey(details.hashCode),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                // Lessons Card
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
                          unschedulableLessons: unschedulableLessons,
                        ),
                      );
                      await provider.refreshPackDetails();
                    },
                  ),
                ),
                const SizedBox(height: 16),
                // Pack Progress Records Card
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
                const SizedBox(height: 16),
                // View Parents Card
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
                      }
                    },
                  ),
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
                                                fontSize: 14,
                                              ),
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
                                        // Inside the IconButton's onPressed callback in buildCard:
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
                                            bool? updated;
                                            try {
                                              // If the School tile is tapped.
                                              if (label == "School") {
                                                // Get the school name from the pack details.
                                                final String schoolName =
                                                    details['school_name'] ??
                                                        '';

                                                // Obtain the SchoolProvider.
                                                final schoolProvider =
                                                    Provider.of<SchoolProvider>(
                                                        context,
                                                        listen: false);

                                                // Look up the full school details from apiSchools based on the name.
                                                final matchingSchool =
                                                    schoolProvider.apiSchools
                                                        .firstWhere(
                                                  (s) =>
                                                      s['name'] != null &&
                                                      s['name']
                                                              .toString()
                                                              .toLowerCase() ==
                                                          schoolName
                                                              .toLowerCase(),
                                                  orElse: () => {},
                                                );

                                                // Update the selected school in the provider.
                                                schoolProvider.selectSchool(
                                                    matchingSchool);

                                                // Optionally, you can close any open modal before opening the new one.
                                                Navigator.pop(context);

                                                // Open a bottom modal with the ContactSchoolWidget,
                                                // passing in the full school details.
                                                showModalBottomSheet(
                                                  context: context,
                                                  shape:
                                                      const RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.vertical(
                                                            top:
                                                                Radius.circular(
                                                                    16)),
                                                  ),
                                                  isScrollControlled: true,
                                                  builder: (context) {
                                                    final schoolToPass =
                                                        (matchingSchool
                                                                .isNotEmpty)
                                                            ? matchingSchool
                                                            : {
                                                                'name':
                                                                    schoolName,
                                                              };
                                                    return SizedBox(
                                                      height:
                                                          MediaQuery.of(context)
                                                                  .size
                                                                  .height *
                                                              0.8,
                                                      child:
                                                          ContactSchoolWidget(
                                                              school:
                                                                  schoolToPass),
                                                    );
                                                  },
                                                );
                                              } else if (label == "Debt" &&
                                                  currentRole == "Parent") {
                                                Navigator.pop(context);

                                                Navigator.of(context)
                                                    .pushNamedAndRemoveUntil(
                                                  '/main',
                                                  (route) => false,
                                                  arguments: {
                                                    'initialIndex': 2
                                                  },
                                                );
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
                                                            top:
                                                                Radius.circular(
                                                                    16)),
                                                  ),
                                                  builder: (context) =>
                                                      SubjectModal(
                                                    packId: provider
                                                            .pack['pack_id'] ??
                                                        provider.pack['id'],
                                                  ),
                                                );
                                              }
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
                      children: combinedItems.asMap().entries.map((entry) {
                        int index = entry.key;
                        Map<String, dynamic> item = entry.value;
                        final bool withAction =
                            labelsWithAction.contains(item['label']);
                        return AnimatedGridItem(
                          delay: Duration(milliseconds: 100 * index),
                          child: buildCard(item, withAction: withAction),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }
}
