import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_markdown/flutter_markdown.dart';

class MarkdownPage extends StatelessWidget {
  final String title;
  final String assetPath;
  const MarkdownPage({ 
    Key? key, 
    required this.title, 
    required this.assetPath 
  }) : super(key: key);

  Future<String> _load() => rootBundle.loadString(assetPath);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: FutureBuilder<String>(
        future: _load(),
        builder: (context, snap) {
          if (!snap.hasData) return Center(child: CircularProgressIndicator());
          return Markdown(data: snap.data!);
        },
      ),
    );
  }
}
