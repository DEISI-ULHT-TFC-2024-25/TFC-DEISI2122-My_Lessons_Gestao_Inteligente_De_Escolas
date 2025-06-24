import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../providers/profile_provider.dart';
import '../providers/home_page_provider.dart';
import '../services/profile_service.dart';
import '../widgets/connect_calendar_button_widget.dart';
import 'student_page.dart';
import 'bulk_import_page.dart';
import 'manage_school.dart';
import '../main.dart';
import 'markdown_page.dart';
import 'student_pairing_screen.dart';


class ProfilePage extends StatelessWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ProfileProvider>(
      create: (_) => ProfileProvider(),
      child: const _ProfileView(),
    );
  }
}

class _ProfileView extends StatefulWidget {
  const _ProfileView({Key? key}) : super(key: key);

  @override
  __ProfileViewState createState() => __ProfileViewState();
}

class __ProfileViewState extends State<_ProfileView> with RouteAware {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ModalRoute? route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    context.read<ProfileProvider>().fetchProfileData();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProfileProvider>();
    final isAdmin = provider.currentRole == 'Admin';

    final tabs = <Tab>[
      const Tab(text: 'Info'),
      const Tab(text: 'Students'),
      if (isAdmin) const Tab(text: 'School'),
      const Tab(text: 'Legal'),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          bottom: TabBar(tabs: tabs, isScrollable: true),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => provider.logout(context),
            ),
          ],
        ),
        body: provider.isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  // Info Tab
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 16),
                        if (!provider.hasCalendarToken)
                          const ConnectCalendarButton(),
                        const SizedBox(height: 16),
                        _buildInput(
                          'First Name',
                          provider.firstNameController,
                          readOnly: !provider.isEditingProfile,
                        ),
                        _buildInput(
                          'Last Name',
                          provider.lastNameController,
                          readOnly: !provider.isEditingProfile,
                        ),
                        _buildInput(
                          'Email',
                          provider.emailController,
                          readOnly: !provider.isEditingProfile,
                        ),
                        const SizedBox(height: 8),
                        _buildBirthdayField(provider),
                        const SizedBox(height: 8),
                        _buildPhoneField(provider),
                        if (provider.isEditingProfile) ...[
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => provider.updateProfile(context),
                            child: const Text('Save Profile'),
                          ),
                        ] else ...[
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: provider.toggleEditing,
                            child: const Text('Edit Profile'),
                          ),
                        ],
                        const SizedBox(
                          height: 80,
                          child: Align(
                            alignment: Alignment.center,
                            child: ToggleRoleButtons(),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Students Tab
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Show “Pair” button for regular parents...
                        if (provider.currentRole != 'Admin')
                          ElevatedButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => StudentPairingScreen()),
                            ),
                            child: const Text('Pair with a Student'),
                          ),


                        const SizedBox(height: 16),

                        // Then the existing students list
                        Expanded(
                          child: ListView.builder(
                            itemCount: provider.associatedStudents.length,
                            itemBuilder: (ctx, i) {
                              final st = provider.associatedStudents[i];
                              return ListTile(
                                title: Text(
                                    "${st['first_name']} ${st['last_name']}"),
                                subtitle: Text(st['birthday']),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Keep the “info” button if you like:
                                    IconButton(
                                      icon: const Icon(Icons.info_outline),
                                      onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              StudentPage(studentId: st["id"]),
                                        ),
                                      ),
                                    ),
                                    // NEW: generate key
                                    IconButton(
                                      icon: const Icon(Icons.vpn_key),
                                      tooltip: 'Generate pairing key',
                                      onPressed: () async {
                                        await provider.generateAssociationKey(
                                            context, st['id'] as int);
                                        if (provider.lastGeneratedKey != null) {
                                          showDialog(
                                            context: context,
                                            builder: (_) => AlertDialog(
                                              title: const Text('Pairing Key'),
                                              content: SelectableText(
                                                  provider.lastGeneratedKey!),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.of(context)
                                                          .pop(),
                                                  child: const Text('Close'),
                                                ),
                                              ],
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  // School Tab (Admin only)
                  if (isAdmin)
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SchoolSetupPage(
                                  isCreatingSchool:
                                      provider.availableSchools.isEmpty,
                                  fetchProfileData: provider.fetchProfileData,
                                ),
                              ),
                            ),
                            child: Text(provider.availableSchools.isEmpty
                                ? 'Create School'
                                : 'Manage School'),
                          ),
                          if (!provider.availableSchools.isEmpty) ...[
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BulkImportPage(),
                                ),
                              ),
                              child: const Text('Import Data'),
                            ),
                          ]
                        ],
                      ),
                    ),

                  // Legal Tab
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const MarkdownPage(
                                title: 'Termos e Condições',
                                assetPath: 'assets/terms.md',
                              ),
                            ),
                          ),
                          child: const Text('Termos e Condições de Utilização'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const MarkdownPage(
                                title: 'Política de Privacidade',
                                assetPath: 'assets/privacy.md',
                              ),
                            ),
                          ),
                          child: const Text('Política de Privacidade'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController controller,
      {bool readOnly = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Widget _buildBirthdayField(ProfileProvider provider) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: provider.birthdayController,
            readOnly: true,
            decoration: InputDecoration(
              labelText: 'Birthday',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.calendar_today),
          onPressed: provider.isEditingProfile
              ? () async {
                  DateTime initial = DateTime.now();
                  if (provider.birthdayController.text.isNotEmpty) {
                    initial =
                        DateTime.tryParse(provider.birthdayController.text) ??
                            DateTime.now();
                  }
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: initial,
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    provider.birthdayController.text =
                        picked.toIso8601String().split('T').first;
                  }
                }
              : null,
        ),
      ],
    );
  }

  Widget _buildPhoneField(ProfileProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: IntlPhoneField(
        initialCountryCode: provider.phoneCountryCode,
        initialValue: provider.phoneController.text,
        enabled: provider.isEditingProfile,
        decoration: InputDecoration(
          labelText: 'Phone Number',
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(32.0),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(32.0),
            borderSide: const BorderSide(color: Colors.orange, width: 2),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(32.0),
            borderSide: const BorderSide(color: Colors.orange, width: 2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(32.0),
            borderSide: const BorderSide(color: Colors.orange, width: 2),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        ),
        onCountryChanged: (country) {
          provider.phoneCountryCode = country.code;
        },
        onChanged: (phone) {
          provider.phoneController.text = phone.number;
        },
      ),
    );
  }
}

class ToggleRoleButtons extends StatelessWidget {
  const ToggleRoleButtons({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProfileProvider>();
    return ToggleButtons(
      isSelected: provider.availableRoles
          .map((r) => r == provider.currentRole)
          .toList(),
      onPressed: (index) =>
          provider.changeRole(context, provider.availableRoles[index]),
      borderRadius: BorderRadius.circular(8),
      fillColor: Colors.transparent,
      selectedBorderColor: Theme.of(context).primaryColor,
      children: provider.availableRoles
          .map((r) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(r),
              ))
          .toList(),
    );
  }
}
