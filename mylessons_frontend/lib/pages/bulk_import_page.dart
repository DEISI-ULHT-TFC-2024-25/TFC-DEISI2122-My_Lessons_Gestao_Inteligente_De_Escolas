import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

import '../services/api_service.dart'; // defines baseUrl and getAuthHeaders()

class BulkImportPage extends StatefulWidget {
  @override
  _BulkImportPageState createState() => _BulkImportPageState();
}

class _BulkImportPageState extends State<BulkImportPage> {
  String? _selectedTarget;
  PlatformFile? _pickedFile;
  final List<String> _targets = ['Student', 'Pack', 'Lesson', 'Payment'];
  bool _loading = false;
  String? _result;

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    if (result != null) {
      setState(() => _pickedFile = result.files.first);
    }
  }

  Future<void> _downloadTemplate() async {
    if (_selectedTarget == null) return;
    setState(() {
      _loading = true;
      _result = null;
    });

    try {
      final uri = Uri.parse('$baseUrl/api/import-excel/template/');
      final headers = await getAuthHeaders();
      final resp = await http.get(uri, headers: headers);
      if (resp.statusCode != 200) {
        setState(() => _result = 'Error downloading: ${resp.statusCode}');
        return;
      }

      final bytes = resp.bodyBytes;
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/bulk_import_template.xlsx';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      final box = context.findRenderObject() as RenderBox?;
      await Share.shareXFiles(
        [XFile(filePath)],
        text: '${_selectedTarget!} Template',
        sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
      );

      setState(() => _result = 'Template shared successfully');
    } catch (e) {
      setState(() => _result = 'Download failed: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _upload() async {
    if (_pickedFile == null || _selectedTarget == null) return;
    setState(() {
      _loading = true;
      _result = null;
    });

    final uri = Uri.parse('$baseUrl/api/import-excel/');
    final headers = await getAuthHeaders();
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(headers)
      ..fields['target'] = _selectedTarget!.toLowerCase()
      ..files.add(
        await http.MultipartFile.fromPath(
          'file',
          _pickedFile!.path!,
          filename: _pickedFile!.name,
          contentType: MediaType(
            'application',
            'vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          ),
        ),
      );

    try {
      final streamed = await request.send();
      final respStr = await streamed.stream.bytesToString();
      setState(() {
        _result = streamed.statusCode == 200
            ? 'Import Successful: $respStr'
            : 'Error (${streamed.statusCode}): $respStr';
      });
    } catch (e) {
      setState(() => _result = 'Upload failed: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Bulk Excel Import')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              decoration: InputDecoration(labelText: 'Select Type'),
              items: _targets
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedTarget = v),
              value: _selectedTarget,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _selectedTarget == null || _loading ? null : _downloadTemplate,
              child: Text('Download ${_selectedTarget ?? ''} Template'),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loading ? null : _pickFile,
              child: Text(_pickedFile == null ? 'Choose Excel File' : _pickedFile!.name),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loading ? null : _upload,
              child: Text(_loading ? 'Processing...' : 'Upload & Import'),
            ),
            if (_result != null) ...[
              SizedBox(height: 24),
              Text(_result!),
            ],
          ],
        ),
      ),
    );
  }
}
