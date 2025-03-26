// File: lib/pages/new_progress_record_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/api_service.dart' as ApiService;
import 'progress_hub_page.dart';

class NewProgressRecordPage extends StatefulWidget {
  final dynamic student; // Pass the selected student
  const NewProgressRecordPage({Key? key, required this.student}) : super(key: key);

  @override
  _NewProgressRecordPageState createState() => _NewProgressRecordPageState();
}

class _NewProgressRecordPageState extends State<NewProgressRecordPage> {
  final _formKey = GlobalKey<FormState>();
  // Dummy data; replace with real API data.
  List<dynamic> lessons = [
    {'id': 1, 'name': 'Basketball Basics'},
    {'id': 2, 'name': 'Soccer Drills'},
  ];
  List<dynamic> skills = [
    {'id': 1, 'name': 'Dribbling'},
    {'id': 2, 'name': 'Passing'},
    {'id': 3, 'name': 'Shooting'},
  ];

  dynamic selectedLesson;
  DateTime recordDate = DateTime.now();
  List<dynamic> selectedSkills = [];
  final TextEditingController _notesController = TextEditingController();
  bool _isLoading = false;

  Future<void> _saveRecord() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      final payload = {
        'lesson_id': selectedLesson['id'],
        'date': DateFormat('yyyy-MM-dd').format(recordDate),
        'skills_ids': selectedSkills.map((s) => s['id']).toList(),
        'notes': _notesController.text,
        'student_id': widget.student['id'],
      };
      try {
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

  Widget _buildProgressHubLink() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: const Icon(Icons.dashboard, color: Colors.orange),
          title: const Text("Progress Hub"),
          subtitle: const Text("Go back to progress options"),
          trailing: const Icon(Icons.arrow_forward, color: Colors.orange),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProgressHubPage(
                  student: widget.student,
                  lesson: selectedLesson ?? lessons.first,
                ),
              ),
            );
          },
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
                    DropdownButtonFormField<dynamic>(
                      decoration: const InputDecoration(
                        labelText: 'Class/Lesson',
                        border: OutlineInputBorder(),
                      ),
                      items: lessons
                          .map((lesson) => DropdownMenuItem(
                                value: lesson,
                                child: Text(lesson['name']),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedLesson = value;
                        });
                      },
                      validator: (value) => value == null
                          ? 'Please select a lesson'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Date'),
                      subtitle: Text(DateFormat('yyyy-MM-dd').format(recordDate)),
                      trailing: IconButton(
                        icon: const Icon(Icons.calendar_today),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: recordDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() {
                              recordDate = picked;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Skills Covered'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: skills
                          .map((skill) => FilterChip(
                                label: Text(skill['name']),
                                selected: selectedSkills.contains(skill),
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      selectedSkills.add(skill);
                                    } else {
                                      selectedSkills.remove(skill);
                                    }
                                  });
                                },
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        hintText: 'Enter quick notes here...',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _saveRecord,
                      child: const Text('Save Record'),
                    ),
                    _buildProgressHubLink(),
                  ],
                ),
              ),
      ),
    );
  }
}
