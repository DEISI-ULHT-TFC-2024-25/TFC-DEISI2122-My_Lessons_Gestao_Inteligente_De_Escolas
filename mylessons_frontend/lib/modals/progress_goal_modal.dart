import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart'; // Ensure this file defines getAuthHeaders() and baseUrl

/// The combined modal for creating a new goal or a new skill.
class ProgressGoalModal extends StatefulWidget {
  final dynamic student;
  final dynamic lesson;
  const ProgressGoalModal({
    Key? key,
    required this.student,
    required this.lesson,
  }) : super(key: key);

  @override
  _ProgressGoalModalState createState() => _ProgressGoalModalState();
}

class _ProgressGoalModalState extends State<ProgressGoalModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int? newlyCreatedSkillId; // When a new skill is created, store its ID.

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  // Callback from the New Skill tab.
  void _handleSkillCreated(Map<String, dynamic> newSkill) {
    setState(() {
      newlyCreatedSkillId = newSkill['id'];
      // Switch back to the New Goal tab.
      _tabController.animateTo(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.9,
        child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: "New Goal"),
                Tab(text: "New Skill"),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              CreateNewGoalTab(
                student: widget.student,
                lesson: widget.lesson,
                newlyCreatedSkillId: newlyCreatedSkillId,
              ),
              CreateNewSkillTab(
                lesson: widget.lesson,
                onSkillCreated: _handleSkillCreated,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The "New Goal" tab widget.
class CreateNewGoalTab extends StatefulWidget {
  final dynamic student;
  final dynamic lesson;
  final int? newlyCreatedSkillId;
  const CreateNewGoalTab({
    Key? key,
    required this.student,
    required this.lesson,
    this.newlyCreatedSkillId,
  }) : super(key: key);

  @override
  _CreateNewGoalTabState createState() => _CreateNewGoalTabState();
}

class _CreateNewGoalTabState extends State<CreateNewGoalTab> {
  final _formKey = GlobalKey<FormState>();
  List<dynamic> skills = [];
  bool isLoadingSkills = true;
  bool _isLoading = false;
  int? selectedSkillId;

  @override
  void initState() {
    super.initState();
    fetchSkills();
  }

  @override
  void didUpdateWidget(covariant CreateNewGoalTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If a new skill was created, re-select it in the dropdown.
    if (widget.newlyCreatedSkillId != null &&
        widget.newlyCreatedSkillId != selectedSkillId) {
      fetchSkills(reselectId: widget.newlyCreatedSkillId);
    }
  }

  Future<void> fetchSkills({int? reselectId}) async {
    setState(() {
      isLoadingSkills = true;
    });
    try {
      // Convert lesson["subject_id"] to int explicitly.
      final subjectId = int.parse(widget.lesson["subject_id"].toString());
      final fetchedSkills = await getSkillForASubject(subjectId);
      setState(() {
        skills = fetchedSkills;
        isLoadingSkills = false;
        if (reselectId != null) {
          selectedSkillId = reselectId;
        }
      });
    } catch (e) {
      setState(() {
        isLoadingSkills = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching skills: $e')),
        );
      });
    }
  }

  Future<void> _saveGoal() async {
    if (_formKey.currentState!.validate()) {
      if (selectedSkillId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a skill')),
        );
        return;
      }
      setState(() {
        _isLoading = true;
      });
      final payload = {
        'student_id': widget.student['id'],
        'skill_id': selectedSkillId,
      };
      try {
        await createGoal(payload); // API call to create the goal.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Goal created successfully')),
        );
        Navigator.pop(context); // Close the modal upon success.
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating goal: $e')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoadingSkills) {
      return const Center(child: CircularProgressIndicator());
    }
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                children: [
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'Skill',
                      border: OutlineInputBorder(),
                    ),
                    value: selectedSkillId,
                    items: skills.map((skill) {
                      // Convert the skill's id to int.
                      final id = int.parse(skill['id'].toString());
                      final name = skill['name'] as String;
                      return DropdownMenuItem<int>(
                        value: id,
                        child: Text(name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedSkillId = value;
                      });
                    },
                    validator: (value) =>
                        value == null ? 'Please select a skill' : null,
                  ),
                  const SizedBox(height: 16),
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

/// The "New Skill" tab widget.
class CreateNewSkillTab extends StatefulWidget {
  final dynamic lesson;
  final Function(Map<String, dynamic> newSkill) onSkillCreated;
  const CreateNewSkillTab({
    Key? key,
    required this.lesson,
    required this.onSkillCreated,
  }) : super(key: key);

  @override
  _CreateNewSkillTabState createState() => _CreateNewSkillTabState();
}

class _CreateNewSkillTabState extends State<CreateNewSkillTab> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _skillNameController = TextEditingController();
  bool _isLoading = false;

  Future<void> _saveSkill() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      final payload = {
        'name': _skillNameController.text.trim(),
        'sport_id': widget.lesson["subject_id"],
      };
      try {
        final newSkill = await createSkill(payload);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Skill created successfully')),
        );
        // Return the new skill to the parent so it can be pre-selected.
        widget.onSkillCreated(newSkill);
        // Clear the form so the modal remains open for additional entries if needed.
        _skillNameController.clear();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating skill: $e')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
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
                  TextFormField(
                    controller: _skillNameController,
                    decoration: const InputDecoration(
                      labelText: 'Skill Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Please enter the skill name'
                        : null,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _saveSkill,
                    child: const Text('Save Skill'),
                  ),
                ],
              ),
            ),
    );
  }
}

