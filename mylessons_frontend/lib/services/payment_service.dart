import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';

Future<Map<String, dynamic>> postPaymentTypeData({
  String? schoolId,
  String? schoolName,
  required String keyPath,
  required dynamic newValue,
  String? userId,
}) async {
  final url = Uri.parse('$baseUrl/api/schools/update_payment_type/');
  final payload = {
    'school_id': schoolId,
    'school_name': schoolName,
    'key_path': keyPath,
    'new_value': newValue,
  };
  if (userId != null) {
    payload["user_id"] = userId;
  }
  final headers = await getAuthHeaders();
  final response =
      await http.post(url, headers: headers, body: jsonEncode(payload));
  if (response.statusCode == 200) return json.decode(utf8.decode(response.bodyBytes));
  throw Exception('Failed to update payment type: ${response.body}');
}

String computeExpirationDate(String? timeLimit) {
  if (timeLimit == null || timeLimit.toLowerCase() == "none") return "";
  DateTime now = DateTime.now();
  if (timeLimit.toLowerCase() == "1 month") {
    return DateTime(now.year, now.month + 1, now.day).toIso8601String();
  }
  if (timeLimit.toLowerCase() == "2 months") {
    return DateTime(now.year, now.month + 2, now.day).toIso8601String();
  }
  if (timeLimit.toLowerCase() == "3 months") {
    return DateTime(now.year, now.month + 3, now.day).toIso8601String();
  }
  if (timeLimit.toLowerCase().contains("days")) {
    int days = int.tryParse(timeLimit.split(" ")[0]) ?? 0;
    return now.add(Duration(days: days)).toIso8601String();
  }
  return "";
}

String formatPricingOption(Map pricingOption) {
  return pricingOption.entries.map((e) => "${e.key}: ${e.value}").join(", ");
}
