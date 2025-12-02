import 'package:flutter/material.dart';
import 'package:jamsetgemini/main.dart';
import 'package:jamsetgemini/screens/GestisciElencoCataloghi.dart';
import 'package:jamsetgemini/screens/variazione_dati_generali_screen.dart';

class GestioneDatiGlobaliScreen extends StatelessWidget {
  const GestioneDatiGlobaliScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        foregroundColor: Colors.white,
        backgroundColor: Colors.grey,
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text('Gestione Dati Globali'),
            SelectableText(
              'Cartella DB: $gDatabasePath',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.settings_applications),
              label: const Text('Variazione Dati Generali'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                textStyle: const TextStyle(fontSize: 16),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const VariazioneDatiGeneraliScreen()),
                );
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.list_alt),
              label: const Text('Variazione Elenco Cataloghi'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                textStyle: const TextStyle(fontSize: 16),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const GestisciElencoCataloghi()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
