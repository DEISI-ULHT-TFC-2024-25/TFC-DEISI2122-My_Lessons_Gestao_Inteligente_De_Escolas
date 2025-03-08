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

  // Default sample schools (for details pages if needed).
  final List<Map<String, dynamic>> defaultSchools = [
    {
      'name': 'sunshine academy',
      'image': 'https://via.placeholder.com/150',
      'description': 'a top school for diverse educational experiences.',
      'rating': 4.5,
      'sports': ['soccer', 'basketball', 'swimming'],
      'locations': ['new york', 'los angeles'],
      'isFavorite': true,
      'lastPurchases': [
        {'packName': 'math pack', 'date': '2025-02-22', 'price': '\$100'},
        {'packName': 'science pack', 'date': '2025-02-20', 'price': '\$80'},
      ],
      'services': [
        {
          'name': 'private lessons',
          'image': 'https://via.placeholder.com/300',
          'images': [
            'https://via.placeholder.com/300/ff0000',
            'https://via.placeholder.com/300/00ff00',
            'https://via.placeholder.com/300/0000ff',
          ],
          'description':
              'one-on-one personalized tutoring sessions to help your child excel.',
          'benefits': [
            'personal attention',
            'customized curriculum',
            'flexible scheduling'
          ],
          'locations': ['room 101', 'room 102'],
        },
        {
          'name': 'group lessons',
          'image': 'https://via.placeholder.com/300',
          'images': [
            'https://via.placeholder.com/300/aaaaaa',
            'https://via.placeholder.com/300/bbbbbb',
          ],
          'description': 'interactive sessions in small groups fostering teamwork.',
          'benefits': [
            'collaborative learning',
            'social skills',
            'competitive pricing'
          ],
          'locations': ['lab a', 'lab b'],
        },
      ],
    },
    {
      'name': 'green valley school',
      'image': 'https://via.placeholder.com/150',
      'description': 'focused on holistic development and innovation.',
      'rating': 4.2,
      'sports': ['tennis', 'baseball'],
      'locations': ['chicago'],
      'isFavorite': false,
      'lastPurchases': [
        {'packName': 'art pack', 'date': '2025-02-18', 'price': '\$90'},
      ],
      'services': [
        {
          'name': 'camps',
          'image': 'https://via.placeholder.com/300',
          'images': [
            'https://via.placeholder.com/300/123456',
            'https://via.placeholder.com/300/654321',
          ],
          'description': 'engaging summer camps that combine fun and learning.',
          'benefits': [
            'outdoor activities',
            'expert instructors',
            'peer bonding'
          ],
          'locations': ['camp ground 1', 'camp ground 2'],
        },
      ],
    },
    {
      'name': 'blue ocean institute',
      'image': 'https://via.placeholder.com/150',
      'description': 'providing world-class learning opportunities.',
      'rating': 4.8,
      'sports': ['soccer', 'tennis'],
      'locations': ['san francisco', 'boston'],
      'isFavorite': true,
      'lastPurchases': [
        {'packName': 'language pack', 'date': '2025-02-15', 'price': '\$120'},
      ],
      'services': [
        {
          'name': 'special events',
          'image': 'https://via.placeholder.com/300',
          'images': [
            'https://via.placeholder.com/300/cccccc',
            'https://via.placeholder.com/300/dddddd',
          ],
          'description': 'exclusive events tailored to your interests.',
          'benefits': ['vip access', 'networking', 'expert talks'],
          'locations': ['main hall', 'conference room'],
        },
      ],
    },
  ];

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
        final schoolName = school['name'].toString();
        final matchesQuery = query.isEmpty || schoolName.toLowerCase().contains(query.toLowerCase());

        // Extract applied sports and locations from selectedFilters.
        final appliedSports = selectedFilters
            .where((f) => f['type'] == 'sport')
            .map((f) => f['value']!)
            .toList();
        final appliedLocations = selectedFilters
            .where((f) => f['type'] == 'location')
            .map((f) => f['value']!)
            .toList();

        final sportList = (school['sports'] as List).map((s) => s.toString()).toList();
        final matchesSport =
            appliedSports.isEmpty || sportList.any((s) => appliedSports.contains(s));

        final locationList = (school['locations'] as List).map((l) => l.toString()).toList();
        final matchesLocation = appliedLocations.isEmpty ||
            locationList.any((l) => appliedLocations.contains(l));

        return matchesQuery && matchesSport && matchesLocation;
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

  List<Map<String, dynamic>> getFavoriteSchools(List<Map<String, dynamic>> schoolsData) {
    return schoolsData.where((school) => school['isFavorite'] == true).toList();
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

  // Show a modal bottom sheet for filters with accordions.
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
            // Helper function to check if a filter is selected.
            bool isFilterSelected(String type, String value) {
              return tempFilters.any((f) => f['type'] == type && f['value'] == value);
            }
            return Padding(
              padding: MediaQuery.of(context).viewInsets,
              child: Container(
                padding: const EdgeInsets.all(16.0),
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
                                  // Insert new filter at the beginning.
                                  tempFilters.insert(0, {'type': 'sport', 'value': sport});
                                } else {
                                  tempFilters.removeWhere(
                                      (f) => f['type'] == 'sport' && f['value'] == sport);
                                }
                              });
                              // Apply automatically.
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
                                  tempFilters.removeWhere(
                                      (f) => f['type'] == 'location' && f['value'] == loc);
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
                      const SizedBox(height: 16),
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

  Widget buildSchoolList(List<Map<String, dynamic>> schoolsData) {
    final favorites = getFavoriteSchools(schoolsData);
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (favorites.isNotEmpty) ...[
            const Text(
              'Favorite Schools',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: favorites.length,
                itemBuilder: (context, index) {
                  final fav = favorites[index];
                  return GestureDetector(
                    onTap: () => selectSchool(fav),
                    child: Container(
                      width: 120,
                      margin: const EdgeInsets.only(right: 12),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              fav['image'],
                              height: 60,
                              width: 120,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 60,
                                  width: 120,
                                  color: Colors.grey,
                                  child: const Icon(Icons.error),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            fav['name'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
          Expanded(
            child: ListView.builder(
              itemCount: filteredSchools.length,
              itemBuilder: (context, index) {
                final school = filteredSchools[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    onTap: () => selectSchool(school),
                    leading: SizedBox(
                      width: 60,
                      height: 60,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(
                          school['image'],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey,
                              child: const Icon(Icons.error, color: Colors.red),
                            );
                          },
                        ),
                      ),
                    ),
                    title: Text(school['name']),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.star, size: 16, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(school['rating'].toString()),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          (school['locations'] as List<dynamic>).join(', '),
                          style: const TextStyle(fontSize: 12),
                        ),
                        Text(
                          (school['sports'] as List<dynamic>).join(', '),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
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
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              TextButton.icon(
                                onPressed: () {
                                  _showFilterModal(apiSchools);
                                },
                                icon: const Icon(Icons.filter_list, color: Colors.black),
                                label: const Text('Filters', style: TextStyle(color: Colors.black)),
                              ),
                              const SizedBox(width: 4),
                              ...selectedFilters.map((filter) => Padding(
                                    padding: const EdgeInsets.only(right: 2.0),
                                    child: Chip(
                                      label: Text(filter['value']!),
                                      deleteIcon: const Icon(Icons.close, color: Colors.black),
                                      onDeleted: () {
                                        setState(() {
                                          selectedFilters.remove(filter);
                                          filterSchoolsBySearch(searchController.text, apiSchools);
                                        });
                                      },
                                      backgroundColor: Colors.transparent,
                                      side: const BorderSide(color: Colors.transparent),
                                      labelStyle: const TextStyle(color: Colors.black),
                                    ),
                                  )),
                              if (selectedFilters.isNotEmpty)
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      selectedFilters.clear();
                                      filterSchoolsBySearch(searchController.text, apiSchools);
                                    });
                                  },
                                  child: const Text('Clear All', style: TextStyle(color: Colors.black)),
                                ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(child: buildSchoolList(apiSchools)),
                    ],
                  ),
      );
    }
  }
}
