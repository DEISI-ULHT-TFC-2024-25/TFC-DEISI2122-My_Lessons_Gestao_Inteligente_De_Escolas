import 'package:currency_picker/currency_picker.dart' as CurrencyPicker;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

const String baseUrl = 'http://127.0.0.1:8000';

// Initialize secure storage.
final FlutterSecureStorage storage = const FlutterSecureStorage();

// Function to get auth headers.
Future<Map<String, String>> getAuthHeaders() async {
  String? token = await storage.read(key: 'auth_token');
  if (token == null) {
    throw Exception("No auth token found");
  }
  return {
    'Authorization': 'Token $token',
    'Content-Type': 'application/json',
  };
}

// POST request to update pack price.
Future<Map<String, dynamic>> postPackData({
  String? schoolId,
  String? schoolName,
  required String packType,
  required int duration,
  int? numberOfPeople,
  int? numberOfClasses,
  required double price,
  required String expirationDate,
  required String currency,
}) async {
  final url = Uri.parse('$baseUrl/api/schools/update_pack_price/');
  final payload = {
    'school_id': schoolId,
    'school_name': schoolName,
    'pack_type': packType,
    'duration': duration,
    'number_of_people': numberOfPeople,
    'number_of_classes': numberOfClasses,
    'price': price,
    'expiration_date': expirationDate,
    'currency': currency,
  };

  final headers = await getAuthHeaders();
  final response = await http.post(
    url,
    headers: headers,
    body: jsonEncode(payload),
  );

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    throw Exception('Failed to update pack price: ${response.body}');
  }
}

// GET request to fetch school details.
Future<Map<String, dynamic>> fetchSchoolDetails() async {
  final url = Uri.parse('$baseUrl/api/schools/details/');
  final headers = await getAuthHeaders();
  final response = await http.get(url, headers: headers);

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    throw Exception('Failed to fetch school details');
  }
}

/// Compute the expiration date based on the selected time limit.
/// If timeLimit is "None", returns an empty string.
/// For "1 Month", "2 Months", "3 Months", or a custom value like "30 days",
/// this function adds the appropriate duration to DateTime.now() and returns the ISO8601 string.
String computeExpirationDate(String? timeLimit) {
  if (timeLimit == null || timeLimit.toLowerCase() == "none") {
    return "";
  }
  DateTime now = DateTime.now();
  if (timeLimit.toLowerCase() == "1 month") {
    DateTime exp = DateTime(now.year, now.month + 1, now.day);
    return exp.toIso8601String();
  } else if (timeLimit.toLowerCase() == "2 months") {
    DateTime exp = DateTime(now.year, now.month + 2, now.day);
    return exp.toIso8601String();
  } else if (timeLimit.toLowerCase() == "3 months") {
    DateTime exp = DateTime(now.year, now.month + 3, now.day);
    return exp.toIso8601String();
  } else if (timeLimit.toLowerCase().contains("days")) {
    int days = int.tryParse(timeLimit.split(" ")[0]) ?? 0;
    DateTime exp = now.add(Duration(days: days));
    return exp.toIso8601String();
  }
  return "";
}

Widget buildPaymentTypesWidget(Map<String, dynamic> paymentTypes) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: paymentTypes.entries.map<Widget>((roleEntry) {
      String role = roleEntry.key;
      Map<String, dynamic> roleData = roleEntry.value;
      return ExpansionTile(
        title: Text(role.toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        children: roleData.entries.map<Widget>((paymentEntry) {
          String paymentType = paymentEntry.key;
          var paymentDetails = paymentEntry.value;

          if (paymentType == "private lesson" &&
              paymentDetails is Map<String, dynamic>) {
            return ExpansionTile(
              title: Text("Private Lesson"),
              children: [
                ListTile(
                  title: Text("Commission: ${paymentDetails["commission"]} %"),
                ),
                ExpansionTile(
                  title: Text("Fixed Pricing"),
                  children: (paymentDetails["fixed"] as List<dynamic>)
                      .map<Widget>((fixedEntry) {
                    return ListTile(
                      title: Text("${fixedEntry["duration"]} min"),
                      subtitle: Text(
                          "Min students: ${fixedEntry["min_students"]}, Max students: ${fixedEntry["max_students"]}, Price: ${fixedEntry["price"]} €"),
                    );
                  }).toList(),
                )
              ],
            );
          } else {
            return ListTile(
              title: Text(paymentType),
              subtitle: Text(paymentDetails?.toString() ?? "N/A"),
            );
          }
        }).toList(),
      );
    }).toList(),
  );
}

/// Build an accordion-like widget to display pack_prices.
Widget buildPackPricesWidget(Map<String, dynamic> packPrices) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: packPrices.entries.map<Widget>((packTypeEntry) {
      String packType = packTypeEntry.key;
      Map<String, dynamic> durations = packTypeEntry.value;
      return ExpansionTile(
        title: Text(packType.toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        children: durations.entries.map<Widget>((durationEntry) {
          String duration = durationEntry.key.toString();
          var subData = durationEntry.value;
          if (packType == "private") {
            return ExpansionTile(
              title: Text("$duration min"),
              children: (subData as Map<String, dynamic>)
                  .entries
                  .map<Widget>((peopleEntry) {
                String people = peopleEntry.key.toString();
                var classesData = peopleEntry.value;
                return ExpansionTile(
                  title: Text("$people person(s)"),
                  children: (classesData as Map<String, dynamic>)
                      .entries
                      .map<Widget>((classEntry) {
                    String classes = classEntry.key.toString();
                    var details = classEntry.value;
                    return ListTile(
                      title: Text("$classes class(es)"),
                      subtitle: Text(
                          "Price: ${details['price']} €, Expires: ${details['expiration_date']}"),
                    );
                  }).toList(),
                );
              }).toList(),
            );
          } else {
            // group pack
            return ExpansionTile(
              title: Text("$duration min"),
              children: (subData as Map<String, dynamic>)
                  .entries
                  .map<Widget>((classEntry) {
                String classes = classEntry.key.toString();
                var details = classEntry.value;
                return ListTile(
                  title: Text("$classes class(es)"),
                  subtitle: Text(
                      "Price: ${details['price']} €, Expires: ${details['expiration_date']}"),
                );
              }).toList(),
            );
          }
        }).toList(),
      );
    }).toList(),
  );
}

class SchoolSetupModal extends StatefulWidget {
  const SchoolSetupModal({super.key});

  @override
  _SchoolSetupModalState createState() => _SchoolSetupModalState();
}

class _SchoolSetupModalState extends State<SchoolSetupModal> {
  @override
  void initState() {
    super.initState();
    fetchAndDisplaySchoolDetails();
  }

  final TextEditingController _schoolNameController = TextEditingController();
  Map<String, dynamic>? schoolDetails;

  // Fetch and update the school details in the state.
  Future<void> fetchAndDisplaySchoolDetails() async {
    try {
      final details = await fetchSchoolDetails();
      setState(() {
        schoolDetails = details;
        if (details['school_name'] != null) {
          _schoolNameController.text = details['school_name'];
        }
      });
    } catch (e) {
      print('Error fetching school details: $e');
    }
  }

  // Helper function to post payment type data.
  Future<Map<String, dynamic>> postPaymentTypeDataCustom(
      Map<String, dynamic> payload) async {
    final url = Uri.parse('$baseUrl/api/schools/update_payment_type/');
    final headers = await getAuthHeaders();
    final response =
        await http.post(url, headers: headers, body: jsonEncode(payload));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to update payment type: ${response.body}');
    }
  }

  /// The addPaymentType modal function.
  ///
  /// [context] - BuildContext for showing the modal.
  /// [schoolDetails] - A Map containing at least "school_id".
  /// [schoolNameController] - Controller for the school name (if needed).
  /// [refreshSchoolDetails] - A callback to refresh the details after an update.
  void addPaymentType(
    BuildContext context,
    Map<String, dynamic> schoolDetails,
    TextEditingController schoolNameController,
    Future<void> Function() refreshSchoolDetails,
  ) {
    // Local state variables.
    String? selectedRole;
    String? selectedPaymentMode; // "fixed" or "lesson"
    String? selectedLessonType; // "private" or "group"

    // Controllers for fixed mode and lesson mode.
    final TextEditingController fixedMonthlyRateController =
        TextEditingController();
    final TextEditingController commissionController = TextEditingController();

    // For lesson mode fixed pricing editing (only one fixed pricing entry allowed)
    bool editFixedPricing = false;
    final TextEditingController fixedPricingDurationController =
        TextEditingController();
    final TextEditingController fixedPricingMinStudentsController =
        TextEditingController();
    final TextEditingController fixedPricingMaxStudentsController =
        TextEditingController();
    final TextEditingController fixedPricingPriceController =
        TextEditingController();

    // Scroll controller for auto-scrolling.
    final ScrollController scrollController = ScrollController();

    // Helper function to update payment fields via separate API calls.
    Future<void> updatePaymentTypeFields() async {
      // For Fixed Monthly Rate mode.
      if (selectedPaymentMode == "fixed") {
        if (fixedMonthlyRateController.text.isEmpty) {
          throw Exception("Monthly rate is required.");
        }
        double monthlyRate =
            double.tryParse(fixedMonthlyRateController.text) ?? 0.0;
        String keyPath = "$selectedRole[fixed monthly rate]";
        Map<String, dynamic> payload = {
          'school_id': schoolDetails["school_id"]?.toString(),
          'key_path': keyPath,
          'new_value': monthlyRate,
        };
        await postPaymentTypeDataCustom(payload);
      }
      // For Lesson Based mode.
      else if (selectedPaymentMode == "lesson") {
        if (selectedLessonType == null) {
          throw Exception("Lesson type must be selected.");
        }
        // Update commission if provided.
        if (commissionController.text.isNotEmpty) {
          int commission = int.tryParse(commissionController.text) ?? 0;
          String keyPath = "$selectedRole[$selectedLessonType][commission]";
          Map<String, dynamic> payload = {
            'school_id': schoolDetails["school_id"]?.toString(),
            'key_path': keyPath,
            'new_value': commission,
          };
          await postPaymentTypeDataCustom(payload);
        }
        // Update fixed pricing if editing is enabled.
        if (editFixedPricing) {
          String keyPath = "$selectedRole[$selectedLessonType][fixed]";
          Map<String, dynamic> pricingEntry = {
            'duration': int.tryParse(fixedPricingDurationController.text),
            'min_students':
                int.tryParse(fixedPricingMinStudentsController.text),
            'max_students':
                int.tryParse(fixedPricingMaxStudentsController.text),
            'price': double.tryParse(fixedPricingPriceController.text),
          };
          await postPaymentTypeDataCustom({
            'school_id': schoolDetails["school_id"]?.toString(),
            'key_path': keyPath,
            'new_value': pricingEntry,
          });
        }
      }
    }

    // Display the modal bottom sheet.
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // Function to scroll to the bottom.
            void scrollToBottom() {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (scrollController.hasClients) {
                  scrollController.animateTo(
                    scrollController.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              });
            }

            // Determine if we can show the Save button.
            bool canSave = false;
            if (selectedPaymentMode == "fixed") {
              canSave = fixedMonthlyRateController.text.trim().isNotEmpty;
            } else if (selectedPaymentMode == "lesson") {
              bool commissionProvided =
                  commissionController.text.trim().isNotEmpty;
              bool fixedPricingProvided = false;
              if (editFixedPricing) {
                fixedPricingProvided = fixedPricingDurationController.text
                        .trim()
                        .isNotEmpty &&
                    fixedPricingMinStudentsController.text.trim().isNotEmpty &&
                    fixedPricingMaxStudentsController.text.trim().isNotEmpty &&
                    fixedPricingPriceController.text.trim().isNotEmpty;
              }
              canSave = commissionProvided || fixedPricingProvided;
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Modal header.
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Edit Payment Type",
                          style: GoogleFonts.lato(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Step 1: Select a Role (always visible).
                    Text(
                      "Select Role:",
                      style: GoogleFonts.lato(
                          fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            setModalState(() {
                              selectedRole = "admin";
                            });
                            scrollToBottom();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                selectedRole == "admin" ? Colors.blue : null,
                            foregroundColor:
                                selectedRole == "admin" ? Colors.white : null,
                          ),
                          child: const Text("Admin"),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            setModalState(() {
                              selectedRole = "instructor";
                            });
                            scrollToBottom();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: selectedRole == "instructor"
                                ? Colors.blue
                                : null,
                            foregroundColor: selectedRole == "instructor"
                                ? Colors.white
                                : null,
                          ),
                          child: const Text("Instructor"),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            setModalState(() {
                              selectedRole = "monitor";
                            });
                            scrollToBottom();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                selectedRole == "monitor" ? Colors.blue : null,
                            foregroundColor:
                                selectedRole == "monitor" ? Colors.white : null,
                          ),
                          child: const Text("Monitor"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Step 2: Select Payment Mode (visible only after role is selected).
                    if (selectedRole != null) ...[
                      Text(
                        "Select Payment Mode:",
                        style: GoogleFonts.lato(
                            fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              setModalState(() {
                                selectedPaymentMode = "fixed";
                                selectedLessonType = null;
                              });
                              scrollToBottom();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: selectedPaymentMode == "fixed"
                                  ? Colors.blue
                                  : null,
                              foregroundColor: selectedPaymentMode == "fixed"
                                  ? Colors.white
                                  : null,
                            ),
                            child: const Text("Fixed Monthly Rate"),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              setModalState(() {
                                selectedPaymentMode = "lesson";
                                fixedMonthlyRateController.clear();
                              });
                              scrollToBottom();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: selectedPaymentMode == "lesson"
                                  ? Colors.blue
                                  : null,
                              foregroundColor: selectedPaymentMode == "lesson"
                                  ? Colors.white
                                  : null,
                            ),
                            child: const Text("Lesson Based"),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    // Step 3: Inputs based on payment mode.
                    if (selectedPaymentMode == "fixed") ...[
                      // For fixed mode, show monthly rate input.
                      TextField(
                        controller: fixedMonthlyRateController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Monthly Rate",
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (val) {
                          // As soon as user types, update state and scroll to bottom.
                          setModalState(() {});
                          scrollToBottom();
                        },
                      ),
                    ],
                    if (selectedPaymentMode == "lesson") ...[
                      // Step 3a: Select Lesson Type.
                      Text(
                        "Select Lesson Type:",
                        style: GoogleFonts.lato(
                            fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              setModalState(() {
                                selectedLessonType = "private";
                              });
                              scrollToBottom();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: selectedLessonType == "private"
                                  ? Colors.blue
                                  : null,
                              foregroundColor: selectedLessonType == "private"
                                  ? Colors.white
                                  : null,
                            ),
                            child: const Text("Private"),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              setModalState(() {
                                selectedLessonType = "group";
                              });
                              scrollToBottom();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: selectedLessonType == "group"
                                  ? Colors.blue
                                  : null,
                              foregroundColor: selectedLessonType == "group"
                                  ? Colors.white
                                  : null,
                            ),
                            child: const Text("Group"),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Step 3b: Commission input (visible only after lesson type is selected).
                      if (selectedLessonType != null) ...[
                        Text(
                          "Commission Percentage (0-100):",
                          style: GoogleFonts.lato(
                              fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: commissionController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: "Commission %",
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (val) {
                            setModalState(() {});
                            scrollToBottom();
                          },
                        ),
                        const SizedBox(height: 16),
                        // Step 3c: Fixed Pricing Editing for Lesson mode.
                        ElevatedButton(
                          onPressed: () {
                            setModalState(() {
                              editFixedPricing = !editFixedPricing;
                            });
                            scrollToBottom();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                editFixedPricing ? Colors.blue : null,
                            foregroundColor:
                                editFixedPricing ? Colors.white : null,
                          ),
                          child: Text(editFixedPricing
                              ? "Hide Fixed Pricing"
                              : "Edit Fixed Pricing"),
                        ),
                        const SizedBox(height: 16),
                        if (editFixedPricing) ...[
                          // Fixed pricing inputs arranged in a 2x2 grid.
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              SizedBox(
                                width:
                                    (MediaQuery.of(context).size.width - 32) /
                                            2 -
                                        8,
                                child: TextField(
                                  controller: fixedPricingDurationController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: "Duration (min)",
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (val) {
                                    setModalState(() {});
                                    scrollToBottom();
                                  },
                                ),
                              ),
                              SizedBox(
                                width:
                                    (MediaQuery.of(context).size.width - 32) /
                                            2 -
                                        8,
                                child: TextField(
                                  controller: fixedPricingMinStudentsController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: "Min Students",
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (val) {
                                    setModalState(() {});
                                    scrollToBottom();
                                  },
                                ),
                              ),
                              SizedBox(
                                width:
                                    (MediaQuery.of(context).size.width - 32) /
                                            2 -
                                        8,
                                child: TextField(
                                  controller: fixedPricingMaxStudentsController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: "Max Students",
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (val) {
                                    setModalState(() {});
                                    scrollToBottom();
                                  },
                                ),
                              ),
                              SizedBox(
                                width:
                                    (MediaQuery.of(context).size.width - 32) /
                                            2 -
                                        8,
                                child: TextField(
                                  controller: fixedPricingPriceController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: "Price",
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (val) {
                                    setModalState(() {});
                                    scrollToBottom();
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ],
                    const SizedBox(height: 24),
                    // Final Save Button (only visible when required fields are filled).
                    if (canSave)
                      Center(
                        child: ElevatedButton(
                          onPressed: () async {
                            try {
                              await updatePaymentTypeFields();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        "Payment type updated successfully!")),
                              );
                              await refreshSchoolDetails();
                              Navigator.pop(context);
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        "Failed to update payment type: $e")),
                              );
                            }
                          },
                          child: const Text("Save Payment Type"),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void addPack() {
    // Require that a school name is entered.
    if (_schoolNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please input a school name first.")),
      );
      return;
    }

    // Variables for selected values
    String? selectedType;
    int? selectedDuration;
    int? selectedPeople;
    int? selectedClasses;
    String? selectedTimeLimit;
    String selectedCurrency = "EUR"; // Default is EUR

    // Controllers for custom inputs
    final TextEditingController customDurationController =
        TextEditingController();
    final TextEditingController customPeopleController =
        TextEditingController();
    final TextEditingController customClassesController =
        TextEditingController();
    final TextEditingController customTimeLimitController =
        TextEditingController();
    final TextEditingController priceController = TextEditingController();

    // Create a ScrollController to auto-scroll when new fields appear
    final ScrollController scrollController = ScrollController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // Helper to scroll to the bottom
            void scrollToBottom() {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (scrollController.hasClients) {
                  scrollController.animateTo(
                    scrollController.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with back button
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Edit Pack",
                            style: GoogleFonts.lato(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Step 1: Pack Type
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          "Select Pack Type:",
                          style: GoogleFonts.lato(
                              fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              setModalState(() {
                                selectedType = "private";
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: selectedType == "private"
                                  ? Colors.blue
                                  : null,
                              foregroundColor: selectedType == "private"
                                  ? Colors.white
                                  : null,
                            ),
                            child: const Text("Private"),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              setModalState(() {
                                selectedType = "group";
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  selectedType == "group" ? Colors.blue : null,
                              foregroundColor:
                                  selectedType == "group" ? Colors.white : null,
                            ),
                            child: const Text("Group"),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Step 2: Duration
                      if (selectedType != null) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            "Duration (minutes):",
                            style: GoogleFonts.lato(
                                fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                setModalState(() {
                                  selectedDuration = 30;
                                  customDurationController.clear();
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    selectedDuration == 30 ? Colors.blue : null,
                                foregroundColor: selectedDuration == 30
                                    ? Colors.white
                                    : null,
                              ),
                              child: const Text("30"),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                setModalState(() {
                                  selectedDuration = 60;
                                  customDurationController.clear();
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    selectedDuration == 60 ? Colors.blue : null,
                                foregroundColor: selectedDuration == 60
                                    ? Colors.white
                                    : null,
                              ),
                              child: const Text("60"),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                setModalState(() {
                                  selectedDuration = 90;
                                  customDurationController.clear();
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    selectedDuration == 90 ? Colors.blue : null,
                                foregroundColor: selectedDuration == 90
                                    ? Colors.white
                                    : null,
                              ),
                              child: const Text("90"),
                            ),
                            Container(
                              width: 80,
                              child: TextField(
                                controller: customDurationController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: "Other",
                                  contentPadding: const EdgeInsets.symmetric(
                                      vertical: 12, horizontal: 16),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                onChanged: (value) {
                                  if (value.isNotEmpty) {
                                    setModalState(() {
                                      selectedDuration = int.tryParse(value);
                                    });
                                    scrollToBottom();
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Step 3: Number of People
                      if (selectedDuration != null) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            "Number of People:",
                            style: GoogleFonts.lato(
                                fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                setModalState(() {
                                  selectedPeople = 1;
                                  customPeopleController.clear();
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    selectedPeople == 1 ? Colors.blue : null,
                                foregroundColor:
                                    selectedPeople == 1 ? Colors.white : null,
                              ),
                              child: const Text("1"),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                setModalState(() {
                                  selectedPeople = 2;
                                  customPeopleController.clear();
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    selectedPeople == 2 ? Colors.blue : null,
                                foregroundColor:
                                    selectedPeople == 2 ? Colors.white : null,
                              ),
                              child: const Text("2"),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                setModalState(() {
                                  selectedPeople = 3;
                                  customPeopleController.clear();
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    selectedPeople == 3 ? Colors.blue : null,
                                foregroundColor:
                                    selectedPeople == 3 ? Colors.white : null,
                              ),
                              child: const Text("3"),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                setModalState(() {
                                  selectedPeople = 4;
                                  customPeopleController.clear();
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    selectedPeople == 4 ? Colors.blue : null,
                                foregroundColor:
                                    selectedPeople == 4 ? Colors.white : null,
                              ),
                              child: const Text("4"),
                            ),
                            Container(
                              width: 80,
                              child: TextField(
                                controller: customPeopleController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: "Other",
                                  contentPadding: const EdgeInsets.symmetric(
                                      vertical: 12, horizontal: 16),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                onChanged: (value) {
                                  if (value.isNotEmpty) {
                                    setModalState(() {
                                      selectedPeople = int.tryParse(value);
                                    });
                                    scrollToBottom();
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Step 4: Number of Classes
                      if (selectedPeople != null) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            "Number of Classes:",
                            style: GoogleFonts.lato(
                                fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                setModalState(() {
                                  selectedClasses = 1;
                                  customClassesController.clear();
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    selectedClasses == 1 ? Colors.blue : null,
                                foregroundColor:
                                    selectedClasses == 1 ? Colors.white : null,
                              ),
                              child: const Text("1"),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                setModalState(() {
                                  selectedClasses = 4;
                                  customClassesController.clear();
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    selectedClasses == 4 ? Colors.blue : null,
                                foregroundColor:
                                    selectedClasses == 4 ? Colors.white : null,
                              ),
                              child: const Text("4"),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                setModalState(() {
                                  selectedClasses = 8;
                                  customClassesController.clear();
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    selectedClasses == 8 ? Colors.blue : null,
                                foregroundColor:
                                    selectedClasses == 8 ? Colors.white : null,
                              ),
                              child: const Text("8"),
                            ),
                            Container(
                              width: 80,
                              child: TextField(
                                controller: customClassesController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: "Other",
                                  contentPadding: const EdgeInsets.symmetric(
                                      vertical: 12, horizontal: 16),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                onChanged: (value) {
                                  if (value.isNotEmpty) {
                                    setModalState(() {
                                      selectedClasses = int.tryParse(value);
                                    });
                                    scrollToBottom();
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Step 5: Time Limit (Before Price)
                      if (selectedClasses != null) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            "Time Limit:",
                            style: GoogleFonts.lato(
                                fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                setModalState(() {
                                  selectedTimeLimit = "None";
                                  customTimeLimitController.clear();
                                });
                                scrollToBottom();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: selectedTimeLimit == "None"
                                    ? Colors.blue
                                    : null,
                                foregroundColor: selectedTimeLimit == "None"
                                    ? Colors.white
                                    : null,
                              ),
                              child: const Text("None"),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                setModalState(() {
                                  selectedTimeLimit = "1 month";
                                  customTimeLimitController.clear();
                                });
                                scrollToBottom();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: selectedTimeLimit == "1 month"
                                    ? Colors.blue
                                    : null,
                                foregroundColor: selectedTimeLimit == "1 month"
                                    ? Colors.white
                                    : null,
                              ),
                              child: const Text("1 Month"),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                setModalState(() {
                                  selectedTimeLimit = "2 months";
                                  customTimeLimitController.clear();
                                });
                                scrollToBottom();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: selectedTimeLimit == "2 months"
                                    ? Colors.blue
                                    : null,
                                foregroundColor: selectedTimeLimit == "2 months"
                                    ? Colors.white
                                    : null,
                              ),
                              child: const Text("2 Months"),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                setModalState(() {
                                  selectedTimeLimit = "3 months";
                                  customTimeLimitController.clear();
                                });
                                scrollToBottom();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: selectedTimeLimit == "3 months"
                                    ? Colors.blue
                                    : null,
                                foregroundColor: selectedTimeLimit == "3 months"
                                    ? Colors.white
                                    : null,
                              ),
                              child: const Text("3 Months"),
                            ),
                            Container(
                              width: 80,
                              child: TextField(
                                controller: customTimeLimitController,
                                keyboardType: TextInputType.text,
                                decoration: InputDecoration(
                                  labelText: "Other",
                                  contentPadding: const EdgeInsets.symmetric(
                                      vertical: 12, horizontal: 16),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                onChanged: (value) {
                                  if (value.isNotEmpty) {
                                    setModalState(() {
                                      selectedTimeLimit = "$value days";
                                    });
                                    scrollToBottom();
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Step 6: Price with Currency Picker
                      if (selectedTimeLimit != null) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            "Price:",
                            style: GoogleFonts.lato(
                                fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: priceController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: "Price",
                                  contentPadding: const EdgeInsets.symmetric(
                                      vertical: 12, horizontal: 16),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                onChanged: (value) {
                                  setModalState(() {});
                                  scrollToBottom();
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: () {
                                CurrencyPicker.showCurrencyPicker(
                                  context: context,
                                  showFlag: true,
                                  showCurrencyName: true,
                                  onSelect: (currency) {
                                    setModalState(() {
                                      selectedCurrency = currency.code;
                                    });
                                  },
                                );
                              },
                              child: Text(selectedCurrency),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Final Save Button
                      if (selectedType != null &&
                          selectedDuration != null &&
                          selectedPeople != null &&
                          selectedClasses != null &&
                          (priceController.text.isNotEmpty) &&
                          selectedTimeLimit != null)
                        Center(
                          child: ElevatedButton(
                            onPressed: () async {
                              try {
                                // Compute expiration date based on the selected time limit.
                                final String expirationDate =
                                    computeExpirationDate(selectedTimeLimit);
                                final result = await postPackData(
                                  schoolId:
                                      schoolDetails!["school_id"]?.toString(),
                                  schoolName: _schoolNameController.text,
                                  packType: selectedType!,
                                  duration: selectedDuration!,
                                  numberOfPeople: selectedPeople,
                                  numberOfClasses: selectedClasses,
                                  price: double.parse(priceController.text),
                                  expirationDate: expirationDate,
                                  currency: selectedCurrency,
                                );
                                print('Pack updated: $result');
                                // Instead of closing the modal, refresh the school details so the new info shows.
                                await fetchAndDisplaySchoolDetails();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text("Pack updated successfully!")),
                                );
                                Navigator.pop(context);
                              } catch (e) {
                                print('Error updating pack price: $e');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          'Failed to update pack price: $e')),
                                );
                              }
                            },
                            child: const Text("Salvar Pacote"),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // Adjust height as needed.
      height: MediaQuery.of(context).size.height * 0.6,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "School Settings",
            style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _schoolNameController,
            decoration: InputDecoration(
              labelText: "Nome da Escola",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.add, color: Colors.blue),
            title: const Text("Edit Pack"),
            onTap: () {
              // Ensure a school name has been entered.
              if (_schoolNameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text("Please input a school name first.")),
                );
                return;
              }
              addPack();
            },
          ),
          ListTile(
            leading: const Icon(Icons.add, color: Colors.blue),
            title: const Text("Edit Payment Type"),
            onTap: () {
              // Ensure a school name has been entered.
              if (_schoolNameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text("Please input a school name first.")),
                );
                return;
              }
              addPaymentType(context, schoolDetails!, _schoolNameController,
                  fetchAndDisplaySchoolDetails);
            },
          ),
          const SizedBox(height: 16),
          if (schoolDetails != null)
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "PACKS",
                      style: GoogleFonts.lato(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    // Use our accordion widget to display pack_prices
                    if (schoolDetails!['pack_prices'] != null)
                      buildPackPricesWidget(schoolDetails!['pack_prices'])
                    else
                      const Text("No pack prices available."),
                    Text(
                      "STAFF PAYMENTS",
                      style: GoogleFonts.lato(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    // Use our accordion widget to display pack_prices
                    if (schoolDetails!['payment_types'] != null)
                      buildPaymentTypesWidget(schoolDetails!['payment_types'])
                    else
                      const Text("No payment types available."),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

void showSchoolSetupModal(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => const SchoolSetupModal(),
  );
}
