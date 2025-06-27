import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/home_page_provider.dart';
import '../services/api_service.dart' as ApiService;
import '../modals/progress_goal_modal.dart';

// TODO when updating a record there should be an option to add a new goal even if the goal isnt linked wit hthat lesson as well

class NewProgressRecordPage extends StatefulWidget {
  final dynamic student; // The selected student.
  final dynamic lesson; // The current lesson.
  const NewProgressRecordPage(
      {Key? key, required this.student, required this.lesson})
      : super(key: key);

  @override
  _NewProgressRecordPageState createState() => _NewProgressRecordPageState();
}

class _NewProgressRecordPageState extends State<NewProgressRecordPage> {
  final _formKey = GlobalKey<FormState>();

  DateTime recordDate = DateTime.now();
  final TextEditingController _notesController = TextEditingController();
  bool _isLoading = false;

  // List of goals to display on the page.
  List<dynamic> activeGoals = [];
  // Map to store updated progression for each goal (goal id -> level value).
  final Map<int, int> goalProgress = {};
  int? recordId; // Existing progress record ID (if one exists).

  @override
  void initState() {
    super.initState();
    // Try to fetch an existing progress record first.
    fetchExistingProgressRecord();
  }

  /// Fetch an existing progress record based on student_id and lesson_id.
  Future<void> fetchExistingProgressRecord() async {
    try {
      // Use 'lesson_id' from widget.lesson as required.
      final record = await ApiService.getProgressRecord(
          widget.student['id'], widget.lesson['lesson_id']);
      if (record != null && record['id'] != null) {
        setState(() {
          recordId = record['id'];
          _notesController.text = record['notes'] ?? "";
          // Use the goals linked to this record (all goals, even completed).
          activeGoals = record['goals'] ?? [];
          // Update goalProgress map with the levels from the record.
          for (var goal in activeGoals) {
            goalProgress[goal['id']] = goal['level'] ?? 0;
          }
        });
      } else {
        // If no record exists, fetch active (uncompleted) goals.
        await fetchActiveGoals();
      }
    } catch (e) {
      // If record not found or error occurs, assume create mode.
      await fetchActiveGoals();
    }
  }

  /// In create mode, fetch only the active (uncompleted) goals.
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

  // Updates the progression for a goal by adding the change value.
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
        final payload = {
          'student_id': widget.student['id'],
          'lesson_id': widget.lesson['lesson_id'], // Ensure this key exists.
          'notes': _notesController.text,
          'goals': goalProgress.entries
              .map((e) => {'goal_id': e.key, 'progress': e.value})
              .toList(),
        };
        if (recordId != null) {
          // Update existing record.
          await ApiService.updateProgressRecord(recordId!, payload);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Progress record updated')),
          );
        } else {
          // Create new record.
          await ApiService.createProgressRecord(payload);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Progress record saved')),
          );
        }
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

  Widget buildGoalCard(dynamic goal, bool isReadOnly) {
    final progress = goalProgress[goal['id']] ?? 0;
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
              onPressed:
                  isReadOnly ? null : () => updateGoalProgress(goal['id'], -1),
            ),
            Text("$progress", style: const TextStyle(fontSize: 16)),
            const Text(" / 5", style: TextStyle(fontSize: 16)),
            IconButton(
              icon: const Icon(Icons.add, color: Colors.orange),
              onPressed: isReadOnly || progress >= 5
                  ? null
                  : () => updateGoalProgress(goal['id'], 1),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // READ the currentRole from your HomePageProvider:
    final currentRole = context.watch<HomePageProvider>().currentRole;
    final isReadOnly = currentRole == 'Parent';

    return Scaffold(
      appBar: AppBar(
        title: Text('Progress Record'),
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
                    // — goals —
                    if (activeGoals.isEmpty)
                      const Center(child: Text("No active goals."))
                    else
                      Column(
                        children: activeGoals.map((goal) {
                          return buildGoalCard(goal, isReadOnly);
                        }).toList(),
                      ),

                    // — “Create New Goal” button, hide or disable when read-only —
                    if (!isReadOnly)
                      Align(
                        alignment: Alignment.center,
                        child: TextButton.icon(
                          onPressed: () async {
                            await showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(16)),
                              ),
                              builder: (_) => ProgressGoalModal(
                                  student: widget.student,
                                  lesson: widget.lesson),
                            );
                            await fetchExistingProgressRecord();
                          },
                          icon: const Icon(Icons.add, color: Colors.orange),
                          label: const Text(
                            "Create New Goal",
                            style: TextStyle(color: Colors.orange),
                          ),
                        ),
                      ),

                    const SizedBox(height: 16),

                    // — notes field (disable when read-only) —
                    TextFormField(
                      controller: _notesController,
                      enabled: !isReadOnly,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        hintText: 'Enter quick notes here...',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: null,
                    ),

                    const SizedBox(height: 24),
                    if (!isReadOnly) ... {
                      // — Save/Update button (disable when read-only) —
                      ElevatedButton(
                        onPressed: isReadOnly ? null : _saveRecord,
                        child: Text(
                            recordId != null ? 'Update Record' : 'Save Record'),
                      ),
                    }
                  ],
                ),
              ),
      ),
    );
  }
}
