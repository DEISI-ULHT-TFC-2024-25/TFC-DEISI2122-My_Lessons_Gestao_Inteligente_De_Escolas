// File: lib/modals/update_progress_form.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart'; // Contains baseUrl and getAuthHeaders

class UpdateProgressForm extends StatefulWidget {
  final Map<String, dynamic> currentData; // Current progress record data
  const UpdateProgressForm({Key? key, required this.currentData}) : super(key: key);

  @override
  _UpdateProgressFormState createState() => _UpdateProgressFormState();
}

class _UpdateProgressFormState extends State<UpdateProgressForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _notesController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(text: widget.currentData['notes'] ?? '');
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitUpdate() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSubmitting = true;
      });
      // Prepare updated data; here we're updating only the notes.
      Map<String, dynamic> updatedData = {
        'notes': _notesController.text,
      };
      // Assume progress record id is provided in currentData['id']
      final recordId = widget.currentData['id'];
      final headers = await getAuthHeaders();
      final url = Uri.parse('$baseUrl/api/progress/record/update/$recordId/');
      final response = await http.patch(
        url,
        headers: headers,
        body: jsonEncode(updatedData),
      );
      setState(() {
        _isSubmitting = false;
      });
      if (response.statusCode == 200) {
        // Update successful: return the updated data.
        Navigator.pop(context, updatedData);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update progress.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Adjust padding for keyboard
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Update Progress',
                  style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Notes',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter some notes';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _isSubmitting 
                    ? CircularProgressIndicator(color: Colors.orange)
                    : ElevatedButton(
                        onPressed: _submitUpdate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                        child: Text('Submit', style: GoogleFonts.lato()),
                      ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
