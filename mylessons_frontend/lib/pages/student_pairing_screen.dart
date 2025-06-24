import 'package:flutter/material.dart';

import '../services/profile_service.dart';

class StudentPairingScreen extends StatefulWidget {
  @override
  _StudentPairingScreenState createState() => _StudentPairingScreenState();
}

class _StudentPairingScreenState extends State<StudentPairingScreen> {
  final _keyController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _submitKey() async {
    setState(() => _isSubmitting = true);
    try {
      await ProfileService.pairWithStudentByKey(_keyController.text.trim());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Successfully paired!')),
      );
      Navigator.of(context).pop(); // back to profile
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pairing failed: ${e.toString()}')),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pair with Student')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _keyController,
              decoration: const InputDecoration(
                labelText: 'Enter pairing key',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitKey,
              child: _isSubmitting
                  ? const CircularProgressIndicator()
                  : const Text('Submit Key'),
            ),
          ],
        ),
      ),
    );
  }
}
