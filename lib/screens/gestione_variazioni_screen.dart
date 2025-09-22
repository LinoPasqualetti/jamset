// lib/screens/gestione_variazioni_screen.dart
import 'package:flutter/material.dart';
import 'variabili_ambiente_screen.dart'; // <--- IMPORTA LA NUOVA SCHERMATA

class GestioneVariazioniScreen extends StatelessWidget {
  const GestioneVariazioniScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestione Variazioni e Dati'),
        backgroundColor: Colors.teal[700],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: <Widget>[
          // ... (le altre _buildFeatureButton come prima) ...
          _buildFeatureButton(
            context,
            icon: Icons.upload_file_outlined,
            title: 'a) Caricamento nuovi PDF',
            subtitle: 'Aggiungi nuovi spartiti alla libreria',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Funzione "Caricamento PDF" non ancora implementata.')),
              );
            },
          ),
          _buildFeatureButton(
            context,
            icon: Icons.rule_folder_outlined,
            title: 'b) Variazione Indici',
            subtitle: 'Modifica metadati e collegamenti dei brani',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Funzione "Variazione Indici" non ancora implementata.')),
              );
            },
          ),
          _buildFeatureButton(
            context,
            icon: Icons.backup_outlined,
            title: 'c) Funzioni di Backup e Authority File',
            subtitle: 'Gestisci backup, import/export e authority file',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Funzione "Backup/Authority" non ancora implementata.')),
              );
            },
          ),
          _buildFeatureButton(
            context,
            icon: Icons.settings_applications_outlined,
            title: 'd) Impostazioni Percorso', // Titolo aggiornato
            subtitle: 'Configura il percorso base per i file', // Sottotitolo aggiornato
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const VariabiliAmbienteScreen()), // <--- NAVIGA QUI
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureButton(BuildContext context, {required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: ListTile(
        leading: Icon(icon, size: 40, color: Theme.of(context).primaryColorDark),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        onTap: onTap,
        contentPadding: const EdgeInsets.all(15.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      ),
    );
  }
}
