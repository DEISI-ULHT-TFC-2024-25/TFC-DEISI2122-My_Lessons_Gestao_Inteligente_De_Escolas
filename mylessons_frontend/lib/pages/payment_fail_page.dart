import 'package:flutter/material.dart';

class PaymentFailPage extends StatelessWidget {
  final String? sessionId;
  const PaymentFailPage({Key? key, this.sessionId}) : super(key: key);

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
            if (sessionId != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text("Session ID: $sessionId"),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Navigate back or allow the user to try again.
                Navigator.pop(context);
              },
              child: const Text("Try Again"),
            ),
          ],
        ),
      ),
    );
  }
}
