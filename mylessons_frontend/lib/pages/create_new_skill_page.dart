// File: create_new_skill_page.dart

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/api_service.dart' as ApiService;

class CreateNewSkillPage extends StatefulWidget {
  final dynamic lesson;
  const CreateNewSkillPage({Key? key, this.lesson}) : super(key: key);

  @override
  _CreateNewSkillPageState createState() => _CreateNewSkillPageState();
}

class _CreateNewSkillPageState extends State<CreateNewSkillPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _skillNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  // Dummy list of sports; replace with your API data if available.
  List<dynamic> sports = [
    {'id': 1, 'name': 'Basketball'},
    {'id': 2, 'name': 'Soccer'},
  ];
  bool _isLoading = false;

  Future<void> _saveSkill() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      final payload = {
        'name': _skillNameController.text,
        'description': _descriptionController.text,
        'sport_id': widget.lesson?["subject_id"],
      };
      print(payload);
      try {
        await ApiService.createSkill(payload);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Skill created successfully')),
        );
        Navigator.pop(context);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Skill'),
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
      ),
    );
  }
}
