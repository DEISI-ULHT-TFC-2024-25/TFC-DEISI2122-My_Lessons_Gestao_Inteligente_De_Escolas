// lib/pages/manage_school.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../modals/add_equipment_modal.dart';
import '../modals/add_staff_modal.dart';
import '../modals/equipment_details_modal.dart';
import '../modals/payment_type_modal.dart';
import '../modals/service_modal.dart';
import '../modals/subject_modal.dart';
import '../modals/location_modal.dart';
import '../models/phone_input.dart';
import '../models/team_input.dart';
import '../providers/profile_provider.dart';
import '../providers/school_data_provider.dart';
import '../services/school_service.dart';
import '../widgets/contact_section.dart';
import '../widgets/payment_widgets.dart';
import '../widgets/staff_widgets.dart';

class SchoolSetupPage extends StatefulWidget {
  final bool isCreatingSchool;
  final Future<void> Function() fetchProfileData;

  const SchoolSetupPage({
    Key? key,
    this.isCreatingSchool = false,
    required this.fetchProfileData,
  }) : super(key: key);

  @override
  _SchoolSetupPageState createState() => _SchoolSetupPageState();
}

class _SchoolSetupPageState extends State<SchoolSetupPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _schoolNameController = TextEditingController();
  bool _isCreated = false;
  File? _schoolImage;
  final ImagePicker _picker = ImagePicker();
  bool _contactsInitialized = false;

  List<TeamInput> _contactTeams = [];
  List<TeamInput>? _editContactTeams;

  final List<String> _tabLabels = [
    'Service',
    'Staff',
    'Staff Payment',
    'Contacts',
    'Subject',
    'Equipment',
    'Location',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabLabels.length, vsync: this)
      ..addListener(() {
        setState(() {});
      });
    if (!widget.isCreatingSchool) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<SchoolDataProvider>().loadSchoolDetails();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.watch<SchoolDataProvider>();

    // hydrate exactly once when details arrive
    if (!_contactsInitialized && !provider.isLoading && provider.schoolDetails != null) {
      _contactTeams = provider.contactTeams;
      _contactsInitialized = true;
    }
  }


  @override
  void dispose() {
    _tabController.dispose();
    _schoolNameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _schoolImage = File(picked.path);
      });
    }
  }

  Future<void> _onCreateSchool() async {
    final name = _schoolNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a school name')),
      );
      return;
    }
    try {
      await context.read<SchoolDataProvider>().createSchool(
            name,
            imageFile: _schoolImage,
          );
      _isCreated = true;
      await widget.fetchProfileData();
      await context.read<SchoolDataProvider>().loadSchoolDetails();
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create school: $e')),
      );
    }
  }

  Future<void> _onBottomButtonPressed() async {
    final provider = context.read<SchoolDataProvider>();
    final details = provider.schoolDetails!;
    final schoolId = details['school_id'] as int;

    switch (_tabController.index) {
      case 0:
        await showAddEditServiceModal(context, details);
        break;
      case 1:
        await showAddStaffModal(context);
        break;
      case 2:
        await showPaymentTypeModal(
          context,
          details,
          _schoolNameController,
        );
        break;
      case 3:
        final schoolId = provider.schoolDetails!['school_id'] as int;
        final payload = {
          'contacts': {
            'teams': _contactTeams.map((t) => t.toJson()).toList(),
          },
        };
        await provider.updateContacts(schoolId, payload);
        // refresh & allow re-hydration:
        _contactsInitialized = false;
        await provider.loadSchoolDetails();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Contacts saved')));
        break;
      case 4:
        await showSubjectModal(context, schoolId: schoolId);
        break;
      case 5:
        await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          builder: (_) => AddEquipmentModal(schoolId: schoolId),
        );
        break;
      case 6:
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => LocationModal(schoolId: schoolId),
        );
        break;
      default:
        break;
    }

    await provider.loadSchoolDetails();
  }

  String _getBottomButtonLabel() {
    if (_tabLabels[_tabController.index] == 'Contacts') {
      return 'Save Contacts';
    }
    return 'Add ${_tabLabels[_tabController.index]}';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isCreatingSchool && !_isCreated) {
      return Scaffold(
        appBar: AppBar(title: const Text('School Setup')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create School',
                style: GoogleFonts.lato(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _schoolNameController,
                decoration: const InputDecoration(
                  labelText: 'School Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              if (_schoolImage != null)
                Center(
                  child: Image.file(
                    _schoolImage!,
                    height: 100,
                    fit: BoxFit.cover,
                  ),
                ),
              ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.image),
                label: const Text('Upload Image (optional)'),
              ),
              const SizedBox(height: 24),
              const SizedBox(height: 24),
              ContactsSection(
                initialTeams: _contactTeams,
                onTeamsChanged: (teams) =>
                    setState(() => _contactTeams = teams),
              ),
              const SizedBox(height: 24),
              Center(
                child: ElevatedButton(
                  onPressed: _onCreateSchool,
                  child: const Text('Create School'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Consumer<SchoolDataProvider>(
      builder: (context, provider, child) {
        final details = provider.schoolDetails;

        if (provider.isLoading || details == null) {
          return Scaffold(
            appBar: AppBar(
              title: Text(
                  widget.isCreatingSchool ? 'School Setup' : 'School Settings'),
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        // ─── Hydrate one time from the server payload ──────────
        if (!provider.isLoading &&
            details['contacts'] != null &&
            !_contactsInitialized) {
          final rawTeams = (details['contacts']['teams'] as List<dynamic>);
          _contactTeams = rawTeams.map((raw) {
            // turn the JSON into your TeamInput/PhoneInput model:
            final phonesRaw = (raw['phones'] as List<dynamic>);
            final phones = phonesRaw.map((p) {
              return PhoneInput(
                countryCode: (p['country_code'] as String) ?? '',
                number:      (p['number']       as String) ?? '',
                canCall:     (p['capabilities']['call'] as bool?) ?? false,
                canText:     (p['capabilities']['text'] as bool?) ?? false,
              );
            }).toList();

            return TeamInput(
              label:  (raw['label']  as String) ?? '',
              emails: List<String>.from(raw['emails'] as List<dynamic>),
              phones: phones,
            );
          }).toList();

          _contactsInitialized = true;
        }

        final String? critical = details['critical_message'] as String?;

        final appBarTitle = details['school_name'] != null
            ? '${details['school_name']} Settings'
            : 'School Settings';

        return DefaultTabController(
          length: _tabLabels.length,
          child: Scaffold(
            appBar: AppBar(
              title: Text(appBarTitle),
              bottom: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: [
                  ..._tabLabels.map((l) => Tab(text: l)),
                ],
              ),
            ),
            body: Column(
              children: [
                if (critical != null && critical.isNotEmpty)
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
                            critical,
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
                          _buildServicesTab(details),
                          _buildStaffTab(details),
                          buildStaffPaymentsTab(),
                          _buildContactsTab(),
                          _buildSubjectsTab(details),
                          _buildEquipmentsTab(details),
                          _buildLocationsTab(details),
                        ],
                      ),
                      Positioned(
                        bottom: 24,
                        left: 24,
                        right: 24,
                        child: ElevatedButton(
                          onPressed: _onBottomButtonPressed,
                          style: ElevatedButton.styleFrom(
                            shape: const StadiumBorder(),
                            backgroundColor: Colors.orange,
                            padding: const EdgeInsets.symmetric(vertical: 12),
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
      },
    );
  }

  Widget _buildServicesTab(Map<String, dynamic> details) {
    final raw = details['services'];
    final List services = raw is List
        ? raw
        : raw is Map
            ? raw.values.toList()
            : [];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: services.isEmpty
          ? const Text('No services available.')
          : Column(
              children: services.map((s) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 24),
                  child: ListTile(
                    title: Text(
                      s['name'] ?? 'No Name',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit, color: Colors.orange),
                      onPressed: () =>
                          showAddEditServiceModal(context, details, service: s),
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildStaffTab(Map<String, dynamic> schoolDetails) {
    final List staff = (schoolDetails['staff'] as List?) ?? [];
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: staff.isNotEmpty
            ? buildStaffSection(
                List<dynamic>.from(staff),
                context: context,
                schoolDetails: schoolDetails,
                schoolNameController: _schoolNameController,
              )
            : const Text("No staff data available."),
      ),
    );
  }

  Widget buildStaffPaymentsTab() {
    final provider = context.read<SchoolDataProvider>();
    Map<String, dynamic>? schoolDetails = provider.schoolDetails;
    if (schoolDetails == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final Map<String, dynamic> paymentTypes =
        (schoolDetails['payment_types'] as Map<String, dynamic>?) ?? {};
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: paymentTypes.isNotEmpty
            ? buildPaymentTypesWidget(
                paymentTypes,
                context: context,
                schoolDetails: schoolDetails,
                schoolNameController: _schoolNameController,
              )
            : const Text("No payment types available."),
      ),
    );
  }

  Widget _buildSubjectsTab(Map<String, dynamic> details) {
    final List subs = details['subjects'] as List? ?? [];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: subs.isEmpty
          ? const Text('No subjects available.')
          : Column(
              children: subs.map((sub) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 24),
                  child: ListTile(
                    title: Text(sub['subject_name'] ?? 'No Name'),
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildEquipmentsTab(Map<String, dynamic> details) {
    final List eqs = details['equipment'] as List? ?? [];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: eqs.isEmpty
          ? const Text('No equipments available.')
          : Column(
              children: eqs.map((e) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ListTile(
                    title: Text(e['equipment_name'] ?? 'No Name'),
                    subtitle: Text(
                      '${e['location_name'] ?? ''} • ${e['size'] ?? ''}',
                    ),
                    trailing: TextButton(
                      child: const Text('Details'),
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => EquipmentDetailsModal(
                            equipment: e,
                          ),
                        );
                      },
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildLocationsTab(Map<String, dynamic> details) {
    final List locs = details['locations'] as List? ?? [];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: locs.isEmpty
          ? const Text('No locations available.')
          : Column(
              children: locs.map((l) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 24),
                  child: ListTile(
                    title: Text(l['location_name'] ?? 'No Name'),
                    subtitle: Text(l['address'] ?? ''),
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildContactsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ContactsSection(
        initialTeams: _contactTeams,
        onTeamsChanged: (teams) => setState(() {
          _contactTeams = teams;
        }),
      ),
    );
  }
}
