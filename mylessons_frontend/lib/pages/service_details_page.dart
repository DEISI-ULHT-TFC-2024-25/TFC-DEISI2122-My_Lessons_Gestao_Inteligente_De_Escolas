import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/school_provider.dart';
import '../modals/student_selection_modal.dart';
import '../widgets/showMapOptionsBottomModal.dart';

/// Returns the currency symbol for a given currency code.
String getCurrencySymbol(String currencyCode) {
  return NumberFormat.simpleCurrency(name: currencyCode).currencySymbol;
}

class OptionCard extends StatelessWidget {
  final String text;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const OptionCard({
    Key? key,
    required this.text,
    required this.icon,
    required this.selected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: selected
                ? const BorderSide(color: Colors.orange, width: 2)
                : BorderSide(color: Colors.grey.shade300, width: 1),
          ),
          color: selected ? Colors.orange : Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 28,
                  color: selected ? Colors.white : Colors.orange,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: GoogleFonts.lato(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: selected ? Colors.white : Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                    softWrap: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ServiceDetailsContent extends StatefulWidget {
  const ServiceDetailsContent({Key? key}) : super(key: key);

  @override
  _ServiceDetailsContentState createState() => _ServiceDetailsContentState();
}

class _ServiceDetailsContentState extends State<ServiceDetailsContent> {
  late Map<String, dynamic> _service;
  late final PageController _pageController;
  late final ScrollController _scrollController;

  // Pricing variables for pack‑type services.
  int? selectedDuration;
  String? currency;
  int? selectedPeople;
  int? selectedClasses;
  double? currentPrice;
  int? currentTimeLimit;
  Map<String, dynamic>? selectedSubject;
  Map<String, dynamic>? selectedInstructor;
  // New state variable for location selection.
  Map<String, dynamic>? selectedLocation;

  // Toggle view for pricing details.
  bool isTableView = false;

  // Track selected student count.
  int _selectedStudentsCount = 0;

  // Multi-step booking process state:
  // 0: Subject selection (required)
  // 1: Duration selection (required)
  // 2: Number of classes (required)
  // 3: Number of people (required)
  // 4: Location selection (required)
  // 5: Instructor selection (optional)
  // 6: Price review (final step)
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _scrollController = ScrollController();

    // Get the service from the provider.
    final provider = Provider.of<SchoolProvider>(context, listen: false);
    _service = provider.selectedService!;
    // Set currency from service (defaulting to "EUR").
    currency = _service['currency'] ?? "EUR";
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Scrolls down so that elements become visible.
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showStudentSelectionModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return StudentSelectionModal(
          service: _service,
          requiredCount: selectedPeople,
          selectedDuration: selectedDuration,
          selectedClasses: selectedClasses,
          selectedPeople: selectedPeople,
          currentPrice: currentPrice,
          currentTimeLimit: currentTimeLimit,
          // Pass the extra data
          selectedSubject: selectedSubject,
          selectedLocation: selectedLocation,
          selectedInstructor: selectedInstructor,
          onSelectionUpdated: (count) {
            setState(() {
              _selectedStudentsCount = count;
            });
          },
        );
      },
    );
  }

  Widget _buildBookingStepContent() {
    // Define pricingOptions once for use in all cases.
    final List<dynamic> pricingOptions =
        _service['details']?['pricing_options'] as List<dynamic>? ?? [];

    Widget stepContent;

    switch (_currentStep) {
      case 0:
        // Step 1: Subject selection
        final selectedSchool =
            Provider.of<SchoolProvider>(context, listen: false).selectedSchool;
        final List<dynamic> subjects =
            (selectedSchool?['subjects'] as List<dynamic>?) ?? [];
        stepContent = Column(
          children: [
            Text(
              "Step 1: Select Subject",
              style:
                  GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Column(
              children: subjects.map<Widget>((subject) {
                final bool isSelected = selectedSubject != null &&
                    selectedSubject?['id'] == subject['id'];
                return OptionCard(
                  text: subject['name'],
                  icon: Icons.menu_book,
                  selected: isSelected,
                  onTap: () {
                    setState(() {
                      selectedSubject = subject;
                      // Reset subsequent selections if subject changes.
                      selectedLocation = null;
                      selectedInstructor = null;
                      _currentStep = 1;
                    });
                  },
                );
              }).toList(),
            ),
          ],
        );
        break;
      case 1:
        // Step 2: Duration selection
        final List<int> durations = pricingOptions
            .map((e) => e['duration'] as int)
            .toSet()
            .toList()
          ..sort();
        stepContent = Column(
          children: [
            Text(
              "Step 2: Select Duration",
              style:
                  GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Column(
              children: durations.map<Widget>((d) {
                final bool isSelected = selectedDuration == d;
                return OptionCard(
                  text: "$d minutes",
                  icon: Icons.timer,
                  selected: isSelected,
                  onTap: () {
                    setState(() {
                      selectedDuration = d;
                      _currentStep = 2;
                    });
                  },
                );
              }).toList(),
            ),
          ],
        );
        break;
      case 2:
        // Step 3: Number of classes selection
        final filteredOptionsForClasses = pricingOptions
            .where((option) => option['duration'] == selectedDuration);
        final List<int> classesOptions = filteredOptionsForClasses
            .map((e) => e['classes'] as int)
            .toSet()
            .toList()
          ..sort();

        stepContent = Column(
          children: [
            Text(
              "Step 3: Select Number of Classes",
              style:
                  GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Column(
              children: classesOptions.map<Widget>((c) {
                final bool isSelected = selectedClasses == c;
                return OptionCard(
                  text: "$c",
                  icon: Icons.class_,
                  selected: isSelected,
                  onTap: () {
                    setState(() {
                      selectedClasses = c;
                      _currentStep = 3;
                    });
                  },
                );
              }).toList(),
            ),
          ],
        );

      case 3:
        // Step 4: Number of people selection
        final filteredOptionsForPeople = pricingOptions.where((option) =>
            option['duration'] == selectedDuration &&
            option['classes'] == selectedClasses);
        final List<int> peopleOptions = filteredOptionsForPeople
            .map((e) => e['people'] as int)
            .toSet()
            .toList()
          ..sort();

        stepContent = Column(
          children: [
            Text(
              "Step 4: Select Number of People",
              style:
                  GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Column(
              children: peopleOptions.map<Widget>((p) {
                final bool isSelected = selectedPeople == p;
                return OptionCard(
                  text: "$p",
                  icon: Icons.people,
                  selected: isSelected,
                  onTap: () {
                    setState(() {
                      selectedPeople = p;
                      _currentStep = 4;
                    });
                  },
                );
              }).toList(),
            ),
          ],
        );
      case 4:
        // Step 5: Preferred location selection
        final List<dynamic> locations = selectedSubject != null
            ? (selectedSubject?['locations'] as List<dynamic>? ?? [])
            : [];
        stepContent = Column(
          children: [
            Text(
              "Step 5: Select Preferred Location",
              style:
                  GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            locations.isNotEmpty
                ? Column(
                    children: locations.map<Widget>((location) {
                      final bool isSelected = selectedLocation != null &&
                          selectedLocation?['id'] == location['id'];
                      return OptionCard(
                        text: location['name'],
                        icon: Icons.location_on,
                        selected: isSelected,
                        onTap: () {
                          setState(() {
                            selectedLocation = location;
                          });
                          // Check for instructors in the chosen location.
                          final List<dynamic> locInstructors =
                              (location['instructors'] as List<dynamic>? ?? []);
                          if (locInstructors.isEmpty) {
                            // No instructors available, move directly to price review.
                            setState(() {
                              _currentStep = 6;
                            });
                          } else {
                            // Instructors exist, move to instructor selection.
                            setState(() {
                              _currentStep = 5;
                            });
                          }
                        },
                      );
                    }).toList(),
                  )
                : Text(
                    "No locations available.",
                    style: GoogleFonts.lato(fontSize: 14),
                  ),
          ],
        );
        break;
      case 5:
        // Step 6: Instructor selection (optional)
        // Use the instructors directly from the selected location.
        final List<dynamic> instructors = selectedLocation != null
            ? (selectedLocation!['instructors'] as List<dynamic>? ?? [])
            : [];
        stepContent = Column(
          children: [
            Text(
              "Step 6 (Optional): Select Instructor",
              style:
                  GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            instructors.isNotEmpty
                ? Column(
                    children: instructors.map<Widget>((instructor) {
                      final bool isSelected = selectedInstructor != null &&
                          selectedInstructor?['id'] == instructor['id'];
                      return OptionCard(
                        text: instructor['name'],
                        icon: Icons.person_outline,
                        selected: isSelected,
                        onTap: () {
                          setState(() {
                            selectedInstructor = instructor;
                            // After selecting an instructor, move to price review.
                            _currentStep = 6;
                          });
                        },
                      );
                    }).toList(),
                  )
                : Text(
                    "No instructors available for the selected subject in this location.",
                    style: GoogleFonts.lato(fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
            if (instructors.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: ElevatedButton(
                  onPressed: () {
                    // Skip instructor selection and move to price review.
                    setState(() {
                      _currentStep = 6;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32),
                    ),
                  ),
                  child: Text(
                    "Skip & Review Price",
                    style: GoogleFonts.lato(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        );
        break;
      case 6:
        // Step 7: Price review (final step before checkout)
        if (selectedDuration != null &&
            selectedPeople != null &&
            selectedClasses != null) {
          final matchingOption = pricingOptions.firstWhere(
            (option) =>
                option['duration'] == selectedDuration &&
                option['people'] == selectedPeople &&
                option['classes'] == selectedClasses,
            orElse: () => null,
          );
          if (matchingOption != null) {
            currentPrice = matchingOption['price'];
            currentTimeLimit = matchingOption['time_limit'];
          } else {
            currentPrice = null;
            currentTimeLimit = null;
            print("didnt find matching price option");
            print(pricingOptions);
            print("selected duration $selectedDuration");
            print("selected people $selectedPeople");
            print("selected classes $selectedClasses");
          }
        }
        final String currencySymbol = getCurrencySymbol(currency!);
        stepContent = Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                "Step 7: Review Price",
                style:
                    GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (selectedSubject != null)
                Text(
                  "Subject: ${selectedSubject!['name']}",
                  style: GoogleFonts.lato(fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              if (selectedLocation != null)
                Text(
                  "Location: ${selectedLocation!['name']}",
                  style: GoogleFonts.lato(fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              if (selectedInstructor != null)
                Text(
                  "Instructor: ${selectedInstructor!['name']}",
                  style: GoogleFonts.lato(fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              if (selectedDuration != null)
                Text(
                  "Duration: $selectedDuration minutes",
                  style: GoogleFonts.lato(fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              if (selectedClasses != null)
                Text(
                  "Classes: $selectedClasses",
                  style: GoogleFonts.lato(fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              if (selectedPeople != null)
                Text(
                  "People: $selectedPeople",
                  style: GoogleFonts.lato(fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              if (currentPrice != null)
                Text(
                  "Price: ${currentPrice!.toStringAsFixed(2)} $currencySymbol",
                  style: GoogleFonts.lato(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange),
                  textAlign: TextAlign.center,
                ),
              if (currentTimeLimit != null)
                Text(
                  "Time Limit: ${currentTimeLimit!} days",
                  style: GoogleFonts.lato(fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _showStudentSelectionModal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32),
                  ),
                ),
                child: Text(
                  "Confirm & Book Service",
                  style: GoogleFonts.lato(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );
        break;
      default:
        stepContent = Container();
    }

    if (_currentStep > 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.orange),
            onPressed: () {
              setState(() {
                _currentStep--;
              });
            },
          ),
          stepContent,
        ],
      );
    }
    return stepContent;
  }

  @override
  Widget build(BuildContext context) {
    final String description =
        _service['description'] ?? 'No description available.';
    List<Tab> tabs = const [
      Tab(text: 'Book Service'),
      Tab(text: 'Locations'),
      Tab(text: 'Benefits'),
    ];

    Widget bookServiceStepUI = SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildBookingStepContent(),
          const SizedBox(height: 16),
        ],
      ),
    );

    List<Widget> tabViews = [
      bookServiceStepUI,
      _buildLocationsTab(),
      _buildBenefitsTab(),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.orange),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                description,
                style: GoogleFonts.lato(fontSize: 14, color: Colors.black54),
              ),
            ],
          ),
          bottom: TabBar(
            isScrollable: true,
            labelColor: Colors.orange,
            unselectedLabelColor: Colors.black54,
            indicatorColor: Colors.orange,
            tabs: tabs,
          ),
        ),
        body: TabBarView(
          children: tabViews,
        ),
      ),
    );
  }

  Widget _buildLocationsTab() {
    // 1) Cast your raw list of locations from the service:
    final List<Map<String, dynamic>> locations =
        (_service['locations'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>()
            .toList() ??
            [];

    if (locations.isEmpty) {
      return Center(
        child: Text(
          'No locations provided.',
          style: GoogleFonts.lato(fontSize: 14),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: locations.length,
      itemBuilder: (context, index) {
        final loc = locations[index];
        final name = loc['name'] as String? ?? '';
        final address = loc['address'] as String? ?? '';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            leading: const Icon(
              Icons.location_on,
              color: Colors.orange,
              size: 24,
            ),
            title: Text(
              name,
              style: GoogleFonts.lato(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              address,
              style: GoogleFonts.lato(fontSize: 14),
            ),
            trailing: const Icon(Icons.directions, color: Colors.orange),
            onTap: () async {
              if (address.isNotEmpty) {
                await showMapOptionsBottomModal(context, address);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Location address not available."),
                  ),
                );
              }
            },
          ),
        );
      },
    );
  }



  Widget _buildBenefitsTab() {
    final List<String> benefits = (_service['benefits'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: benefits.isEmpty
          ? Center(
              child: Text('No benefits provided.',
                  style: GoogleFonts.lato(fontSize: 14)))
          : Column(
              children: benefits.map((b) {
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        const Icon(Icons.check, size: 20, color: Colors.orange),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(b,
                              style: GoogleFonts.lato(
                                  fontSize: 14, fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }
}
