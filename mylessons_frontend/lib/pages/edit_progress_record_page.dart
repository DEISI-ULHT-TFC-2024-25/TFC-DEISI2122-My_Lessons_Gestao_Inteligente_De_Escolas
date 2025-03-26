import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/api_service.dart' as ApiService;

class EditProgressRecordPage extends StatefulWidget {
  final dynamic record; // The record object passed from the previous screen

  const EditProgressRecordPage({Key? key, required this.record})
      : super(key: key);

  @override
  _EditProgressRecordPageState createState() => _EditProgressRecordPageState();
}

class _EditProgressRecordPageState extends State<EditProgressRecordPage> {
  final _formKey = GlobalKey<FormState>();

  // Dummy data for lessons and skills; replace with API data as needed.
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
  late DateTime recordDate;
  List<dynamic> selectedSkills = [];
  late TextEditingController _notesController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Prepopulate fields with widget.record data.
    selectedLesson = lessons.firstWhere(
        (lesson) => lesson['id'] == widget.record['lesson_id'],
        orElse: () => lessons.first);
    recordDate = DateTime.tryParse(widget.record['date']) ?? DateTime.now();
    // Assuming widget.record['skills'] is a list of skill objects.
    selectedSkills = List<dynamic>.from(widget.record['skills'] ?? []);
    _notesController = TextEditingController(text: widget.record['notes'] ?? '');
  }

  Future<void> _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      final payload = {
        'lesson_id': selectedLesson['id'],
        'date': DateFormat('yyyy-MM-dd').format(recordDate),
        'skills_ids': selectedSkills.map((s) => s['id']).toList(),
        'notes': _notesController.text,
      };
      try {
        await ApiService.updateProgressRecord(widget.record['id'], payload);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Progress record updated')),
        );
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating record: $e')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildSkillChip(dynamic skill) {
    bool isSelected = selectedSkills.any((s) => s['id'] == skill['id']);
    return FilterChip(
      label: Text(skill['name']),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            selectedSkills.add(skill);
          } else {
            selectedSkills.removeWhere((s) => s['id'] == skill['id']);
          }
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Progress Record'),
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
                      value: selectedLesson,
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
                      children: skills.map((skill) => _buildSkillChip(skill)).toList(),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: _saveChanges,
                          child: const Text('Save Changes'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                          child: const Text('Discard Changes'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
