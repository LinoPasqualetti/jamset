// lib/screens/gestione_variazioni_screen.dart
import 'package:flutter/material.dart';
import 'package:livescore/screens/gestione_dati_globali_screen.dart';
import 'package:livescore/screens/test_apertura_file_screen.dart';
import 'package:livescore/screens/dichiarazione_file_volume_screen.dart';
import 'package:livescore/screens/elenco_volumi_catalogo_screen.dart'; // Nuova Schermata
import 'package:livescore/screens/GestisciElencoCataloghi.dart'; // Gestione Database

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
                          icon: Icons.find_in_page_outlined,
                          title: 'e) Test Apertura',
                          subtitle: 'Testa l\'apertura di un file a una pagina specifica',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const TestAperturaFileScreen()),
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
                              MaterialPageRoute(builder: (context) => const DichiarazioneFileVolumeScreen()),
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
                              const SnackBar(content: Text('Usa "f) Inserisci da file" o il popolamento da Master in Varia Catalogo.')),
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
}
