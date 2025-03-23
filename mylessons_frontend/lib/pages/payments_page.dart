import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import 'payment_fail_page.dart';
import 'payment_success_page.dart';

class PaymentsPage extends StatefulWidget {
  const PaymentsPage({Key? key}) : super(key: key);

  @override
  _PaymentsPageState createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> {
  bool _loading = true;
  String _currentRole = "";

  // ----- Parent Data -----
  double _debt = 0;
  List<Map<String, dynamic>> _unpaid = [];
  List<Map<String, dynamic>> _parentHistory = [];

  // ----- Instructor Data -----
  double _balance = 0;
  String _nextPayoutDate = "";
  List<int> _statsData = [];
  List<Map<String, dynamic>> _instructorHistory = [];

  // ----- Admin Data -----
  List<Map<String, dynamic>> _userDebt = [];
  List<Map<String, dynamic>> _upcomingPayouts = [];
  List<Map<String, dynamic>> _adminHistory = [];

  // Common search query for Payment History.
  String _historySearchQuery = "";

  // State to track selected items and split amounts for Parent unpaid items.
  Map<dynamic, bool> _selectedItems = {};
  Map<dynamic, double> _splitAmounts = {};

  @override
  void initState() {
    super.initState();
    _initPage();
  }

  Future<void> _initPage() async {
    _currentRole = await fetchCurrentRole();
    await _fetchData();
    setState(() => _loading = false);
  }

  Future<void> _fetchData() async {
    if (_currentRole == "Parent") {
      await _fetchParentData();
    } else if (_currentRole == "Instructor") {
      await _fetchInstructorData();
    } else if (_currentRole == "Admin") {
      await _fetchAdminData();
    }
  }

  // ------------------- Parent Data -------------------
  Future<void> _fetchParentData() async {
    final headers = await getAuthHeaders();
    try {
      final debtRes = await http.get(Uri.parse('$baseUrl/api/payments/debt/'),
          headers: headers);
      final unpaidRes = await http.get(
          Uri.parse('$baseUrl/api/payments/unpaid_items/'),
          headers: headers);
      final historyRes = await http
          .get(Uri.parse('$baseUrl/api/payments/history/'), headers: headers);

      if (debtRes.statusCode == 200) {
        final decoded = json.decode(utf8.decode(debtRes.bodyBytes));
        _debt = double.tryParse(decoded['current_debt'].toString()) ?? 0;
      }
      if (unpaidRes.statusCode == 200) {
        _unpaid = List<Map<String, dynamic>>.from(json.decode(utf8.decode(unpaidRes.bodyBytes)));
        // Initialize each item's selection state and split amount.
        for (var item in _unpaid) {
          var packId = item['pack_id'];
          if (!_selectedItems.containsKey(packId)) {
            _selectedItems[packId] = true;
            double fullAmount =
                double.tryParse(item['amount']?.toString() ?? "0") ?? 0;
            _splitAmounts[packId] = fullAmount;
          }
        }
      }
      if (historyRes.statusCode == 200) {
        _parentHistory =
            List<Map<String, dynamic>>.from(json.decode(utf8.decode(historyRes.bodyBytes)));
      }
    } catch (e) {
      debugPrint("Error fetching Parent data: $e");
    }
  }

  // ------------------- Instructor Data -------------------
  Future<void> _fetchInstructorData() async {
    final headers = await getAuthHeaders();
    try {
      final historyRes = await http.get(
          Uri.parse('$baseUrl/api/payments/instructor_payment_history/'),
          headers: headers);
      if (historyRes.statusCode == 200) {
        _instructorHistory =
            List<Map<String, dynamic>>.from(json.decode(utf8.decode(historyRes.bodyBytes)));
      }
      final balanceResponse = await http.get(
          Uri.parse('$baseUrl/api/users/current_balance/'),
          headers: headers);
      if (balanceResponse.statusCode == 200) {
        final b = json.decode(utf8.decode(balanceResponse.bodyBytes))['current_balance'];
        _balance = double.tryParse(b.toString()) ?? 0.0;
      }
      _nextPayoutDate = "Not Defined";
      _statsData = [12, 8, 14, 5, 19, 22, 7, 10, 13, 8, 12, 15];
    } catch (e) {
      debugPrint("Error fetching Instructor data: $e");
    }
  }

  // ------------------- Admin Data -------------------
  Future<void> _fetchAdminData() async {
    final headers = await getAuthHeaders();
    try {
      final debtRes = await http.get(
          Uri.parse('$baseUrl/api/payments/school_unpaid_items/'),
          headers: headers);
      final upcomingRes = await http.get(
          Uri.parse('$baseUrl/api/payments/upcoming_payouts/'),
          headers: headers);
      final historyRes = await http.get(
          Uri.parse('$baseUrl/api/payments/school_payment_history/'),
          headers: headers);

      final decodedDebt = json.decode(utf8.decode(debtRes.bodyBytes));
      if (decodedDebt is List) {
        _userDebt = List<Map<String, dynamic>>.from(decodedDebt);
      } else if (decodedDebt is Map && decodedDebt.containsKey("data")) {
        _userDebt = List<Map<String, dynamic>>.from(decodedDebt["data"]);
      } else {
        _userDebt = [];
      }

      final decodedUpcoming = json.decode(utf8.decode(upcomingRes.bodyBytes));
      if (decodedUpcoming is List) {
        _upcomingPayouts = List<Map<String, dynamic>>.from(decodedUpcoming);
      } else if (decodedUpcoming is Map &&
          decodedUpcoming.containsKey("data")) {
        _upcomingPayouts =
            List<Map<String, dynamic>>.from(decodedUpcoming["data"]);
      } else {
        _upcomingPayouts = [];
      }

      final decodedHistory = json.decode(utf8.decode(historyRes.bodyBytes));
      if (decodedHistory is List) {
        _adminHistory = List<Map<String, dynamic>>.from(decodedHistory);
      } else if (decodedHistory is Map && decodedHistory.containsKey("data")) {
        _adminHistory = List<Map<String, dynamic>>.from(decodedHistory["data"]);
      } else {
        _adminHistory = [];
      }
    } catch (e) {
      debugPrint("Error fetching Admin data: $e");
    }
  }

  Future<void> _redulateDebt() async {
    try {
      final headers = await getAuthHeaders();
      final response = await http.post(
          Uri.parse('$baseUrl/api/payments/redulate_debt/'),
          headers: headers);
      if (response.statusCode == 200) {
        await _fetchData();
      } else {
        debugPrint("Failed to redulate debt. Status: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error redulating debt: $e"); // TODO utf8?
    }
  }

  // Example in _showPaymentDetailsModal:
  Future<void> _showPaymentDetailsModal(Map<String, dynamic> item) async {
    final dateStr = item['date'] ?? "2025-01-15";
    final timeStr = item['time'] ?? "09:00";
    final dateTimeStr = "$dateStr $timeStr";
    final parsedDate = DateTime.tryParse(dateTimeStr) ?? DateTime.now();
    // Updated formatting:
    final formattedDate = DateFormat("dd MMM yyyy").format(parsedDate);
    final formattedTime = DateFormat("hh:mm a").format(parsedDate);
    final school = (item['school'] ?? "").toString();
    final amount = double.tryParse(item['amount']?.toString() ?? "0")
            ?.toStringAsFixed(2) ??
        "0.00";
    final desc = item['description'];
    String detailsStr;
    if (desc is String) {
      detailsStr = desc;
    } else if (desc is Map || desc is List) {
      detailsStr = json.encode(desc);
    } else {
      detailsStr = desc?.toString() ?? '';
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 16,
            left: 16,
            right: 16,
          ),
          child: SingleChildScrollView(
            child: _buildDetailsModalContent(
              formattedDate: formattedDate,
              formattedTime: formattedTime,
              school: school,
              amount: amount,
              details: detailsStr,
            ),
          ),
        );
      },
    );
  }

  // NEW: Admin Balance Modal Details – shows only roles, amount and description.
  Future<void> _showAdminBalanceModal(Map<String, dynamic> item) async {
    // Expecting the upcoming payout item to have keys: "roles", "current_balance" and "description".
    final roles = item['roles']?.toString() ?? "N/A";
    final amount = double.tryParse(item['current_balance']?.toString() ?? "0")
            ?.toStringAsFixed(2) ??
        "0.00";
    final description = item['description']?.toString() ?? "";
    print("description_raw\n${item["description"]}\n");
    print("description_str\n$description\n");
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 16,
            left: 16,
            right: 16,
          ),
          child: SingleChildScrollView(
            child: _buildAdminBalanceModalContent(
              roles: roles,
              amount: amount,
              description: description,
            ),
          ),
        );
      },
    );
  }

  Widget _buildAdminBalanceModalContent({
    required String roles,
    required String amount,
    required String description,
  }) {
    // Attempt to parse the description as JSON.
    // We expect it to be a list of transaction entries.
    List<dynamic> transactions = [];
    try {
      transactions = json.decode(utf8.decode(description.codeUnits)) as List<dynamic>;
    } catch (e) {
      debugPrint("Error parsing description JSON: $e");
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text("Balance Details",
            style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        // Roles Info
        Row(
          children: [
            Expanded(child: _buildInfoCard(Icons.person, "Roles", roles)),
          ],
        ),
        const SizedBox(height: 8),
        // Amount Info
        Row(
          children: [
            Expanded(
                child:
                    _buildInfoCard(Icons.attach_money, "Amount", "$amount€")),
          ],
        ),
        const SizedBox(height: 8),
        // Description Label
        Text("Description",
            style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        // Scrollable list of transactions from the description JSON
        Container(
          height: 200,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: transactions.isNotEmpty
              ? ListView.builder(
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final tx = transactions[index] as Map<String, dynamic>;
                    final txTimestampRaw = tx["timestamp"] ?? "Unknown Time";
                    DateTime? txDateTime;
                    try {
                      txDateTime = DateTime.parse(txTimestampRaw);
                    } catch (e) {
                      debugPrint("Error parsing transaction timestamp: $e");
                    }
                    final txTimestampFormatted = (txDateTime != null)
                        ? DateFormat("dd MMM yyyy 'at' HH:mm")
                            .format(txDateTime)
                        : txTimestampRaw;

                    final txAmount = tx["amount"] ?? "0.00";
                    final txMessage = tx["message"] ?? "";
                    final txBalance = tx["current_balance"] ?? "0.00";

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          vertical: 4, horizontal: 4),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(txMessage,
                                style: GoogleFonts.lato(
                                    fontSize: 14, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text("Registered: $txTimestampFormatted",
                                style: GoogleFonts.lato(fontSize: 12)),
                            Text("Amount: $txAmount",
                                style: GoogleFonts.lato(fontSize: 12)),
                            Text("Balance: $txBalance",
                                style: GoogleFonts.lato(fontSize: 12)),
                          ],
                        ),
                      ),
                    );
                  },
                )
              : Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text("No transactions available.",
                      style: GoogleFonts.lato(fontSize: 14)),
                ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
          ),
          child: const Text("Close", style: TextStyle(color: Colors.white)),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  bool _isLoading = false;

  ///////////////// Stripe Payment Integration ///////////////////
  bool _stripeLoading = false;
  String? _stripeClientSecret;
  String? _stripeError;
  double _discount = 0.0;

  Future<void> _createDebtPaymentIntentStripe() async {
    setState(() {
      _stripeLoading = true;
      _stripeError = null;
    });
    try {
      // Extract a list of pack IDs from the _unpaid items.
      List<dynamic> packIds = _unpaid.map((item) => item['pack_id']).toList();
      final Map<String, dynamic> payload = {
        "pack_ids": packIds,
      };

      final url =
          Uri.parse('$baseUrl/api/payments/create_debt_payment_intent/');
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
        _stripeError = "Exception in _createDebtPaymentIntentStripe: $e";
      });
      debugPrint("Exception in _createDebtPaymentIntentStripe: $e");
    }
    setState(() {
      _stripeLoading = false;
    });
  }

  Future<void> _presentPaymentSheetStripe() async {
    // Build a map of selected pack IDs to their respective split amounts.
    Map<dynamic, double> selectedAmounts = {};
    for (var item in _unpaid) {
      var packId = item['pack_id'];
      if (_selectedItems[packId] ?? true) {
        double fullAmount =
            double.tryParse(item['amount']?.toString() ?? "0") ?? 0;
        double amountToPay = _splitAmounts[packId] ?? fullAmount;
        selectedAmounts[packId] = amountToPay;
      }
    }

    try {
      await Stripe.instance.presentPaymentSheet();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentSuccessPage(
            packAmounts:
                selectedAmounts, // Pass the mapping to the success page.
          ),
        ),
      );
    } catch (e) {
      debugPrint("PaymentSheet error: $e");
      // From your payments flow:
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const PaymentFailPage(isFromCheckout: false),
        ),
      );
    }
  }

  // Updated payment handler to use selected items and their split amounts.
  Future<void> _handleDebtStripePayment() async {
    // Filter the unpaid items to only those that are selected.
    List<dynamic> selectedPackIds = _unpaid
        .where((item) {
          var packId = item['pack_id'];
          return _selectedItems[packId] ?? true;
        })
        .map((item) => item['pack_id'])
        .toList();

    // Build a mapping for the split amounts of the selected items.
    Map<dynamic, double> selectedSplitAmounts = {};
    for (var item in _unpaid) {
      var packId = item['pack_id'];
      if (_selectedItems[packId] ?? true) {
        double fullAmount =
            double.tryParse(item['amount']?.toString() ?? "0") ?? 0;
        double amountToPay = _splitAmounts[packId] ?? fullAmount;
        selectedSplitAmounts[packId] = amountToPay;
      }
    }

    setState(() {
      _stripeLoading = true;
      _stripeError = null;
    });
    try {
      debugPrint("Payload amounts: $selectedSplitAmounts");
      debugPrint("Payload pack_ids: $selectedPackIds");

      final headers = await getAuthHeaders();
      final payload = {
        "pack_ids": selectedPackIds,
        "amounts": selectedSplitAmounts,
      };
      final url =
          Uri.parse('$baseUrl/api/payments/create_debt_payment_intent/');
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
        await _presentPaymentSheetStripe();
      } else {
        setState(() {
          _stripeError = "Error creating PaymentIntent: ${response.body}";
        });
        debugPrint("Error creating PaymentIntent: ${response.body}");
      }
    } catch (e) {
      setState(() {
        _stripeError = "Exception in _handleDebtStripePayment: $e";
      });
      debugPrint("Exception in _handleDebtStripePayment: $e");
    }
    setState(() {
      _stripeLoading = false;
    });
  }

  Widget _buildDetailsModalContent({
    required String formattedDate,
    required String formattedTime,
    required String school,
    required String amount,
    required String details,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text("Payment Details",
            style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
                child: _buildInfoCard(
                    Icons.calendar_today, "DATE", formattedDate)),
            const SizedBox(width: 8),
            Expanded(
                child:
                    _buildInfoCard(Icons.access_time, "TIME", formattedTime)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildInfoCard(Icons.school, "SCHOOL", school)),
            const SizedBox(width: 8),
            Expanded(
                child:
                    _buildInfoCard(Icons.attach_money, "AMOUNT", "$amount€")),
          ],
        ),
        const SizedBox(height: 8),
        _buildFullWidthCard(Icons.description, "DETAILS", details),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
          ),
          child: const Text("Close", style: TextStyle(color: Colors.white)),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildInfoCard(IconData icon, String label, String value) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.lato(
                          fontSize: 12, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(value,
                      style: GoogleFonts.lato(fontSize: 12),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullWidthCard(IconData icon, String label, String value) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.lato(
                          fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(value, style: GoogleFonts.lato(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Parent Tabs ----------------
  Widget _buildParentUnpaidTab() {
    // Compute the sum of selected items' amounts.
    double selectedDebt = 0;
    for (var item in _unpaid) {
      var packId = item['pack_id'];
      double fullAmount =
          double.tryParse(item['amount']?.toString() ?? "0") ?? 0;
      double currentSplit = _splitAmounts[packId] ?? fullAmount;
      if (_selectedItems[packId] ?? true) {
        selectedDebt += currentSplit;
      }
    }

    // Using a Stack so the Pay Debt button can float fixed at the bottom.
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _fetchData,
          color: Colors.orange,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                // Card showing Total Debt and, if different, Selected Debt.
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  color: Colors.grey[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Total Debt",
                                style: GoogleFonts.lato(
                                    fontSize: 20, fontWeight: FontWeight.bold)),
                            Text("${_debt.toStringAsFixed(2)}€",
                                style: GoogleFonts.lato(
                                    fontSize: 20, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        if (selectedDebt != _debt)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Selected Debt",
                                    style: GoogleFonts.lato(fontSize: 16)),
                                Text("${selectedDebt.toStringAsFixed(2)}€",
                                    style: GoogleFonts.lato(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _unpaid.isEmpty
                    ? Text("No unpaid items",
                        style: GoogleFonts.lato(color: Colors.black54))
                    : Column(
                        children: _unpaid
                            .map((item) => _buildUnpaidItemCard(item))
                            .toList(),
                      ),
              ],
            ),
          ),
        ),
        // Fixed Pay Debt button at the bottom.
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: ElevatedButton(
            onPressed: (_debt == 0 || selectedDebt == 0 || _stripeLoading)
                ? null
                : _handleDebtStripePayment,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32)),
            ),
            child: _stripeLoading
                ? const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  )
                : const Text(
                    "Pay Debt",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ],
    );
  }

  // Build a card for each unpaid item with a checkbox and a split button.
  Widget _buildUnpaidItemCard(Map<String, dynamic> item) {
    final packId = item['pack_id'];
    double fullAmount = double.tryParse(item['amount']?.toString() ?? "0") ?? 0;
    double currentSplit = _splitAmounts[packId] ?? fullAmount;
    bool isSelected = _selectedItems[packId] ?? true;
    final dateStr = item['date'] ?? "2025-01-15";
    final timeStr = item['time'] ?? "09:00";
    final dateTimeStr = "$dateStr $timeStr";
    final parsedDate = DateTime.tryParse(dateTimeStr) ?? DateTime.now();
    final formattedDate =
        DateFormat("d MMM yyyy 'at' HH:mm").format(parsedDate);

    // If the user split the amount (i.e. currentSplit differs from fullAmount),
    // show "X€ of Y€", otherwise just show the full amount.
    final amountDisplay = (currentSplit != fullAmount)
        ? "${currentSplit.toStringAsFixed(2)}€ of ${fullAmount.toStringAsFixed(2)}€"
        : "${fullAmount.toStringAsFixed(2)}€";

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.grey[50],
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // Checkbox (default checked).
            Checkbox(
              value: isSelected,
              onChanged: (val) {
                setState(() {
                  _selectedItems[packId] = val ?? false;
                });
              },
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(formattedDate,
                      style: GoogleFonts.lato(
                          fontSize: 14, color: Colors.black87)),
                  // Display the split amount as "X€ of Y€" if applicable.
                  Text(
                    amountDisplay,
                    style: GoogleFonts.lato(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                ],
              ),
            ),
            // Split button to adjust the payable amount.
            TextButton(
              onPressed: () async {
                double? result =
                    await _showSplitDialog(currentSplit, fullAmount);
                if (result != null) {
                  setState(() {
                    _splitAmounts[packId] = result;
                  });
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.orange),
              child: const Text("Split"),
            ),
            // More details button.
            IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.orange),
              onPressed: () => _showPaymentDetailsModal(item),
            ),
          ],
        ),
      ),
    );
  }

  // Dialog for adjusting the split amount with a dynamic fraction input.
  Future<double?> _showSplitDialog(double currentValue, double maxValue) async {
    // Main amount controller for direct input.
    TextEditingController amountController =
        TextEditingController(text: currentValue.toString());
    // Controllers for numerator and denominator.
    TextEditingController numeratorController = TextEditingController();
    TextEditingController denominatorController = TextEditingController();
    return showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Split Payment"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Direct input field.
              TextField(
                controller: amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: "Enter amount (max ${maxValue.toStringAsFixed(2)})",
                ),
              ),
              const SizedBox(height: 8),
              const Text("Or enter a fraction:"),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: numeratorController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Numerator",
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text("/"),
                  ),
                  Expanded(
                    child: TextField(
                      controller: denominatorController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Denom.",
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                onPressed: () {
                  double? numerator = double.tryParse(numeratorController.text);
                  double? denominator =
                      double.tryParse(denominatorController.text);
                  if (numerator != null &&
                      denominator != null &&
                      denominator != 0) {
                    double computedValue = (numerator / denominator) * maxValue;
                    if (computedValue > maxValue) computedValue = maxValue;
                    amountController.text = computedValue.toStringAsFixed(2);
                  }
                },
                child: const Text("Apply Fraction"),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                double? entered = double.tryParse(amountController.text);
                if (entered != null && entered <= maxValue && entered > 0) {
                  Navigator.of(context).pop(entered);
                } else {
                  // Optionally handle invalid input.
                }
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildParentHistoryTab() {
    final filtered = _parentHistory.where((item) {
      final dateStr = (item['date'] ?? "2025-01-15").toString();
      final timeStr = (item['time'] ?? "09:00").toString();
      final dtParsed = DateTime.tryParse("$dateStr $timeStr") ?? DateTime.now();
      final dtFormatted =
          DateFormat("d MMM yyyy 'at' HH:mm").format(dtParsed).toLowerCase();
      final school = (item['school'] ?? "").toString().toLowerCase();
      final amountStr = (double.tryParse(item['amount']?.toString() ?? "0")
                  ?.toStringAsFixed(2) ??
              "0.00")
          .toLowerCase();
      final query = _historySearchQuery.toLowerCase();
      return query.isEmpty ||
          dtFormatted.contains(query) ||
          school.contains(query) ||
          amountStr.contains(query);
    }).toList();

    return RefreshIndicator(
      onRefresh: _fetchData,
      color: Colors.orange,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: "Search by date, school, or amount...",
                  prefixIcon: const Icon(Icons.search, color: Colors.orange),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(32),
                    borderSide: const BorderSide(color: Colors.orange),
                  ),
                ),
                onChanged: (val) {
                  setState(() {
                    _historySearchQuery = val;
                  });
                },
              ),
            ),
            if (filtered.isEmpty)
              Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                color: Colors.grey[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('No payment history',
                      style: GoogleFonts.lato(color: Colors.black54)),
                ),
              )
            else
              Column(
                children: filtered.map((item) => _buildCard(item)).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> item) {
    final dateStr = item['date'] ?? "2025-01-15";
    final timeStr = item['time'] ?? "09:00";
    final dateTimeStr = "$dateStr $timeStr";
    final parsedDate = DateTime.tryParse(dateTimeStr) ?? DateTime.now();
    final formattedDate =
        DateFormat("d MMM yyyy 'at' HH:mm").format(parsedDate);
    final amount = double.tryParse(item['amount']?.toString() ?? "0")
            ?.toStringAsFixed(2) ??
        "0.00";

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.grey[50],
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                formattedDate,
                style: GoogleFonts.lato(fontSize: 14, color: Colors.black87),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 1,
              child: Center(
                child: Text(
                  "$amount€",
                  style: GoogleFonts.lato(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.orange),
              onPressed: () => _showPaymentDetailsModal(item),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Instructor Tabs ----------------
  Widget _buildInstructorOverviewTab() {
    return RefreshIndicator(
      onRefresh: _fetchData,
      color: Colors.orange,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    color: Colors.grey[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Your Balance",
                              style: GoogleFonts.lato(
                                  fontSize: 16, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text("${_balance.toStringAsFixed(2)}€",
                              style: GoogleFonts.lato(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    color: Colors.grey[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Next Payout",
                              style: GoogleFonts.lato(
                                  fontSize: 16, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text(_nextPayoutDate,
                              style: GoogleFonts.lato(
                                  fontSize: 20, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              color: Colors.grey[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Statistics",
                        style:
                            GoogleFonts.lato(fontSize: 16, color: Colors.grey)),
                    const SizedBox(height: 8),
                    _buildBarChartPlaceholder(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructorHistoryTab() {
    return _buildParentHistoryTab();
  }

  Widget _buildBarChartPlaceholder() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _statsData.map((value) {
          return Container(
            width: 10,
            height: value * 5.0,
            color: Colors.orange,
          );
        }).toList(),
      ),
    );
  }

  // ---------------- Admin Tabs ----------------
  Widget _buildAdminDebtTab() {
    return _loading
        ? const Center(child: CircularProgressIndicator(color: Colors.orange))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _userDebt.isEmpty
                ? Text("No unpaid items",
                    style: GoogleFonts.lato(color: Colors.black54))
                : Column(
                    children:
                        _userDebt.map((item) => _buildCard(item)).toList(),
                  ),
          );
  }

  // For Admin, the "Balance" tab (formerly Payouts) now shows a custom modal.
  Widget _buildAdminPayoutsTab() {
    return _loading
        ? const Center(child: CircularProgressIndicator(color: Colors.orange))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _upcomingPayouts.isEmpty
                ? Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    color: Colors.grey[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('No upcoming payouts',
                          style: GoogleFonts.lato(color: Colors.black54)),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _upcomingPayouts.map((item) {
                      final name = item['name'] ?? "";
                      final balance = double.tryParse(
                                  item['current_balance']?.toString() ?? "0")
                              ?.toStringAsFixed(2) ??
                          "0.00";
                      return Card(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        color: Colors.grey[50],
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Icon(Icons.person, color: Colors.grey),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Text(name, style: GoogleFonts.lato())),
                              Text("$balance€",
                                  style: GoogleFonts.lato(
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(width: 12),
                              IconButton(
                                icon: const Icon(Icons.more_vert,
                                    color: Colors.orange),
                                onPressed: () => _showAdminBalanceModal(item),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          );
  }

  Widget _buildAdminHistoryTab() {
    return _loading
        ? const Center(child: CircularProgressIndicator(color: Colors.orange))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _adminHistory.isEmpty
                ? Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    color: Colors.grey[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('No payment history',
                          style: GoogleFonts.lato(color: Colors.black54)),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children:
                        _adminHistory.map((item) => _buildCard(item)).toList(),
                  ),
          );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text("Payments")),
        body: const Center(
            child: CircularProgressIndicator(color: Colors.orange)),
      );
    }
    if (_currentRole == "Admin") {
      return DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: const Text("Payments"),
            bottom: const TabBar(
              indicatorColor: Colors.orange,
              tabs: [
                Tab(text: 'Debt'),
                Tab(text: 'Balance'),
                Tab(text: 'History'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _buildAdminDebtTab(),
              _buildAdminPayoutsTab(),
              _buildAdminHistoryTab(),
            ],
          ),
        ),
      );
    }
    if (_currentRole == "Instructor") {
      return DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text("Payments"),
            bottom: const TabBar(
              indicatorColor: Colors.orange,
              tabs: [
                Tab(text: "Overview"),
                Tab(text: "History"),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _buildInstructorOverviewTab(),
              _buildInstructorHistoryTab(),
            ],
          ),
        ),
      );
    }
    // Parent Role
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Payments"),
          bottom: const TabBar(
            indicatorColor: Colors.orange,
            tabs: [
              Tab(text: "Debt"),
              Tab(text: "History"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildParentUnpaidTab(),
            _buildParentHistoryTab(),
          ],
        ),
      ),
    );
  }
}
