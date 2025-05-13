import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/school_data_provider.dart';
import '../services/payment_service.dart';
import '../services/api_service.dart';

/// Added an optional parameter [preselectedOptions] to pre-populate fields.
Future showPaymentTypeModal(
    BuildContext context,
    Map<String, dynamic> schoolDetails,
    TextEditingController schoolNameController,
    {Map<String, dynamic>? preselectedOptions,
    String? userId}) async {
  // Selected values.
  String? selectedRole;
  String? selectedPaymentMode;
  String? selectedLessonType;
  final TextEditingController activityPriceController = TextEditingController();
  final TextEditingController hourlyRateController = TextEditingController();

  String? selectedBillingMode; // “activity” or “hour”

  // Controllers for fixed monthly rate & commission.
  final TextEditingController fixedMonthlyRateController =
      TextEditingController();
  final TextEditingController commissionController = TextEditingController();

  // Controllers for a new fixed pricing entry.
  final TextEditingController fixedPricingDurationController =
      TextEditingController();
  final TextEditingController fixedPricingMinStudentsController =
      TextEditingController();
  final TextEditingController fixedPricingMaxStudentsController =
      TextEditingController();
  final TextEditingController fixedPricingPriceController =
      TextEditingController();

  // List to hold multiple fixed pricing entries (for lesson mode).
  List<Map<String, dynamic>> fixedPricingList = [];

  // If editing an existing payment type, pre-populate the modal fields.
  if (preselectedOptions != null) {
    selectedRole = preselectedOptions["role"];
    selectedPaymentMode = preselectedOptions["paymentMode"];
    selectedLessonType = preselectedOptions["lessonType"];
    if (preselectedOptions.containsKey("fixedMonthlyRate")) {
      fixedMonthlyRateController.text =
          preselectedOptions["fixedMonthlyRate"].toString();
    }
    if (preselectedOptions.containsKey("commission")) {
      commissionController.text = preselectedOptions["commission"].toString();
    }
    if (preselectedOptions.containsKey("fixedPricingList")) {
      fixedPricingList = List<Map<String, dynamic>>.from(
          preselectedOptions["fixedPricingList"]);
    }
  }

  final ScrollController scrollController = ScrollController();

  Future<void> updatePaymentTypeFields() async {
    // For Admin, only fixed monthly rate is allowed.
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
        userId: userId,
      );
    }
    // For Lesson-based payment type (non-admin).
    else if (selectedPaymentMode == "lesson") {
      if (selectedLessonType == null) {
        throw Exception("Lesson type must be selected.");
      }
      if (["camp", "birthday", "event"].contains(selectedLessonType)) {
        if (selectedBillingMode == null) {
          throw Exception("Please choose Hour or Activity.");
        }
        // pick the right controller
        final rawText = selectedBillingMode == "activity"
            ? activityPriceController.text
            : hourlyRateController.text;
        final price = double.tryParse(rawText) ?? 0.0;

        // build a keyPath with the billing mode as the key
        String keyPath =
            "$selectedRole[$selectedLessonType][$selectedBillingMode]";

        await postPaymentTypeData(
          schoolId: schoolDetails["school_id"]?.toString(),
          schoolName: schoolNameController.text,
          keyPath: keyPath,
          newValue: price,
          userId: userId,
        );
        return; // skip the rest
      }

      // Save commission if provided.
      if (commissionController.text.isNotEmpty) {
        int commission = int.tryParse(commissionController.text) ?? 0;
        String keyPath = "$selectedRole[$selectedLessonType][commission]";
        await postPaymentTypeData(
          schoolId: schoolDetails["school_id"]?.toString(),
          schoolName: schoolNameController.text,
          keyPath: keyPath,
          newValue: commission,
          userId: userId,
        );
      }
      // Save fixed pricing entries if any.
      if (fixedPricingList.isNotEmpty) {
        String keyPath = "$selectedRole[$selectedLessonType][fixed]";
        await postPaymentTypeData(
          schoolId: schoolDetails["school_id"]?.toString(),
          schoolName: schoolNameController.text,
          keyPath: keyPath,
          newValue: fixedPricingList,
          userId: userId,
        );
      }
    }
  }

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

          // helper to load commission + fixed list whenever lessonType changes
          void loadLessonData(StateSetter setState) {
            final roleMap = (schoolDetails["payment_types"]
                    as Map?)?[selectedRole] as Map<String, dynamic>? ??
                {};
            final lessonMap =
                (roleMap[selectedLessonType] as Map<String, dynamic>?) ?? {};

            // existing:
            commissionController.text =
                (lessonMap["commission"] ?? "").toString();
            fixedPricingList =
                List<Map<String, dynamic>>.from(lessonMap["fixed"] ?? []);

            // ─── add this block ───
            if (["camp", "birthday", "event"].contains(selectedLessonType)) {
              activityPriceController.text =
                  (lessonMap["activity"] ?? "").toString();
              hourlyRateController.text = (lessonMap["hour"] ?? "").toString();
            }
            // ───────────────────────

            setState(() {});
          }

          // Determine if we can enable the Save button.
          bool canSave = false;
          if (selectedPaymentMode == "fixed") {
            canSave = fixedMonthlyRateController.text.trim().isNotEmpty;
          } else if (selectedPaymentMode == "lesson") {
            if (["camp", "birthday", "event"].contains(selectedLessonType)) {
              canSave = (selectedBillingMode == "activity")
                  ? activityPriceController.text.trim().isNotEmpty
                  : hourlyRateController.text.trim().isNotEmpty;
            } else {
              bool commissionProvided =
                  commissionController.text.trim().isNotEmpty;
              bool hasFixedPricing = fixedPricingList.isNotEmpty;
              canSave = commissionProvided || hasFixedPricing;
            }
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
                    // Header.
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
                    // Role selection.
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
                              selectedPaymentMode = "fixed";
                              selectedLessonType = null;
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
                              selectedPaymentMode = null;
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
                              selectedPaymentMode = null;
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
                    // Payment Mode Selection (for non-admin roles).
                    if (selectedRole != null && selectedRole != "admin") ...[
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
                    // Fixed monthly rate field.
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
                    // Lesson-based payment options.
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
                          // Private button
                          ElevatedButton(
                            onPressed: () {
                              setModalState(() {
                                selectedLessonType = "private";
                                selectedBillingMode = null;
                                activityPriceController.clear();
                                hourlyRateController.clear();
                                loadLessonData(setModalState);
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

// Group button
                          ElevatedButton(
                            onPressed: () {
                              setModalState(() {
                                selectedLessonType = "group";
                                selectedBillingMode = null;
                                activityPriceController.clear();
                                hourlyRateController.clear();
                                loadLessonData(setModalState);
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

                          ElevatedButton(
                            onPressed: () {
                              setModalState(() {
                                selectedLessonType = "camp";
                                selectedBillingMode = null;
                                activityPriceController.clear();
                                hourlyRateController.clear();
                                loadLessonData(setModalState);
                              });
                              scrollToBottom();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: selectedLessonType == "camp"
                                  ? Colors.blue
                                  : null,
                              foregroundColor: selectedLessonType == "camp"
                                  ? Colors.white
                                  : null,
                            ),
                            child: const Text("Camp"),
                          ),

                          ElevatedButton(
                            onPressed: () {
                              setModalState(() {
                                selectedLessonType = "birthday";
                                selectedBillingMode = null;
                                activityPriceController.clear();
                                hourlyRateController.clear();
                                loadLessonData(setModalState);
                              });
                              scrollToBottom();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: selectedLessonType == "birthday"
                                  ? Colors.blue
                                  : null,
                              foregroundColor: selectedLessonType == "birthday"
                                  ? Colors.white
                                  : null,
                            ),
                            child: const Text("Birthday"),
                          ),

                          ElevatedButton(
                            onPressed: () {
                              setModalState(() {
                                selectedLessonType = "event";
                                selectedBillingMode = null;
                                activityPriceController.clear();
                                hourlyRateController.clear();
                                loadLessonData(setModalState);
                              });
                              scrollToBottom();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: selectedLessonType == "event"
                                  ? Colors.blue
                                  : null,
                              foregroundColor: selectedLessonType == "event"
                                  ? Colors.white
                                  : null,
                            ),
                            child: const Text("Event"),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (selectedLessonType != null) ...[
                        // --- special “camp/birthday/event” billing pickers ---
                        if (<String>["camp", "birthday", "event"]
                            .contains(selectedLessonType)) ...[
                          Text(
                            "Charge ${selectedLessonType!}:",
                            style: GoogleFonts.lato(
                                fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 10,
                            children: [
                              ElevatedButton(
                                onPressed: () => setModalState(() {
                                  selectedBillingMode = "activity";
                                }),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      selectedBillingMode == "activity"
                                          ? Colors.blue
                                          : null,
                                ),
                                child: const Text("By Activity"),
                              ),
                              ElevatedButton(
                                onPressed: () => setModalState(() {
                                  selectedBillingMode = "hour";
                                }),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: selectedBillingMode == "hour"
                                      ? Colors.blue
                                      : null,
                                ),
                                child: const Text("By Hour"),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // — now always show the price field for whichever mode is selected —
                          if (selectedBillingMode != null)
                            TextField(
                              controller: selectedBillingMode == "activity"
                                  ? activityPriceController
                                  : hourlyRateController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: selectedBillingMode == "activity"
                                    ? "Price per Activity"
                                    : "Price per Hour",
                                border: const OutlineInputBorder(),
                              ),
                              onChanged: (_) {
                                setModalState(() {});
                                scrollToBottom();
                              },
                            ),
                        ] else ...[
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
                          Text(
                            "Add/Edit Fixed Pricing Entries (optional):",
                            style: GoogleFonts.lato(
                                fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
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
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () {
                              if (fixedPricingDurationController.text
                                      .trim()
                                      .isNotEmpty &&
                                  fixedPricingMinStudentsController.text
                                      .trim()
                                      .isNotEmpty &&
                                  fixedPricingMaxStudentsController.text
                                      .trim()
                                      .isNotEmpty &&
                                  fixedPricingPriceController.text
                                      .trim()
                                      .isNotEmpty) {
                                setModalState(() {
                                  fixedPricingList.add({
                                    'duration': int.tryParse(
                                        fixedPricingDurationController.text),
                                    'min_students': int.tryParse(
                                        fixedPricingMinStudentsController.text),
                                    'max_students': int.tryParse(
                                        fixedPricingMaxStudentsController.text),
                                    'price': double.tryParse(
                                        fixedPricingPriceController.text),
                                  });
                                  fixedPricingDurationController.clear();
                                  fixedPricingMinStudentsController.clear();
                                  fixedPricingMaxStudentsController.clear();
                                  fixedPricingPriceController.clear();
                                });
                                scrollToBottom();
                              }
                            },
                            child: const Text("Add Pricing Entry"),
                          ),
                          const SizedBox(height: 16),
                          if (fixedPricingList.isNotEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: fixedPricingList.map((entry) {
                                return Card(
                                  child: ListTile(
                                    // Delete button on the left side.
                                    leading: IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                      onPressed: () async {
                                        // Construct payload for deletion.
                                        Map<String, dynamic> payload = {
                                          "school_id":
                                              schoolDetails["school_id"]
                                                  ?.toString(),
                                          "school_name":
                                              schoolNameController.text,
                                          "key_path":
                                              "$selectedRole[$selectedLessonType][fixed]",
                                          "entry": entry,
                                          "user_id": userId,
                                        };
                                        try {
                                          final response = await http.post(
                                            Uri.parse(
                                                "$baseUrl/api/schools/delete_payment_type_entry/"),
                                            headers: await getAuthHeaders(),
                                            body: json.encode(payload),
                                          );
                                          if (response.statusCode == 200) {
                                            setModalState(() {
                                              fixedPricingList.remove(entry);
                                            });
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                  content: Text(
                                                      "Fixed pricing entry deleted.")),
                                            );
                                          } else {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                  content: Text(
                                                      "Failed to delete pricing entry: ${response.body}")),
                                            );
                                          }
                                        } catch (e) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                                content: Text("Error: $e")),
                                          );
                                        }
                                      },
                                    ),
                                    title: Text(
                                      "Duration: ${entry['duration']} min, Students: ${entry['min_students']}-${entry['max_students']}, Price: ${entry['price']}",
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    // Edit button on the right side.
                                    trailing: IconButton(
                                      icon: const Icon(Icons.edit,
                                          color: Colors.orange),
                                      onPressed: () {
                                        setModalState(() {
                                          fixedPricingDurationController.text =
                                              entry['duration'].toString();
                                          fixedPricingMinStudentsController
                                                  .text =
                                              entry['min_students'].toString();
                                          fixedPricingMaxStudentsController
                                                  .text =
                                              entry['max_students'].toString();
                                          fixedPricingPriceController.text =
                                              entry['price'].toString();
                                          fixedPricingList.remove(entry);
                                        });
                                        scrollToBottom();
                                      },
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
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
                                await context
                                    .read<SchoolDataProvider>()
                                    .loadSchoolDetails();
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
                  ]),
            ),
          );
        },
      );
    },
  );
}
