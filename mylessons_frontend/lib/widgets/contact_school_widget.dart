import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl_phone_field/countries.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactSchoolWidget extends StatelessWidget {
  final Map<String, dynamic> school;
  
  const ContactSchoolWidget({
    Key? key,
    required this.school,
  }) : super(key: key);

  // Helper method to launch URLs (email, call, text)
  Future<void> _launchURL(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch $url', style: GoogleFonts.lato())),
      );
    }
  }

  // Helper method to get a formatted country code.
  String getFormattedCountryCode(String isoCode) {
    try {
      final matchingCountry = countries.firstWhere(
        (country) => country.code.toUpperCase() == isoCode.toUpperCase(),
      );
      return matchingCountry.dialCode;
    } catch (e) {
      return isoCode;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Extract contacts data from the school object.
    final contactsData = school['contacts'] as Map<String, dynamic>?;

    if (contactsData == null || contactsData.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text('No contacts available.', style: GoogleFonts.lato()),
        ),
      );
    }

    final teams = contactsData['teams'] as List<dynamic>? ?? [];

    if (teams.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text('No contact teams available.', style: GoogleFonts.lato()),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: teams.map<Widget>((team) {
          final label = team['label'] ?? 'Team';
          final emails = team['emails'] as List<dynamic>? ?? [];
          final phones = team['phones'] as List<dynamic>? ?? [];

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Team header.
                  Text(
                    label,
                    style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  // Emails section.
                  if (emails.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    ...emails.map((email) => Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            title: Text(email.toString(), style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
                            trailing: ElevatedButton.icon(
                              onPressed: () => _launchURL(context, "mailto:${email.toString()}"),
                              icon: const Icon(Icons.send, color: Colors.white),
                              label: const SizedBox.shrink(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        )),
                  ],
                  // Phones section.
                  if (phones.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    ...phones.map((phone) {
                      final originalCode = phone['country_code'] ?? "";
                      final countryCode = getFormattedCountryCode(originalCode);
                      final number = phone['number'] ?? "";
                      final fullNumber = "$countryCode$number";
                      final capabilities = phone['capabilities'] as Map<String, dynamic>? ?? {};

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("+$fullNumber",
                                  style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  if (capabilities['call'] == true)
                                    ElevatedButton(
                                      onPressed: () => _launchURL(context, "tel:$fullNumber"),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        padding: const EdgeInsets.all(12),
                                      ),
                                      child: const Icon(Icons.call, color: Colors.white),
                                    ),
                                  if (capabilities['call'] == true && capabilities['text'] == true)
                                    const SizedBox(width: 12),
                                  if (capabilities['text'] == true)
                                    ElevatedButton(
                                      onPressed: () => _launchURL(context, "sms:$fullNumber"),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        padding: const EdgeInsets.all(12),
                                      ),
                                      child: const Icon(Icons.message, color: Colors.white),
                                    ),
                                  const SizedBox(width: 12),
                                  // WhatsApp button.
                                  ElevatedButton(
                                    onPressed: () => _launchURL(context, "https://wa.me/$fullNumber"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      padding: const EdgeInsets.all(12),
                                    ),
                                    child: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.white),
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
