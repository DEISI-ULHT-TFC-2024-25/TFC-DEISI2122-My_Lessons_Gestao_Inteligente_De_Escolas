// File: update_skill_level_modal.dart

import 'package:flutter/material.dart';

class UpdateSkillLevelModal extends StatefulWidget {
  final String skillName;
  final int currentLevel;
  final Function(int) onSave;

  const UpdateSkillLevelModal({
    Key? key,
    required this.skillName,
    required this.currentLevel,
    required this.onSave,
  }) : super(key: key);

  @override
  _UpdateSkillLevelModalState createState() => _UpdateSkillLevelModalState();
}

class _UpdateSkillLevelModalState extends State<UpdateSkillLevelModal> {
  late int level;

  @override
  void initState() {
    super.initState();
    level = widget.currentLevel;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      // Use a white background with rounded corners if desired
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Update ${widget.skillName} Level',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Text('Current Level: $level/5'),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.remove),
                onPressed: () {
                  if (level > 1) {
                    setState(() {
                      level--;
                    });
                  }
                },
              ),
              Text(
                '$level/5',
                style: const TextStyle(fontSize: 16),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () {
                  if (level < 5) {
                    setState(() {
                      level++;
                    });
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () {
                  widget.onSave(level);
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
