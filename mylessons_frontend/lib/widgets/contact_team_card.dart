import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import '../models/team_input.dart';
import '../models/phone_input.dart';

/// Reusable card for one team including emails & phones
class ContactTeamCard extends StatelessWidget {
  final TeamInput team;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  const ContactTeamCard({
    Key? key,
    required this.team,
    required this.onChanged,
    this.onRemove,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Team label
            TextFormField(
              initialValue: team.label,
              decoration: const InputDecoration(labelText: 'Team Label'),
              onChanged: (v) {
                team.label = v;    // ← actually write into your model
                onChanged();
              },
            ),
            const SizedBox(height: 16),
            ...team.emails.asMap().entries.map((e) {
              return Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: e.value,
                      decoration: InputDecoration(labelText: 'Email'),
                      onChanged: (v) => team.emails[e.key] = v,
                    ),
                  ),
                  if (team.emails.length > 1)
                    IconButton(
                      icon: const Icon(Icons.remove_circle, color: Colors.red),
                      onPressed: () {
                        team.emails.removeAt(e.key);
                        onChanged();
                      },
                    ),
                ],
              );
            }).toList(),
            TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add Email'),
              onPressed: () {
                team.emails.add('');
                onChanged();
              },
            ),
            const Divider(),
            const SizedBox(height: 16),
            ...team.phones.asMap().entries.map((p) {
              return Column(
                children: [
                  IntlPhoneField(
                    // Default to Portuguese if no countryCode set
                    initialCountryCode: p.value.countryCode.isNotEmpty
                        ? p.value.countryCode
                        : 'PT',
                    initialValue: p.value.number,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      border: OutlineInputBorder(),
                    ),
                    onCountryChanged: (phoneCountry) {
                      p.value.countryCode = phoneCountry.code;
                      onChanged();
                    },
                    onChanged: (phone) {
                      p.value.number = phone.number;
                      onChanged();
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Checkbox(
                        value: p.value.canCall,
                        onChanged: (v) {
                          p.value.canCall = v!;
                          onChanged();
                        },
                      ),
                      const Text('Call'),
                      const SizedBox(width: 16),
                      Checkbox(
                        value: p.value.canText,
                        onChanged: (v) {
                          p.value.canText = v!;
                          onChanged();
                        },
                      ),
                      const Text('Text'),
                      if (team.phones.length > 1) ...[
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.remove_circle, color: Colors.red),
                          onPressed: () {
                            team.phones.removeAt(p.key);
                            onChanged();
                          },
                        ),
                      ],
                    ],
                  ),
                ],
              );
            }).toList(),
            TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add Phone'),
              onPressed: () {
                team.phones.add(PhoneInput(countryCode: 'PT'));
                onChanged();
              },
            ),

            // Remove team button
            if (onRemove != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onRemove,
                  child: const Text('Remove Team', style: TextStyle(color: Colors.red)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}