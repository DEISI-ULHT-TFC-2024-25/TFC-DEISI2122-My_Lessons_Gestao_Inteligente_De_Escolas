// lib/widgets/pack_card.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PackCard extends StatelessWidget {
  final dynamic pack;

  const PackCard({Key? key, required this.pack}) : super(key: key);

  void _showPackCardOptions(dynamic pack) {
    // TODO: implement options (view details, etc.)
  }

  void _showScheduleMultipleLessonsModal(
      BuildContext context, List<dynamic> lessons, String? expirationDate) {
    // TODO: implement scheduling for multiple lessons
  }

  void showPackDetailsModal(dynamic pack) {
    // TODO: implement details modal
  }

  @override
  Widget build(BuildContext context) {
    final bool isGroup =
        pack['type'].toString().toLowerCase() == 'group';

    return InkWell(
      onTap: () => _showPackCardOptions(pack),
      child: Card(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8),
          child: Row(
            children: [
              const SizedBox(width: 16),
              InkWell(
                onTap: () {
                  if (isGroup) {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text("Scheduling Unavailable"),
                        content: const Text(
                            "To change a group pack, please contact the school."),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.of(context).pop(),
                            child: const Text("OK"),
                          )
                        ],
                      ),
                    );
                  } else {
                    _showScheduleMultipleLessonsModal(
                        context,
                        pack['lessons'] as List<dynamic>,
                        pack["expiration_date"] as String?);
                  }
                },
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: const Icon(
                    Icons.calendar_today,
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
                      pack['students_name'] ?? '',
                      style: GoogleFonts.lato(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${pack['lessons_remaining']} lessons remaining\n'
                      '${pack['unscheduled_lessons']} unscheduled lessons\n'
                      '${pack['days_until_expiration']} days until expiration',
                      style: GoogleFonts.lato(
                        fontSize: 14,
                        color: Colors.black54,
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
                  InkWell(
                    onTap: () => showPackDetailsModal(pack),
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
