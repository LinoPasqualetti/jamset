
import 'package:flutter/material.dart';
import 'package:jamset/screens/GestisciElencoCataloghi.dart';
import 'package:jamset/screens/variazione_dati_generali_screen.dart';

class GestioneDatiGlobaliScreen extends StatelessWidget {
  const GestioneDatiGlobaliScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestione Dati Globali'),
        backgroundColor: Colors.indigo,
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
