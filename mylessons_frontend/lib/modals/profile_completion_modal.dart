import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

class ProfileCompletionPage extends StatefulWidget {
  // Optional initial values (for instance, fetched from the backend)
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
  late final TextEditingController _phoneController;

  // Save the ISO country code (e.g., "PT"). This is what you want to save.
  String _selectedCountryCode = 'PT';

  int _currentPage = 0;
  late final PageController _pageController;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _firstNameController =
        TextEditingController(text: widget.initialFirstName ?? '');
    _lastNameController =
        TextEditingController(text: widget.initialLastName ?? '');
    _phoneController = TextEditingController(text: widget.initialPhone ?? '');
    _selectedCountryCode = widget.initialCountryCode ?? 'PT';
    _pageController = PageController();

    _buildPages();

    // If no page is required, immediately complete.
    if (_pages.isEmpty) {
      Future.microtask(() {
        _completeProfile();
      });
    }
  }

  // Build the list of pages based on missing data.
  void _buildPages() {
    _pages = [];
    // If either first name or last name is missing, add the name page.
    if (_firstNameController.text.trim().isEmpty ||
        _lastNameController.text.trim().isEmpty) {
      _pages.add(_buildNamePage());
    }
    // If the phone is missing, add the contact page.
    if (_phoneController.text.trim().isEmpty) {
      _pages.add(_buildContactPage());
    }
  }

  bool get _isNameValid =>
    _firstNameController.text.trim().isNotEmpty &&
    _lastNameController.text.trim().isNotEmpty;

  bool get _isContactValid =>
      _phoneController.text.trim().isNotEmpty; // phone is required

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
      // Last step completed, complete the profile.
      _completeProfile();
    }
  }

  void _completeProfile() {
    // Instead of popping a modal, return data or navigate to home.
    Navigator.of(context).pop({
      'firstName': _firstNameController.text.trim(),
      'lastName': _lastNameController.text.trim(),
      'id': _selectedCountryCode, // ISO country code
      'phone': _phoneController.text.trim(),
    });
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
              setState(() {}); // Update validity
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
              setState(() {}); // Update validity
            },
          ),
          const SizedBox(height: 24),
          Center(
            child: ElevatedButton(
              onPressed: _isNameValid ? _nextPage : null,
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
          const SizedBox(height: 24),
          IntlPhoneField(
            initialCountryCode: _selectedCountryCode,
            initialValue: _phoneController.text,
            decoration: InputDecoration(
              labelText: "Phone",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
            onCountryChanged: (phoneCountry) {
              setState(() {
                // Save the ISO country code (e.g., "PT")
                _selectedCountryCode = phoneCountry.code;
              });
            },
            onChanged: (phone) {
              setState(() {
                _phoneController.text = phone.number;
              });
            },
          ),
          const SizedBox(height: 24),
          Center(
            child: ElevatedButton(
              onPressed: _isContactValid ? _nextPage : null,
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
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Disable system back navigation
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Complete Your Profile"),
          automaticallyImplyLeading: false, // No back button in the AppBar
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
