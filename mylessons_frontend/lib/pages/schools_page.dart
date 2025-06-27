import 'package:flutter/material.dart';
import 'package:mylessons_frontend/widgets/school_card.dart';
import 'package:provider/provider.dart';
import 'school_details_page.dart';
import 'service_details_page.dart';
import '../providers/school_provider.dart';

class SchoolsPage extends StatefulWidget {
  const SchoolsPage({Key? key}) : super(key: key);

  @override
  _SchoolsPageState createState() => _SchoolsPageState();
}

class _SchoolsPageState extends State<SchoolsPage> {
  final TextEditingController searchController = TextEditingController();

  void _showFilterModal(SchoolProvider provider) {
    final allSports = provider.getAllSports();
    final allLocations = provider.getAllLocations();
    List<Map<String, String>> tempFilters = List.from(provider.selectedFilters);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          bool isFilterSelected(String type, String value) {
            return tempFilters
                .any((f) => f['type'] == type && f['value'] == value);
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
                                tempFilters.insert(
                                    0, {'type': 'sport', 'value': sport});
                              } else {
                                tempFilters.removeWhere((f) =>
                                    f['type'] == 'sport' &&
                                    f['value'] == sport);
                              }
                            });
                            provider.selectedFilters = List.from(tempFilters);
                            provider
                                .filterSchoolsBySearch(searchController.text);
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
                                tempFilters.insert(
                                    0, {'type': 'location', 'value': loc});
                              } else {
                                tempFilters.removeWhere((f) =>
                                    f['type'] == 'location' &&
                                    f['value'] == loc);
                              }
                            });
                            provider.selectedFilters = List.from(tempFilters);
                            provider
                                .filterSchoolsBySearch(searchController.text);
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
                        child: const Text('Close',
                            style: TextStyle(color: Colors.black)),
                      ),
                    )
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }

  Widget _buildSchoolCard(
      Map<String, dynamic> school, SchoolProvider provider) {
    return SchoolCard(school: school, provider: provider);
  }

  Widget _buildFilterChip(Map<String, String> filter, SchoolProvider provider) {
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
              provider.selectedFilters.remove(filter);
              provider.filterSchoolsBySearch(searchController.text);
            },
            child: const Icon(Icons.close, size: 16, color: Colors.white),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SchoolProvider>(
      builder: (context, provider, child) {
        // If a service is selected, show ServiceDetailsContent.
        if (provider.selectedService != null) {
          return Scaffold(
            appBar: AppBar(
              title: Text(provider.selectedService!['name']),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: provider.clearSelectedService,
              ),
            ),
            body: const ServiceDetailsContent(),
          );
        } else if (provider.selectedSchool != null) {
          return Scaffold(
            appBar: AppBar(
              title: Text(provider.selectedSchool!['name']),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: provider.clearSelectedSchool,
              ),
            ),
            body: SchoolDetailsContent(
              school: provider.selectedSchool!,
            ),
          );
        } else {
          // Sort schools so that favorites appear first.
          final sortedSchools =
              List<Map<String, dynamic>>.from(provider.filteredSchools);
          sortedSchools.sort((a, b) {
            if (a['isFavorite'] == true && b['isFavorite'] != true) {
              return -1;
            } else if (a['isFavorite'] != true && b['isFavorite'] == true) {
              return 1;
            }
            return 0;
          });

          return Scaffold(
            appBar: AppBar(title: const Text('Schools')),
            body: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.errorMessage.isNotEmpty
                    ? Center(child: Text('Error: ${provider.errorMessage}'))
                    : SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Search bar and filter button.
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: searchController,
                                      decoration: InputDecoration(
                                        hintText: 'Search schools...',
                                        prefixIcon: const Icon(Icons.search),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8.0),
                                        ),
                                      ),
                                      onChanged: (query) {
                                        provider.filterSchoolsBySearch(query);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.filter_list,
                                            color: Colors.orange),
                                        onPressed: () {
                                          _showFilterModal(provider);
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
                              // Display selected filter chips.
                              if (provider.selectedFilters.isNotEmpty)
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      ...provider.selectedFilters
                                          .map((filter) => _buildFilterChip(
                                              filter, provider))
                                          .toList(),
                                      TextButton(
                                        onPressed: () {
                                          provider.selectedFilters.clear();
                                          provider.filterSchoolsBySearch(
                                              searchController.text);
                                        },
                                        child: const Text('Clear All',
                                            style: TextStyle(
                                                color: Colors.orange)),
                                      ),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 24),
                              // List of school cards.
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: sortedSchools.length,
                                itemBuilder: (context, index) {
                                  return _buildSchoolCard(
                                      sortedSchools[index], provider);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
          );
        }
      },
    );
  }
}
