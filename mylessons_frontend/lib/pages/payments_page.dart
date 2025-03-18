import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';

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
      final debtRes = await http.get(Uri.parse('$baseUrl/api/payments/debt/'), headers: headers);
      final unpaidRes = await http.get(Uri.parse('$baseUrl/api/payments/unpaid_items/'), headers: headers);
      final historyRes = await http.get(Uri.parse('$baseUrl/api/payments/history/'), headers: headers);

      if (debtRes.statusCode == 200) {
        final decoded = json.decode(debtRes.body);
        _debt = double.tryParse(decoded['current_debt'].toString()) ?? 0;
      }
      if (unpaidRes.statusCode == 200) {
        _unpaid = List<Map<String, dynamic>>.from(json.decode(unpaidRes.body));
      }
      if (historyRes.statusCode == 200) {
        _parentHistory = List<Map<String, dynamic>>.from(json.decode(historyRes.body));
      }
    } catch (e) {
      debugPrint("Error fetching Parent data: $e");
    }
  }

  // ------------------- Instructor Data -------------------
  Future<void> _fetchInstructorData() async {
    final headers = await getAuthHeaders();
    try {
      final historyRes = await http.get(Uri.parse('$baseUrl/api/payments/instructor_payment_history/'), headers: headers);
      if (historyRes.statusCode == 200) {
        _instructorHistory = List<Map<String, dynamic>>.from(json.decode(historyRes.body));
      }
      final balanceResponse = await http.get(Uri.parse('$baseUrl/api/users/current_balance/'), headers: headers);
      if (balanceResponse.statusCode == 200) {
        final b = json.decode(balanceResponse.body)['current_balance'];
        _balance = double.tryParse(b.toString()) ?? 0.0;
      }
      _nextPayoutDate = "31 January";
      _statsData = [12, 8, 14, 5, 19, 22, 7, 10, 13, 8, 12, 15];
    } catch (e) {
      debugPrint("Error fetching Instructor data: $e");
    }
  }

  // ------------------- Admin Data -------------------
  Future<void> _fetchAdminData() async {
    final headers = await getAuthHeaders();
    try {
      final debtRes = await http.get(Uri.parse('$baseUrl/api/payments/unpaid_items/'), headers: headers);
      final upcomingRes = await http.get(Uri.parse('$baseUrl/api/admin/payments/upcoming_payouts/'), headers: headers);
      final historyRes = await http.get(Uri.parse('$baseUrl/api/admin/payments/school_payment_history/'), headers: headers);

      // Check for iterable type or a dictionary wrapping the list.
      final decodedDebt = json.decode(debtRes.body);
      if (decodedDebt is List) {
        _userDebt = List<Map<String, dynamic>>.from(decodedDebt);
      } else if (decodedDebt is Map && decodedDebt.containsKey("data")) {
        _userDebt = List<Map<String, dynamic>>.from(decodedDebt["data"]);
      } else {
        _userDebt = [];
      }

      final decodedUpcoming = json.decode(upcomingRes.body);
      if (decodedUpcoming is List) {
        _upcomingPayouts = List<Map<String, dynamic>>.from(decodedUpcoming);
      } else if (decodedUpcoming is Map && decodedUpcoming.containsKey("data")) {
        _upcomingPayouts = List<Map<String, dynamic>>.from(decodedUpcoming["data"]);
      } else {
        _upcomingPayouts = [];
      }

      final decodedHistory = json.decode(historyRes.body);
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
      final response = await http.post(Uri.parse('$baseUrl/api/payments/redulate_debt/'), headers: headers);
      if (response.statusCode == 200) {
        await _fetchData();
      } else {
        debugPrint("Failed to redulate debt. Status: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error redulating debt: $e");
    }
  }

  // ============ Shared: Payment Details Modal ============
  Future<void> _showPaymentDetailsModal(Map<String, dynamic> item) async {
    final dateStr = item['date'] ?? "2025-01-15";
    final timeStr = item['time'] ?? "09:00";
    final dateTimeStr = "$dateStr $timeStr";
    final parsedDate = DateTime.tryParse(dateTimeStr) ?? DateTime.now();
    final formattedDate = DateFormat("d MMM yyyy").format(parsedDate);
    final formattedTime = DateFormat("HH:mm").format(parsedDate);
    final school = (item['school'] ?? "").toString();
    final amount = double.tryParse(item['amount']?.toString() ?? "0")?.toStringAsFixed(2) ?? "0.00";
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
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
        Text("Payment Details", style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildInfoCard(Icons.calendar_today, "DATE", formattedDate)),
            const SizedBox(width: 8),
            Expanded(child: _buildInfoCard(Icons.access_time, "TIME", formattedTime)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildInfoCard(Icons.school, "SCHOOL", school)),
            const SizedBox(width: 8),
            Expanded(child: _buildInfoCard(Icons.attach_money, "AMOUNT", "$amount€")),
          ],
        ),
        const SizedBox(height: 8),
        _buildFullWidthCard(Icons.description, "DETAILS", details),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
          ),
          child: const Text("Close", style: TextStyle(color: Colors.white)),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // _buildInfoCard used in the Parent/Instructor details modal.
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
                  Text(label, style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(value, style: GoogleFonts.lato(fontSize: 12), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // _buildFullWidthCard used in the details modal.
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
                  Text(label, style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.bold)),
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
    return RefreshIndicator(
      onRefresh: _fetchData,
      color: Colors.orange,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    "${_debt.toStringAsFixed(2)}€",
                    style: GoogleFonts.lato(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    // Implement payment flow.
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                  ),
                  child: const Text("Pay Debt", style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
            const Divider(height: 32),
            _unpaid.isEmpty
                ? Text("No unpaid items", style: GoogleFonts.lato(color: Colors.black54))
                : Column(
                    children: _unpaid.map((item) => _buildHistoryRow(item)).toList(),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildParentHistoryTab() {
    final filtered = _parentHistory.where((item) {
      final dateStr = (item['date'] ?? "2025-01-15").toString();
      final timeStr = (item['time'] ?? "09:00").toString();
      final dtParsed = DateTime.tryParse("$dateStr $timeStr") ?? DateTime.now();
      final dtFormatted = DateFormat("d MMM yyyy 'at' HH:mm").format(dtParsed).toLowerCase();
      final school = (item['school'] ?? "").toString().toLowerCase();
      final amountStr = (double.tryParse(item['amount']?.toString() ?? "0")?.toStringAsFixed(2) ?? "0.00").toLowerCase();
      final query = _historySearchQuery.toLowerCase();
      return query.isEmpty || dtFormatted.contains(query) || school.contains(query) || amountStr.contains(query);
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                color: Colors.grey[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('No payment history', style: GoogleFonts.lato(color: Colors.black54)),
                ),
              )
            else
              Column(
                children: filtered.map((item) => _buildHistoryRow(item)).toList(),
              ),
          ],
        ),
      ),
    );
  }

  // Shared history row for Parent/Instructor.
  Widget _buildHistoryRow(Map<String, dynamic> item) {
    final dateStr = item['date'] ?? "2025-01-15";
    final timeStr = item['time'] ?? "09:00";
    final dateTimeStr = "$dateStr $timeStr";
    final parsedDate = DateTime.tryParse(dateTimeStr) ?? DateTime.now();
    final formattedDate = DateFormat("d MMM yyyy 'at' HH:mm").format(parsedDate);
    final amount = double.tryParse(item['amount']?.toString() ?? "0")?.toStringAsFixed(2) ?? "0.00";

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
                  style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    color: Colors.grey[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Your Balance", style: GoogleFonts.lato(fontSize: 16, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text("${_balance.toStringAsFixed(2)}€", style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    color: Colors.grey[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Next Payout", style: GoogleFonts.lato(fontSize: 16, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text(_nextPayoutDate, style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              color: Colors.grey[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Statistics", style: GoogleFonts.lato(fontSize: 16, color: Colors.grey)),
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
                ? Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    color: Colors.grey[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('No unpaid items', style: GoogleFonts.lato(color: Colors.black54)),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _userDebt.map((item) {
                      final studentsName = item['students_name'] ?? "";
                      final packDate = item['date'] ?? "";
                      return Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        color: Colors.grey[50],
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.grey),
                              const SizedBox(width: 12),
                              Expanded(child: Text(studentsName, style: GoogleFonts.lato())),
                              Text(packDate, style: GoogleFonts.lato(color: Colors.black54)),
                              const SizedBox(width: 12),
                              IconButton(
                                icon: const Icon(Icons.more_vert, color: Colors.orange),
                                onPressed: () => _showPaymentDetailsModal(item),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          );
  }

  Widget _buildAdminPayoutsTab() {
    return _loading
        ? const Center(child: CircularProgressIndicator(color: Colors.orange))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _upcomingPayouts.isEmpty
                ? Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    color: Colors.grey[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('No upcoming payouts', style: GoogleFonts.lato(color: Colors.black54)),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _upcomingPayouts.map((item) {
                      final name = item['name'] ?? "";
                      final balance = double.tryParse(item['current_balance']?.toString() ?? "0")?.toStringAsFixed(2) ?? "0.00";
                      return Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        color: Colors.grey[50],
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Icon(Icons.person, color: Colors.grey),
                              const SizedBox(width: 12),
                              Expanded(child: Text(name, style: GoogleFonts.lato())),
                              Text("$balance€", style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
                              const SizedBox(width: 12),
                              IconButton(
                                icon: const Icon(Icons.more_vert, color: Colors.orange),
                                onPressed: () => _showPaymentDetailsModal(item),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    color: Colors.grey[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('No payment history', style: GoogleFonts.lato(color: Colors.black54)),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _adminHistory.map((item) => _buildAdminHistoryRow(item)).toList(),
                  ),
          );
  }

  Widget _buildAdminHistoryRow(Map<String, dynamic> item) {
    final dateStr = item['date'] ?? "2025-01-15";
    final parsed = DateTime.tryParse(dateStr) ?? DateTime.now();
    final formatted = DateFormat("d MMM yyyy").format(parsed);
    final amount = double.tryParse(item['amount']?.toString() ?? "0")?.toStringAsFixed(2) ?? "0.00";
    final user = item['user_name'] ?? "";
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.grey[50],
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.person, color: Colors.grey),
            const SizedBox(width: 12),
            Expanded(child: Text(user, style: GoogleFonts.lato())),
            Text("$amount€", style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
            const SizedBox(width: 12),
            Text(formatted, style: GoogleFonts.lato(color: Colors.black54)),
            const SizedBox(width: 12),
            IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.orange),
              onPressed: () => _showAdminDetailsModal(item),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAdminDetailsModal(Map<String, dynamic> item) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) {
        final dateStr = item['date'] ?? "2025-01-15";
        final parsed = DateTime.tryParse(dateStr) ?? DateTime.now();
        final formatted = DateFormat("d MMM yyyy 'at' HH:mm").format(parsed);
        final user = item['user_name'] ?? "Unknown User";
        final amt = double.tryParse(item['amount']?.toString() ?? "0")?.toStringAsFixed(2) ?? "0.00";
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text("Details", style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _infoCard("User", user),
                _infoCard("Amount", "$amt€"),
                _infoCard("Date", formatted),
                _infoCard("School", item['school_name'] ?? ""),
                _buildFullWidthCard(Icons.description, "Notes", item['notes'] ?? ""),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32))),
                  child: const Text("Close", style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // This helper method is used in the Admin details modal.
  Widget _infoCard(String label, String value) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.grey),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(value, style: GoogleFonts.lato(fontSize: 14)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text("Payments")),
        body: const Center(child: CircularProgressIndicator(color: Colors.orange)),
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
                Tab(text: 'Payouts'),
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
    // Parent
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Payments"),
          bottom: const TabBar(
            indicatorColor: Colors.orange,
            tabs: [
              Tab(text: "Unpaid Items"),
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
