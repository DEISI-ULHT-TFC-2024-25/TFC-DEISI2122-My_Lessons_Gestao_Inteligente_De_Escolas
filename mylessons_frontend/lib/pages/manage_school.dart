import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../modals/add_staff_modal.dart';
import '../modals/payment_modal.dart';
import '../modals/service_modal.dart';
import '../modals/subject_modal.dart';
import '../modals/location_modal.dart';
import '../services/school_service.dart';
import '../services/api_service.dart';
import '../widgets/payment_widgets.dart';
import '../widgets/staff_widgets.dart';

class SchoolSetupPage extends StatefulWidget {
  final bool isCreatingSchool;
  final Future<void> Function() fetchProfileData; // Callback to refresh the whole home page
  const SchoolSetupPage({
    super.key,
    this.isCreatingSchool = false,
    required this.fetchProfileData,
  });

  @override
  _SchoolSetupPageState createState() => _SchoolSetupPageState();
}

class _SchoolSetupPageState extends State<SchoolSetupPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _schoolNameController = TextEditingController();
  Map<String, dynamic>? schoolDetails;
  bool isLoading = true;
  bool _isCreated = false;

  late TabController _tabController;
  final List<String> _tabLabels = [
    "Service",
    "Staff",
    "Staff Payment",
    "Subject",
    "Equipment",
    "Location"
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Update bottom button label when tab changes
    });

    if (!widget.isCreatingSchool) {
      fetchAndDisplaySchoolDetails();
    } else {
      isLoading = false;
    }
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

  Future<void> createSchoolAction() async {
    final schoolName = _schoolNameController.text.trim();
    if (schoolName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a school name")),
      );
      return;
    }
    try {
      await createSchool(schoolName);
      await fetchAndDisplaySchoolDetails();
      setState(() {
        _isCreated = true;
      });
      await widget.fetchProfileData();
      await fetchAndDisplaySchoolDetails();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to create school: $e")),
      );
    }
  }

  // Tabs Content

  Widget _buildServicesTab() {
    if (schoolDetails == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final dynamic servicesData = schoolDetails!['services'];
    final List services;
    if (servicesData is List) {
      services = servicesData;
    } else if (servicesData is Map) {
      services = servicesData.values.toList();
    } else {
      services = [];
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: services.isNotEmpty
            ? Column(
                children: services.map<Widget>((service) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 24),
                    child: ListTile(
                      title: Text(
                        service['name'] ?? "No Name",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.edit,
                          color: Colors.orange,
                        ),
                        onPressed: () async {
                          await showAddEditServiceModal(context, schoolDetails!,
                              service: service);
                          await fetchAndDisplaySchoolDetails();
                        },
                      ),
                    ),
                  );
                }).toList(),
              )
            : const Text("No services available."),
      ),
    );
  }

  Widget _buildStaffTab() {
    if (schoolDetails == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final List staff = (schoolDetails!['staff'] as List?) ?? [];
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: staff.isNotEmpty
            ? buildStaffSection(
                List<dynamic>.from(staff),
                context: context,
                schoolDetails: schoolDetails!,
                schoolNameController: _schoolNameController,
                refreshSchoolDetails: fetchAndDisplaySchoolDetails,
              )
            : const Text("No staff data available."),
      ),
    );
  }

  Widget _buildStaffPaymentsTab() {
    if (schoolDetails == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final Map<String, dynamic> paymentTypes =
        (schoolDetails!['payment_types'] as Map<String, dynamic>?) ?? {};
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: paymentTypes.isNotEmpty
            ? buildPaymentTypesWidget(
                paymentTypes,
                context: context,
                schoolDetails: schoolDetails!,
                schoolNameController: _schoolNameController,
                refreshSchoolDetails: fetchAndDisplaySchoolDetails,
              )
            : const Text("No payment types available."),
      ),
    );
  }

  Widget _buildSubjectsTab() {
    if (schoolDetails == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final List subjects = (schoolDetails!['subjects'] as List?) ?? [];
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: subjects.isNotEmpty
            ? Column(
                children: subjects.map<Widget>((subject) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 24),
                    child: ListTile(
                      title: Text(subject['subject_name'] ?? "No Name"),
                    ),
                  );
                }).toList(),
              )
            : const Text("No subjects available."),
      ),
    );
  }

  Widget _buildEquipmentsTab() {
    if (schoolDetails == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final List equipments = (schoolDetails!['equipment'] as List?) ?? [];
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: equipments.isNotEmpty
            ? Column(
                children: equipments.map<Widget>((equipment) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 24),
                    child: ListTile(
                      title: Text(equipment['equipment_name'] ?? "No Name"),
                      subtitle: Text(equipment['location'] ?? ""),
                    ),
                  );
                }).toList(),
              )
            : const Text("No equipments available."),
      ),
    );
  }

  Widget _buildLocationsTab() {
    if (schoolDetails == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final List locations = (schoolDetails!['locations'] as List?) ?? [];
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: locations.isNotEmpty
            ? Column(
                children: locations.map<Widget>((location) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 24),
                    child: ListTile(
                      title: Text(location['location_name'] ?? "No Name"),
                      subtitle: Text(location['address'] ?? ""),
                    ),
                  );
                }).toList(),
              )
            : const Text("No locations available."),
      ),
    );
  }

  Future<void> _onBottomButtonPressed() async {
    int index = _tabController.index;
    switch (index) {
      case 0:
        if (schoolDetails != null) {
          await showAddEditServiceModal(context, schoolDetails!);
          await fetchAndDisplaySchoolDetails();
        }
        break;
      case 1:
        final result = await showAddStaffModal(context);
        if (result == true) {
          await fetchAndDisplaySchoolDetails();
        }
        break;
      case 2:
        if (schoolDetails != null) {
          await showPaymentTypeModal(
            context,
            schoolDetails!,
            _schoolNameController,
            () async {
              await fetchAndDisplaySchoolDetails();
            },
          );
        }
        break;
      case 3:
        if (schoolDetails != null) {
          await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (context) => SubjectModal(
              schoolId: schoolDetails!['school_id'],
            ),
          );
          await fetchAndDisplaySchoolDetails();
        }
        break;
      case 4:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Add Equipment clicked")),
        );
        break;
      case 5:
        if (schoolDetails != null && schoolDetails!['school_id'] != null) {
          await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (context) => LocationModal(
              schoolId: schoolDetails!['school_id'],
            ),
          );
          await fetchAndDisplaySchoolDetails();
        }
        break;
      default:
        break;
    }
  }

  String _getBottomButtonLabel() {
    final currentIndex = _tabController.index;
    return "Add ${_tabLabels[currentIndex]}";
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isCreatingSchool && !_isCreated) {
      return Scaffold(
        appBar: AppBar(title: const Text("School Setup")),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Create School",
                  style: GoogleFonts.lato(
                      fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              TextField(
                controller: _schoolNameController,
                decoration: const InputDecoration(
                  labelText: "School Name",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: ElevatedButton(
                  onPressed: createSchoolAction,
                  child: const Text("Create School"),
                ),
              ),
            ],
          ),
        ),
      );
    }

    String appBarTitle = schoolDetails?['school_name'] != null
        ? "${schoolDetails!['school_name']} Settings"
        : "School Settings";

    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: Text(appBarTitle),
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: const [
              Tab(text: "Services"),
              Tab(text: "Staff"),
              Tab(text: "Staff Payments"),
              Tab(text: "Subjects"),
              Tab(text: "Equipments"),
              Tab(text: "Locations"),
            ],
          ),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  if (schoolDetails != null &&
                      schoolDetails!['critical_message'] != null &&
                      schoolDetails!['critical_message']
                          .toString()
                          .trim()
                          .isNotEmpty)
                    Container(
                      width: double.infinity,
                      color: Colors.redAccent,
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(Icons.warning, color: Colors.white),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              schoolDetails!['critical_message'],
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: Stack(
                      children: [
                        TabBarView(
                          controller: _tabController,
                          children: [
                            _buildServicesTab(),
                            _buildStaffTab(),
                            _buildStaffPaymentsTab(),
                            _buildSubjectsTab(),
                            _buildEquipmentsTab(),
                            _buildLocationsTab(),
                          ],
                        ),
                        // Positioned button overlayed at the bottom of the content
                        Positioned(
                          bottom: 24,
                          left: 24,
                          right: 24,
                          child: ElevatedButton(
                            onPressed: _onBottomButtonPressed,
                            style: ElevatedButton.styleFrom(
                              shape: const StadiumBorder(),
                              backgroundColor: Colors.orange,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 10),
                            ),
                            child: Text(
                              _getBottomButtonLabel(),
                              style: const TextStyle(
                                  color: Colors.black, fontSize: 16),
                            ),
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
