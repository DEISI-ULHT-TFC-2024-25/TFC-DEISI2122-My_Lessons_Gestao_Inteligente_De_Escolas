import 'package:flutter/material.dart';
import '../services/api_service.dart';

class SchoolProvider extends ChangeNotifier {
  List<Map<String, dynamic>> apiSchools = [];
  List<Map<String, dynamic>> filteredSchools = [];
  List<Map<String, String>> selectedFilters = [];
  Map<String, dynamic>? selectedSchool;
  Map<String, dynamic>? selectedService;
  bool isLoading = true;
  String errorMessage = '';

  SchoolProvider() {
    fetchAndSetSchools();
  }

  Future<void> fetchAndSetSchools() async {
    try {
      final data = await fetchSchools();
      apiSchools = data;
      filteredSchools = data;
      isLoading = false;
      notifyListeners();
    } catch (e) {
      errorMessage = e.toString();
      isLoading = false;
      notifyListeners();
    }
  }

  void filterSchoolsBySearch(String query) {
    filteredSchools = apiSchools.where((school) {
      final lowerQuery = query.toLowerCase();
      bool matchesSchoolName =
          school['name'].toString().toLowerCase().contains(lowerQuery);
      bool matchesService =
          (school['services'] as List<dynamic>? ?? []).any((svc) {
        final svcName = svc['name']?.toString().toLowerCase() ?? '';
        return svcName.contains(lowerQuery);
      });
      bool matchesSport =
          (school['sports'] as List<dynamic>? ?? []).any((sport) {
        return sport.toString().toLowerCase().contains(lowerQuery);
      });
      bool matchesLocation =
          (school['locations'] as List<dynamic>? ?? []).any((loc) {
        return loc.toString().toLowerCase().contains(lowerQuery);
      });
      final matchesQuery = query.isEmpty ||
          matchesSchoolName ||
          matchesService ||
          matchesSport ||
          matchesLocation;

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
    notifyListeners();
  }

  List<String> getAllSports() {
    final Set<String> sportsSet = {};
    for (var school in apiSchools) {
      for (var sport in school['sports']) {
        sportsSet.add(sport);
      }
    }
    return sportsSet.toList();
  }

  List<String> getAllLocations() {
    final Set<String> locSet = {};
    for (var school in apiSchools) {
      for (var loc in school['locations']) {
        locSet.add(loc);
      }
    }
    return locSet.toList();
  }

  void selectSchool(Map<String, dynamic> school) {
    selectedSchool = school;
    selectedService = null;
    notifyListeners();
  }

  void clearSelectedSchool() {
    selectedSchool = null;
    selectedService = null;
    notifyListeners();
  }

  void selectService(Map<String, dynamic> service) {
    selectedService = service;
    notifyListeners();
  }

  void clearSelectedService() {
    selectedService = null;
    notifyListeners();
  }
}
