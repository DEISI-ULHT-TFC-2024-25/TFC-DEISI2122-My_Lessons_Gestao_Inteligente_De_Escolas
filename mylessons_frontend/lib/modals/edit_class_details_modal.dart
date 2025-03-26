// File: edit_class_details_modal.dart

import 'package:flutter/material.dart';

class EditClassDetailsModal extends StatefulWidget {
  final List<String> skillsCovered; // e.g., ['Dribbling', 'Passing']
  final String initialNote;
  final Function(List<String> updatedSkills, String updatedNote) onSave;

  const EditClassDetailsModal({
    Key? key,
    required this.skillsCovered,
    required this.initialNote,
    required this.onSave,
  }) : super(key: key);

  @override
  _EditClassDetailsModalState createState() => _EditClassDetailsModalState();
}

class _EditClassDetailsModalState extends State<EditClassDetailsModal> {
  late List<String> skills;
  late TextEditingController noteController;

  @override
  void initState() {
    super.initState();
    skills = List.from(widget.skillsCovered);
    noteController = TextEditingController(text: widget.initialNote);
  }

  @override
  void dispose() {
    noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Edit Class Details',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          // Display skills as chips
          Wrap(
            spacing: 8,
            children: skills.map((skill) => Chip(label: Text(skill))).toList(),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: noteController,
            keyboardType: TextInputType.multiline,
            minLines: 1,
            maxLines: null, // Allows the field to expand as needed.
            decoration: const InputDecoration(
              hintText: "Enter detailed notes...",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () {
                  widget.onSave(skills, noteController.text);
                  Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                ),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
