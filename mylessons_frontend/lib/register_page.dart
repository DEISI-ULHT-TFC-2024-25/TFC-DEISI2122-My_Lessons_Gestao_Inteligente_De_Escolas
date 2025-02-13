import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:io' show Platform; // Import for platform detection
import 'package:flutter/foundation.dart' show kIsWeb;

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // Controller for the multi-step PageView.
  final PageController _pageController = PageController();
  // Keeps track of the current step/page.
  int _currentPage = 0;

  // Controllers for form fields.
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final String _selectedCountryCode = "+351"; // Default Portugal

  // State for checkboxes.
  bool _dontReceiveMarketing = false;
  bool _agreeTerms = false;

  void _nextPage() {
    if ((_currentPage == 0 && _emailController.text.isNotEmpty) ||
        (_currentPage == 1 && _passwordController.text.isNotEmpty) ||
        (_currentPage == 2 && _firstNameController.text.isNotEmpty && _lastNameController.text.isNotEmpty) ||
        (_currentPage == 3 && _phoneController.text.isNotEmpty)) {
      setState(() {
        _currentPage++;
      });
      _pageController.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  // Navigate to the previous page.
  void _previousPage() {
    if (_currentPage > 0) {
      setState(() {
        _currentPage--;
      });
      _pageController.previousPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  Future<void> _register() async {
    if (!_agreeTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You must accept the terms and conditions to proceed.")),
      );
      return;
    }

    // Dynamically determine the correct API base URL
    final String apiBaseUrl = kIsWeb
        ? "http://127.0.0.1:8000" // Web (localhost)
        : (Platform.isAndroid ? "http://10.0.2.2:8000" : "http://127.0.0.1:8000"); // Mobile

    final Uri registerUrl = Uri.parse("$apiBaseUrl/api/users/register/");

    try {
      final response = await http.post(
        registerUrl,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": _emailController.text.trim(),
          "password": _passwordController.text,
          "first_name": _firstNameController.text.trim(),
          "last_name": _lastNameController.text.trim(),
          "country_code": _selectedCountryCode,
          "phone": _phoneController.text.trim(),
        }),
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Registration successful!")),
        );

        // Redirect to login page
        Navigator.pushReplacementNamed(context, "/login_success_page");
      } else {
        final errorMessage = jsonDecode(response.body)['error'] ?? "An error occurred.";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $errorMessage")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Network error: $e")),
      );
    }
  }


  @override
  void dispose() {
    _pageController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // An app bar with a centered title.
      appBar: AppBar(
        title: const Text("Register on MyLessons"),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          // A container that limits the maximum width (helpful for web)
          // and applies generous padding.
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            padding: const EdgeInsets.all(24.0),
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildEmailPage(),
                _buildPasswordPage(),
                _buildNamePage(),
                _buildContactPage(),
                _buildTermsPage(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Page 1: Email Registration Screen
  Widget _buildEmailPage() {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          const Text(
            "Register on MyLessons",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: "Email",
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _nextPage,
            child: const Text("Next"),
          ),
          const SizedBox(height: 24),
          // Divider with an "or" in between.
          Row(
            children: const <Widget>[
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: Text("or"),
              ),
              Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              // TODO: Implement Google sign-up.
            },
            icon: const Icon(Icons.account_circle),
            label: const Text("Register with Google"),
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/');
            },
            child: const Text("Already have an account? Login here"),
          ),
        ],
      ),
    );
  }

  /// Page 2 (Step 1 of 4): Create a Password
  Widget _buildPasswordPage() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Step header with a back arrow and step indicator.
          Row(
            children: [
              IconButton(
                onPressed: _previousPage,
                icon: const Icon(Icons.arrow_back),
              ),
              const Spacer(),
              const Text("Step 1 of 4"),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            "Create a password",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: "Password",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          // Password requirements list.
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text("Your password needs at least:"),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.check_box_outline_blank, size: 16),
                    SizedBox(width: 8),
                    Text("1 letter"),
                  ],
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.check_box_outline_blank, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                          "1 number or special character (example: # ? ! &)"),
                    )
                  ],
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.check_box_outline_blank, size: 16),
                    SizedBox(width: 8),
                    Text("10 characters"),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _nextPage,
            child: const Text("Next"),
          ),
        ],
      ),
    );
  }

  /// Page 3 (Step 2 of 4): Tell Us About Yourself
  Widget _buildNamePage() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Step header.
          Row(
            children: [
              IconButton(
                onPressed: _previousPage,
                icon: const Icon(Icons.arrow_back),
              ),
              const Spacer(),
              const Text("Step 2 of 4"),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            "Tell us a little about yourself",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _firstNameController,
            decoration: const InputDecoration(
              labelText: "First Name",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _lastNameController,
            decoration: const InputDecoration(
              labelText: "Last Name",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _nextPage,
            child: const Text("Next"),
          ),
        ],
      ),
    );
  }

  /// Page 4 (Step 3 of 4): Stay in Touch
  Widget _buildContactPage() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Step header.
          Row(
            children: [
              IconButton(
                onPressed: _previousPage,
                icon: const Icon(Icons.arrow_back),
              ),
              const Spacer(),
              const Text("Step 3 of 4"),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            "Let's stay in touch",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          // A placeholder for an ID field with flag. For a full implementation,
          // you might use a package like intl_phone_field.
          TextField(
            decoration: const InputDecoration(
              labelText: "ID (with flag)",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: "Number",
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _nextPage,
            child: const Text("Next"),
          ),
        ],
      ),
    );
  }

  /// Page 5 (Step 4 of 4): Terms and Conditions
  Widget _buildTermsPage() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Step header.
          Row(
            children: [
              IconButton(
                onPressed: _previousPage,
                icon: const Icon(Icons.arrow_back),
              ),
              const Spacer(),
              const Text("Step 4 of 4"),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            "Terms And Conditions",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          CheckboxListTile(
            title: const Text("I don't want to receive marketing from MyLessons"),
            value: _dontReceiveMarketing,
            onChanged: (bool? value) {
              setState(() {
                _dontReceiveMarketing = value ?? false;
              });
            },
          ),
          CheckboxListTile(
            title: const Text("I agree with the terms and conditions of MyLessons"),
            value: _agreeTerms,
            onChanged: (bool? value) {
              setState(() {
                _agreeTerms = value ?? false;
              });
            },
          ),
          const SizedBox(height: 16),
          const Text(
            "To learn more about how we collect, use, share and protect your personal data, "
            "check out our privacy policy.",
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _register,
            child: const Text("Register"),
          ),
        ],
      ),
    );
  }
}
