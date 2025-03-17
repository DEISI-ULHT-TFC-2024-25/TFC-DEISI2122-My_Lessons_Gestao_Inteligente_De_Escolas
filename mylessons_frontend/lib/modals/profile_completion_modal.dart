import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';

class ProfileCompletionModal extends StatefulWidget {
  const ProfileCompletionModal({Key? key}) : super(key: key);

  @override
  State<ProfileCompletionModal> createState() => _ProfileCompletionModalState();
}

class _ProfileCompletionModalState extends State<ProfileCompletionModal> {
  int _currentPage = 0;
  final PageController _pageController = PageController();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();

  // Use a default country (Portugal) as in your registration page.
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

  @override
  void initState() {
    super.initState();
    // Listen to text changes so our validity getters update
    _firstNameController.addListener(() => setState(() {}));
    _lastNameController.addListener(() => setState(() {}));
    _phoneController.addListener(() => setState(() {}));
  }

  bool get _isStep1Valid =>
      _firstNameController.text.trim().isNotEmpty &&
      _lastNameController.text.trim().isNotEmpty;

  // For step 2, we only require the phone input since a country is always selected.
  bool get _isStep2Valid => _phoneController.text.trim().isNotEmpty;

  void _nextPage() {
    if (_currentPage == 0 && _isStep1Valid) {
      setState(() => _currentPage = 1);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else if (_currentPage == 1 && _isStep2Valid) {
      // Return the entered data:
      // 'id' is taken from the selected country's code (or phone code, as required)
      Navigator.of(context).pop({
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'id': _selectedCountry.countryCode, // or use phoneCode if needed
        'phone': _phoneController.text.trim(),
      });
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      setState(() => _currentPage = 0);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
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
    final screenHeight = MediaQuery.of(context).size.height;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    // When keyboard is visible, use 90% of screen height; otherwise, 50%.
    final modalHeight =
        keyboardHeight > 0 ? screenHeight * 0.9 : screenHeight * 0.5;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      height: modalHeight,
      // This padding prevents content from being overlapped by the keyboard.
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Orange handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            // Use Flexible to let the PageView expand within available space.
            Flexible(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  // STEP 1: First Name & Last Name
                  SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Step 1 of 2",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 16),
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
                        const SizedBox(height: 16),
                        Center(
                          child: ElevatedButton(
                            onPressed: _isStep1Valid ? _nextPage : null,
                            child: const Text("Next"),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // STEP 2: Country Picker (ID) & Phone
                  SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: _previousPage,
                              icon: const Icon(Icons.arrow_back),
                            ),
                            const Spacer(),
                            const Text(
                              "Step 2 of 2",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const Spacer(),
                          ],
                        ),
                        const SizedBox(height: 16),
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
                                    textStyle: const TextStyle(
                                        fontSize: 16, color: Colors.black),
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
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
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
                                    const Icon(Icons.arrow_drop_down,
                                        color: Colors.grey),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _phoneController,
                                decoration: const InputDecoration(
                                  labelText: "Phone",
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.phone,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: ElevatedButton(
                            onPressed: _isStep2Valid ? _nextPage : null,
                            child: const Text("Submit"),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
