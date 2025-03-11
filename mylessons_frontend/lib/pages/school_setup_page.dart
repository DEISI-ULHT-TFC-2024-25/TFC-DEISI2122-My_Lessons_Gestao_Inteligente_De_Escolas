import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../modals/add_staff_modal.dart';
import '../services/school_service.dart';
import '../services/api_service.dart';
import '../widgets/payment_widgets.dart';
import '../widgets/staff_widgets.dart';
import '../modals/payment_modal.dart';
import '../modals/service_modal.dart';

class SchoolSetupPage extends StatefulWidget {
  final bool isCreatingSchool;
  const SchoolSetupPage({Key? key, this.isCreatingSchool = false})
      : super(key: key);

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
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to create school: $e")),
      );
    }
  }

  /// Tabs Content

  Widget _buildServicesTab() {
    if (schoolDetails == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final List services = (schoolDetails!['services'] as List?) ?? [];
    return Padding(
      padding: const EdgeInsets.only(bottom: 100),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24), // increased padding
          child: services.isNotEmpty
              ? Column(
                  children: services.map<Widget>((service) {
                    return Card(
                      margin: const EdgeInsets.only(
                          bottom: 24), // extra spacing between cards
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
                            await showAddEditServiceModal(
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
        ),
      ),
    );
  }

  Widget _buildStaffTab() {
    if (schoolDetails == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final List staff = (schoolDetails!['staff'] as List?) ?? [];
    return Padding(
      padding: const EdgeInsets.only(bottom: 100),
      child: SingleChildScrollView(
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
      ),
    );
  }

  // Updated _buildStaffPaymentsTab() to pass extra parameters so the edit icon works.
  Widget _buildStaffPaymentsTab() {
    if (schoolDetails == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final Map<String, dynamic> paymentTypes =
        (schoolDetails!['payment_types'] as Map<String, dynamic>?) ?? {};
    return Padding(
      padding: const EdgeInsets.only(bottom: 100),
      child: SingleChildScrollView(
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
      ),
    );
  }

  Widget _buildSubjectsTab() {
    if (schoolDetails == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final List subjects = (schoolDetails!['subjects'] as List?) ?? [];
    return Padding(
      padding: const EdgeInsets.only(bottom: 100),
      child: SingleChildScrollView(
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
      ),
    );
  }

  Widget _buildEquipmentsTab() {
    if (schoolDetails == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final List equipments = (schoolDetails!['equipment'] as List?) ?? [];
    return Padding(
      padding: const EdgeInsets.only(bottom: 100),
      child: SingleChildScrollView(
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
      ),
    );
  }

  Widget _buildLocationsTab() {
    if (schoolDetails == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final List locations = (schoolDetails!['locations'] as List?) ?? [];
    return Padding(
      padding: const EdgeInsets.only(bottom: 100),
      child: SingleChildScrollView(
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
      ),
    );
  }

  /// Actions for the bottom button
  Future<void> _onBottomButtonPressed() async {
    int index = _tabController.index;
    switch (index) {
      case 0:
        // Services tab
        if (schoolDetails != null) {
          showAddEditServiceModal(context, schoolDetails!);
        }
        break;
      case 1:
        // Staff tab - open the Add Staff modal
        final result = await showAddStaffModal(context);
        if (result == true) {
          await fetchAndDisplaySchoolDetails();
        }
        break;
      case 2:
        // Staff Payments tab
        if (schoolDetails != null) {
          showPaymentTypeModal(
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
        // Subjects tab - placeholder
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Add Subject clicked")),
        );
        break;
      case 4:
        // Equipments tab - placeholder
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Add Equipment clicked")),
        );
        break;
      case 5:
        // Locations tab - placeholder
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Add Location clicked")),
        );
        break;
      default:
        break;
    }
  }

  String _getBottomButtonLabel() {
    final currentIndex = _tabController.index;
    return "Add ${_tabLabels[currentIndex]}";
  }

  /// Builds the bottom-aligned pill-shaped button
  Widget _buildBottomButton() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ElevatedButton(
          onPressed: _onBottomButtonPressed,
          style: ElevatedButton.styleFrom(
            shape: const StadiumBorder(),
            backgroundColor: Colors.orange,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          ),
          child: Text(
            _getBottomButtonLabel(),
            style: const TextStyle(color: Colors.black, fontSize: 16),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // If in creation mode and the school has not been created yet, show the creation UI.
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

    // After the school is created, display the school name in the AppBar title.
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
            : TabBarView(
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
        bottomNavigationBar: _buildBottomButton(),
      ),
    );
  }
}
