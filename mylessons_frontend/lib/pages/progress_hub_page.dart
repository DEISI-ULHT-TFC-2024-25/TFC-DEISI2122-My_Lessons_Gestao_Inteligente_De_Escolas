// File: lib/pages/progress_hub_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'create_new_goal_page.dart';
import 'create_new_skill_page.dart';
import 'my_skills_page.dart';
import 'new_progress_record_page.dart';
import '../modals/edit_class_details_modal.dart';

class ProgressHubPage extends StatelessWidget {
  final dynamic student; // Selected student object
  final dynamic lesson;  // Lesson object from which we came

  const ProgressHubPage({Key? key, required this.student, required this.lesson}) : super(key: key);

  // Helper method to build a navigation card with the same style
  Widget _buildNavCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: ListTile(
        leading: Icon(icon, color: Colors.orange),
        title: Text(title, style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: GoogleFonts.lato(fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward, color: Colors.orange),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The hub shows links to various progress pages.
    return Scaffold(
      appBar: AppBar(
        title: const Text("Progress Hub"),
      ),
      body: ListView(
        children: [
          _buildNavCard(
            context: context,
            icon: Icons.note_add,
            title: "New Progress Record",
            subtitle: "Add a new record for ${student['name']}",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NewProgressRecordPage(student: student),
                ),
              );
            },
          ),
          _buildNavCard(
            context: context,
            icon: Icons.school,
            title: "My Skills",
            subtitle: "View & update skills for ${student['name']}",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MySkillsPage(student: student),
                ),
              );
            },
          ),
          _buildNavCard(
            context: context,
            icon: Icons.flag,
            title: "Create New Goal",
            subtitle: "Set a new goal for ${student['name']}",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CreateNewGoalPage(student: student),
                ),
              );
            },
          ),
          _buildNavCard(
            context: context,
            icon: Icons.add_circle_outline,
            title: "Create New Skill",
            subtitle: "Add a new skill (for all users)",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CreateNewSkillPage(),
                ),
              );
            },
          ),
          _buildNavCard(
            context: context,
            icon: Icons.edit,
            title: "Edit Class Details",
            subtitle: "Quick updates from today's class",
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                builder: (context) => EditClassDetailsModal(
                  skillsCovered: lesson['skills_covered'] ?? [],
                  initialNote: lesson['class_note'] ?? '',
                  onSave: (updatedSkills, updatedNote) {
                    // Call an API to update class details here.
                    Navigator.pop(context);
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
