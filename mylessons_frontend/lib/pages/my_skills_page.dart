// File: my_skills_page.dart

import 'package:flutter/material.dart';
import '../modals/update_skill_level_modal.dart';
import '../services/api_service.dart';
import '../services/api_service.dart' as ApiService; // Assumes ApiService methods exist

class MySkillsPage extends StatefulWidget {
  final dynamic student; // <-- Added student parameter

  const MySkillsPage({
    Key? key,
    required this.student, // <-- Make sure to require the student
  }) : super(key: key);

  @override
  _MySkillsPageState createState() => _MySkillsPageState();
}

class _MySkillsPageState extends State<MySkillsPage> {
  bool _isLoading = true;
  List<dynamic> skillProficiencies = [];

  @override
  void initState() {
    super.initState();
    _fetchSkillProficiencies();
  }

  Future<void> _fetchSkillProficiencies() async {
    setState(() {
      _isLoading = true;
    });
    try {
      // If your API endpoint can fetch skill proficiencies for a specific student,
      // call that endpoint. For example:
      //
      // final data = await ApiService.getSkillProficienciesForStudent(widget.student['id']);
      //
      // Otherwise, use the generic method:
      final data = await ApiService.getSkillProficiencies();
      setState(() {
        skillProficiencies = data;
      });
    } catch (e) {
      // Handle error appropriately
      print("Error fetching skill proficiencies: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showUpdateModal(dynamic proficiency) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return UpdateSkillLevelModal(
          skillName: proficiency['skill']['name'],
          currentLevel: proficiency['level'],
          onSave: (newLevel) async {
            await ApiService.updateSkillProficiencyLevel(proficiency['id'], newLevel, widget.student["id"]);
            _fetchSkillProficiencies();
          },
        );
      },
    );
  }

  Widget _buildSkillCard(dynamic proficiency) {
    final skillName = proficiency['skill']['name'];
    final sport = proficiency['skill']['sport'] ?? 'N/A';
    final level = proficiency['level'];
    final lastUpdated = proficiency['last_updated'];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Skill: $skillName', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Sport: $sport'),
            const SizedBox(height: 4),
            Text('Level: $level/5'),
            const SizedBox(height: 4),
            Text('Last Updated: $lastUpdated'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _showUpdateModal(proficiency),
              child: const Text('Update Level'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Optionally display the student's name in the app bar, if desired:
    final studentName = widget.student['name'] ?? 'Unknown Student';

    return Scaffold(
      appBar: AppBar(
        title: Text('My Skills - $studentName'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchSkillProficiencies,
              child: ListView(
                children: skillProficiencies.map((sp) => _buildSkillCard(sp)).toList(),
              ),
            ),
    );
  }
}
