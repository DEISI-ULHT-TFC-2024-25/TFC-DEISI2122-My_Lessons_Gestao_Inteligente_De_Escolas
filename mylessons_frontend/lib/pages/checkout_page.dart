import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;
import '../modals/schedule_first_lesson_modal.dart';
import '../services/api_service.dart';
import '../services/cart_service.dart';
import 'payment_success_page.dart';
import 'payment_fail_page.dart';

/// Helper function to get the currency symbol.
String getCurrencySymbol(String currencyCode) {
  return NumberFormat.simpleCurrency(name: currencyCode).currencySymbol;
}

class CheckoutPage extends StatefulWidget {
  final VoidCallback onBack; // Callback to return to the main view.
  const CheckoutPage({super.key, required this.onBack});

  @override
  _CheckoutPageState createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  List<Map<String, dynamic>> get cartItems => CartService().items;

  // Derives the currency symbol from the first cart item.
  String get cartCurrencySymbol {
    if (cartItems.isEmpty) return '';
    final firstItem = cartItems.first;
    final checkoutDetails =
        firstItem['service']['checkout_details'] as Map<String, dynamic>? ?? {};
    final currencyCode = checkoutDetails['currency'] ?? 'N/A';
    return getCurrencySymbol(currencyCode);
  }

  // Calculate the total using the numeric price from each item.
  double get totalPrice {
    double total = 0;
    for (var item in cartItems) {
      final checkoutDetails =
          item['service']['checkout_details'] as Map<String, dynamic>? ?? {};
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

  Future<void> _handleConfirmBooking() async {
    // Prevent multiple submissions by checking if already loading.
    if (_isLoading) return;

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

    // Save a copy of the checkout items (so we can show their card in the scheduling modal).
    final List<Map<String, dynamic>> checkoutPackItems =
        List<Map<String, dynamic>>.from(packItems);

    setState(() {
      _isLoading = true;
    });

    // Build a booking payload for each pack.
    List<Map<String, dynamic>> bookings = [];
    for (var packItem in packItems) {
      final checkoutDetails =
          packItem['service']['checkout_details'] as Map<String, dynamic>;

      // Determine timeLimit from checkoutDetails['time_limit'].
      final dynamic rawTimeLimit = checkoutDetails['time_limit'] ?? "0";
      final int timeLimitDays = rawTimeLimit is int
          ? rawTimeLimit
          : int.tryParse(rawTimeLimit.toString()) ?? 0;
      // Calculate expiration date.
      final expirationDate = DateTime.now().add(Duration(days: timeLimitDays));
      final formattedExpirationDate =
          expirationDate.toIso8601String().split("T")[0];

      final bookingPayload = {
        "students": packItem['students'] ?? [],
        "school": checkoutDetails['school_name'] ?? 'default_school_id',
        "expiration_date": formattedExpirationDate,
        "number_of_classes": checkoutDetails['classes'],
        "duration_in_minutes": checkoutDetails['duration'],
        "instructors": packItem['service']['instructors'] ?? [],
        "subject": checkoutDetails['subject'] ?? null, // new key for subject
        "location": checkoutDetails['location'] ?? null, // new key for location
        "price": checkoutDetails['price'],
        "payment": "cash",
        "discount_id": null,
        "type": checkoutDetails['type'] is Map &&
                checkoutDetails['type'].containsKey('pack')
            ? checkoutDetails['type']['pack']
            : checkoutDetails['type'] ?? "private",
      };

      bookings.add(bookingPayload);
    }

    final body = jsonEncode({"packs": bookings});
    final url = Uri.parse('$baseUrl/api/users/book_pack/');
    final headers = await getAuthHeaders();
    headers['Content-Type'] = 'application/json';

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                "All packs booked successfully! Please pay by cash upon service."),
          ),
        );

        // Finally clear the cart and redirect to home.
        CartService().clear();
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/main',
          (route) => false,
        );
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

  ///////////////// Stripe Payment Integration ///////////////////

  bool _stripeLoading = false;
  String? _stripeClientSecret;
  String? _stripeError;
  double _discount = 0.0;

  Future<void> _createPaymentIntentStripe() async {
    setState(() {
      _stripeLoading = true;
      _stripeError = null;
    });
    try {
      final cartItems = CartService().items;
      final Map<String, dynamic> payload = {
        "cart": cartItems,
        "discount": _discount,
      };

      final url = Uri.parse('$baseUrl/api/payments/create_payment_intent/');
      final headers = await getAuthHeaders();
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        _stripeClientSecret = data["clientSecret"];
        await Stripe.instance.initPaymentSheet(
          paymentSheetParameters: SetupPaymentSheetParameters(
            paymentIntentClientSecret: _stripeClientSecret!,
            merchantDisplayName: 'My Lessons',
          ),
        );
      } else {
        setState(() {
          _stripeError = "Error creating PaymentIntent: ${response.body}";
        });
        debugPrint("Error creating PaymentIntent: ${response.body}");
      }
    } catch (e) {
      setState(() {
        _stripeError = "Exception in _createPaymentIntent: $e";
      });
      debugPrint("Exception in _createPaymentIntent: $e");
    }
    setState(() {
      _stripeLoading = false;
    });
  }

  Future<void> _presentPaymentSheetStripe() async {
    try {
      await Stripe.instance.presentPaymentSheet();
      // Payment succeeded: clear the cart and navigate to PaymentSuccessPage.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PaymentSuccessPage()),
      );
    } catch (e) {
      debugPrint("PaymentSheet error: $e");
      // From your checkout flow:
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const PaymentFailPage(isFromCheckout: true),
        ),
      );
    }
  }

  Future<void> _handleStripePayment() async {
    await _createPaymentIntentStripe();
    if (_stripeClientSecret != null) {
      await _presentPaymentSheetStripe();
    } else if (_stripeError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_stripeError!)),
      );
    }
  }

  //////////////////////////////////////////////////////////////////

  Widget _buildCheckoutCard(Map<String, dynamic> checkoutItem) {
    final service = checkoutItem['service'] as Map<String, dynamic>? ?? {};
    final checkoutDetails =
        service['checkout_details'] as Map<String, dynamic>? ?? {};

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
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
            Text(
                "Number of Students: ${checkoutDetails['number_of_students'] ?? 'N/A'}"),
            const SizedBox(height: 4),
            if (checkoutDetails['student_names'] is List)
              ...List<String>.from(checkoutDetails['student_names'])
                  .map((name) => Text("    - $name")),
            const SizedBox(height: 4),
            Text("Time Limit: ${checkoutDetails['time_limit'] ?? 'N/A'} days"),
            Text("Price: ${checkoutDetails['formatted_price'] ?? 'N/A'}"),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsCard(Map<String, dynamic> cartItem, int index) {
    final service = cartItem['service'] as Map<String, dynamic>? ?? {};
    final checkoutDetails =
        service['checkout_details'] as Map<String, dynamic>? ?? {};

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
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  Text(
                      "Duration: ${checkoutDetails['duration'] ?? 'N/A'} minutes"),
                  Text(
                      "Number of Classes: ${checkoutDetails['classes'] ?? 'N/A'}"),
                  Text(
                      "Number of Students: ${checkoutDetails['number_of_students'] ?? 'N/A'}"),
                  const SizedBox(height: 4),
                  if (checkoutDetails['student_names'] is List)
                    ...List<String>.from(checkoutDetails['student_names'])
                        .map((name) => Text("    - $name")),
                  const SizedBox(height: 4),
                  Text(
                      "Time Limit: ${checkoutDetails['time_limit'] ?? 'N/A'} days"),
                  const Divider(),
                  // NEW: Add subject, location and instructor details if available.
                  if (checkoutDetails['subject'] != null)
                    Text("Subject: ${checkoutDetails['subject']?["name"]}",
                        style: const TextStyle(fontSize: 14)),
                  if (checkoutDetails['location'] != null)
                    Text("Location: ${checkoutDetails['location']?["name"]}",
                        style: const TextStyle(fontSize: 14)),
                  if (checkoutDetails['instructor'] != null)
                    Text(
                        "Instructor: ${checkoutDetails['instructor']?["name"]}",
                        style: const TextStyle(fontSize: 14)),
                  const Divider(),
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
                icon: const Icon(Icons.delete, color: Colors.red),
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
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                // Payment options buttons.
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Cash Payment Button calls the integrated booking method.
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleConfirmBooking,
                      child: const Text("Pay by Cash"),
                    ),
                    // Stripe Payment Button now calls the integrated Stripe payment flow.
                    ElevatedButton(
                      onPressed: _handleStripePayment,
                      child: _stripeLoading
                          ? const CircularProgressIndicator()
                          : const Text("Pay Now"),
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
