import 'package:currency_picker/currency_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../modals/student_selection_modal.dart'; // Updated import

/// Helper function that uses intl to get the currency symbol.
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

  // Variables for pack pricing (only used if service type is pack).
  int? selectedDuration;
  String? currency;
  int? selectedPeople;
  int? selectedClasses;
  double? currentPrice;
  int? currentTimeLimit;

  // Toggle between progressive (grid) and table view.
  bool isTableView = false;

  // ADDED: Keep track of how many students are currently selected.
  int _selectedStudentsCount = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _scrollController = ScrollController();

    // Initialize pricing values if service type is pack.
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

  /// Scrolls down so that the Book Service button is visible.
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

  /// Renders the details card below the main service card.
  /// Shows how many students are selected, number of classes, price, etc.
  Widget _buildSelectedDetailsCard() {
    if (selectedPeople == null ||
        selectedClasses == null ||
        currentPrice == null ||
        currentTimeLimit == null) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Number of People: $_selectedStudentsCount / $selectedPeople",
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              "Duration: $selectedDuration",
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              "Number of Classes: $selectedClasses",
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              "Price: $currentPrice${getCurrencySymbol(currency!)}",
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              "Time Limit: $currentTimeLimit days",
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  /// Progressive view: uses a 2x2 grid layout for "pack" pricing.
  Widget buildPackPricingProgressive() {
    final pricingOptions =
        widget.service['details']?['pricing_options'] as List<dynamic>?;
    if (pricingOptions == null || pricingOptions.isEmpty) {
      return const Text('No pricing options available.');
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
        // Header with toggle button.
        Row(
          children: [
            const Text(
              'Pricing Options',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  isTableView = true;
                });
              },
              child: const Text("Table View"),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // 2x2 grid layout.
        Table(
          columnWidths: const {
            0: FlexColumnWidth(1),
            1: FlexColumnWidth(1),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            // Row 1: Duration and People.
            TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Duration:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      DropdownButton<int>(
                        isExpanded: true,
                        value: selectedDuration,
                        items: durations
                            .map((d) => DropdownMenuItem<int>(
                                  value: d,
                                  child: Text('$d minutes'),
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
                      const Text('People:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      DropdownButton<int>(
                        isExpanded: true,
                        value: selectedPeople,
                        items: peopleOptions
                            .map((p) => DropdownMenuItem<int>(
                                  value: p,
                                  child: Text('$p'),
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
            // Row 2: Classes and Price details.
            TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Classes:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      DropdownButton<int>(
                        isExpanded: true,
                        value: selectedClasses,
                        items: classesOptions
                            .map((c) => DropdownMenuItem<int>(
                                  value: c,
                                  child: Text('$c'),
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
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentPrice != null
                              ? 'Price: ${currentPrice!.toStringAsFixed(2)} $currencySymbol'
                              : 'No pricing available',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueAccent,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (currentTimeLimit != null)
                          Text(
                            'Time Limit: ${currentTimeLimit!} days',
                            style: const TextStyle(fontSize: 16),
                          ),
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

  /// Table view: displays all pricing options in a DataTable.
  Widget buildPackPricingTable() {
    final pricingOptions =
        widget.service['details']?['pricing_options'] as List<dynamic>?;
    if (pricingOptions == null || pricingOptions.isEmpty) {
      return const Text('No pricing options available.');
    }
    final String currencySymbol = getCurrencySymbol(widget.service['currency']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with toggle button.
        Row(
          children: [
            const Text(
              'Pricing Options',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  isTableView = false;
                });
              },
              child: const Text("Progressive View"),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 12,
            columns: const [
              DataColumn(label: Text('Duration')),
              DataColumn(label: Text('People')),
              DataColumn(label: Text('Classes')),
              DataColumn(label: Text('Price')),
              DataColumn(label: Text('Time Limit')),
            ],
            rows: pricingOptions.map((option) {
              return DataRow(cells: [
                DataCell(Text('${option['duration']} min')),
                DataCell(Text('${option['people']}')),
                DataCell(Text('${option['classes']}')),
                DataCell(Text(
                    '${(option['price'] as double).toStringAsFixed(2)} $currencySymbol')),
                DataCell(Text('${option['time_limit']} days')),
              ]);
            }).toList(),
          ),
        ),
      ],
    );
  }

  /// Chooses which pricing view to show (progressive or table).
  Widget buildPackPricing() {
    return isTableView
        ? buildPackPricingTable()
        : buildPackPricingProgressive();
  }

  /// Widget to display activity-specific details.
  Widget buildActivityDetails() {
    final details = widget.service['details'] as Map<String, dynamic>?;
    if (details == null || details.isEmpty) {
      return const Text('No additional details available.');
    }
    final filteredKeys =
        details.keys.where((key) => key != 'pricing_options').toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Activity Details',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...filteredKeys.map((key) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Text('$key: ${details[key]}'),
            )),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<String> images = (widget.service['images'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [widget.service['image'] ?? 'https://via.placeholder.com/300'];
    final List<String> benefits = (widget.service['benefits'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        ['benefit 1', 'benefit 2'];
    final List<String> locations =
        (widget.service['locations'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            ['location a', 'location b'];

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              widget.service['school_name'] ?? 'School Name',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
          // Image carousel.
          SizedBox(
            height: 200,
            child: PageView.builder(
              controller: _pageController,
              itemCount: images.length,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      images[index],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey,
                          child: const Icon(Icons.error),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          // Service description.
          Text(
            widget.service['description'] ?? 'No description available.',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          // Benefits.
          const Text('Benefits',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...benefits.map((b) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    const Icon(Icons.check, size: 16),
                    const SizedBox(width: 4),
                    Text(b),
                  ],
                ),
              )),
          const SizedBox(height: 16),
          // Locations.
          const Text('Available Locations',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...locations.map((loc) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, size: 16),
                    const SizedBox(width: 4),
                    Text(loc),
                  ],
                ),
              )),
          const SizedBox(height: 16),
          // Pricing or activity details.
          if (widget.service['type'] is Map &&
              widget.service['type'].containsKey('pack'))
            buildPackPricing()
          else if (widget.service['type'] is Map &&
              widget.service['type'].containsKey('activity'))
            buildActivityDetails(),
          const SizedBox(height: 40),
          Center(
            child: ElevatedButton(
              onPressed: _showStudentSelectionModal,
              child: const Text('Book Service'),
            ),
          ),
        ],
      ),
    );
  }
}
