// File: create_new_goal_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/api_service.dart' as ApiService;

class CreateNewGoalPage extends StatefulWidget {
  final dynamic student; // <-- Add this to accept the student

  const CreateNewGoalPage({
    Key? key,
    required this.student, // <-- Make it required
  }) : super(key: key);

  @override
  _CreateNewGoalPageState createState() => _CreateNewGoalPageState();
}

class _CreateNewGoalPageState extends State<CreateNewGoalPage> {
  final _formKey = GlobalKey<FormState>();

  // Dummy list of skills; replace with real API data if needed.
  List<dynamic> skills = [
    {'id': 1, 'name': 'Dribbling'},
    {'id': 2, 'name': 'Passing'},
  ];

  dynamic selectedSkill;
  final TextEditingController _descriptionController = TextEditingController();
  DateTime? targetDate;
  bool _isLoading = false;

  Future<void> _selectTargetDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: targetDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        targetDate = picked;
      });
    }
  }

  Future<void> _saveGoal() async {
    // Validate form fields
    if (_formKey.currentState!.validate() && targetDate != null) {
      setState(() {
        _isLoading = true;
      });
      // Build the payload using the passed-in student
      final payload = {
        'student_id': widget.student['id'],       // <-- Using widget.student
        'skill_id': selectedSkill['id'],
        'description': _descriptionController.text,
        'target_date': DateFormat('yyyy-MM-dd').format(targetDate!),
      };
      try {
        await ApiService.createGoal(payload);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Goal created successfully')),
        );
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating goal: $e')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all fields')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentName = widget.student['name'] ?? 'Unknown Student';

    return Scaffold(
      appBar: AppBar(
        title: Text('Create New Goal for $studentName'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  children: [
                    // --- SKILL DROPDOWN ---
                    DropdownButtonFormField<dynamic>(
                      decoration: const InputDecoration(
                        labelText: 'Skill',
                        border: OutlineInputBorder(),
                      ),
                      items: skills
                          .map((skill) => DropdownMenuItem(
                                value: skill,
                                child: Text(skill['name']),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedSkill = value;
                        });
                      },
                      validator: (value) =>
                          value == null ? 'Please select a skill' : null,
                    ),
                    const SizedBox(height: 16),
                    // --- DESCRIPTION ---
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      validator: (value) => value == null || value.isEmpty
                          ? 'Enter goal description'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    // --- TARGET DATE ---
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Target Date'),
                      subtitle: Text(targetDate != null
                          ? DateFormat('yyyy-MM-dd').format(targetDate!)
                          : 'Select a date'),
                      trailing: IconButton(
                        icon: const Icon(Icons.calendar_today),
                        onPressed: _selectTargetDate,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // --- SAVE BUTTON ---
                    ElevatedButton(
                      onPressed: _saveGoal,
                      child: const Text('Save Goal'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
