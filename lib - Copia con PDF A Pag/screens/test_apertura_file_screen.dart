// lib/screens/test_apertura_file_screen.dart
import 'package:flutter/material.dart';
// import 'package:opener/opener.dart'; // Temporaneamente commentato
import 'package:shared_preferences/shared_preferences.dart';

class TestAperturaFileScreen extends StatefulWidget {
  const TestAperturaFileScreen({super.key});

  @override
  _TestAperturaFileScreenState createState() => _TestAperturaFileScreenState();
}

class _TestAperturaFileScreenState extends State<TestAperturaFileScreen> {
  final _fileNameController = TextEditingController();
  final _pageNumberController = TextEditingController();
  String? _basePdfPath;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadBasePath();
  }

  @override
  void dispose() {
    _fileNameController.dispose();
    _pageNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadBasePath() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _basePdfPath = prefs.getString('basePdfPath');
    });
  }

  // --- METODO MANCANTE AGGIUNTO QUI ---
  Future<void> _testOpenFile() async {
    // FUNZIONE TEMPORANEAMENTE DISABILITATA IN ATTESA DI RISOLVERE LE DIPENDENZE

    // Mostra un messaggio all'utente per informarlo che la funzione non è attiva.
    if (mounted) { // Controlla se il widget è ancora nell'albero dei widget
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Funzione di apertura temporaneamente disabilitata.')),
      );
    }

    // Il codice originale per aprire il file è commentato qui sotto
    // per essere riattivato una volta risolto il problema con il pacchetto 'opener'.
    /*
    if (_basePdfPath == null || _basePdfPath!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Percorso base PDF non configurato!')),
        );
      }
      return;
    }

    final String fileName = _fileNameController.text;
    final int? pageNumber = int.tryParse(_pageNumberController.text);

    if (fileName.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Per favore, inserisci un nome file.')),
        );
      }
      return;
    }

    setState(() { _isLoading = true; });

    final String fullPath = '$_basePdfPath\\$fileName';

    try {
      // await Opener.open(fullPath); // Chiamata da riattivare
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore durante l\'apertura: $e')),
        );
      }
    } finally {
      setState(() { _isLoading = false; });
    }
    */
  }
  // ------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Apertura File'),
        backgroundColor: Colors.indigo,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/FabbricaPerImpostazioni.jpg',
            fit: BoxFit.cover,
            color: Colors.black.withOpacity(0.5),
            colorBlendMode: BlendMode.darken,
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Percorso Base PDF: ${_basePdfPath ?? "Non impostato"}',
                  style: const TextStyle(color: Colors.white, fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _fileNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome File (es. V01_001.pdf)',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white70,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _pageNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Numero di Pagina (opzionale)',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white70,
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 20),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  ElevatedButton.icon(
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Apri File'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.indigoAccent,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _testOpenFile,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
