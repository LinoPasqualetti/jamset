// lib/screens/gestione_variazioni_screen.dart
import 'package:flutter/material.dart';
import 'variabili_ambiente_screen.dart';
import 'test_apertura_file_screen.dart'; // <-- 1. AGGIUNGI QUESTO IMPORT

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
                    // --- 2. AGGIORNA LA STRUTTURA A 3 RIGHE ---
                    // Prima riga
                    Row(
                      children: [
                        Expanded(child: _buildFeatureButton(context, icon: Icons.upload_file_outlined, title: 'a) Carica PDF', subtitle: 'Aggiungi nuovi spartiti', onTap: () {})),
                        const SizedBox(width: 8),
                        Expanded(child: _buildFeatureButton(context, icon: Icons.rule_folder_outlined, title: 'b) Varia Indici', subtitle: 'Modifica metadati', onTap: () {})),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Seconda riga
                    Row(
                      children: [
                        Expanded(child: _buildFeatureButton(context, icon: Icons.backup_outlined, title: 'c) Backup', subtitle: 'Gestisci backup e authority', onTap: () {})),
                        const SizedBox(width: 8),
                        Expanded(child: _buildFeatureButton(context, icon: Icons.settings_applications_outlined, title: 'd) Impostazioni', subtitle: 'Configura percorsi', onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const VariabiliAmbienteScreen()));
                        })),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Terza riga con il nuovo bottone
                    Row(
                      children: [
                        // --- 3. AGGIUNGI IL NUOVO BOTTONE ---
                        Expanded(
                          child: _buildFeatureButton(
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
                        ),
                        // Aggiungiamo uno spacer per bilanciare la riga se non ci sono altri bottoni
                        const Expanded(child: SizedBox()),
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

  // Il metodo _buildFeatureButton rimane invariato
  Widget _buildFeatureButton(BuildContext context, {required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return Tooltip(
      message: subtitle,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
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
    );
  }
}
