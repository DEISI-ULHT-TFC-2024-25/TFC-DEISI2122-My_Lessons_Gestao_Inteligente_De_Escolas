import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:mylessons_frontend/services/api_service.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../services/cart_service.dart';
import '../pages/checkout_page.dart';

class StudentSelectionModal extends StatefulWidget {
  final Map<String, dynamic> service;
  final int? requiredCount; // Number of students required.
  final int? selectedDuration;
  final int? selectedClasses;
  final int? selectedPeople;
  final double? currentPrice;
  final int? currentTimeLimit;
  // Callback that notifies the parent how many students are selected.
  final Function(int)? onSelectionUpdated;

  const StudentSelectionModal({
    super.key,
    required this.service,
    this.requiredCount,
    this.selectedDuration,
    this.selectedClasses,
    this.selectedPeople,
    this.currentPrice,
    this.currentTimeLimit,
    this.onSelectionUpdated,
  });

  @override
  _StudentSelectionModalState createState() => _StudentSelectionModalState();
}

class _StudentSelectionModalState extends State<StudentSelectionModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTabIndex = 0;

  /// Future to fetch students from the backend.
  Future<Map<String, dynamic>>? _studentsFuture;

  // Controllers for text fields.
  final TextEditingController _studentIdController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _birthdayController = TextEditingController();

  /// Holds an existing student lookup result.
  Map<String, dynamic>? _existingStudentConfirmation;

  /// Holds the currently selected birthday in the "New" tab.
  DateTime? selectedBirthday;

  /// Date format for birthdays.
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  /// List of currently selected students.
  List<Map<String, dynamic>> _selectedStudents = [];

  // Pricing/Details variables (unused in this modal now).
  int? selectedDuration;
  int? selectedPeople;
  int? selectedClasses;
  double? currentPrice;
  int? currentTimeLimit;
  String? currency;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _studentsFuture = _fetchStudents();

    // Use the values passed from the parent.
    selectedDuration = widget.selectedDuration;
    selectedPeople = widget.selectedPeople;
    selectedClasses = widget.selectedClasses;
    currentPrice = widget.currentPrice;
    currentTimeLimit = widget.currentTimeLimit;
    currency = widget.service['currency'] ?? 'N/A';
  }

  /// Fetches the list of students from the backend.
  Future<Map<String, dynamic>> _fetchStudents() async {
    final url = Uri.parse('$baseUrl/api/users/students/');
    final headers = await getAuthHeaders();
    final response = await http.get(url, headers: headers);
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    }
    throw Exception('Failed to load students');
  }

  /// Creates a new student via POST request.
  Future<Map<String, dynamic>> _createStudent(
      String firstName, String lastName, String birthday) async {
    final url = Uri.parse('$baseUrl/api/users/students/create/');
    final headers = await getAuthHeaders();
    final body = jsonEncode({
      "first_name": firstName,
      "last_name": lastName,
      "birthday": birthday,
    });
    final response = await http.post(
      url,
      headers: {
        ...headers,
        'Content-Type': 'application/json',
      },
      body: body,
    );
    if (response.statusCode == 201) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    }
    throw Exception('Failed to create student');
  }

  @override
  void dispose() {
    _tabController.dispose();
    _studentIdController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _birthdayController.dispose();
    super.dispose();
  }

  /// Returns true if we've reached the required number of students.
  bool get _isSelectionComplete {
    return widget.requiredCount != null &&
        _selectedStudents.length == widget.requiredCount;
  }

  /// Updates the selected students list and notifies the parent.
  void _updateSelection(List<Map<String, dynamic>> newSelection) {
    setState(() {
      _selectedStudents = newSelection;
    });
    widget.onSelectionUpdated?.call(_selectedStudents.length);
  }

  /// Builds a simple header showing the selection count.
  Widget _buildSelectionHeader() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        "Selected Students: ${_selectedStudents.length} / ${widget.requiredCount ?? 'N/A'}",
        style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  /// Opens a calendar for picking the birthday in the "New" tab.
  void _showBirthdayPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final DateTime initialDate = selectedBirthday ?? DateTime(2000, 1, 1);
        return Container(
          height: 400,
          padding: const EdgeInsets.all(16),
          child: SfDateRangePicker(
            view: DateRangePickerView.month,
            selectionMode: DateRangePickerSelectionMode.single,
            initialSelectedDate: initialDate,
            showActionButtons: true,
            onSubmit: (Object? val) {
              if (val is DateTime) {
                setState(() {
                  selectedBirthday = val;
                  _birthdayController.text = _dateFormat.format(val);
                });
              }
              Navigator.pop(context);
            },
            onCancel: () => Navigator.pop(context),
            monthViewSettings: const DateRangePickerMonthViewSettings(
              firstDayOfWeek: 1,
              showTrailingAndLeadingDates: true,
            ),
            headerStyle: const DateRangePickerHeaderStyle(
              textAlign: TextAlign.center,
              textStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
    );
  }

  /// Builds checkout details (if needed for cart/checkout operations).
  Map<String, dynamic> _buildCheckoutDetails() {
    return {
      'service_name': widget.service['name'] ?? 'N/A',
      'school_name': widget.service['school_name'] ?? 'N/A',
      'number_of_students': _selectedStudents.length,
      'student_names': _selectedStudents.map((student) {
        final firstName = student['first_name'] ?? '';
        final lastName = student['last_name'] ?? '';
        return "$firstName $lastName";
      }).toList(),
      'price': currentPrice,
      'formatted_price': (currentPrice != null &&
              currency != null &&
              currency!.isNotEmpty)
          ? "${getCurrencySymbol(currency!)}${currentPrice!.toStringAsFixed(2)}"
          : 'N/A',
      'currency': currency ?? 'N/A',
      'type': widget.service['type'],
      'duration': widget.selectedDuration,
      'classes': widget.selectedClasses,
      'time_limit': widget.currentTimeLimit,
    };
  }

  @override
  Widget build(BuildContext context) {
    // Use a ConstrainedBox to allow the modal to expand up to 90% of the screen height if needed.
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle.
            Center(
              child: Container(
                width: 40,
                height: 4,
                color: Colors.grey,
                margin: const EdgeInsets.only(bottom: 16),
              ),
            ),
            // Only display the selection header.
            _buildSelectionHeader(),
            const SizedBox(height: 8),
            Expanded(
              child: Column(
                children: [
                  TabBar(
                    controller: _tabController,
                    onTap: (index) {
                      setState(() {
                        _selectedTabIndex = index;
                      });
                    },
                    tabs: const [
                      Tab(text: "Associated"),
                      Tab(text: "Existing"),
                      Tab(text: "New"),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // 1) Associated Tab
                        FutureBuilder<Map<String, dynamic>>(
                          future: _studentsFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }
                            if (snapshot.hasError) {
                              return const Center(
                                  child: Text("Error loading students"));
                            }
                            final List<Map<String, dynamic>> assoc =
                                (snapshot.data?["associated_students"]
                                        as List<dynamic>)
                                    .map((e) => e as Map<String, dynamic>)
                                    .toList();
                            return ListView.builder(
                              itemCount: assoc.length,
                              itemBuilder: (context, index) {
                                final student = assoc[index];
                                final alreadySelected = _selectedStudents
                                    .any((s) => s['id'] == student['id']);
                                return ListTile(
                                  title: Text(
                                    "${student['id']} - ${student['first_name']} ${student['last_name']}",
                                  ),
                                  subtitle:
                                      Text("Birthday: ${student['birthday']}"),
                                  trailing: alreadySelected
                                      ? const Icon(Icons.check,
                                          color: Colors.green)
                                      : null,
                                  onTap: () {
                                    if (!alreadySelected) {
                                      if (_selectedStudents.length <
                                          (widget.requiredCount ?? 999999)) {
                                        final newSelection = [
                                          ..._selectedStudents,
                                          student
                                        ];
                                        _updateSelection(newSelection);
                                      }
                                    } else {
                                      final newSelection = _selectedStudents
                                          .where(
                                              (s) => s['id'] != student['id'])
                                          .toList();
                                      _updateSelection(newSelection);
                                    }
                                  },
                                );
                              },
                            );
                          },
                        ),
                        // 2) Existing Tab (Search by ID)
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                TextField(
                                  controller: _studentIdController,
                                  decoration: const InputDecoration(
                                    labelText: "Enter Student ID",
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed: () async {
                                    final enteredId =
                                        _studentIdController.text.trim();
                                    if (enteredId.isNotEmpty) {
                                      // Dummy lookup logic.
                                      if (enteredId == "s3") {
                                        setState(() {
                                          _existingStudentConfirmation = {
                                            "id": "s3",
                                            "first_name": "Charlie",
                                            "last_name": "Brown",
                                            "birthday": "2008-03-20"
                                          };
                                        });
                                      } else {
                                        setState(() {
                                          _existingStudentConfirmation = null;
                                        });
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content:
                                                  Text("Student not found")),
                                        );
                                      }
                                    }
                                  },
                                  child: const Text("Check Student"),
                                ),
                                if (_existingStudentConfirmation != null)
                                  ListTile(
                                    title: Text(
                                      "${_existingStudentConfirmation!['id']} - ${_existingStudentConfirmation!['first_name']} ${_existingStudentConfirmation!['last_name']}",
                                    ),
                                    subtitle: Text(
                                        "Birthday: ${_existingStudentConfirmation!['birthday']}"),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.add),
                                      onPressed: () {
                                        if (_selectedStudents.length <
                                            (widget.requiredCount ?? 999999)) {
                                          final newSelection = [
                                            ..._selectedStudents,
                                            _existingStudentConfirmation!
                                          ];
                                          _updateSelection(newSelection);
                                          setState(() {
                                            _existingStudentConfirmation = null;
                                            _studentIdController.clear();
                                          });
                                        }
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        // 3) New Tab (Register a new student)
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                TextField(
                                  controller: _firstNameController,
                                  decoration: const InputDecoration(
                                    labelText: "First Name",
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _lastNameController,
                                  decoration: const InputDecoration(
                                    labelText: "Last Name",
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _birthdayController,
                                        readOnly: true,
                                        decoration: const InputDecoration(
                                          labelText: "Birthday",
                                          border: OutlineInputBorder(),
                                          hintText: "Select a date",
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.calendar_today),
                                      onPressed: _showBirthdayPicker,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed: () async {
                                    if (_firstNameController.text
                                            .trim()
                                            .isNotEmpty &&
                                        _lastNameController.text
                                            .trim()
                                            .isNotEmpty &&
                                        selectedBirthday != null) {
                                      try {
                                        final createdStudent =
                                            await _createStudent(
                                          _firstNameController.text.trim(),
                                          _lastNameController.text.trim(),
                                          _dateFormat.format(selectedBirthday!),
                                        );
                                        final newSelection = [
                                          ..._selectedStudents,
                                          createdStudent
                                        ];
                                        _updateSelection(newSelection);
                                        _firstNameController.clear();
                                        _lastNameController.clear();
                                        _birthdayController.clear();
                                        selectedBirthday = null;
                                        setState(() {
                                          _studentsFuture = _fetchStudents();
                                        });
                                        _tabController.animateTo(0);
                                      } catch (e) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              content: Text(
                                                  "Error creating student: $e")),
                                        );
                                      }
                                    }
                                  },
                                  child: const Text("Register Student"),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_isSelectionComplete)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      final checkoutDetails = _buildCheckoutDetails();
                      final serviceWithCheckout =
                          Map<String, dynamic>.from(widget.service)
                            ..['checkout_details'] = checkoutDetails;
                      CartService().addToCart(
                          serviceWithCheckout, _selectedStudents, currentPrice);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Added to cart")),
                      );
                      // Pop using the root navigator
                      Navigator.of(context, rootNavigator: true).pop();
                    },
                    child: const Text("Add to Cart"),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      final checkoutDetails = _buildCheckoutDetails();
                      final serviceWithCheckout =
                          Map<String, dynamic>.from(widget.service)
                            ..['checkout_details'] = checkoutDetails;
                      CartService().addToCart(
                          serviceWithCheckout, _selectedStudents, currentPrice);

                      // Pop the modal using the global navigator.
                      navigatorKey.currentState!.pop();

                      // Delay to ensure the modal is completely dismissed.
                      Future.delayed(const Duration(milliseconds: 100), () {
                        navigatorKey.currentState!.push(
                          MaterialPageRoute(
                            builder: (_) => CheckoutPage(
                              onBack: () => navigatorKey.currentState!.pop(),
                            ),
                          ),
                        );
                      });
                    },
                    child: const Text("Buy Now"),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
