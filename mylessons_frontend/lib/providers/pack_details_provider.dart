import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart' as ApiService;

class PackDetailsProvider extends ChangeNotifier {
  /// Data passed in from outside.
  dynamic pack;
  String currentRole = '';
  dynamic unschedulableLessons;
  Future<void> Function()? fetchData; // Optional callback to refresh home page

  /// The future that loads pack details from the API.
  Future<Map<String, dynamic>?>? _packDetailsFuture;

  /// A map to track loading states of different actions (e.g., 'Debt', 'School', etc.).
  final Map<String, bool> _isActionLoading = {};

  Map<String, bool> get isActionLoading => _isActionLoading;

  /// Initialize the provider with data. This replaces constructor arguments.
  void initialize({
    required dynamic pack,
    required String currentRole,
    required Future<void> Function()? fetchData,
    dynamic unschedulableLessons,
  }) {
    this.pack = pack;
    this.currentRole = currentRole;
    this.fetchData = fetchData;
    this.unschedulableLessons = unschedulableLessons;

    _refreshPackDetails();
  }

  /// Expose the future for the UI to use in a FutureBuilder.
  Future<Map<String, dynamic>?>? get packDetailsFuture => _packDetailsFuture;

  /// Refresh the modal's pack details.
  void _refreshPackDetails() {
    final int packId = _getPackId();
    _packDetailsFuture = ApiService.fetchPackDetails(packId);
    notifyListeners();
  }

  int _getPackId() {
    return pack['pack_id'] ?? pack['id'];
  }

  /// Mark an action as loading or not loading.
  void setActionLoading(String label, bool isLoading) {
    _isActionLoading[label] = isLoading;
    notifyListeners();
  }

  /// Format a date string to "15 mar 2025"
  String formatDate(String dateStr) {
    try {
      final DateTime date = DateTime.parse(dateStr);
      return DateFormat('d MMM yyyy').format(date).toLowerCase();
    } catch (e) {
      return dateStr;
    }
  }

  /// Public method to force a refresh of data from outside.
  Future<void> refreshPackDetails() async {
    _refreshPackDetails();
  }

  /// Sends the new expiration date to the API and refreshes.
  Future<bool> updateExpirationDate(DateTime newDate) async {
    final label = 'Expiration Date';
    setActionLoading(label, true);
    try {
      final int packId = _getPackId();
      final String formatted = DateFormat('yyyy-MM-dd').format(newDate);
      final success = await ApiService.updatePackExpirationDate(
        packId: packId,
        expirationDate: formatted,
      );
      if (success) {
        await refreshPackDetails();
      }
      return success;
    } finally {
      setActionLoading(label, false);
    }
  }
}
