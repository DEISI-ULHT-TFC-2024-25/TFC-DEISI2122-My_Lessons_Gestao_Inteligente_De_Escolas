import 'dart:convert';
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import '../services/cart_service.dart';
import 'package:flutter/material.dart';

class PaymentSuccessPage extends StatefulWidget {
  /// Instead of a list of pack IDs, we now accept a map of
  /// each pack's ID to the amount paid.
  final Map<dynamic, double>? packAmounts;
  const PaymentSuccessPage({
    Key? key,
    this.packAmounts, // mapping of pack ID to amount (in euros)
  }) : super(key: key);

  @override
  _PaymentSuccessPageState createState() => _PaymentSuccessPageState();
}

class _PaymentSuccessPageState extends State<PaymentSuccessPage> {
  final CartService _cartService = CartService();
  List<dynamic> bookedPacks = [];

  // Make sure you have the Stripe client secret from your payment flow.
  // If you stored it in a variable like `_stripeClientSecret` in your previous page,
  // pass it here via constructor or route arguments.
  final String? _stripeClientSecret = null; // or pass via constructor

  @override
  void initState() {
    super.initState();
    _processSuccess();
  }

  /// Overall success handler:
  /// - If there are no items in the cart, create a debt payment record.
  /// - Otherwise, proceed to book packs.
  Future<void> _processSuccess() async {
    if (_cartService.items.isEmpty) {
      await _createDebtPaymentRecord();
    } else {
      await _bookPacks();
    }
  }

  /// Create a debt payment record using the provided pack amounts.
  Future<void> _createDebtPaymentRecord() async {
    if (widget.packAmounts == null || widget.packAmounts!.isEmpty) {
      debugPrint("No pack amounts to send; skipping debt payment record.");
      return;
    }

    final Map<String, dynamic> payload = {
      "pack_amounts": widget.packAmounts,
    };

    try {
      final url = Uri.parse("$baseUrl/api/payments/create_debt_payment_record/");
      final headers = await getAuthHeaders();

      final response = await http.post(
        url,
        headers: headers,
        body: json.encode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint("Debt Payment record created successfully: ${response.body}");
      } else {
        debugPrint(
          "Failed to create debt payment record: ${response.statusCode}, ${response.body}",
        );
      }
    } catch (e) {
      debugPrint("Error creating debt payment record from Stripe metadata: $e");
    }
  }

  /// Books the packs using your existing booking endpoint.
  Future<void> _bookPacks() async {
    // Build payload only for items that represent a pack.
    List<Map<String, dynamic>> packsPayload = _cartService.items.where((item) {
      // Check if the cart item has a 'service' with a 'type' map containing the key 'pack'.
      if (item.containsKey('service') &&
          item['service'] is Map<String, dynamic>) {
        final service = item['service'];
        if (service.containsKey('type') &&
            service['type'] is Map<String, dynamic> &&
            service['type'].containsKey('pack')) {
          return true;
        }
      }
      return false;
    }).map((item) {
      final service = item['service'] as Map<String, dynamic>;
      final checkoutDetails = service.containsKey('checkout_details') &&
              service['checkout_details'] is Map<String, dynamic>
          ? service['checkout_details'] as Map<String, dynamic>
          : {};

      return {
        "students": item['students'],
        "school": service['school_name'] ?? "Test School",
        "expiration_date": DateTime.now()
            .add(const Duration(days: 30))
            .toIso8601String()
            .split('T')
            .first,
        "number_of_classes": checkoutDetails['classes'] ?? 0,
        "duration_in_minutes": checkoutDetails['duration'] ?? 0,
        "instructors": [],
        "price": item['price'],
        "payment": item['price'],
        "discount_id": null,
        "type": service['type'],
        // Flag to indicate that this booking comes from the success page.
        "user_paid": true,
      };
    }).toList();

    Map<String, dynamic> payload = {"packs": packsPayload};

    try {
      debugPrint("Cart service items:\n${_cartService.items}\n");
      debugPrint("Booking packs with payload:\n$payload\n");

      final response = await http.post(
        Uri.parse("$baseUrl/api/users/book_pack/"),
        headers: await getAuthHeaders(),
        body: json.encode(payload),
      );

      if (response.statusCode == 201) {
        _cartService.clear();
        debugPrint("Pack booking successful: ${response.body}");
        final decodedResponse = json.decode(response.body);
        setState(() {
          bookedPacks = decodedResponse["booked_packs"];
        });
      } else {
        debugPrint(
            "Failed to book packs. Status: ${response.statusCode}, Body: ${response.body}");
      }
    } catch (e) {
      debugPrint("Error booking packs: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Payment Successful")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Thank you for your payment!",
              style: TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/main',
                  (route) => false,
                  arguments: {'newBookedPacks': bookedPacks},
                );
              },
              child: const Text("Continue"),
            ),
          ],
        ),
      ),
    );
  }
}
