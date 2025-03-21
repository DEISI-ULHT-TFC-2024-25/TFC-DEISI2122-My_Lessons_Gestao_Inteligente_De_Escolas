import 'package:flutter/material.dart';

class PaymentFailPage extends StatelessWidget {
  final bool isFromCheckout;

  const PaymentFailPage({
    Key? key,
    required this.isFromCheckout,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Payment Failed")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Payment was not successful.",
              style: TextStyle(fontSize: 20, color: Colors.red),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (isFromCheckout) {
                  // For the Checkout flow, just pop back
                  Navigator.pop(context);
                } else {
                  // For the Payments page flow, do something else:
                  // e.g., pop multiple times or push a specific route.
                  // Example: go back to the PaymentsPage
                  Navigator.pushReplacementNamed(
                    context,
                    '/main',
                    arguments: {
                      'newBookedPacks': [],
                      'initialIndex': 2, // Payments tab index
                    },
                  );
                }
              },
              child: const Text("Try Again"),
            ),
          ],
        ),
      ),
    );
  }
}
