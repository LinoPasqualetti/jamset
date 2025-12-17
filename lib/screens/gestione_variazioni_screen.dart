// lib/screens/gestione_variazioni_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:jamsetgemini/screens/gestione_dati_globali_screen.dart';
import 'package:jamsetgemini/screens/test_apertura_file_screen.dart';
import 'package:jamsetgemini/screens/dichiarazione_file_volume_screen.dart';
import 'package:jamsetgemini/services/database_service.dart';

import '../main.dart'; // Importa databaseService

class GestioneVariazioniScreen extends StatelessWidget {
  const GestioneVariazioniScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestione Variazioni e Dati'),
        backgroundColor: Colors.teal[700],
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(
            'assets/images/FabbricaPerImpostazioni.jpg',
            fit: BoxFit.cover,
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16.0),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Prima riga
                    Row(
                      children: [
                        _buildFeatureButton(
                          context,
                          icon: Icons.upload_file_outlined,
                          title: 'a) Carica PDF',
                          subtitle: 'Aggiungi nuovi spartiti',
                          onTap: () {},
                        ),
                        const SizedBox(width: 8),
                        _buildFeatureButton(
                          context,
                          icon: Icons.storage,
                          title: 'b) Gestione Volumi',
                          subtitle: 'Seleziona database e gestisci cataloghi',
                          onTap: () => _showSimpleDatabaseDialog(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Seconda riga
                    Row(
                      children: [
                        _buildFeatureButton(
                          context,
                          icon: Icons.backup_outlined,
                          title: 'c) Backup',
                          subtitle: 'Gestisci backup e authority',
                          onTap: () {},
                        ),
                        const SizedBox(width: 8),
                        _buildFeatureButton(
                          context,
                          icon: Icons.settings_applications_outlined,
                          title: 'd) Impostazioni',
                          subtitle: 'Gestisci Dati Globali',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const GestioneDatiGlobaliScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Terza riga
                    Row(
                      children: [
                        _buildFeatureButton(
                          context,
                          icon: Icons.find_in_page_outlined,
                          title: 'e) Test Apertura',
                          subtitle: 'Testa l\'apertura di un file a una pagina specifica',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const TestAperturaFileScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildFeatureButton(
                          context,
                          icon: Icons.file_upload,
                          title: 'f) Inserisci da file',
                          subtitle: 'Importa dati da file CSV/Excel',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const DichiarazioneFileVolumeScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Quarta riga
                    Row(
                      children: [
                        _buildFeatureButton(
                          context,
                          icon: Icons.playlist_add_check,
                          title: 'g) Popola Cataloghi',
                          subtitle: 'Trattamento Dati, Archivio PDF e Popolamento',
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Funzione non ancora implementata.')),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Container()),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureButton(BuildContext context,
      {required IconData icon,
        required String title,
        required String subtitle,
        required VoidCallback onTap}) {
    return Expanded(
      child: Tooltip(
        message: subtitle,
        child: Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          color: Colors.white.withOpacity(0.95),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 28, color: Colors.teal[800]),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showSimpleDatabaseDialog(BuildContext context) async {
    try {
      // Ricarica la lista dei volumi per essere sicuro sia aggiornata
      await databaseService.synchronizeCatalogs();
      final List<Map<String, dynamic>> volumes = await databaseService.getAvailableVolumes();
      final Map<String, dynamic> currentVolume = await databaseService.getCurrentVolume();

      showDialog(
        context: context,
        builder: (BuildContext context) {
          final volumeWidgets = volumes.map<Widget>((volume) {
            final bool isActive = volume['id'] == currentVolume['id'];
            return ListTile(
              leading: Icon(isActive ? Icons.folder_open : Icons.folder, color: isActive ? Colors.blue : null),
              title: Text(volume['nome_catalogo']?.toString() ?? 'Senza nome', style: TextStyle(fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
              subtitle: Text(volume['descrizione']?.toString() ?? ''),
              trailing: isActive
                  ? const Chip(
                      label: Text('Attivo'),
                      backgroundColor: Colors.green,
                      labelStyle: TextStyle(color: Colors.white),
                    )
                  : null,
              onTap: () {
                Navigator.pop(context);
                final fileName = volume['nome_file_db']?.toString() ?? '';
                if (fileName.isNotEmpty) {
                  _onVolumeSelected(context, fileName);
                }
              },
            );
          }).toList();

          return AlertDialog(
            title: const Text('Gestione dei Volumi'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Volume corrente: ${currentVolume['nome_catalogo']?.toString() ?? 'N/A'}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text('Seleziona un volume:'),
                  const SizedBox(height: 8),
                  ...volumeWidgets,
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annulla'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _onVolumeSelected(BuildContext context, String dbFileName) async {
    final success = await databaseService.switchVolume(dbFileName);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Volume cambiato a: $dbFileName' : 'Errore nel cambio volume.'),
        backgroundColor: success ? Colors.teal[800] : Colors.red,
      ),
    );
    print('Volume selezionato: $dbFileName');
  }
}
