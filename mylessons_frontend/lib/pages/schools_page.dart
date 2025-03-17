import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'school_details_page.dart';
import 'service_details_page.dart';

class SchoolsPage extends StatefulWidget {
  const SchoolsPage({super.key});

  @override
  _SchoolsPageState createState() => _SchoolsPageState();
}

class _SchoolsPageState extends State<SchoolsPage> {
  final TextEditingController searchController = TextEditingController();

  // Variables holding API data.
  List<Map<String, dynamic>> apiSchools = [];
  List<Map<String, dynamic>> filteredSchools = [];
  // Combined list of applied filters.
  // Each filter: { "type": "sport" or "location", "value": "..." }
  List<Map<String, String>> selectedFilters = [];

  // Selected school and service.
  Map<String, dynamic>? selectedSchool;
  Map<String, dynamic>? selectedService;

  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    fetchAndSetSchools();
  }

  Future<void> fetchAndSetSchools() async {
    try {
      final data = await fetchSchools();
      setState(() {
        apiSchools = data;
        filteredSchools = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  void filterSchoolsBySearch(String query, List<Map<String, dynamic>> schoolsData) {
    setState(() {
      filteredSchools = schoolsData.where((school) {
        final lowerQuery = query.toLowerCase();

        // Check school name.
        bool matchesSchoolName =
            school['name'].toString().toLowerCase().contains(lowerQuery);

        // Check service names.
        bool matchesService =
            (school['services'] as List<dynamic>? ?? []).any((svc) {
          final svcName = svc['name']?.toString().toLowerCase() ?? '';
          return svcName.contains(lowerQuery);
        });

        // Check subjects (sports).
        bool matchesSport =
            (school['sports'] as List<dynamic>? ?? []).any((sport) {
          return sport.toString().toLowerCase().contains(lowerQuery);
        });

        // Check locations.
        bool matchesLocation =
            (school['locations'] as List<dynamic>? ?? []).any((loc) {
          return loc.toString().toLowerCase().contains(lowerQuery);
        });

        final matchesQuery = query.isEmpty ||
            matchesSchoolName || matchesService || matchesSport || matchesLocation;

        // Apply filter selections (if any).
        final appliedSports = selectedFilters
            .where((f) => f['type'] == 'sport')
            .map((f) => f['value']!)
            .toList();
        final appliedLocations = selectedFilters
            .where((f) => f['type'] == 'location')
            .map((f) => f['value']!)
            .toList();
        final sportList =
            (school['sports'] as List).map((s) => s.toString()).toList();
        final matchesFilterSport = appliedSports.isEmpty ||
            sportList.any((s) => appliedSports.contains(s));
        final locationList =
            (school['locations'] as List).map((l) => l.toString()).toList();
        final matchesFilterLocation = appliedLocations.isEmpty ||
            locationList.any((l) => appliedLocations.contains(l));

        return matchesQuery && matchesFilterSport && matchesFilterLocation;
      }).toList();
    });
  }

  List<String> getAllSports(List<Map<String, dynamic>> schoolsData) {
    final Set<String> sportsSet = {};
    for (var school in schoolsData) {
      for (var sport in school['sports']) {
        sportsSet.add(sport);
      }
    }
    return sportsSet.toList();
  }

  List<String> getAllLocations(List<Map<String, dynamic>> schoolsData) {
    final Set<String> locSet = {};
    for (var school in schoolsData) {
      for (var loc in school['locations']) {
        locSet.add(loc);
      }
    }
    return locSet.toList();
  }

  void selectSchool(Map<String, dynamic> school) {
    setState(() {
      selectedSchool = school;
      selectedService = null;
    });
  }

  void clearSelectedSchool() {
    setState(() {
      selectedSchool = null;
      selectedService = null;
    });
  }

  void selectService(Map<String, dynamic> service) {
    setState(() {
      selectedService = service;
    });
  }

  void clearSelectedService() {
    setState(() {
      selectedService = null;
    });
  }

  /// Builds a school card using the unified design.
  /// - The top row shows the school image on the left and a column with the school name and rating (plus number of reviews).
  /// - A heart icon is displayed if the school is a favorite.
  /// - Below, the horizontally scrollable list of service chips is displayed.
  Widget _buildSchoolCard(Map<String, dynamic> school) {
    return GestureDetector(
      onTap: () => selectSchool(school),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0), // Increased inner card padding
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: image and a column with school name and rating.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        school['image'] ?? "https://www.placeholder.com/150/",
                        height: 40,
                        width: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 40,
                            width: 40,
                            color: Colors.grey,
                            child: const Icon(Icons.error, size: 20),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            school['name'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Row(
                            children: [
                              const Icon(Icons.star,
                                  size: 16, color: Colors.amber),
                              const SizedBox(width: 4),
                              Text(school['rating'].toString()),
                              const SizedBox(width: 8),
                              Text(
                                '(${school['reviews'] ?? 0} reviews)',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Show heart icon if this school is a favorite.
                    if (school['isFavorite'] == true)
                      const Icon(Icons.favorite, color: Colors.red),
                  ],
                ),
                const SizedBox(height: 12),
                // Horizontally scrollable list of service chips.
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children:
                        (school['services'] as List<dynamic>? ?? []).map((svc) {
                      final service = svc as Map<String, dynamic>;
                      return GestureDetector(
                        onTap: () {
                          final updatedService =
                              Map<String, dynamic>.from(service);
                          updatedService['school_name'] =
                              school['name'] ?? 'N/A';
                          setState(() {
                            selectedSchool = school;
                            selectedService = updatedService;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(32.0),
                          ),
                          child: Text(
                            service['name'] ?? 'Service',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Helper to build a filter chip matching the service chip appearance.
  Widget _buildFilterChip(Map<String, String> filter) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.orange,
        borderRadius: BorderRadius.circular(32.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            filter['value']!,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () {
              setState(() {
                selectedFilters.remove(filter);
                filterSchoolsBySearch(searchController.text, apiSchools);
              });
            },
            child: const Icon(Icons.close, size: 16, color: Colors.white),
          ),
        ],
      ),
    );
  }

  /// Show a modal bottom sheet for filters with accordions.
  void _showFilterModal(List<Map<String, dynamic>> schoolsData) {
    final allSports = getAllSports(schoolsData);
    final allLocations = getAllLocations(schoolsData);
    // Use local copies for modal state.
    List<Map<String, String>> tempFilters = List.from(selectedFilters);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            bool isFilterSelected(String type, String value) {
              return tempFilters.any((f) => f['type'] == type && f['value'] == value);
            }
            return Padding(
              padding: MediaQuery.of(context).viewInsets,
              child: Container(
                padding: const EdgeInsets.all(24.0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ExpansionTile(
                        title: const Text('Sports'),
                        children: allSports.map((sport) {
                          return CheckboxListTile(
                            title: Text(sport),
                            value: isFilterSelected('sport', sport),
                            onChanged: (checked) {
                              setModalState(() {
                                if (checked == true) {
                                  tempFilters.insert(0, {'type': 'sport', 'value': sport});
                                } else {
                                  tempFilters.removeWhere((f) => f['type'] == 'sport' && f['value'] == sport);
                                }
                              });
                              setState(() {
                                selectedFilters = List.from(tempFilters);
                                filterSchoolsBySearch(searchController.text, schoolsData);
                              });
                            },
                          );
                        }).toList(),
                      ),
                      ExpansionTile(
                        title: const Text('Locations'),
                        children: allLocations.map((loc) {
                          return CheckboxListTile(
                            title: Text(loc),
                            value: isFilterSelected('location', loc),
                            onChanged: (checked) {
                              setModalState(() {
                                if (checked == true) {
                                  tempFilters.insert(0, {'type': 'location', 'value': loc});
                                } else {
                                  tempFilters.removeWhere((f) => f['type'] == 'location' && f['value'] == loc);
                                }
                              });
                              setState(() {
                                selectedFilters = List.from(tempFilters);
                                filterSchoolsBySearch(searchController.text, schoolsData);
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: const Text('Close', style: TextStyle(color: Colors.black)),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Create a sorted copy so that favorites appear first.
    final sortedSchools = List<Map<String, dynamic>>.from(filteredSchools);
    sortedSchools.sort((a, b) {
      if (a['isFavorite'] == true && b['isFavorite'] != true) {
        return -1;
      } else if (a['isFavorite'] != true && b['isFavorite'] == true) {
        return 1;
      }
      return 0;
    });

    if (selectedService != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(selectedService!['name']),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: clearSelectedService,
          ),
        ),
        body: ServiceDetailsContent(service: selectedService!),
      );
    } else if (selectedSchool != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(selectedSchool!['name']),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: clearSelectedSchool,
          ),
        ),
        body: SchoolDetailsContent(
          school: selectedSchool!,
          onServiceSelected: selectService,
        ),
      );
    } else {
      return Scaffold(
        appBar: AppBar(title: const Text('Schools')),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage.isNotEmpty
                ? Center(child: Text('Error: $errorMessage'))
                : SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Search bar row with filter button.
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: searchController,
                                  decoration: InputDecoration(
                                    hintText: 'Search schools...',
                                    prefixIcon: const Icon(Icons.search),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                  ),
                                  onChanged: (query) {
                                    filterSchoolsBySearch(query, apiSchools);
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.filter_list, color: Colors.orange),
                                    onPressed: () {
                                      _showFilterModal(apiSchools);
                                    },
                                  ),
                                  const Text(
                                    'Filter',
                                    style: TextStyle(
                                      color: Colors.orange,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              )
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Display selected filters as chips.
                          if (selectedFilters.isNotEmpty)
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  ...selectedFilters.map((filter) => _buildFilterChip(filter)).toList(),
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        selectedFilters.clear();
                                        filterSchoolsBySearch(searchController.text, apiSchools);
                                      });
                                    },
                                    child: const Text('Clear All', style: TextStyle(color: Colors.orange)),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 24),
                          // Vertical list of school cards.
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: sortedSchools.length,
                            itemBuilder: (context, index) {
                              return _buildSchoolCard(sortedSchools[index]);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
      );
    }
  }
}
