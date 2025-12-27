// lib/screens/gestione_variazioni_screen.dart
import 'package:flutter/material.dart';
import 'package:livescore/screens/gestione_dati_globali_screen.dart';
import 'package:livescore/screens/test_apertura_file_screen.dart';
import 'package:livescore/screens/dichiarazione_file_volume_screen.dart';
import 'package:livescore/screens/elenco_volumi_catalogo_screen.dart';
import 'package:livescore/screens/gestisci_elenco_cataloghi.dart'; // Assicurati che esista
import 'package:livescore/screens/popola_cataloghi_screen.dart';
import 'package:livescore/screens/export_csv_screen.dart';
import 'package:livescore/screens/gestione_indici_screen.dart';

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
                          icon: Icons.storage_rounded,
                          title: 'a) Elenco Cataloghi',
                          subtitle: 'Gestisci i file database (.db)',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const GestisciElencoCataloghi()),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildFeatureButton(
                          context,
                          icon: Icons.library_books,
                          title: 'b) Gestione Volumi',
                          subtitle: 'Indice dei volumi nel catalogo attivo',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const ElencoVolumiCatalogoScreen()),
                            );
                          },
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
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Funzionalità Backup in sviluppo')),
                            );
                          },
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
                              MaterialPageRoute(builder: (context) => const GestioneDatiGlobaliScreen()),
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
                          icon: Icons.file_upload,
                          title: 'e) Inserisci da file',
                          subtitle: 'Importa dati da file CSV/Excel',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const DichiarazioneFileVolumeScreen()),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildFeatureButton(
                          context,
                          icon: Icons.playlist_add_check,
                          title: 'f) Popola Cataloghi',
                          subtitle: 'Gestione e inserimento indici',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const PopolaCataloghiScreen(),
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
                          icon: Icons.tune,
                          title: 'g) Gestione Indici',
                          subtitle: 'Produzione e gestione indici FTS',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const GestioneIndiciScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildFeatureButton(
                          context,
                          icon: Icons.file_download,
                          title: 'h) Export CSV',
                          subtitle: 'Esporta catalogo in formato CSV',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ExportCsvScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Quinta riga (solo un pulsante al centro)
                    Row(
                      children: [
                        Expanded(
                          child: _buildFeatureButton(
                            context,
                            icon: Icons.build,
                            title: 'i) Strumenti DB',
                            subtitle: 'Diagnostica e riparazione database',
                            onTap: () {
                              _showDatabaseToolsDialog(context);
                            },
                          ),
                        ),
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

  void _showDatabaseToolsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Strumenti Database'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Seleziona un\'operazione sul database attivo:'),
            SizedBox(height: 16),
            // Aggiunto Genera Indici FTS
          ],
        ),
        actions: [
          // Aggiunto pulsante Genera Indici FTS
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Navigare a GeneraIndiciFtsScreen o chiamare direttamente
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Generazione indici FTS...')),
              );
            },
            child: const Text('Genera Indici FTS'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Diagnostica database in esecuzione...')),
              );
            },
            child: const Text('Diagnostica'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Riparazione FTS in esecuzione...')),
              );
            },
            child: const Text('Ripara FTS'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ottimizzazione database in esecuzione...')),
              );
            },
            child: const Text('Ottimizza'),
          ),
        ],
      ),
    );
  }
}