// cart_service.dart
import 'package:flutter/foundation.dart';

class CartService {
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;
  CartService._internal();

  final List<Map<String, dynamic>> _items = [];
  // ValueNotifier to track changes in the cart count.
  final ValueNotifier<int> cartCount = ValueNotifier<int>(0);

  List<Map<String, dynamic>> get items => _items;

  void addToCart(
    Map<String, dynamic> service,
    List<Map<String, dynamic>> selectedStudents,
    double? price, {
    int? subjectId,
    String? subjectName,
    int? locationId,
    String? locationName,
    int? instructorId,
    String? instructorName,
  }) {
    _items.add({
      'service': service,
      'students': selectedStudents,
      'subject': (subjectId != null && subjectName != null)
          ? {'id': subjectId, 'name': subjectName}
          : null,
      'location': (locationId != null && locationName != null)
          ? {'id': locationId, 'name': locationName}
          : null,
      'instructor': (instructorId != null && instructorName != null)
          ? {'id': instructorId, 'name': instructorName}
          : null,
      'price': price,
    });
    cartCount.value = _items.length;
  }

  void removeAt(int index) {
    _items.removeAt(index);
    cartCount.value = _items.length;
  }

  void clear() {
    _items.clear();
    cartCount.value = 0;
  }

  int get totalItems => _items.length;
}
