import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../modals/student_selection_modal.dart';

/// Returns the currency symbol for a given currency code.
String getCurrencySymbol(String currencyCode) {
  return NumberFormat.simpleCurrency(name: currencyCode).currencySymbol;
}

class ServiceDetailsContent extends StatefulWidget {
  final Map<String, dynamic> service;
  const ServiceDetailsContent({Key? key, required this.service})
      : super(key: key);

  @override
  _ServiceDetailsContentState createState() => _ServiceDetailsContentState();
}

class _ServiceDetailsContentState extends State<ServiceDetailsContent> {
  late final PageController _pageController;
  late final ScrollController _scrollController;
  int _currentPage = 0;

  // Pricing variables for pack‑type services.
  int? selectedDuration;
  String? currency;
  int? selectedPeople;
  int? selectedClasses;
  double? currentPrice;
  int? currentTimeLimit;

  // Toggle view for pricing details.
  bool isTableView = false;

  // Track selected student count.
  int _selectedStudentsCount = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _scrollController = ScrollController();

    // Initialize pricing values if the service is a pack.
    if (widget.service['type'] is Map &&
        widget.service['type'].containsKey('pack')) {
      final pricingOptions =
          widget.service['details']?['pricing_options'] as List<dynamic>?;
      if (pricingOptions != null && pricingOptions.isNotEmpty) {
        final firstOption = pricingOptions.first;
        selectedDuration = firstOption['duration'];
        currency = widget.service['currency'];
        selectedPeople = firstOption['people'];
        selectedClasses = firstOption['classes'];
        currentPrice = firstOption['price'];
        currentTimeLimit = firstOption['time_limit'];
      }
    }
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
          service: widget.service,
          requiredCount: selectedPeople,
          selectedDuration: selectedDuration,
          selectedClasses: selectedClasses,
          selectedPeople: selectedPeople,
          currentPrice: currentPrice,
          currentTimeLimit: currentTimeLimit,
          onSelectionUpdated: (count) {
            setState(() {
              _selectedStudentsCount = count;
            });
          },
        );
      },
    );
  }

  /// ------------------ Book Service Tab ------------------
  /// This tab combines the booking call-to-action with current details (pricing or activity).
  Widget _buildBookTab() {
    Widget detailsWidget;

    // For pack‑type services, show pricing details along with toggle buttons.
    if (widget.service['type'] is Map &&
        widget.service['type'].containsKey('pack')) {
      detailsWidget = Column(
        children: [
          // Toggle buttons for "Choose Options" and "View Table".
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: isTableView
                      ? OutlinedButton(
                          onPressed: () {
                            setState(() {
                              isTableView = false;
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: Colors.orange),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(32)),
                          ),
                          child: Text("Options",
                              style: GoogleFonts.lato(
                                fontWeight: FontWeight.bold,
                                  color: Colors.orange, fontSize: 16)),
                        )
                      : ElevatedButton(
                          onPressed: () {
                            setState(() {
                              isTableView = false;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(32)),
                          ),
                          child: Text("Options",
                              style: GoogleFonts.lato(
                                fontWeight: FontWeight.bold,
                                  color: Colors.white, fontSize: 16)),
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: isTableView
                      ? ElevatedButton(
                          onPressed: () {
                            setState(() {
                              isTableView = true;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(32)),
                          ),
                          child: Text("Table",
                              style: GoogleFonts.lato(
                                fontWeight: FontWeight.bold,
                                  color: Colors.white, fontSize: 16)),
                        )
                      : OutlinedButton(
                          onPressed: () {
                            setState(() {
                              isTableView = true;
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: Colors.orange),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(32)),
                          ),
                          child: Text("Table",
                              style: GoogleFonts.lato(
                                fontWeight: FontWeight.bold,
                                  color: Colors.orange, fontSize: 16)),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Pricing section that switches based on isTableView.
          _buildPricingSection(),
        ],
      );
    } else if (widget.service['type'] is Map &&
        widget.service['type'].containsKey('activity')) {
      final details = widget.service['details'] as Map<String, dynamic>?;
      if (details == null || details.isEmpty) {
        detailsWidget = Center(
            child: Text('No additional details available.',
                style: GoogleFonts.lato()));
      } else {
        final filteredKeys =
            details.keys.where((key) => key != 'pricing_options').toList();
        detailsWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Activity Details',
                style: GoogleFonts.lato(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...filteredKeys.map((key) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child:
                      Text('$key: ${details[key]}', style: GoogleFonts.lato()),
                )),
          ],
        );
      }
    } else {
      detailsWidget = Center(
          child: Text('No details available.', style: GoogleFonts.lato()));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          detailsWidget,
          const SizedBox(height: 24),
          // Book Service button appears only in the Options view.
          if (!isTableView)
            Center(
              child: ElevatedButton(
                onPressed: _showStudentSelectionModal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: Text('Book Service',
                    style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
              ),
            ),
        ],
      ),
    );
  }

  /// ------------------ Benefits Tab ------------------
  Widget _buildBenefitsTab() {
    final List<String> benefits = (widget.service['benefits'] as List<dynamic>?)
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

  /// ------------------ Locations Tab ------------------
  Widget _buildLocationsTab() {
    final List<String> locations =
        (widget.service['locations'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: locations.isEmpty
          ? Center(
              child: Text('No locations provided.',
                  style: GoogleFonts.lato(fontSize: 14)))
          : Column(
              children: locations.map((loc) {
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on,
                            size: 20, color: Colors.orange),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(loc,
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

  /// ------------------ Pack Pricing (Progressive) ------------------
  Widget _buildPackPricingProgressive() {
    final pricingOptions =
        widget.service['details']?['pricing_options'] as List<dynamic>?;
    if (pricingOptions == null || pricingOptions.isEmpty) {
      return Text('No pricing options available.',
          style: GoogleFonts.lato(fontSize: 14));
    }
    final String currencySymbol = getCurrencySymbol(widget.service['currency']);
    final durations = pricingOptions
        .map((e) => e['duration'] as int)
        .toSet()
        .toList()
      ..sort();
    final peopleOptions =
        pricingOptions.map((e) => e['people'] as int).toSet().toList()..sort();
    final classesOptions =
        pricingOptions.map((e) => e['classes'] as int).toSet().toList()..sort();

    var matchingOption;
    if (selectedDuration != null &&
        selectedPeople != null &&
        selectedClasses != null) {
      matchingOption = pricingOptions.firstWhere(
        (option) =>
            option['duration'] == selectedDuration &&
            option['people'] == selectedPeople &&
            option['classes'] == selectedClasses,
        orElse: () => null,
      );
    }
    if (matchingOption != null) {
      currentPrice = matchingOption['price'];
      currentTimeLimit = matchingOption['time_limit'];
    } else {
      currentPrice = null;
      currentTimeLimit = null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Table(
          columnWidths: const {
            0: FlexColumnWidth(1),
            1: FlexColumnWidth(1),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Duration:',
                          style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      DropdownButton<int>(
                        isExpanded: true,
                        value: selectedDuration,
                        items: durations
                            .map((d) => DropdownMenuItem<int>(
                                  value: d,
                                  child: Text('$d minutes',
                                      style: GoogleFonts.lato()),
                                ))
                            .toList(),
                        onChanged: (val) {
                          setState(() {
                            selectedDuration = val;
                          });
                          _scrollToBottom();
                        },
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('People:',
                          style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      DropdownButton<int>(
                        isExpanded: true,
                        value: selectedPeople,
                        items: peopleOptions
                            .map((p) => DropdownMenuItem<int>(
                                  value: p,
                                  child: Text('$p', style: GoogleFonts.lato()),
                                ))
                            .toList(),
                        onChanged: (val) {
                          setState(() {
                            selectedPeople = val;
                          });
                          _scrollToBottom();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Classes:',
                          style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      DropdownButton<int>(
                        isExpanded: true,
                        value: selectedClasses,
                        items: classesOptions
                            .map((c) => DropdownMenuItem<int>(
                                  value: c,
                                  child: Text('$c', style: GoogleFonts.lato()),
                                ))
                            .toList(),
                        onChanged: (val) {
                          setState(() {
                            selectedClasses = val;
                          });
                          _scrollToBottom();
                        },
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentPrice != null
                              ? 'Price:\n${currentPrice!.toStringAsFixed(2)}$currencySymbol'
                              : 'No pricing available',
                          style: GoogleFonts.lato(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange),
                        ),
                        const SizedBox(height: 8),
                        if (currentTimeLimit != null)
                          Text('Time Limit:\n${currentTimeLimit!} days',
                              style: GoogleFonts.lato(fontSize: 16)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  /// ------------------ Pack Pricing Table View ------------------
  Widget _buildPackPricingTable() {
    final pricingOptions =
        widget.service['details']?['pricing_options'] as List<dynamic>?;
    if (pricingOptions == null || pricingOptions.isEmpty) {
      return Text('No pricing options available.',
          style: GoogleFonts.lato(fontSize: 14));
    }
    final String currencySymbol = getCurrencySymbol(widget.service['currency']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        // Wrap the DataTable in a Container to add a border and padding.
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.orangeAccent),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              showCheckboxColumn: false,
              headingTextStyle: GoogleFonts.lato(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange),
              dataTextStyle:
                  GoogleFonts.lato(fontSize: 14, color: Colors.black87),
              dividerThickness: 1,
              columnSpacing: 12,
              columns: [
                DataColumn(label: Text('Duration')),
                DataColumn(label: Text('People')),
                DataColumn(label: Text('Classes')),
                DataColumn(label: Text('Price')),
                DataColumn(label: Text('Time Limit')),
              ],
              rows: pricingOptions.map((option) {
                return DataRow(
                  onSelectChanged: (selected) {
                    if (selected ?? false) {
                      setState(() {
                        selectedDuration = option['duration'];
                        selectedPeople = option['people'];
                        selectedClasses = option['classes'];
                        currentPrice = option['price'];
                        currentTimeLimit = option['time_limit'];
                      });
                      _showStudentSelectionModal();
                    }
                  },
                  cells: [
                    DataCell(Text('${option['duration']} min')),
                    DataCell(Text('${option['people']}')),
                    DataCell(Text('${option['classes']}')),
                    DataCell(Text(
                        '${(option['price'] as double).toStringAsFixed(2)} $currencySymbol')),
                    DataCell(Text('${option['time_limit']} days')),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  /// Chooses between progressive and table view for pricing.
  Widget _buildPricingSection() {
    return isTableView
        ? _buildPackPricingTable()
        : _buildPackPricingProgressive();
  }

  /// ------------------ Build ------------------
  @override
  Widget build(BuildContext context) {
    final String description =
        widget.service['description'] ?? 'No description available.';

    // Define the tabs.
    List<Tab> tabs = [
      const Tab(text: 'Book Service'),
      const Tab(text: 'Locations'),
      const Tab(text: 'Benefits'),
    ];
    List<Widget> tabViews = [
      _buildBookTab(),
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
          // Make the title a column to hold both the service name and the description.
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                description,
                style: GoogleFonts.lato(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
          // Put the TabBar at the bottom of the AppBar.
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
}
