// lib/widgets/connect_calendar_button.dart

import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mylessons_frontend/services/api_service.dart';
import 'package:http/http.dart' as http;
import 'package:mylessons_frontend/services/google_calendar_service.dart';

class ConnectCalendarButton extends StatefulWidget {
  const ConnectCalendarButton({Key? key}) : super(key: key);

  @override
  _ConnectCalendarButtonState createState() => _ConnectCalendarButtonState();
}

class _ConnectCalendarButtonState extends State<ConnectCalendarButton> {
  bool _isConnecting = false;
  final _calendarService = GoogleCalendarService();

  Future<void> _connectCalendar() async {
    setState(() => _isConnecting = true);

    try {
      // 1️⃣ Trigger the sign-in flow and get the one-time code
      final code = await _calendarService.getServerAuthCode();
      if (code == null) {
        // user cancelled or no code
        return;
      }

      // 3️⃣ Exchange the code on your Django backend
      final resp = await http.post(
        Uri.parse('$baseUrl/calendar/oauth2/exchange/'),
        headers: await getAuthHeaders(),
        body: jsonEncode({'code': code}),
      );

      if (resp.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Google Calendar connected!')),
        );
      } else {
        debugPrint('Backend error (${resp.statusCode}): ${resp.body}');
        throw Exception('Failed to connect calendar');
      }
    } catch (e) {
      debugPrint('Error in connect_calendar: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Could not connect Calendar')),
      );
    } finally {
      setState(() => _isConnecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.calendar_today),
      label: _isConnecting
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text('Connect Calendar'),
      onPressed: _isConnecting ? null : _connectCalendar,
    );
  }
}
