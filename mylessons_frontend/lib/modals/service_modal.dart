import 'dart:convert';
import 'package:currency_picker/currency_picker.dart' as CurrencyPicker;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import '../services/service_service.dart';

Future<void> showAddEditServiceModal(
  BuildContext context,
  Map<String, dynamic> schoolDetails, {
  Map<String, dynamic>? service,
}) async {
  final TextEditingController nameController =
      TextEditingController(text: service?['name'] ?? '');
  final TextEditingController descriptionController =
      TextEditingController(text: service?['description'] ?? '');
  final TextEditingController photosController = TextEditingController(
      text: service?['photos'] != null ? service!['photos'].join(", ") : '');
  final TextEditingController benefitsController = TextEditingController(
      text: service?['benefits'] != null ? service!['benefits'].join(", ") : '');
  final TextEditingController sportsController = TextEditingController(
      text: service?['sports'] != null ? service!['sports'].join(", ") : '');
  final TextEditingController locationsController = TextEditingController(
      text: service?['locations'] != null ? service!['locations'].join(", ") : '');

  String? selectedType;
  if (service != null && service['type'] != null) {
    if (service['type'].containsKey('pack')) {
      selectedType = 'pack';
    } else if (service['type'].containsKey('activity')) {
      selectedType = 'activity';
    }
  }
  final TextEditingController typeValueController = TextEditingController(
      text: selectedType == 'activity' ? service?['type']?['activity'] ?? '' : '');

  String? selectedPackOption;
  if (selectedType == 'pack' &&
      service != null &&
      service['type'] != null &&
      service['type']['pack'] != null) {
    selectedPackOption = service['type']['pack'];
  }
  final TextEditingController currencyController =
      TextEditingController(text: service?['currency'] ?? '');
  List<Map<String, dynamic>> pricingOptions = [];
  if (service != null &&
      service['details'] != null &&
      service['details']['pricing_options'] != null) {
    pricingOptions =
        List<Map<String, dynamic>>.from(service['details']['pricing_options']);
  }

  Future<void> showPricingOptionDialog(
      {Map<String, dynamic>? pricingOption,
      required void Function(Map<String, dynamic>) onSave}) async {
    final TextEditingController durationController = TextEditingController(
        text: pricingOption != null ? pricingOption['duration']?.toString() : '');
    final TextEditingController peopleController = TextEditingController(
        text: pricingOption != null ? pricingOption['people']?.toString() : '');
    final TextEditingController classesController = TextEditingController(
        text: pricingOption != null ? pricingOption['classes']?.toString() : '');
    final TextEditingController timeLimitController = TextEditingController(
        text: pricingOption != null ? pricingOption['time_limit']?.toString() : '');
    final TextEditingController priceController = TextEditingController(
        text: pricingOption != null ? pricingOption['price']?.toString() : '');

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(pricingOption == null ? "Add Pricing Option" : "Edit Pricing Option"),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: durationController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Duration (min)",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: peopleController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Number of People",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: classesController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Number of Classes",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: timeLimitController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Time Limit (days)",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Price",
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
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
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
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
                Row(
                  children: [
                    IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
                    const SizedBox(width: 8),
                    Text(
                      service == null ? "Add Service" : "Edit Service",
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: "Service Name", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: "Description", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: photosController,
                  decoration: const InputDecoration(labelText: "Photos (comma separated URLs)", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: benefitsController,
                  decoration: const InputDecoration(labelText: "Benefits (comma separated)", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: sportsController,
                  decoration: const InputDecoration(labelText: "Sports (comma separated)", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: locationsController,
                  decoration: const InputDecoration(labelText: "Locations (comma separated)", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                Text("Service Type", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
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
                        backgroundColor: selectedType == 'pack' ? Colors.blue : null,
                        foregroundColor: selectedType == 'pack' ? Colors.white : null,
                      ),
                      child: const Text("Pack"),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        setModalState(() {
                          selectedType = 'activity';
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selectedType == 'activity' ? Colors.blue : null,
                        foregroundColor: selectedType == 'activity' ? Colors.white : null,
                      ),
                      child: const Text("Activity"),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (selectedType == 'activity')
                  TextField(
                    controller: typeValueController,
                    decoration: const InputDecoration(labelText: "Activity Value", border: OutlineInputBorder()),
                  ),
                if (selectedType == 'pack') ...[
                  Text("Select Pack Option", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
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
                          backgroundColor: selectedPackOption == 'private' ? Colors.blue : null,
                          foregroundColor: selectedPackOption == 'private' ? Colors.white : null,
                        ),
                        child: const Text("Private"),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          setModalState(() {
                            selectedPackOption = 'group';
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: selectedPackOption == 'group' ? Colors.blue : null,
                          foregroundColor: selectedPackOption == 'group' ? Colors.white : null,
                        ),
                        child: const Text("Group"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
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
                    child: Text(currencyController.text.isEmpty ? "Select Currency" : currencyController.text),
                  ),
                  const SizedBox(height: 16),
                  Text("Pricing Options", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Column(
                    children: pricingOptions.map((option) {
                      return ListTile(
                        title: Text("Duration: ${option['duration']} min, People: ${option['people']}, Classes: ${option['classes']}, Time Limit: ${option['time_limit']} days, Price: ${option['price']}"),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
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
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () async {
                      await showPricingOptionDialog(onSave: (newOption) {
                        setModalState(() {
                          pricingOptions.add(newOption);
                        });
                      });
                    },
                    child: const Text("Add Pricing Option"),
                  ),
                ],
                const SizedBox(height: 24),
                Center(
                  child: ElevatedButton(
                    onPressed: () async {
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

                      if (service != null && service["id"] != null) {
                        payload["id"] = service["id"];
                      }

                      if (selectedType == 'pack') {
                        payload["type"] = {"pack": selectedPackOption ?? ""};
                        payload["currency"] = currencyController.text;
                        payload["details"] = {"pricing_options": pricingOptions};
                      } else if (selectedType == 'activity') {
                        payload["type"] = {"activity": typeValueController.text};
                      }
                      try {
                        final response = await http.post(
                          Uri.parse('$baseUrl/api/schools/${schoolDetails["school_id"]}/services/add_edit/'),
                          headers: await getAuthHeaders(),
                          body: jsonEncode(payload),
                        );
                        if (response.statusCode == 200) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Service updated successfully!")));
                          Navigator.pop(context);
                        } else {
                          throw Exception('Error: ${response.body}');
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Failed to update service: $e")));
                      }
                    },
                    child: Text(service == null ? "Add Service" : "Save Service"),
                  ),
                ),
                if (service != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Center(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          bool confirmed = await showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text("Delete Service"),
                              content: const Text("Are you sure you want to delete this service?"),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text("Cancel")),
                                ElevatedButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text("Delete")),
                              ],
                            ),
                          );
                          if (confirmed) {
                            try {
                              await deleteService(schoolDetails["school_id"].toString(), service["id"]);
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Service deleted successfully")));
                              Navigator.pop(context);
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Failed to delete service: $e")));
                            }
                          }
                        },
                        icon: const Icon(Icons.delete),
                        label: const Text("Delete Service"),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
