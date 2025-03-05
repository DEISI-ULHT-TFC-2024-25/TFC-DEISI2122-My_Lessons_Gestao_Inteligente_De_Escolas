import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/cart_service.dart';
import '../services/auth_service.dart'; // Assuming getAuthHeaders() is defined here.
import 'package:http/http.dart' as http;

/// Helper function to get the currency symbol.
String getCurrencySymbol(String currencyCode) {
  return NumberFormat.simpleCurrency(name: currencyCode).currencySymbol;
}

class CheckoutPage extends StatefulWidget {
  final VoidCallback onBack; // Callback to return to the main view.
  const CheckoutPage({Key? key, required this.onBack}) : super(key: key);

  @override
  _CheckoutPageState createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  List<Map<String, dynamic>> get cartItems => CartService().items;

  // Derives the currency symbol from the first cart item.
  String get cartCurrencySymbol {
    if (cartItems.isEmpty) return '';
    final firstItem = cartItems.first;
    final checkoutDetails = firstItem['service']['checkout_details'] as Map<String, dynamic>? ?? {};
    final currencyCode = checkoutDetails['currency'] ?? 'N/A';
    return getCurrencySymbol(currencyCode);
  }

  // Calculate the total using the numeric price from each item.
  double get totalPrice {
    double total = 0;
    for (var item in cartItems) {
      final checkoutDetails = item['service']['checkout_details'] as Map<String, dynamic>? ?? {};
      final rawPrice = checkoutDetails['price'];
      if (rawPrice != null) {
        total += rawPrice is double
            ? rawPrice
            : double.tryParse(rawPrice.toString()) ?? 0;
      }
    }
    return total;
  }

  void _removeItem(int index) {
    setState(() {
      CartService().removeAt(index);
    });
  }

  /// Handles booking via cash.
  /// This function builds a booking payload for each pack service in the cart,
  /// calls your backend API, and on success clears the cart and navigates back.
  Future<void> _handleConfirmBooking() async {
    final cartItems = CartService().items;
    // Filter only pack services.
    final packItems = cartItems.where((item) {
      final service = item['service'] as Map<String, dynamic>;
      return service['type'] is Map && service['type'].containsKey('pack');
    }).toList();

    if (packItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No pack services found in your cart.")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Build a list of booking payloads for each pack in the cart.
    List<Map<String, dynamic>> bookings = [];
    for (var packItem in packItems) {
      final checkoutDetails = packItem['service']['checkout_details'] as Map<String, dynamic>;

      // Determine timeLimitDays from checkoutDetails['time_limit'] which may be either an int or a String.
      final dynamic rawTimeLimit = checkoutDetails['time_limit'] ?? "0";
      final int timeLimitDays = rawTimeLimit is int
          ? rawTimeLimit
          : int.tryParse(rawTimeLimit.toString()) ?? 0;
      // Add the days to the current date.
      final expirationDate = DateTime.now().add(Duration(days: timeLimitDays));
      // Format the date as YYYY-MM-DD.
      final formattedExpirationDate = expirationDate.toIso8601String().split("T")[0];

      final bookingPayload = {
        "students": packItem['students'] ?? [],
        // Use the school name from checkout details; your backend should convert it accordingly.
        "school": checkoutDetails['school_name'] ?? 'default_school_id',
        "expiration_date": formattedExpirationDate,
        "number_of_classes": checkoutDetails['classes'],
        "duration_in_minutes": checkoutDetails['duration'],
        "instructors": packItem['service']['instructors'] ?? [],
        "price": checkoutDetails['price'],
        "payment": "cash",
        "discount_id": null,
        "type": checkoutDetails['type'] is Map && checkoutDetails['type'].containsKey('pack')
            ? checkoutDetails['type']['pack']
            : checkoutDetails['type'] ?? "private",
      };

      bookings.add(bookingPayload);
    }

    // Build the complete request body with all booking payloads.
    final body = jsonEncode({"packs": bookings});
    final url = Uri.parse('http://127.0.0.1:8000/api/users/book_pack/');
    final headers = await getAuthHeaders();

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("All packs booked successfully! Please pay by cash upon service."),
          ),
        );
        CartService().clear();
        Navigator.pushNamedAndRemoveUntil(context, '/main', (route) => false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Booking failed: ${response.body}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  bool _isLoading = false;

  /// Initiates Stripe Checkout.
  /// This function should call your backend to create a Stripe Checkout session.
  Future<void> _initiateStripeCheckout() async {
    try {
      // Example: Replace with your actual Stripe integration.
      final sessionUrl = 'https://checkout.stripe.com/pay/cs_test_1234567890';
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Redirecting to Stripe Checkout...")),
      );
      // Use url_launcher or similar package to open the session URL.
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Stripe checkout error: $e")),
      );
    }
  }

  /// Build a details card using the checkout_details from the service.
  /// The [index] is used to remove the item when the delete icon is tapped.
  Widget _buildDetailsCard(Map<String, dynamic> cartItem, int index) {
    final service = cartItem['service'] as Map<String, dynamic>? ?? {};
    final checkoutDetails = service['checkout_details'] as Map<String, dynamic>? ?? {};

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        margin: const EdgeInsets.all(8.0),
        child: Stack(
          children: [
            // Card content.
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${checkoutDetails['service_name'] ?? 'N/A'} - ${checkoutDetails['school_name'] ?? 'N/A'}",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  Text("Duration: ${checkoutDetails['duration'] ?? 'N/A'} minutes"),
                  Text("Number of Classes: ${checkoutDetails['classes'] ?? 'N/A'}"),
                  Text("Number of Students: ${checkoutDetails['number_of_students'] ?? 'N/A'}"),
                  const SizedBox(height: 4),
                  if (checkoutDetails['student_names'] is List)
                    ...List<String>.from(checkoutDetails['student_names'])
                        .map((name) => Text("    - $name")),
                  const SizedBox(height: 4),
                  Text("Time Limit: ${checkoutDetails['time_limit'] ?? 'N/A'} days"),
                  Text("Price: ${checkoutDetails['formatted_price'] ?? 'N/A'}"),
                  const SizedBox(height: 40),
                ],
              ),
            ),
            // Delete icon positioned at bottom right inside the card.
            Positioned(
              bottom: 0,
              right: 0,
              child: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => _removeItem(index),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Checkout Confirmation"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: cartItems.isEmpty
                ? const Center(child: Text("Your cart is empty"))
                : ListView.builder(
                    itemCount: cartItems.length,
                    itemBuilder: (context, index) {
                      return _buildDetailsCard(cartItems[index], index);
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(
                  "Total: $cartCurrencySymbol${totalPrice.toStringAsFixed(2)}",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                // Payment options buttons.
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Cash Payment Button calls the integrated booking method.
                    ElevatedButton(
                      onPressed: _handleConfirmBooking,
                      child: const Text("Pay by Cash"),
                    ),
                    // Stripe Checkout Button.
                    ElevatedButton(
                      onPressed: _initiateStripeCheckout,
                      child: const Text("Pay Now"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
