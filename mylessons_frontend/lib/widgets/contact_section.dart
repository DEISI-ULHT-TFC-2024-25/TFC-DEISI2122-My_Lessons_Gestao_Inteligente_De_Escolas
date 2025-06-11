import 'package:flutter/material.dart';

import '../models/team_input.dart';
import 'contact_team_card.dart';

class ContactsSection extends StatefulWidget {
  final List<TeamInput>? initialTeams;
  final ValueChanged<List<TeamInput>> onTeamsChanged;

  const ContactsSection({
    Key? key,
    this.initialTeams,
    required this.onTeamsChanged,
  }) : super(key: key);

  @override
  _ContactsSectionState createState() => _ContactsSectionState();
}

class _ContactsSectionState extends State<ContactsSection> {
  late List<TeamInput> _teams;

  @override
  void initState() {
    super.initState();
    _teams = widget.initialTeams ?? [TeamInput()];
  }

  void _notifyChange() {
    widget.onTeamsChanged(_teams);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ..._teams.asMap().entries.map((entry) {
          final index = entry.key;
          final team = entry.value;
          return ContactTeamCard(
            team: team,
            onChanged: () {
              setState(_notifyChange);
            },
            onRemove: _teams.length > 1
                ? () {
              setState(() {
                _teams.removeAt(index);
                _notifyChange();
              });
            }
                : null,
          );
        }),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Add Team'),
          onPressed: () {
            setState(() {
              _teams.add(TeamInput());
              _notifyChange();
            });
          },
        ),
      ],
    );
  }
}
