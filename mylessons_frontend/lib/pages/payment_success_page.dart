import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/api_service.dart';
import '../services/cart_service.dart';


class PaymentSuccessPage extends StatefulWidget {
  const PaymentSuccessPage({Key? key}) : super(key: key);

  @override
  _PaymentSuccessPageState createState() => _PaymentSuccessPageState();
}

class _PaymentSuccessPageState extends State<PaymentSuccessPage> {
  final CartService _cartService = CartService();

  @override
  void initState() {
    super.initState();
    _bookPacks();
  }

  Future<void> _bookPacks() async {
    // Filter only cart items that represent a pack.
    List<Map<String, dynamic>> packsPayload = _cartService.items.where((item) {
      // Check that the "type" is either a map with a "pack" key
      if (item.containsKey('type')) {
        if (item['type'] is Map<String, dynamic> && item['type'].containsKey('pack')) {
          return true;
        }
      }
      return false;
    }).map((item) {
      // Build the payload using the actual cart structure
      return {
        "students": item['students'],
        "school": item['school'],
        "expiration_date": item['expiration_date'], // in YYYY-MM-DD format
        "number_of_classes": item['number_of_classes'],
        "duration_in_minutes": item['duration_in_minutes'],
        "instructors": item['instructors'],
        "price": item['price'],
        // Payment is the pack's price.
        "payment": item['price'],
        "discount_id": item['discount_id'],
        // Directly use the type from the cart.
        "type": item['type'],
        // New flag to indicate the user paid from the success page.
        "user_paid": true,
      };
    }).toList();

    // Build the final payload.
    Map<String, dynamic> payload = {"packs": packsPayload};

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/users/book_pack/"),
        headers: await getAuthHeaders(),
        body: json.encode(payload),
      );

      if (response.statusCode == 201) {
        // On success, clear the cart.
        _cartService.clear();
        debugPrint("Pack booking successful: ${response.body}");
      } else {
        debugPrint("Failed to book packs. Status: ${response.statusCode}, Body: ${response.body}");
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
                Navigator.pushNamedAndRemoveUntil(context, '/main', (route) => false);
              },
              child: const Text("Continue"),
            ),
          ],
        ),
      ),
    );
  }
}
