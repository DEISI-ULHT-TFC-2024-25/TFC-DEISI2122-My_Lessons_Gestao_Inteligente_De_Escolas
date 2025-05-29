import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:provider/provider.dart';

import '../providers/profile_provider.dart';
import '../services/api_service.dart';

class ProfileCompletionPage extends StatefulWidget {
  // Optional initial values (from your backend)
  final String? initialFirstName;
  final String? initialLastName;
  final String? initialPhone;
  final String? initialCountryCode;

  const ProfileCompletionPage({
    Key? key,
    this.initialFirstName,
    this.initialLastName,
    this.initialPhone,
    this.initialCountryCode,
  }) : super(key: key);

  @override
  State<ProfileCompletionPage> createState() => _ProfileCompletionPageState();
}

class _ProfileCompletionPageState extends State<ProfileCompletionPage> {
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  // We'll store the phone number in a separate variable.
  String _phoneNumber = '';

  bool _isSubmitting = false;

  // Save the ISO country code (e.g., "PT")
  String _selectedCountryCode = 'PT';

  int _currentPage = 0;
  late final PageController _pageController;
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _firstNameController =
        TextEditingController(text: widget.initialFirstName ?? '');
    _lastNameController =
        TextEditingController(text: widget.initialLastName ?? '');
    _phoneNumber = widget.initialPhone ?? '';
    _selectedCountryCode = widget.initialCountryCode ?? 'PT';
    _pageController = PageController();

    _buildPages();

    // If no data is missing, complete immediately.
    if (_pages.isEmpty) {
      Future.microtask(() {
        _completeProfile();
      });
    }
  }

  // Build pages based on missing data.
  void _buildPages() {
    _pages = [];
    // Add the name page if either first or last name is missing.
    if (_firstNameController.text.trim().isEmpty ||
        _lastNameController.text.trim().isEmpty) {
      _pages.add(_buildNamePage());
    }
    // Add the contact page if phone is missing.
    if (_phoneNumber.trim().isEmpty) {
      _pages.add(_buildContactPage());
    }
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      setState(() {
        _currentPage++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeProfile();
    }
  }

  Future<void> _completeProfile() async {
    setState(() => _isSubmitting = true);

    final headers = await getAuthHeaders();
  

    final body = jsonEncode({
      'first_name':   _firstNameController.text.trim(),
      'last_name':    _lastNameController.text.trim(),
      'country_code': _selectedCountryCode,
      'phone':        _phoneNumber.trim(),
    });

    final resp = await http.put(
      Uri.parse('$baseUrl/api/users/profile_data/'),
      headers: headers,
      body: body,
    );

    

    setState(() => _isSubmitting = false);

    if (resp.statusCode == 200) {
      Navigator.of(context).pop({
      'firstName': _firstNameController.text.trim(),
      'lastName': _lastNameController.text.trim(),
      'id': _selectedCountryCode, // ISO country code
      'phone': _phoneNumber.trim(),
    });
    } else {
      String err = 'Failed to update profile. (${resp.statusCode})';
      try {
        final json = jsonDecode(resp.body);
        if (json['error'] != null) err = json['error'];
      } catch (_) {}
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Error'),
          content: Text(err),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildNamePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Step 1 of 2",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 16),
          const Text(
            "Please enter your name",
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _firstNameController,
            decoration: const InputDecoration(
              labelText: "First Name",
              border: OutlineInputBorder(),
            ),
            onChanged: (_) {
              setState(() {}); // Rebuild to update potential validation
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _lastNameController,
            decoration: const InputDecoration(
              labelText: "Last Name",
              border: OutlineInputBorder(),
            ),
            onChanged: (_) {
              setState(() {});
            },
          ),
          const SizedBox(height: 24),
          Center(
            child: ElevatedButton(
              onPressed: () {
                if (_firstNameController.text.trim().isEmpty ||
                    _lastNameController.text.trim().isEmpty) {
                  // Show a warning if either field is empty.
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text("Warning"),
                      content: const Text("Please enter your first and last name."),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text("OK"),
                        ),
                      ],
                    ),
                  );
                } else {
                  _nextPage();
                }
              },
              child: const Text("Next"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Step 2 of 2",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 16),
          const Text(
            "Please enter your phone number",
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 24),
          IntlPhoneField(
            initialCountryCode: _selectedCountryCode,
            // Pass initial value if any.
            initialValue: _phoneNumber,
            decoration: InputDecoration(
              labelText: "Phone",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
            onCountryChanged: (phoneCountry) {
              setState(() {
                _selectedCountryCode = phoneCountry.code;
              });
            },
            onChanged: (phone) {
              setState(() {
                _phoneNumber = phone.number;
              });
            },
          ),
          const SizedBox(height: 24),
          Center(
            child: ElevatedButton(
              onPressed: () {
                if (_phoneNumber.trim().isEmpty) {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text("Warning"),
                      content: const Text("Please enter your phone number."),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text("OK"),
                        ),
                      ],
                    ),
                  );
                } else {
                  _nextPage();
                }
              },
              child: const Text("Submit"),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Disable system back navigation so the user must complete the fields.
    final provider = context.read<ProfileProvider>();
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Complete Your Profile"),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => provider.logout(context),
            ),
          ],
        ),
        body: _pages.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: _pages,
              ),
      ),
    );
  }
}
