import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> showMapOptionsBottomModal(BuildContext context, String address) async {
  // Encode the address so it can be safely used in a URL.
  final encodedAddress = Uri.encodeComponent(address);

  // Build a list of map options based on the platform.
  List<Map<String, String>> options = [];

  if (Platform.isIOS) {
    options.add({
      'name': 'Apple Maps',
      'url': 'http://maps.apple.com/?daddr=$encodedAddress',
    });
    options.add({
      'name': 'Google Maps',
      'url': 'comgooglemaps://?daddr=$encodedAddress',
    });
    options.add({
      'name': 'Waze',
      'url': 'waze://?q=$encodedAddress',
    });
  } else {
    // For Android: Apple Maps is not available.
    options.add({
      'name': 'Google Maps',
      'url': 'google.navigation:q=$encodedAddress',
    });
    options.add({
      'name': 'Waze',
      'url': 'waze://?q=$encodedAddress',
    });
  }

  // Show a bottom modal allowing the user to choose.
  await showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return ListView.separated(
        shrinkWrap: true,
        itemCount: options.length,
        separatorBuilder: (context, index) => const Divider(),
        itemBuilder: (context, index) {
          final option = options[index];
          return ListTile(
            title: Text(option['name']!),
            onTap: () async {
              // Dismiss the modal.
              Navigator.pop(context);
              final url = option['url']!;
              final Uri mapUri = Uri.parse(url);
              if (await canLaunchUrl(mapUri)) {
                await launchUrl(mapUri, mode: LaunchMode.externalApplication);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('Could not launch ${option['name']}')),
                );
              }
            },
          );
        },
      );
    },
  );
}