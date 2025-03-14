import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:country_picker/country_picker.dart';
import '../services/register_service.dart';

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

  // Default country (Portugal) using a Country object.
  Country _selectedCountry = Country(
    countryCode: 'PT',
    phoneCode: '351',
    e164Sc: 0,
    geographic: true,
    level: 1,
    name: 'Portugal',
    displayName: 'Portugal',
    displayNameNoCountryCode: 'Portugal',
    e164Key: '351-PT-0',
    example: '912345678',
  );

  // Checkbox states.
  bool _dontReceiveMarketing = false;
  bool _agreeTerms = false;

  // Password validation booleans.
  bool _hasLetter = false;
  bool _hasNumberOrSpecial = false;
  bool _hasMinLength = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_validatePassword);
  }

  void _validatePassword() {
    final password = _passwordController.text;
    bool hasLetter = RegExp(r'[A-Za-z]').hasMatch(password);
    bool hasNumberOrSpecial = RegExp(r'[\d#?!&]').hasMatch(password);
    bool hasMinLength = password.length >= 10;
    setState(() {
      _hasLetter = hasLetter;
      _hasNumberOrSpecial = hasNumberOrSpecial;
      _hasMinLength = hasMinLength;
    });
  }

  Future<void> _nextPage() async {
    // On Step 1, check username availability.
    if (_currentPage == 0) {
      final email = _emailController.text;
      if (email.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enter an email.")),
        );
        return;
      }
      // Convert email to lowercase.
      final username = email.toLowerCase();
      _emailController.text = username;
      // Check availability via the dedicated endpoint.
      bool available = await isUsernameAvailable(username);
      if (!available) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Username is already taken.")),
        );
        return;
      }
    }
    // Ensure the current step's required field(s) are filled before proceeding.
    if ((_currentPage == 0 && _emailController.text.isNotEmpty) ||
        (_currentPage == 1 && _passwordController.text.isNotEmpty) ||
        (_currentPage == 2 &&
            _firstNameController.text.isNotEmpty &&
            _lastNameController.text.isNotEmpty) ||
        (_currentPage == 3 && _phoneController.text.isNotEmpty)) {
      setState(() {
        _currentPage++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      setState(() {
        _currentPage--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _register() async {
    if (!_agreeTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("You must accept the terms and conditions to proceed."),
        ),
      );
      return;
    }

    try {
      final response = await registerUser(
        email: _emailController.text,
        password: _passwordController.text,
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        phone: _phoneController.text,
        countryCode: _selectedCountry.phoneCode,
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        // Store the token securely.
        final storage = const FlutterSecureStorage();
        await storage.write(key: 'auth_token', value: data['token']);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Registration successful!")),
        );
        Navigator.pushNamedAndRemoveUntil(context, '/main', (route) => false);
      } else {
        final errorMessage =
            jsonDecode(response.body)['error'] ?? "An error occurred.";
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
      appBar: AppBar(
        title: const Text("Register on MyLessons"),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
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

  /// Page 1: Email Registration Screen.
  Widget _buildEmailPage() {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 65),
          const Text(
            "Register an email",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Already have an account? ",
                style: TextStyle(color: Colors.black),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.pushReplacementNamed(context, '/login');
                },
                child: const Text(
                  'Login here!',
                  style: TextStyle(
                    color: Colors.orange,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Page 2: Create a Password.
  Widget _buildPasswordPage() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _previousPage,
                icon: const Icon(Icons.arrow_back),
              ),
              const Spacer(),
              const Text("Step 2 of 5"),
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
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Your password needs at least:"),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      _hasLetter
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 16,
                      color: _hasLetter ? Colors.orange : null,
                    ),
                    const SizedBox(width: 8),
                    const Text("1 letter"),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      _hasNumberOrSpecial
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 16,
                      color: _hasNumberOrSpecial ? Colors.orange : null,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                          "1 number or special character (example: # ? ! &)"),
                    )
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      _hasMinLength
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 16,
                      color: _hasMinLength ? Colors.orange : null,
                    ),
                    const SizedBox(width: 8),
                    const Text("10 characters"),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: (_hasLetter && _hasNumberOrSpecial && _hasMinLength)
                ? _nextPage
                : null,
            child: const Text("Next"),
          ),
        ],
      ),
    );
  }

  /// Page 3: Tell Us About Yourself.
  Widget _buildNamePage() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _previousPage,
                icon: const Icon(Icons.arrow_back),
              ),
              const Spacer(),
              const Text("Step 3 of 5"),
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

  /// Page 4: Stay in Touch.
  Widget _buildContactPage() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _previousPage,
                icon: const Icon(Icons.arrow_back),
              ),
              const Spacer(),
              const Text("Step 4 of 5"),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            "Let's stay in touch",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  showCountryPicker(
                    context: context,
                    onSelect: (Country country) {
                      setState(() {
                        _selectedCountry = country;
                      });
                    },
                    countryListTheme: CountryListThemeData(
                      flagSize: 25,
                      backgroundColor: Colors.white,
                      textStyle: const TextStyle(fontSize: 16, color: Colors.black),
                      bottomSheetHeight: 500,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20.0),
                        topRight: Radius.circular(20.0),
                      ),
                    ),
                  );
                },
                child: Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "${_selectedCountry.flagEmoji} +${_selectedCountry.phoneCode}",
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: "Number",
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
              ),
            ],
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

  /// Page 5: Terms and Conditions.
  Widget _buildTermsPage() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _previousPage,
                icon: const Icon(Icons.arrow_back),
              ),
              const Spacer(),
              const Text("Step 5 of 5"),
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
            "To learn more about how we collect, use, share and protect your personal data, check out our privacy policy.",
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
