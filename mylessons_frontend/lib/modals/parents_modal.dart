import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'parent_details_modal.dart'; // Import the details modal

class ParentsModal extends StatelessWidget {
  final List<dynamic> parents;

  const ParentsModal({
    Key? key,
    required this.parents,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Parents",
              style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: parents.length,
              itemBuilder: (context, index) {
                final parent = parents[index];
                // Extract the list of students for this parent
                final studentsList = parent['students'] as List<dynamic>? ?? [];
                // Join the student names separated by commas
                final studentNames = studentsList
                    .map((student) => student['name'].toString())
                    .join(', ');
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    title: Text(parent['name']),
                    subtitle: Text("Students: $studentNames"),
                    trailing: ElevatedButton(
                      child: const Text("View Details"),
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                          ),
                          builder: (context) => ParentDetailsModal(parent: parent),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Close", style: TextStyle(color: Colors.orange)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
