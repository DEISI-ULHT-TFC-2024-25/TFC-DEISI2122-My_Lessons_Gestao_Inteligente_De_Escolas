import 'dart:convert';
import 'package:currency_picker/currency_picker.dart' as CurrencyPicker;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:mylessons_frontend/modals/camp_modal.dart';
import 'package:provider/provider.dart';
import '../providers/school_data_provider.dart';
import '../services/api_service.dart';
import '../services/service_service.dart';
import '../modals/subject_modal.dart';
import '../modals/location_modal.dart';
import '../widgets/payment_widgets.dart';

Future<void> showAddEditServiceModal(
  BuildContext context,
  Map<String, dynamic> schoolDetails, {
  Map<String, dynamic>? service,
}) async {
  // --- Controllers & state lists ---
  final nameController = TextEditingController(text: service?['name'] ?? '');
  final TextEditingController schoolNameController = TextEditingController();

  final descriptionController =
      TextEditingController(text: service?['description'] ?? '');
  final photosController = TextEditingController(
    text: service?['photos'] != null
        ? (service!['photos'] as List).join(', ')
        : '',
  );

  List<Map<String, dynamic>> selectedSports =
      service != null && service['sports'] != null
          ? List<Map<String, dynamic>>.from(service['sports'])
          : [];
  List<Map<String, dynamic>> selectedLocations =
      service != null && service['locations'] != null
          ? List<Map<String, dynamic>>.from(service['locations'])
          : [];

  // Replace CSV benefits with a List<String>
  List<String> benefitsList = service != null && service['benefits'] != null
      ? List<String>.from(service['benefits'])
      : [];

// NEW: Staff Payments controllers
  final staffPaymentAmountController = TextEditingController(
      text: service?['staff_payment_amount']?.toString() ?? '');
  final staffPaymentFrequencyController =
      TextEditingController(text: service?['staff_payment_frequency'] ?? '');

  String? selectedType;
  if (service != null && service['type'] != null) {
    final t = service['type'] as Map;
    if (t.containsKey('pack')) selectedType = 'pack';
    if (t.containsKey('activity')) selectedType = 'activity';
  }
  final typeValueController = TextEditingController(
    text: selectedType == 'activity'
        ? (service!['type'] as Map)['activity'] ?? ''
        : '',
  );
  String? selectedPackOption;
  if (selectedType == 'pack' &&
      service != null &&
      (service['type'] as Map)['pack'] != null) {
    selectedPackOption = (service['type'] as Map)['pack'];
  }
  final currencyController =
      TextEditingController(text: service?['currency'] ?? '');

  List<Map<String, dynamic>> pricingOptions = [];
  if (service != null &&
      service['details'] != null &&
      (service['details'] as Map)['pricing_options'] != null) {
    pricingOptions = List<Map<String, dynamic>>.from(
      (service!['details'] as Map)['pricing_options'],
    );
  }

  List<Map<String, dynamic>> campPricingByWeek = service != null
      ? List<Map<String, dynamic>>.from(
          service['details']?['camp_by_week'] ?? [])
      : [];
  List<Map<String, dynamic>> campPricingByDay = service != null
      ? List<Map<String, dynamic>>.from(
          service['details']?['camp_by_day'] ?? [])
      : [];
  List<Map<String, dynamic>> campPricingGeneral = service != null
      ? List<Map<String, dynamic>>.from(
          service['details']?['camp_general'] ?? [])
      : [];
  List<Map<String, dynamic>> campPricingSpecific = service != null
      ? List<Map<String, dynamic>>.from(
          service['details']?['camp_specific'] ?? [])
      : [];

  final depositPercentageController = TextEditingController(
      text: service?['details']?['deposit_percentage']?.toString() ?? '');
  final installmentsController = TextEditingController(
      text: service?['details']?['installments']?.toString() ?? '');
  bool requireFullPayment =
      service?['details']?['require_full_payment'] as bool? ?? false;

  // just after your other “List<Map>” declarations:
  List<Map<String, dynamic>> selectedActivities =
      service != null && service['activities'] != null
          ? List<Map<String, dynamic>>.from(service['activities'])
          : [];

  String? selectedActivityKind; // 'camp' | 'birthday' | 'event'

// Subtype fields:

// Camp
  DateTime? campStartDate;
  DateTime? campEndDate;

// Birthday Party
  DateTime? partyDate;
  TimeOfDay? partyStartTime;
  TimeOfDay? partyEndTime;
  final guestCountController = TextEditingController();
  final equipmentController = TextEditingController();
  final partyPriceController = TextEditingController();

// Event
  DateTime? eventDate;
  TimeOfDay? eventTime;
  int? eventLocationId;
  final eventPriceController = TextEditingController();

  // Dialog to add a single benefit
  Future<void> showAddBenefitDialog() async {
    final ctrl = TextEditingController();
    String error = '';
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text("Add Benefit"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                decoration: const InputDecoration(
                  labelText: "Benefit",
                  border: OutlineInputBorder(),
                ),
              ),
              if (error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(error, style: const TextStyle(color: Colors.red)),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                final txt = ctrl.text.trim();
                if (txt.isEmpty) {
                  setState(() => error = "Cannot be empty.");
                  return;
                }
                // prevent duplicates
                if (benefitsList.contains(txt)) {
                  setState(() => error = "Already added.");
                  return;
                }
                benefitsList.add(txt);
                Navigator.pop(ctx);
              },
              child: const Text("Add"),
            ),
          ],
        ),
      ),
    );
  }

  // Pricing‐option dialog (unchanged)...
  Future<void> showPricingOptionDialog({
    Map<String, dynamic>? pricingOption,
    required List<Map<String, dynamic>> pricingOptions,
    required void Function(Map<String, dynamic>) onSave,
  }) async {
    final dC = TextEditingController(
        text: pricingOption?['duration']?.toString() ?? '');
    final pC =
        TextEditingController(text: pricingOption?['people']?.toString() ?? '');
    final cC = TextEditingController(
        text: pricingOption?['classes']?.toString() ?? '');
    final tC = TextEditingController(
        text: pricingOption?['time_limit']?.toString() ?? '');
    final prC =
        TextEditingController(text: pricingOption?['price']?.toString() ?? '');

    await showDialog(
      context: context,
      builder: (ctx) {
        String errorMsg = "";
        return StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            title: Text(
              pricingOption == null
                  ? "Add Pricing Option"
                  : "Edit Pricing Option",
            ),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: dC,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Duration (min)",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: pC,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Number of People",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: cC,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Number of Classes",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: tC,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Time Limit (days)",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: prC,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Price",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (errorMsg.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        errorMsg,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () {
                  final dur = int.tryParse(dC.text) ?? 0;
                  final ppl = int.tryParse(pC.text) ?? 0;
                  final cls = int.tryParse(cC.text) ?? 0;
                  final tmL = int.tryParse(tC.text) ?? 0;
                  final pr = double.tryParse(prC.text) ?? 0.0;

                  if (dur == 0 || ppl == 0 || cls == 0 || tmL == 0) {
                    setState(() {
                      errorMsg =
                          "Duration, people, classes & time-limit must be > 0.";
                    });
                    return;
                  }

                  final isEdit = pricingOption != null;
                  final curIdx =
                      isEdit ? pricingOptions.indexOf(pricingOption!) : -1;
                  final dupIdx = pricingOptions.indexWhere((opt) =>
                      opt['duration'] == dur &&
                      opt['people'] == ppl &&
                      opt['classes'] == cls);
                  if (dupIdx != -1 && dupIdx != curIdx) {
                    setState(() {
                      errorMsg =
                          "A pricing option with these details already exists.";
                    });
                    return;
                  }

                  onSave({
                    "duration": dur,
                    "people": ppl,
                    "classes": cls,
                    "time_limit": tmL,
                    "price": pr,
                  });
                  Navigator.pop(ctx);
                },
                child: const Text("Save"),
              ),
            ],
          ),
        );
      },
    );
  }

  int currentStep = 0;

  // Show bottom sheet
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.9,
        child: StatefulBuilder(
          builder: (ctx, setModalState) {
            final provider = context.read<SchoolDataProvider>();
            // Helpers

            Future<void> saveService() async {
              final payload = <String, dynamic>{
                "name": nameController.text,
                "description": descriptionController.text,
                "photos": photosController.text
                    .split(',')
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toList(),
                // use benefitsList instead of CSV
                "benefits": benefitsList,
                "sports": selectedSports,
                "locations": selectedLocations,
              };
              if (service != null && service["id"] != null) {
                payload["id"] = service["id"];
              }
              if (selectedType == 'pack') {
                payload["type"] = {"pack": selectedPackOption ?? ""};
                payload["currency"] = currencyController.text;
                payload["details"] = {"pricing_options": pricingOptions};
              } else if (selectedType == 'activity') {
                payload['type'] = {'activity': selectedActivityKind};
                if (selectedActivityKind == 'camp') {
                  payload['start_date'] =
                      campStartDate?.toIso8601String().split('T').first;
                  payload['end_date'] =
                      campEndDate?.toIso8601String().split('T').first;
                } else if (selectedActivityKind == 'birthday') {
                  payload['date'] =
                      partyDate?.toIso8601String().split('T').first;
                  payload['start_time'] = partyStartTime?.format(ctx);
                  payload['end_time'] = partyEndTime?.format(ctx);
                  payload['number_of_guests'] =
                      int.tryParse(guestCountController.text) ?? 0;
                  payload['equipment'] = jsonDecode(equipmentController.text);
                  payload['price'] =
                      double.tryParse(partyPriceController.text) ?? 0.0;
                } else if (selectedActivityKind == 'event') {
                  payload['date'] =
                      eventDate?.toIso8601String().split('T').first;
                  payload['time'] = eventTime?.format(ctx);
                  payload['location_id'] = eventLocationId;
                  payload['price'] =
                      double.tryParse(eventPriceController.text) ?? 0.0;
                }
                payload['activities'] = selectedActivities;
              }

              try {
                final resp = await http.post(
                  Uri.parse(
                    '$baseUrl/api/schools/${schoolDetails["school_id"]}/services/add_edit/',
                  ),
                  headers: await getAuthHeaders(),
                  body: jsonEncode(payload),
                );
                if (resp.statusCode == 200) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("Service updated successfully!")),
                  );
                  Navigator.pop(context);
                } else {
                  throw Exception('Error: ${resp.body}');
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Failed to update service: $e")),
                );
              }
            }

            Future<void> deleteServiceConfirmed() async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("Delete Service"),
                  content: const Text(
                      "Are you sure you want to delete this service?"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(_, false),
                      child: const Text("Cancel"),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(_, true),
                      child: const Text("Delete"),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                try {
                  await deleteService(
                    schoolDetails["school_id"].toString(),
                    service!["id"],
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("Service deleted successfully")),
                  );
                  Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Failed to delete service: $e")),
                  );
                }
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: // inside your StatefulBuilder:
                  Stepper(
                currentStep: currentStep,
                onStepTapped: (step) => setModalState(() => currentStep = step),
                onStepContinue: () {
                  if (currentStep < 4) {
                    setModalState(() => currentStep += 1);
                  } else {
                    saveService();
                  }
                },
                onStepCancel: () {
                  if (currentStep > 0) {
                    setModalState(() => currentStep -= 1);
                  } else {
                    Navigator.pop(ctx);
                  }
                },
                controlsBuilder: (ctx, details) {
                  final isLast = currentStep == 4;
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        ElevatedButton(
                          onPressed: details.onStepContinue,
                          child: Text(isLast
                              ? (service == null
                                  ? "Add Service"
                                  : "Save Service")
                              : "Next"),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                            onPressed: details.onStepCancel,
                            child: const Text("Back")),
                      ],
                    ),
                  );
                },
                steps: [
                  // 0 ■ Type
                  Step(
                    title: const Text("Type"),
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Service Type",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 10,
                          children: [
                            ElevatedButton(
                              onPressed: () =>
                                  setModalState(() => selectedType = 'pack'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    selectedType == 'pack' ? Colors.blue : null,
                                foregroundColor: selectedType == 'pack'
                                    ? Colors.white
                                    : null,
                              ),
                              child: const Text("Pack"),
                            ),
                            ElevatedButton(
                              onPressed: () => setModalState(
                                  () => selectedType = 'activity'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: selectedType == 'activity'
                                    ? Colors.blue
                                    : null,
                                foregroundColor: selectedType == 'activity'
                                    ? Colors.white
                                    : null,
                              ),
                              child: const Text("Event"),
                            ),
                          ],
                        ),

                        // once you pick “Event”, choose a subtype
                        if (selectedType == 'activity') ...[
                          const SizedBox(height: 16),
                          const Text("Event Kind",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 10,
                            children: [
                              for (final kind in ['camp', 'birthday', 'other'])
                                ElevatedButton(
                                  onPressed: () => setModalState(
                                      () => selectedActivityKind = kind),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        selectedActivityKind == kind
                                            ? Colors.blue
                                            : null,
                                    foregroundColor:
                                        selectedActivityKind == kind
                                            ? Colors.white
                                            : null,
                                  ),
                                  child: Text(
                                    kind == 'camp'
                                        ? 'Camp'
                                        : kind == 'birthday'
                                            ? 'Birthday Party'
                                            : 'Other',
                                  ),
                                ),
                            ],
                          ),
                        ],

                        // if pack, choose Private vs Group
                        if (selectedType == 'pack') ...[
                          const SizedBox(height: 16),
                          const Text("Pack Option",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 10,
                            children: [
                              ElevatedButton(
                                onPressed: () => setModalState(
                                    () => selectedPackOption = 'private'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      selectedPackOption == 'private'
                                          ? Colors.blue
                                          : null,
                                  foregroundColor:
                                      selectedPackOption == 'private'
                                          ? Colors.white
                                          : null,
                                ),
                                child: const Text("Private"),
                              ),
                              ElevatedButton(
                                onPressed: () => setModalState(
                                    () => selectedPackOption = 'group'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: selectedPackOption == 'group'
                                      ? Colors.blue
                                      : null,
                                  foregroundColor: selectedPackOption == 'group'
                                      ? Colors.white
                                      : null,
                                ),
                                child: const Text("Group"),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // 1 ■ Basic Details
                  Step(
                    title: const Text("Basic Details"),
                    content: Column(
                      children: [
                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: "Service Name",
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: descriptionController,
                          decoration: const InputDecoration(
                            labelText: "Description",
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.multiline,
                          minLines: 1,
                          maxLines: null,
                        ),
                      ],
                    ),
                  ),

                  // 2 ■ Details
                  Step(
                    title: const Text("Details"),
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (selectedType == 'pack') ...[
                          // Subject (previously “Sports”)
                          const Text("Subject",
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              ...selectedSports.map((s) => Chip(
                                    label: Text(s['name']),
                                    onDeleted: () => setModalState(
                                        () => selectedSports.remove(s)),
                                  )),
                              ActionChip(
                                avatar: const Icon(Icons.add),
                                label: const Text("Add Subject"),
                                onPressed: () async {
                                  // 1) grab the school_id from the details you were already given
                                  final schoolId = schoolDetails['school_id'] as int;

                                  // 2) build your initial subject-IDs list:
                                  final initialIds = selectedSports.map((s) => s['id'] as int).toList();

                                  // 3) normalize raw provider subjects
                                  final rawSubjects = context
                                      .read<SchoolDataProvider>()
                                      .subjects
                                      .cast<Map<String, dynamic>>();
                                  final allSubjects = rawSubjects.map((s) => <String, dynamic>{
                                    'id':   s['subject_id']   as int,
                                    'name': s['subject_name'] as String,
                                  }).toList();

                                  // 4) pass the schoolId in to satisfy the assert
                                  final picked = await showSubjectModal<List<Map<String, dynamic>>>(
                                    context,
                                    schoolId: schoolId,        // ← now you have “exactly one” non-null ID
                                    localOnly: true,
                                    initialSelectedIds: initialIds,
                                    items: allSubjects,
                                  );

                                  if (picked != null) {
                                    setModalState(() => selectedSports = picked);
                                  }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Location
                          const Text("Location",
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              ...selectedLocations.map((l) => Chip(
                                    label: Text(l['name']),
                                    onDeleted: () => setModalState(
                                        () => selectedLocations.remove(l)),
                                  )),
                              ActionChip(
                                avatar: const Icon(Icons.add),
                                label: const Text("Add Location"),
                                onPressed: () async {
                                  // 1) grab the exact school ID you were already handed
                                  final schoolId = schoolDetails['school_id'] as int;

                                  // 2) build your initial list of selected location IDs
                                  final initialIds = selectedLocations
                                      .map((l) => l['id'] as int)
                                      .toList();

                                  // 3) normalize raw provider locations
                                  final rawLocations = context
                                      .read<SchoolDataProvider>()
                                      .locations
                                      .cast<Map<String, dynamic>>();
                                  final allLocations = rawLocations.map((l) => <String, dynamic>{
                                    'id': l['location_id'] as int,
                                    'name': l['location_name'] as String,
                                    'address': (l['address'] as String?) ?? '',
                                  }).toList();

                                  // 4) invoke the modal, passing schoolId so the assert passes
                                  final picked = await showLocationModal<List<Map<String, dynamic>>>(
                                    context,
                                    schoolId: schoolId,
                                    localOnly: true,
                                    initialSelectedIds: initialIds,
                                    items: allLocations,
                                  );

                                  // 5) if the user made a choice, update your chip list
                                  if (picked != null) {
                                    setModalState(() {
                                      selectedLocations = picked;
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Benefits
                          const Text("Benefits",
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              ...benefitsList.map((b) => Chip(
                                    label: Text(b),
                                    deleteIcon: const Icon(Icons.close),
                                    onDeleted: () => setModalState(
                                        () => benefitsList.remove(b)),
                                  )),
                              ActionChip(
                                avatar: const Icon(Icons.add),
                                label: const Text("Add Benefit"),
                                onPressed: showAddBenefitDialog,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Photos
                          TextField(
                            controller: photosController,
                            decoration: const InputDecoration(
                              labelText: "Photos (comma separated URLs)",
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ] else ...[
                          // Event/activity details
                          const Text("Activities",
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              ...selectedActivities.map((a) => Chip(
                                    label: Text(a['name']),
                                    onDeleted: () => setModalState(
                                        () => selectedActivities.remove(a)),
                                  )),
                              ActionChip(
                                avatar: const Icon(Icons.add),
                                label: const Text("Add Activity"),
                                onPressed: () async {
                                  final newActs =
                                      await showActivitiesModal(context);
                                  if (newActs != null) {
                                    setModalState(() =>
                                        selectedActivities.addAll(newActs));
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // 3 ■ Price
                  Step(
                    title: const Text("Price"),
                    content: selectedType == 'pack'
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  CurrencyPicker.showCurrencyPicker(
                                    context: context,
                                    showFlag: true,
                                    showCurrencyName: true,
                                    showCurrencyCode: true,
                                    onSelect: (currency) {
                                      setModalState(() => currencyController
                                          .text = currency.code);
                                    },
                                  );
                                },
                                child: Text(currencyController.text.isEmpty
                                    ? "Select Currency"
                                    : currencyController.text),
                              ),
                              const SizedBox(height: 16),
                              const Text("Pricing Options",
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Column(
                                children: pricingOptions.map((opt) {
                                  return ListTile(
                                    title: Text(
                                        "Duration: ${opt['duration']} min, People: ${opt['people']}, Classes: ${opt['classes']}, Time Limit: ${opt['time_limit']} days, Price: ${opt['price']}"),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                      onPressed: () => setModalState(
                                          () => pricingOptions.remove(opt)),
                                    ),
                                    onTap: () async {
                                      await showPricingOptionDialog(
                                        pricingOption: opt,
                                        pricingOptions: pricingOptions,
                                        onSave: (newOpt) {
                                          setModalState(() {
                                            pricingOptions[pricingOptions
                                                .indexOf(opt)] = newOpt;
                                          });
                                        },
                                      );
                                    },
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: () async {
                                  await showPricingOptionDialog(
                                    pricingOptions: pricingOptions,
                                    onSave: (newOpt) => setModalState(
                                        () => pricingOptions.add(newOpt)),
                                  );
                                },
                                child: const Text("Add Pricing Option"),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (selectedActivityKind == 'camp') ...[
                                const Text("Pricing by Week",
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                ...campPricingByWeek.map((opt) => ListTile(
                                      title: Text(
                                          "Duration: ${opt['duration']} days — €${opt['price']}"),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.delete,
                                            color: Colors.red),
                                        onPressed: () => setModalState(() =>
                                            campPricingByWeek.remove(opt)),
                                      ),
                                    )),
                                ElevatedButton(
                                  onPressed: () async {
                                    await showPricingOptionDialog(
                                      pricingOptions: campPricingByWeek,
                                      onSave: (newOpt) => setModalState(
                                          () => campPricingByWeek.add(newOpt)),
                                    );
                                  },
                                  child: const Text("Add Weekly Pricing"),
                                ),
                                const SizedBox(height: 16),
                                const Text("Pricing by Day",
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                ...campPricingByDay.map((opt) => ListTile(
                                      title: Text(
                                          "Duration: ${opt['duration']} hours — €${opt['price']}"),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.delete,
                                            color: Colors.red),
                                        onPressed: () => setModalState(
                                            () => campPricingByDay.remove(opt)),
                                      ),
                                    )),
                                ElevatedButton(
                                  onPressed: () async {
                                    await showPricingOptionDialog(
                                      pricingOptions: campPricingByDay,
                                      onSave: (newOpt) => setModalState(
                                          () => campPricingByDay.add(newOpt)),
                                    );
                                  },
                                  child: const Text("Add Daily Pricing"),
                                ),
                                const SizedBox(height: 16),
                                const Text("Pricing by Activity (General)",
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                ...campPricingGeneral.map((opt) => ListTile(
                                      title: Text(
                                          "${opt['classes']} classes — €${opt['price']}"),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.delete,
                                            color: Colors.red),
                                        onPressed: () => setModalState(() =>
                                            campPricingGeneral.remove(opt)),
                                      ),
                                    )),
                                ElevatedButton(
                                  onPressed: () async {
                                    await showPricingOptionDialog(
                                      pricingOptions: campPricingGeneral,
                                      onSave: (newOpt) => setModalState(
                                          () => campPricingGeneral.add(newOpt)),
                                    );
                                  },
                                  child: const Text(
                                      "Add General Activity Pricing"),
                                ),
                                const SizedBox(height: 16),
                                const Text("Pricing by Specific Activity",
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                for (final act in selectedActivities) ...[
                                  Text(act['name'],
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  ...campPricingSpecific
                                      .where((opt) =>
                                          opt['activityId'] == act['id'])
                                      .map((opt) => ListTile(
                                            title: Text(
                                                "${opt['classes']} classes — €${opt['price']}"),
                                            trailing: IconButton(
                                              icon: const Icon(Icons.delete,
                                                  color: Colors.red),
                                              onPressed: () => setModalState(
                                                  () => campPricingSpecific
                                                      .remove(opt)),
                                            ),
                                          )),
                                  ElevatedButton(
                                    onPressed: () async {
                                      await showPricingOptionDialog(
                                        pricingOptions: campPricingSpecific,
                                        onSave: (newOpt) => setModalState(() =>
                                            campPricingSpecific.add({
                                              ...newOpt,
                                              'activityId': act['id']
                                            })),
                                      );
                                    },
                                    child: Text("Add for ${act['name']}"),
                                  ),
                                ],
                                const SizedBox(height: 24),
                                const Text("Payment Options",
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                TextField(
                                  controller: depositPercentageController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: "Deposit % of Full Price",
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: installmentsController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: "Number of Installments",
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                SwitchListTile(
                                  title: const Text(
                                      "Require Full Payment Upfront"),
                                  value: requireFullPayment,
                                  onChanged: (v) => setModalState(
                                      () => requireFullPayment = v),
                                ),
                              ] else ...[
                                TextField(
                                  controller: eventPriceController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: "Event Price",
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ],
                            ],
                          ),
                  ),

                  Step(
                    title: const Text("Staff Payments"),
                    content: Consumer<SchoolDataProvider>(
                      builder: (stepContext, provider, _) {
                        final details = provider.schoolDetails;
                        if (details == null) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        // Only set once to avoid overwriting user edits:
                        if (schoolNameController.text.isEmpty) {
                          schoolNameController.text =
                              details['school_name'] as String? ?? '';
                        }

                        final paymentTypes = (details['payment_types']
                                as Map<String, dynamic>?) ??
                            {};

                        return SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: paymentTypes.isNotEmpty
                              ? buildPaymentTypesWidget(
                                  paymentTypes,
                                  context: stepContext,
                                  schoolDetails: details,
                                  schoolNameController: schoolNameController,
                                )
                              : const Text("No payment types available."),
                        );
                      },
                    ),
                  ),
                ], // end steps
              ),
            );
          },
        ),
      );
    },
  );
}
