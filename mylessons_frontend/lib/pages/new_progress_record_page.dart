import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/api_service.dart' as ApiService;
import '../modals/progress_goal_modal.dart';

class NewProgressRecordPage extends StatefulWidget {
  final dynamic student; // Pass the selected student
  final dynamic lesson;
  const NewProgressRecordPage(
      {Key? key, required this.student, required this.lesson})
      : super(key: key);

  @override
  _NewProgressRecordPageState createState() => _NewProgressRecordPageState();
}

class _NewProgressRecordPageState extends State<NewProgressRecordPage> {
  final _formKey = GlobalKey<FormState>();

  // Dummy lesson data; replace with API data as needed.
  List<dynamic> lessons = [
    {'id': 1, 'name': 'Basketball Basics'},
    {'id': 2, 'name': 'Soccer Drills'},
  ];
  dynamic selectedLesson;
  DateTime recordDate = DateTime.now();
  final TextEditingController _notesController = TextEditingController();
  bool _isLoading = false;

  // Active goals for the student.
  List<dynamic> activeGoals = [];
  // Map to store updated progression for each goal (goal id -> level value)
  final Map<int, int> goalProgress = {};

  @override
  void initState() {
    super.initState();
    selectedLesson = lessons.first;
    fetchActiveGoals();
  }

  // Fetch active goals for the student from the backend.
  Future<void> fetchActiveGoals() async {
    setState(() {
      _isLoading = true;
    });
    try {
      activeGoals = await ApiService.getActiveGoals(widget.student['id']);
      // Initialize goalProgress with fetched levels.
      for (var goal in activeGoals) {
        goalProgress[goal['id']] = goal['level'] ?? 0;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching goals: $e")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Updates the progression for a goal.
  void updateGoalProgress(int goalId, int change) {
    setState(() {
      int current = goalProgress[goalId] ?? 0;
      // Only allow increment if current is less than 5.
      if (change > 0 && current >= 5) return;
      int updated = current + change;
      if (updated < 0) updated = 0;
      goalProgress[goalId] = updated;
    });
  }

  Future<void> _saveRecord() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      try {
        // For each goal, update the level if it has changed.
        for (var goal in activeGoals) {
          final int goalId = goal['id'];
          final int originalLevel = goal['level'] ?? 0;
          final int updatedLevel = goalProgress[goalId] ?? originalLevel;
          if (updatedLevel != originalLevel) {
            await ApiService.updateGoalLevel(goalId, updatedLevel);
          }
        }

        final payload = {
          'student_id': widget.student['id'],
          'lesson_id': widget
              .lesson['lesson_id'], // Ensure this key exists in your lesson object.
          'notes': _notesController.text,
          'goals': goalProgress.entries
              .map((e) => {'goal_id': e.key, 'progress': e.value})
              .toList(),
        };

        await ApiService.createProgressRecord(payload);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Progress record saved')),
        );
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving record: $e')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget buildGoalCard(dynamic goal) {
    int progress = goalProgress[goal['id']] ?? 0;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Expanded(
              child: Text(
                goal['skill_name'] ?? "No description",
                style: const TextStyle(fontSize: 16),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.remove, color: Colors.orange),
              onPressed: () {
                updateGoalProgress(goal['id'], -1);
              },
            ),
            Text(
              "$progress",
              style: const TextStyle(fontSize: 16),
            ),
            const Text(
              " / 5",
              style: TextStyle(fontSize: 16),
            ),
            IconButton(
              icon: const Icon(Icons.add, color: Colors.orange),
              onPressed: progress < 5
                  ? () {
                      updateGoalProgress(goal['id'], 1);
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Progress Record'),
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
                    // Active Goals section.
                    activeGoals.isEmpty
                        ? const Text("No active goals.")
                        : Column(
                            children: activeGoals.map(buildGoalCard).toList(),
                          ),
                    // Button to create a new goal.
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () async {
                          // Open the Create New Goal modal.
                          await showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(16)),
                            ),
                            builder: (context) => ProgressGoalModal(
                                student: widget.student, lesson: widget.lesson),
                          );
                          // After closing the modal, refresh active goals.
                          fetchActiveGoals();
                        },
                        icon: const Icon(Icons.add, color: Colors.orange),
                        label: const Text("Create New Goal",
                            style: TextStyle(color: Colors.orange)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Notes field.
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        hintText: 'Enter quick notes here...',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: null,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _saveRecord,
                      child: const Text('Save Record'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
