import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../services/api_service.dart'; // contains baseUrl & getAuthHeaders
import '../providers/school_data_provider.dart';
import 'camp_modal.dart'; // for ActivityItem

/// Call this from any page or modal to open the Add/Edit Activity sheet:
Future<T?> showActivityModal<T>(BuildContext context, { ActivityItem? activity }) {
  return showModalBottomSheet<T>(
    useRootNavigator: true,
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (_) => ActivityModal(activity: activity),
  );
}

class ActivityTemplate {
  final int id;
  final String name;
  final String description;
  ActivityTemplate({
    required this.id,
    required this.name,
    required this.description,
  });
  factory ActivityTemplate.fromJson(Map<String, dynamic> json) {
    return ActivityTemplate(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
    );
  }
}

class ActivityModal extends StatefulWidget {
  final ActivityItem? activity;
  const ActivityModal({ Key? key, this.activity }) : super(key: key);

  @override
  _ActivityModalState createState() => _ActivityModalState();
}

class _ActivityModalState extends State<ActivityModal> {
  List<ActivityTemplate> _templates = [];
  ActivityTemplate? _selectedTemplate;
  bool _isNewTemplate = false;

  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  int? _locationId;

  List<DateEntry> _dateEntries = [];

  @override
  void initState() {
    super.initState();
    _fetchTemplates();

    if (widget.activity != null) {
      final act = widget.activity!;
      _nameController.text = act.name;
      final date = DateTime.parse(act.date);
      final startParts = act.startTime.split(':').map(int.parse).toList();
      final endParts = act.endTime.split(':').map(int.parse).toList();
      final entry = DateEntry(date: date);
      entry.intervals.add(TimeInterval(
        TimeOfDay(hour: startParts[0], minute: startParts[1]),
        TimeOfDay(hour: endParts[0], minute: endParts[1]),
      ));
      _dateEntries = [entry];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _fetchTemplates() async {
    final headers = await getAuthHeaders();
    final resp = await http.get(
      Uri.parse('$baseUrl/api/events/activity-models/'),
      headers: headers,
    );
    if (resp.statusCode == 200) {
      final List data = jsonDecode(resp.body);
      setState(() {
        _templates = data.map((j) => ActivityTemplate.fromJson(j)).toList();
        if (_templates.isNotEmpty && widget.activity == null) {
          _selectedTemplate = _templates.first;
          _loadTemplate(_selectedTemplate!);
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load templates: ${resp.statusCode}')),
      );
    }
  }

  void _loadTemplate(ActivityTemplate tmpl) {
    _nameController.text = tmpl.name;
    _descController.text = tmpl.description;
  }

  Future<void> _saveTemplate() async {
    final headers = await getAuthHeaders();
    final provider = context.read<SchoolDataProvider>();
    final schoolId = provider.schoolDetails!['school_id'] as int;
    final body = {
      'name': _nameController.text.trim(),
      'description': _descController.text.trim(),
      if (_locationId != null) 'location': _locationId,
      'school': schoolId,
    };
    final resp = await http.post(
      Uri.parse('$baseUrl/api/events/activity-models/'),
      headers: {
        'Content-Type': 'application/json',
        ...headers,
      },
      body: jsonEncode(body),
    );
    if (resp.statusCode == 201) {
      final data = jsonDecode(resp.body);
      final tmpl = ActivityTemplate.fromJson(data);
      setState(() {
        _templates.add(tmpl);
        _selectedTemplate = tmpl;
        _isNewTemplate = false;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save template: ${resp.statusCode}')),
      );
    }
  }

  Future<void> _saveActivity() async {
    final headers = await getAuthHeaders();
    final provider = context.read<SchoolDataProvider>();
    final schoolId = provider.schoolDetails!['school_id'] as int;

    // EDIT mode
    if (widget.activity != null) {
      if (_dateEntries.isEmpty || _dateEntries.first.intervals.isEmpty) return;
      final entry = _dateEntries.first;
      final interval = entry.intervals.first;
      final duration = (interval.end.hour*60 + interval.end.minute)
                     - (interval.start.hour*60 + interval.start.minute);

      final body = {
        'name': _nameController.text.trim(),
        'description': _descController.text.trim(),
        'date': entry.date.toIso8601String().split('T').first,
        'start_time': interval.start.format(context),
        'end_time': interval.end.format(context),
        'duration_in_minutes': duration,
        if (_locationId != null) 'location': _locationId,
      };

      final resp = await http.put(
        Uri.parse('$baseUrl/api/events/activities/${widget.activity!.id}/'),
        headers: {
          'Content-Type': 'application/json',
          ...headers,
        },
        body: jsonEncode(body),
      );
      if (resp.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Activity updated!')),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: ${resp.statusCode}')),
        );
      }
      return;
    }

    // ADD mode
    for (var entry in _dateEntries) {
      if (!entry.selected) continue;
      for (var interval in entry.intervals) {
        final duration = (interval.end.hour*60 + interval.end.minute)
                       - (interval.start.hour*60 + interval.start.minute);
        final body = {
          'name': _nameController.text.trim(),
          'description': _descController.text.trim(),
          'date': entry.date.toIso8601String().split('T').first,
          'start_time': interval.start.format(context),
          'end_time': interval.end.format(context),
          'duration_in_minutes': duration,
          if (_locationId != null) 'location': _locationId,
          if (_selectedTemplate != null && !_isNewTemplate)
            'activity_model': _selectedTemplate!.id,
          'school': schoolId,
        };
        await http.post(
          Uri.parse('$baseUrl/api/events/activities/'),
          headers: {
            'Content-Type': 'application/json',
            ...headers,
          },
          body: jsonEncode(body),
        );
      }
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.activity != null;
    return FractionallySizedBox(
      heightFactor: 0.9,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).canvasColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 16, right: 16, top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text(
                    isEdit ? 'Edit Activity' : 'Add Activity',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: 24),

                if (!isEdit && !_isNewTemplate) ...[
                  DropdownButtonFormField<ActivityTemplate>(
                    value: _selectedTemplate,
                    decoration: const InputDecoration(
                        labelText: 'Template', isDense: true),
                    items: _templates.map((t) =>
                      DropdownMenuItem(value: t, child: Text(t.name))
                    ).toList(),
                    onChanged: (tmpl) {
                      if (tmpl == null) return;
                      setState(() {
                        _isNewTemplate = false;
                        _selectedTemplate = tmpl;
                        _loadTemplate(tmpl);
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _isNewTemplate = true;
                      _nameController.clear();
                      _descController.clear();
                    }),
                    icon: const Icon(Icons.edit),
                    label: const Text('New Template'),
                  ),
                  const SizedBox(height: 16),
                ],

                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Location ID'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => _locationId = int.tryParse(v),
                ),

                if (_isNewTemplate && !isEdit) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => setState(() {
                          _isNewTemplate = false;
                          if (_selectedTemplate != null) {
                            _loadTemplate(_selectedTemplate!);
                          }
                        }),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _saveTemplate,
                        child: const Text('Save Template'),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 24),
                Text(
                  'When is this taking place?',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _addDate,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Date'),
                ),
                const SizedBox(height: 8),

                for (var entry in _dateEntries) ...[
                  Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Checkbox(
                                value: entry.selected,
                                onChanged: (v) =>
                                  setState(() => entry.selected = v!),
                              ),
                              Text(
                                '${entry.date.month.toString().padLeft(2,'0')}-'
                                '${entry.date.day.toString().padLeft(2,'0')}',
                                style: const TextStyle(fontSize: 16),
                              ),
                              IconButton(
                                icon: const Icon(Icons.calendar_today),
                                tooltip: 'Edit date',
                                onPressed: () => _editDate(entry),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: () => _removeDate(entry),
                                child: const Text('Remove Date'),
                              ),
                            ],
                          ),

                          if (entry.selected) ...[
                            for (var interval in entry.intervals)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '• ${interval.start.format(context)} – '
                                        '${interval.end.format(context)}',
                                        style:
                                            const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      tooltip: 'Edit interval',
                                      onPressed: () =>
                                          _editInterval(entry, interval),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete),
                                      tooltip: 'Delete interval',
                                      onPressed: () =>
                                          _deleteInterval(entry, interval),
                                    ),
                                  ],
                                ),
                              ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () => _addInterval(entry),
                                icon: const Icon(Icons.add),
                                label: const Text('Add Time Interval'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: _saveActivity,
                      child: Text(isEdit ? 'Update Activity' : 'Save Activity'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _addDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _dateEntries.add(DateEntry(date: picked)));
    }
  }

  Future<void> _editDate(DateEntry entry) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: entry.date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => entry.date = picked);
    }
  }

  Future<void> _addInterval(DateEntry entry) async {
    final picked = await _pickInterval();
    if (picked != null) setState(() => entry.intervals.add(picked));
  }

  Future<void> _editInterval(DateEntry entry, TimeInterval interval) async {
    final newInterval = await _pickInterval(
      initialStart: interval.start,
      initialEnd: interval.end,
    );
    if (newInterval != null) {
      setState(() {
        final idx = entry.intervals.indexOf(interval);
        entry.intervals[idx] = newInterval;
      });
    }
  }

  void _deleteInterval(DateEntry entry, TimeInterval interval) {
    setState(() => entry.intervals.remove(interval));
  }

  Future<TimeInterval?> _pickInterval({
    TimeOfDay? initialStart,
    TimeOfDay? initialEnd,
  }) {
    return showModalBottomSheet<TimeInterval>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        TimeOfDay start = initialStart ?? TimeOfDay.now();
        TimeOfDay end = initialEnd ?? TimeOfDay.now();
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SizedBox(
            height: 350,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Start Time',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    use24hFormat: true,
                    initialDateTime: DateTime(
                      0, 0, 0, start.hour, start.minute),
                    onDateTimeChanged: (dt) {
                      start = TimeOfDay(hour: dt.hour, minute: dt.minute);
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Text('End Time',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    use24hFormat: true,
                    initialDateTime: DateTime(
                      0, 0, 0, end.hour, end.minute),
                    onDateTimeChanged: (dt) {
                      end = TimeOfDay(hour: dt.hour, minute: dt.minute);
                    },
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                    onPressed: () =>
                        Navigator.of(context).pop(TimeInterval(start, end)),
                    child: const Text('Done')),
              ],
            ),
          ),
        );
      },
    );
  }

  void _removeDate(DateEntry entry) =>
      setState(() => _dateEntries.remove(entry));
}

class DateEntry {
  DateTime date;
  bool selected;
  List<TimeInterval> intervals;
  DateEntry({ required this.date })
      : selected = true,
        intervals = [];
}

class TimeInterval {
  final TimeOfDay start;
  final TimeOfDay end;
  TimeInterval(this.start, this.end);
}
