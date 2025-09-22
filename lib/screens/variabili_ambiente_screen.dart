// lib/screens/variabili_ambiente_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart'; // <--- IMPORTA FILE_PICKER

// Chiave globale per accedere al valore del percorso da altre parti dell'app (se necessario)
const String kDefaultBasePathKey = 'app_default_base_path';

class VariabiliAmbienteScreen extends StatefulWidget {
  const VariabiliAmbienteScreen({super.key});

  @override
  State<VariabiliAmbienteScreen> createState() => _VariabiliAmbienteScreenState();
}

class _VariabiliAmbienteScreenState extends State<VariabiliAmbienteScreen> {
  final _percorsoController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPercorso();
  }

  Future<void> _loadPercorso() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      _percorsoController.text = prefs.getString(kDefaultBasePathKey) ?? '';
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore nel caricamento del percorso: $e')),
      );
      _percorsoController.text = '';
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _savePercorso() async {
    if (_percorsoController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Il percorso non può essere vuoto.')),
      );
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kDefaultBasePathKey, _percorsoController.text);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Percorso salvato con successo!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore nel salvataggio del percorso: $e')),
      );
    }
  }

  // --- NUOVA FUNZIONE PER SELEZIONARE LA CARTELLA ---
  Future<void> _selectFolder() async {
    try {
      // Usa FilePicker per selezionare una directory
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Seleziona la cartella principale degli spartiti',
      );

      if (selectedDirectory != null) {
        // L'utente ha selezionato una cartella
        setState(() {
          _percorsoController.text = selectedDirectory;
        });
        // Potresti voler salvare automaticamente qui, o lasciare che l'utente clicchi "Salva Percorso"
        // _savePercorso();
      } else {
        // L'utente ha annullato la selezione
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nessuna cartella selezionata.')),
        );
      }
    } catch (e) {
      // Gestisci eventuali errori durante la selezione della cartella
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore nella selezione della cartella: $e')),
      );
    }
  }
  // --- FINE NUOVA FUNZIONE ---

  @override
  void dispose() {
    _percorsoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Impostazioni Percorso'),
        backgroundColor: Colors.blueGrey[700],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(20.0),
        child: ListView(
          children: <Widget>[
            const Text(
              'Percorso Principale dell\'Applicazione:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Questo percorso verrà utilizzato come base per trovare i file (ad esempio, gli spartiti PDF). '
                  'Puoi inserire un percorso manualmente o usare il pulsante "Sfoglia".', // Testo aggiornato
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Row( // Usiamo una Row per affiancare TextField e pulsante Sfoglia
              children: [
                Expanded(
                  child: TextField(
                    controller: _percorsoController,
                    decoration: InputDecoration(
                      labelText: 'Percorso Base',
                      hintText: 'Es: /storage/emulated/0/Spartiti o C:\\Doc...',
                      border: const OutlineInputBorder(),
                      suffixIcon: _percorsoController.text.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _percorsoController.clear();
                          });
                        },
                      )
                          : null,
                    ),
                    keyboardType: TextInputType.text,
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon( // --- PULSANTE SFOGLIA ---
                  icon: const Icon(Icons.folder_open_outlined),
                  label: const Text('Sfoglia'),
                  onPressed: _selectFolder,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15), // Adatta il padding se necessario
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),
            ElevatedButton.icon(
              icon: const Icon(Icons.save_alt_outlined),
              label: const Text('Salva Percorso'),
              onPressed: _savePercorso,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 30),
            const Divider(),
            const SizedBox(height: 10),
            ListTile(
              leading: Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
              title: const Text('Esempi di Percorsi Comuni'),
              subtitle: const Text(
                  'Android: /storage/emulated/0/Download/I_MIEI_SPARTITI\n'
                      'Windows: C:\\Users\\TuoNome\\Documents\\I_MIEI_SPARTITI\n'
                      'Linux: /home/TuoNome/Documenti/I_MIEI_SPARTITI\n'
                      'macOS: /Users/TuoNome/Documents/I_MIEI_SPARTITI'),
              isThreeLine: true,
            ),
          ],
        ),
      ),
    );
  }
}
