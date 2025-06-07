import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mylessons_frontend/providers/lessons_modal_provider.dart';
import 'package:provider/provider.dart';
import 'pack_details_modal.dart';
import '../providers/pack_details_provider.dart'; // NEW: Import the PackDetailsProvider

class PacksModal extends StatefulWidget {
  final List<dynamic> packs;
  final String currentRole;
  final dynamic unschedulablePacks;
  final Future<void> Function() fetchData; // Callback to refresh data

  const PacksModal({
    Key? key,
    required this.packs,
    required this.currentRole,
    required this.fetchData,
    this.unschedulablePacks,
  }) : super(key: key);

  @override
  _PacksModalState createState() => _PacksModalState();
}

class _PacksModalState extends State<PacksModal> {
  late Future<List<dynamic>> _packsFuture;

  @override
  void initState() {
    super.initState();
    // Wrap the provided packs in a Future so the FutureBuilder resolves immediately.
    _packsFuture = Future.value(widget.packs);
    print(widget.packs);
  }

  Widget _buildPackCard(dynamic pack) {
    final bool isGroup = pack['type']?.toString().toLowerCase() == 'group';
    return InkWell(
      onTap: () => _showPackCardOptions(pack),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8),
          child: Row(
            children: [
              const SizedBox(width: 16),
              // Icon with scheduling or report functionality.
              InkWell(
                onTap: () {
                  if (isGroup) {
                    // For group packs, show an alert.
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text("Scheduling Unavailable"),
                        content: const Text(
                            "To change the schedule of a group pack, please contact the school."),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text("OK"),
                          )
                        ],
                      ),
                    );
                  } else if (widget.unschedulablePacks != null &&
                      widget.unschedulablePacks.contains(pack['pack_id'].toString())) {
                    // Show reschedule unavailable alert.
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
                  } else {
                    // Show scheduling modal for packs.
                    _showScheduleMultiplePacksModal(
                        pack['lessons'], pack["expiration_date"]);
                  }
                },
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: const Icon(Icons.calendar_today, size: 28, color: Colors.orange),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pack['students_name'] ?? '',
                      style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${pack['lessons_remaining']} lessons remaining\n'
                      '${pack['unscheduled_lessons']} unscheduled lessons\n'
                      '${pack['days_until_expiration']} days until expiration',
                      style: GoogleFonts.lato(fontSize: 14, color: Colors.black54),
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
                  // Updated: Three-dots icon to view pack details using ChangeNotifierProvider.
                  InkWell(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                        ),
                        builder: (context) => ChangeNotifierProvider(
                          create: (_) {
                            final provider = PackDetailsProvider();
                            provider.initialize(
                              pack: pack,
                              currentRole: widget.currentRole,
                              fetchData: widget.fetchData,
                              unschedulableLessons: widget.unschedulablePacks,
                            );
                            return provider;
                          },
                          child: PackDetailsPage(pack: pack,),
                        ),
                      );
                    },
                    child: const Icon(Icons.more_vert, size: 28, color: Colors.orange),
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

  void _showPackCardOptions(dynamic pack) {
    // Call the provider method to show the pack card options.
    // (You may wish to implement a dedicated method for packs.)
    Provider.of<LessonModalProvider>(context, listen: false).showLessonCardOptions(
      context,
      pack,
    );
  }

  void _showScheduleMultiplePacksModal(dynamic lessons, dynamic expirationDate) {
    // Use the provider to show the scheduling modal for packs.
    // We pass an object with 'lessons', 'expiration_date', and a type flag 'pack'
    Provider.of<LessonModalProvider>(context, listen: false).showScheduleLessonModal(
      context,
      {
        'lessons': lessons,
        'expiration_date': expirationDate,
        'type': 'pack',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _packsFuture,
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
                Text("Packs", style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                const Text("Could not fetch packs."),
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
        final packs = snapshot.data!;
        return Container(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Packs", style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: packs.length,
                  itemBuilder: (context, index) {
                    final pack = packs[index];
                    return _buildPackCard(pack);
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
