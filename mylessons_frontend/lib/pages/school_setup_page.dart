import 'dart:convert';
import 'package:currency_picker/currency_picker.dart' as CurrencyPicker;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart'; // Assuming getAuthHeaders() is defined here.

const String baseUrl = 'http://127.0.0.1:8000';
// Initialize secure storage.
final FlutterSecureStorage storage = const FlutterSecureStorage();

/// POST request to update payment type.
Future<Map<String, dynamic>> postPaymentTypeData({
  String? schoolId,
  String? schoolName,
  required String keyPath,
  required dynamic newValue,
}) async {
  final url = Uri.parse('$baseUrl/api/schools/update_payment_type/');
  final payload = {
    'school_id': schoolId,
    'school_name': schoolName,
    'key_path': keyPath,
    'new_value': newValue,
  };
  final headers = await getAuthHeaders();
  final response =
      await http.post(url, headers: headers, body: jsonEncode(payload));
  if (response.statusCode == 200) return jsonDecode(response.body);
  throw Exception('Failed to update payment type: ${response.body}');
}

/// GET request to fetch school details.
Future<Map<String, dynamic>> fetchSchoolDetails() async {
  final url = Uri.parse('$baseUrl/api/schools/details/');
  final headers = await getAuthHeaders();
  final response = await http.get(url, headers: headers);
  if (response.statusCode == 200) return jsonDecode(response.body);
  throw Exception('Failed to fetch school details');
}

/// Compute the expiration date based on the selected time limit.
String computeExpirationDate(String? timeLimit) {
  if (timeLimit == null || timeLimit.toLowerCase() == "none") return "";
  DateTime now = DateTime.now();
  if (timeLimit.toLowerCase() == "1 month") {
    return DateTime(now.year, now.month + 1, now.day).toIso8601String();
  }
  if (timeLimit.toLowerCase() == "2 months") {
    return DateTime(now.year, now.month + 2, now.day).toIso8601String();
  }
  if (timeLimit.toLowerCase() == "3 months") {
    return DateTime(now.year, now.month + 3, now.day).toIso8601String();
  }
  if (timeLimit.toLowerCase().contains("days")) {
    int days = int.tryParse(timeLimit.split(" ")[0]) ?? 0;
    return now.add(Duration(days: days)).toIso8601String();
  }
  return "";
}

/// Helper function to format a pricing option as a string.
String formatPricingOption(Map pricingOption) {
  return pricingOption.entries.map((e) => "${e.key}: ${e.value}").join(", ");
}

/// A fully flexible accordion builder.
Widget buildFlexibleAccordion(String key, dynamic value) {
  if (key == "pricing_options" && value is List) {
    List<Widget> children = value.map<Widget>((item) {
      if (item is Map) {
        return ListTile(title: Text(formatPricingOption(item)));
      } else {
        return ListTile(title: Text(item.toString()));
      }
    }).toList();
    return ExpansionTile(
      title: Text(key, style: const TextStyle(fontWeight: FontWeight.bold)),
      children: children,
    );
  }
  if (value is Map) {
    List<Widget> children = value.entries
        .map((entry) => buildFlexibleAccordion(entry.key, entry.value))
        .toList();
    return ExpansionTile(
      title: Text(key, style: const TextStyle(fontWeight: FontWeight.bold)),
      children: children,
    );
  }
  if (value is List) {
    if (value.isEmpty) {
      return ListTile(title: Text(key), subtitle: const Text("Empty list"));
    }
    bool allPrimitive = value.every((item) => item is! Map && item is! List);
    if (allPrimitive) {
      List<Widget> children =
          value.map((item) => ListTile(title: Text(item.toString()))).toList();
      return ExpansionTile(
          title: Text(key, style: const TextStyle(fontWeight: FontWeight.bold)),
          children: children);
    }
    List<Widget> children = value.map<Widget>((item) {
      if (item is Map && item.containsKey("name")) {
        return buildFlexibleAccordion(item["name"].toString(), item);
      } else {
        return buildFlexibleAccordion("Item", item);
      }
    }).toList();
    return ExpansionTile(
        title: Text(key, style: const TextStyle(fontWeight: FontWeight.bold)),
        children: children);
  }
  return ListTile(title: Text(key), subtitle: Text(value.toString()));
}

/// Helper function to build the flexible structure from any data type.
Widget buildFlexibleStructure(dynamic data) {
  if (data is Map) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: data.entries
          .map((e) => buildFlexibleAccordion(e.key, e.value))
          .toList(),
    );
  } else if (data is List) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: data.map((e) {
        if (e is Map && e.containsKey("name")) {
          return buildFlexibleAccordion(e["name"].toString(), e);
        } else {
          return buildFlexibleAccordion("Item", e);
        }
      }).toList(),
    );
  }
  return Text(data.toString());
}

/// --- PAYMENT TYPES IMPLEMENTATION (Original Accordion Version) --- ///

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
              title: const Text("Private Lesson"),
              children: [
                ListTile(
                  title: Text("Commission: ${paymentDetails["commission"]} %"),
                ),
                ExpansionTile(
                  title: const Text("Fixed Pricing"),
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

/// Shows the Edit Payment Type modal (Original version).
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
  // For lesson mode fixed pricing editing.
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
    if (selectedPaymentMode == "fixed") {
      if (fixedMonthlyRateController.text.isEmpty) {
        throw Exception("Monthly rate is required.");
      }
      double monthlyRate =
          double.tryParse(fixedMonthlyRateController.text) ?? 0.0;
      String keyPath = "$selectedRole[fixed monthly rate]";
      await postPaymentTypeData(
        schoolId: schoolDetails["school_id"]?.toString(),
        schoolName: schoolNameController.text,
        keyPath: keyPath,
        newValue: monthlyRate,
      );
    } else if (selectedPaymentMode == "lesson") {
      if (selectedLessonType == null) {
        throw Exception("Lesson type must be selected.");
      }
      if (commissionController.text.isNotEmpty) {
        int commission = int.tryParse(commissionController.text) ?? 0;
        String keyPath = "$selectedRole[$selectedLessonType][commission]";
        await postPaymentTypeData(
          schoolId: schoolDetails["school_id"]?.toString(),
          schoolName: schoolNameController.text,
          keyPath: keyPath,
          newValue: commission,
        );
      }
      if (editFixedPricing) {
        String keyPath = "$selectedRole[$selectedLessonType][fixed]";
        Map<String, dynamic> pricingEntry = {
          'duration': int.tryParse(fixedPricingDurationController.text),
          'min_students': int.tryParse(fixedPricingMinStudentsController.text),
          'max_students': int.tryParse(fixedPricingMaxStudentsController.text),
          'price': double.tryParse(fixedPricingPriceController.text),
        };
        await postPaymentTypeData(
          schoolId: schoolDetails["school_id"]?.toString(),
          schoolName: schoolNameController.text,
          keyPath: keyPath,
          newValue: pricingEntry,
        );
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
                  // Step 1: Select a Role.
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
                          backgroundColor:
                              selectedRole == "instructor" ? Colors.blue : null,
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
                  // Step 2: Select Payment Mode.
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
                    TextField(
                      controller: fixedMonthlyRateController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Monthly Rate",
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) {
                        setModalState(() {});
                        scrollToBottom();
                      },
                    ),
                  ],
                  if (selectedPaymentMode == "lesson") ...[
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
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            SizedBox(
                              width:
                                  (MediaQuery.of(context).size.width - 32) / 2 -
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
                                  (MediaQuery.of(context).size.width - 32) / 2 -
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
                                  (MediaQuery.of(context).size.width - 32) / 2 -
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
                                  (MediaQuery.of(context).size.width - 32) / 2 -
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
                                      'Failed to update payment type: $e')),
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

/// --- SERVICES IMPLEMENTATION (Cards with Edit/Delete Buttons) --- ///

/// Deletes a service via API.
Future<void> deleteService(String schoolId, String serviceId) async {
  final url = Uri.parse('$baseUrl/api/schools/$schoolId/services/delete/');
  final payload = {'id': serviceId};
  final headers = await getAuthHeaders();
  final response =
      await http.post(url, headers: headers, body: jsonEncode(payload));
  if (response.statusCode != 200) {
    throw Exception('Failed to delete service: ${response.body}');
  }
}

/// Shows the Add/Edit Service modal.
Future<void> addEditService(
  BuildContext context,
  Map<String, dynamic> schoolDetails, {
  Map<String, dynamic>? service, // If provided, we're editing.
}) async {
  // Basic field controllers.
  final TextEditingController nameController =
      TextEditingController(text: service?['name'] ?? '');
  final TextEditingController descriptionController =
      TextEditingController(text: service?['description'] ?? '');
  final TextEditingController photosController = TextEditingController(
      text: service?['photos'] != null ? service!['photos'].join(", ") : '');
  final TextEditingController benefitsController = TextEditingController(
      text:
          service?['benefits'] != null ? service!['benefits'].join(", ") : '');
  final TextEditingController sportsController = TextEditingController(
      text: service?['sports'] != null ? service!['sports'].join(", ") : '');
  final TextEditingController locationsController = TextEditingController(
      text: service?['locations'] != null
          ? service!['locations'].join(", ")
          : "");

  // Service type selection.
  String? selectedType; // "pack" or "activity"
  if (service != null && service['type'] != null) {
    if (service['type'].containsKey('pack')) {
      selectedType = 'pack';
    } else if (service['type'].containsKey('activity')) selectedType = 'activity';
  }
  // For activity, a simple text field.
  final TextEditingController typeValueController = TextEditingController(
      text: selectedType == 'activity'
          ? service?['type']?['activity'] ?? ''
          : '');

  // For pack, additional fields.
  String? selectedPackOption; // "private" or "group"
  if (selectedType == 'pack' &&
      service != null &&
      service['type'] != null &&
      service['type']['pack'] != null) {
    selectedPackOption = service['type']['pack'];
  }
  // Use a currency picker button.
  final TextEditingController currencyController =
      TextEditingController(text: service?['currency'] ?? '');
  List<Map<String, dynamic>> pricingOptions = [];
  if (service != null &&
      service['details'] != null &&
      service['details']['pricing_options'] != null) {
    pricingOptions =
        List<Map<String, dynamic>>.from(service['details']['pricing_options']);
  }

  // Helper: show dialog to add/edit a pricing option.
  Future<void> showPricingOptionDialog(
      {Map<String, dynamic>? pricingOption,
      required void Function(Map<String, dynamic>) onSave}) async {
    final TextEditingController durationController = TextEditingController(
        text:
            pricingOption != null ? pricingOption['duration']?.toString() : '');
    final TextEditingController peopleController = TextEditingController(
        text: pricingOption != null ? pricingOption['people']?.toString() : '');
    final TextEditingController classesController = TextEditingController(
        text:
            pricingOption != null ? pricingOption['classes']?.toString() : '');
    final TextEditingController timeLimitController = TextEditingController(
        text: pricingOption != null
            ? pricingOption['time_limit']?.toString()
            : '');
    final TextEditingController priceController = TextEditingController(
        text: pricingOption != null ? pricingOption['price']?.toString() : '');

    await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(pricingOption == null
                ? "Add Pricing Option"
                : "Edit Pricing Option"),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: durationController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                        labelText: "Duration (min)",
                        border: OutlineInputBorder()),
                  ),
                  SizedBox(height: 8),
                  TextField(
                    controller: peopleController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                        labelText: "Number of People",
                        border: OutlineInputBorder()),
                  ),
                  SizedBox(height: 8),
                  TextField(
                    controller: classesController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                        labelText: "Number of Classes",
                        border: OutlineInputBorder()),
                  ),
                  SizedBox(height: 8),
                  TextField(
                    controller: timeLimitController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                        labelText: "Time Limit (days)",
                        border: OutlineInputBorder()),
                  ),
                  SizedBox(height: 8),
                  TextField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                        labelText: "Price", border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Cancel")),
              ElevatedButton(
                onPressed: () {
                  Map<String, dynamic> newOption = {
                    "duration": int.tryParse(durationController.text) ?? 0,
                    "people": int.tryParse(peopleController.text) ?? 0,
                    "classes": int.tryParse(classesController.text) ?? 0,
                    "time_limit": int.tryParse(timeLimitController.text) ?? 0,
                    "price": double.tryParse(priceController.text) ?? 0.0,
                  };
                  onSave(newOption);
                  Navigator.pop(context);
                },
                child: Text("Save"),
              ),
            ],
          );
        });
  }

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (context) {
      return StatefulBuilder(builder: (context, setModalState) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Modal header.
                Row(
                  children: [
                    IconButton(
                        icon: Icon(Icons.arrow_back),
                        onPressed: () => Navigator.pop(context)),
                    SizedBox(width: 8),
                    Text(
                      service == null ? "Add Service" : "Edit Service",
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                // Basic fields.
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                      labelText: "Service Name", border: OutlineInputBorder()),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: InputDecoration(
                      labelText: "Description", border: OutlineInputBorder()),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: photosController,
                  decoration: InputDecoration(
                      labelText: "Photos (comma separated URLs)",
                      border: OutlineInputBorder()),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: benefitsController,
                  decoration: InputDecoration(
                      labelText: "Benefits (comma separated)",
                      border: OutlineInputBorder()),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: sportsController,
                  decoration: InputDecoration(
                      labelText: "Sports (comma separated)",
                      border: OutlineInputBorder()),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: locationsController,
                  decoration: InputDecoration(
                      labelText: "Locations (comma separated)",
                      border: OutlineInputBorder()),
                ),
                SizedBox(height: 16),
                // Service Type selection.
                Text("Service Type",
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        setModalState(() {
                          selectedType = 'pack';
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            selectedType == 'pack' ? Colors.blue : null,
                        foregroundColor:
                            selectedType == 'pack' ? Colors.white : null,
                      ),
                      child: Text("Pack"),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        setModalState(() {
                          selectedType = 'activity';
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            selectedType == 'activity' ? Colors.blue : null,
                        foregroundColor:
                            selectedType == 'activity' ? Colors.white : null,
                      ),
                      child: Text("Activity"),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                if (selectedType == 'activity')
                  TextField(
                    controller: typeValueController,
                    decoration: InputDecoration(
                        labelText: "Activity Value",
                        border: OutlineInputBorder()),
                  ),
                if (selectedType == 'pack') ...[
                  // Choose pack option.
                  Text("Select Pack Option",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          setModalState(() {
                            selectedPackOption = 'private';
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: selectedPackOption == 'private'
                              ? Colors.blue
                              : null,
                          foregroundColor: selectedPackOption == 'private'
                              ? Colors.white
                              : null,
                        ),
                        child: Text("Private"),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          setModalState(() {
                            selectedPackOption = 'group';
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: selectedPackOption == 'group'
                              ? Colors.blue
                              : null,
                          foregroundColor: selectedPackOption == 'group'
                              ? Colors.white
                              : null,
                        ),
                        child: Text("Group"),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  // Currency picker.
                  ElevatedButton(
                    onPressed: () {
                      CurrencyPicker.showCurrencyPicker(
                        context: context,
                        showFlag: true,
                        showCurrencyName: true,
                        showCurrencyCode: true,
                        onSelect: (currency) {
                          setModalState(() {
                            currencyController.text = currency.code;
                          });
                        },
                      );
                    },
                    child: Text(currencyController.text.isEmpty
                        ? "Select Currency"
                        : currencyController.text),
                  ),
                  SizedBox(height: 16),
                  // Pricing Options.
                  Text("Pricing Options",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Column(
                    children: pricingOptions.map((option) {
                      return ListTile(
                        title: Text(
                            "Duration: ${option['duration']} min, People: ${option['people']}, Classes: ${option['classes']}, Time Limit: ${option['time_limit']} days, Price: ${option['price']}"),
                        trailing: IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setModalState(() {
                              pricingOptions.remove(option);
                            });
                          },
                        ),
                        onTap: () async {
                          await showPricingOptionDialog(
                              pricingOption: option,
                              onSave: (newOption) {
                                setModalState(() {
                                  int index = pricingOptions.indexOf(option);
                                  pricingOptions[index] = newOption;
                                });
                              });
                        },
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () async {
                      await showPricingOptionDialog(onSave: (newOption) {
                        setModalState(() {
                          pricingOptions.add(newOption);
                        });
                      });
                    },
                    child: Text("Add Pricing Option"),
                  ),
                ],
                SizedBox(height: 24),
                Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      // Build payload.
                      Map<String, dynamic> payload = {
                        "name": nameController.text,
                        "description": descriptionController.text,
                        "photos": photosController.text
                            .split(',')
                            .map((s) => s.trim())
                            .where((s) => s.isNotEmpty)
                            .toList(),
                        "benefits": benefitsController.text
                            .split(',')
                            .map((s) => s.trim())
                            .where((s) => s.isNotEmpty)
                            .toList(),
                        "sports": sportsController.text
                            .split(',')
                            .map((s) => s.trim())
                            .where((s) => s.isNotEmpty)
                            .toList(),
                        "locations": locationsController.text
                            .split(',')
                            .map((s) => s.trim())
                            .where((s) => s.isNotEmpty)
                            .toList(),
                      };

                      // Include service id if editing an existing service.
                      if (service != null && service["id"] != null) {
                        payload["id"] = service["id"];
                      }

                      if (selectedType == 'pack') {
                        payload["type"] = {"pack": selectedPackOption ?? ""};
                        payload["currency"] = currencyController.text;
                        payload["details"] = {
                          "pricing_options": pricingOptions
                        };
                      } else if (selectedType == 'activity') {
                        payload["type"] = {
                          "activity": typeValueController.text
                        };
                      }
                      try {
                        final response = await http.post(
                          Uri.parse(
                              '$baseUrl/api/schools/${schoolDetails["school_id"]}/services/add_edit/'),
                          headers: await getAuthHeaders(),
                          body: jsonEncode(payload),
                        );
                        if (response.statusCode == 200) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text("Service updated successfully!")));
                          Navigator.pop(context);
                        } else {
                          throw Exception('Error: ${response.body}');
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text("Failed to update service: $e")));
                      }
                    },
                    child:
                        Text(service == null ? "Add Service" : "Save Service"),
                  ),
                ),
                // Delete button for whole service (if editing an existing service).
                if (service != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Center(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          bool confirmed = await showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text("Delete Service"),
                              content: Text(
                                  "Are you sure you want to delete this service?"),
                              actions: [
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: Text("Cancel")),
                                ElevatedButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: Text("Delete")),
                              ],
                            ),
                          );
                          if (confirmed) {
                            try {
                              await deleteService(
                                  schoolDetails["school_id"].toString(),
                                  service["id"]);
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          "Service deleted successfully")));
                              Navigator.pop(context);
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          "Failed to delete service: $e")));
                            }
                          }
                        },
                        icon: Icon(Icons.delete),
                        label: Text("Delete Service"),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      });
    },
  );
}

class SchoolSetupPage extends StatefulWidget {
  const SchoolSetupPage({super.key});

  @override
  _SchoolSetupPageState createState() => _SchoolSetupPageState();
}

class _SchoolSetupPageState extends State<SchoolSetupPage> {
  final TextEditingController _schoolNameController = TextEditingController();
  Map<String, dynamic>? schoolDetails;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchAndDisplaySchoolDetails();
  }

  Future<void> fetchAndDisplaySchoolDetails() async {
    try {
      final details = await fetchSchoolDetails();
      setState(() {
        schoolDetails = details;
        if (details['school_name'] != null) {
          _schoolNameController.text = details['school_name'];
        }
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching school details: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("School Settings")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("School Settings",
                      style: GoogleFonts.lato(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _schoolNameController,
                    decoration: const InputDecoration(
                        labelText: "Nome da Escola",
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  // PAYMENT TYPES Section (Original Accordion Implementation)
                  ListTile(
                    leading: const Icon(Icons.add, color: Colors.blue),
                    title: const Text("Edit Payment Type"),
                    onTap: () {
                      if (_schoolNameController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text("Please input a school name first.")),
                        );
                        return;
                      }
                      addPaymentType(
                        context,
                        schoolDetails!,
                        _schoolNameController,
                        () async => await fetchAndDisplaySchoolDetails(),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  if (schoolDetails != null)
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Display Payment Types as Accordion.
                            Text("STAFF PAYMENTS",
                                style: GoogleFonts.lato(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            if (schoolDetails!['payment_types'] != null)
                              buildPaymentTypesWidget(
                                  schoolDetails!['payment_types'])
                            else
                              const Text("No payment types available."),
                            const SizedBox(height: 16),
                            // SERVICES Section (Cards with Edit/Delete Buttons)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("SERVICES",
                                    style: GoogleFonts.lato(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold)),
                                IconButton(
                                  icon:
                                      const Icon(Icons.add, color: Colors.blue),
                                  onPressed: () async {
                                    await addEditService(
                                        context, schoolDetails!);
                                    await fetchAndDisplaySchoolDetails();
                                  },
                                )
                              ],
                            ),
                            const SizedBox(height: 8),
                            (schoolDetails!['services'] as List).isNotEmpty
                                ? Column(
                                    children:
                                        (schoolDetails!['services'] as List)
                                            .map<Widget>((service) {
                                      return Card(
                                        child: ListTile(
                                          leading: IconButton(
                                            icon: Icon(Icons.delete,
                                                color: Colors.red),
                                            onPressed: () async {
                                              bool confirmed = await showDialog(
                                                context: context,
                                                builder: (context) =>
                                                    AlertDialog(
                                                  title: Text("Delete Service"),
                                                  content: Text(
                                                      "Are you sure you want to delete this service?"),
                                                  actions: [
                                                    TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                                context, false),
                                                        child: Text("Cancel")),
                                                    ElevatedButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                                context, true),
                                                        child: Text("Delete")),
                                                  ],
                                                ),
                                              );
                                              if (confirmed) {
                                                try {
                                                  await deleteService(
                                                      schoolDetails![
                                                              "school_id"]
                                                          .toString(),
                                                      service["id"]);
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(SnackBar(
                                                          content: Text(
                                                              "Service deleted successfully")));
                                                  await fetchAndDisplaySchoolDetails();
                                                } catch (e) {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(SnackBar(
                                                          content: Text(
                                                              "Failed to delete service: $e")));
                                                }
                                              }
                                            },
                                          ),
                                          title: Text(
                                              service['name'] ?? "No Name"),
                                          subtitle: Text(
                                              service['description'] ?? ""),
                                          trailing: IconButton(
                                            icon: const Icon(Icons.edit),
                                            onPressed: () async {
                                              await addEditService(
                                                  context, schoolDetails!,
                                                  service: service);
                                              await fetchAndDisplaySchoolDetails();
                                            },
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  )
                                : const Text("No services available."),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}
