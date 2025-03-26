// File: lib/pages/progress_goal_modal.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../pages/create_new_skill_page.dart';

/// A modified goal creation content widget without the target date field,
/// for use inside the progress modal.
class CreateNewGoalModalContent extends StatefulWidget {
  final dynamic student;
  final VoidCallback? onSwitchToSkill;
  final dynamic lesson;
  const CreateNewGoalModalContent({Key? key, required this.student, this.onSwitchToSkill, required this.lesson}) : super(key: key);

  @override
  _CreateNewGoalModalContentState createState() => _CreateNewGoalModalContentState();
}

class _CreateNewGoalModalContentState extends State<CreateNewGoalModalContent> {
  final _formKey = GlobalKey<FormState>();

  // Dummy list of skills; replace with API data if needed.
  final List<dynamic> skills = [
    {'id': 1, 'name': 'Dribbling'},
    {'id': 2, 'name': 'Passing'},
  ];
  dynamic selectedSkill;
  bool _isLoading = false;

  Future<void> _saveGoal() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      // Build payload WITHOUT target date.
      final payload = {
        'student_id': widget.student['id'],
        'skill_id': selectedSkill['id'],
      };
      try {
        // Call API to create goal.
        await Future.delayed(const Duration(seconds: 1)); // Dummy delay
        // Replace with actual API call.
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
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                children: [
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
                  const SizedBox(height: 8),
                  // New "Create New Skill" action as text.
                  Align(
                    alignment: Alignment.center,
                    child: TextButton.icon(
                      onPressed: widget.onSwitchToSkill,
                      icon: const Icon(Icons.add, color: Colors.orange),
                      label: const Text(
                        'Create New Skill',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _saveGoal,
                    child: const Text('Save Goal'),
                  ),
                ],
              ),
            ),
    );
  }
}

/// The ProgressGoalModal allows switching between creating a new goal (without a target date)
/// and creating a new skill.
class ProgressGoalModal extends StatefulWidget {
  final dynamic student;
  final dynamic lesson;
  const ProgressGoalModal({Key? key, required this.student, required this.lesson}) : super(key: key);

  @override
  _ProgressGoalModalState createState() => _ProgressGoalModalState();
}

class _ProgressGoalModalState extends State<ProgressGoalModal> {
  // true: show Create New Goal content; false: show Create New Skill content.
  bool showGoalContent = true;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.9,
        child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            actions: [
              TextButton(
                onPressed: () {
                  setState(() {
                    showGoalContent = !showGoalContent;
                  });
                },
                child: Text(
                  showGoalContent ? 'Switch to Skill' : 'Switch to Goal',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          body: showGoalContent
              ? CreateNewGoalModalContent(
                  student: widget.student,
                  lesson: widget.lesson,
                  onSwitchToSkill: () {
                    setState(() {
                      showGoalContent = false;
                    });
                  },
                )
              : CreateNewSkillPage(
                lesson: widget.lesson,
              ),
        ),
      ),
    );
  }
}
