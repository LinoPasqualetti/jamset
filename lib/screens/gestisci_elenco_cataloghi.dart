import 'package:flutter/material.dart';

class GestisciElencoCataloghi extends StatelessWidget {
  const GestisciElencoCataloghi({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestisci Cataloghi'),
        backgroundColor: Colors.teal[800],
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text('Gestione cataloghi - In sviluppo'),
      ),
    );
  }
}
