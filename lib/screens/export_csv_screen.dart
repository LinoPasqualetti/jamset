import 'package:flutter/material.dart';

class ExportCsvScreen extends StatelessWidget {
  const ExportCsvScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Export CSV'),
        backgroundColor: Colors.teal[800],
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text('Export CSV - In sviluppo'),
      ),
    );
  }
}
