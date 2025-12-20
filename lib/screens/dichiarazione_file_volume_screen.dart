import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path; // AGGIUNTO IMPORT MANCANTE
import 'package:jamsetgemini/main.dart'; // Per databaseService e variabili globali

class DichiarazioneFileVolumeScreen extends StatefulWidget {
  const DichiarazioneFileVolumeScreen({super.key});

  @override
  _DichiarazioneFileVolumeScreenState createState() => _DichiarazioneFileVolumeScreenState();
}

class _DichiarazioneFileVolumeScreenState extends State<DichiarazioneFileVolumeScreen> {
  String? _selectedFilePath;
  String? _selectedFileType;
  
  // Per la selezione del catalogo di destinazione
  List<Map<String, dynamic>> _cataloghiDisponibili = [];
  String? _selectedCatalogDbName;
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCataloghi();
  }

  Future<void> _loadCataloghi() async {
    final list = await databaseService.getAvailableVolumes();
    setState(() {
      _cataloghiDisponibili = list;
      if (list.isNotEmpty) {
        // Di default seleziona quello attivo o il primo
        _selectedCatalogDbName = gActiveCatalogDbName.isNotEmpty ? gActiveCatalogDbName : list.first['nome_file_db'];
      }
    });
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'], 
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFilePath = result.files.single.path;
          _selectedFileType = 'CSV';
        });
      }
    } catch (e) {
      debugPrint('Errore pick file: $e');
    }
  }

  Future<void> _importFile() async {
    if (_selectedFilePath == null || _selectedCatalogDbName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona un file e un catalogo di destinazione'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      debugPrint("🚀 Avvio importazione CSV in $_selectedCatalogDbName...");
      final count = await databaseService.importFromCsv(_selectedFilePath!, _selectedCatalogDbName!);
      
      if (mounted) {
        setState(() => _isLoading = false);
        _showSuccessDialog(count);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore durante l\'importazione: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showSuccessDialog(int count) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 10), Text('Successo')],
        ),
        content: Text('Importazione completata.\n\nSono stati inseriti $count spartiti nel catalogo selezionato.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Chiude dialog
              Navigator.pop(context); // Torna indietro alla gestione
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Importa da CSV'),
        backgroundColor: Colors.orange[700],
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          Image.asset('assets/images/FabbricaPerImpostazioni.jpg', fit: BoxFit.cover, width: double.infinity, height: double.infinity),
          Container(color: Colors.black.withOpacity(0.3)),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                Card(
                  elevation: 8,
                  color: Colors.white.withOpacity(0.95),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.file_upload, size: 50, color: Colors.orange),
                        const SizedBox(height: 10),
                        const Text('CONFIGURAZIONE IMPORTAZIONE', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const Divider(height: 30),
                        
                        // 1. SELEZIONE FILE
                        const Text('1. Seleziona il file CSV:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _pickFile,
                          icon: const Icon(Icons.search),
                          label: Text(_selectedFilePath != null ? path.basename(_selectedFilePath!) : 'Sfoglia file...'),
                        ),
                        const SizedBox(height: 20),

                        // 2. SELEZIONE CATALOGO
                        const Text('2. Catalogo di destinazione:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _selectedCatalogDbName,
                          decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12)),
                          items: _cataloghiDisponibili.map((c) {
                            return DropdownMenuItem<String>(
                              value: c['nome_file_db'],
                              child: Text(c['nome_catalogo'] ?? 'Senza nome'),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() => _selectedCatalogDbName = val),
                        ),
                        
                        const SizedBox(height: 30),

                        // PULSANTE IMPORTA
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _importFile,
                          icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.cloud_upload),
                          label: Text(_isLoading ? 'IMPORTAZIONE IN CORSO...' : 'AVVIA IMPORTAZIONE'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange[800],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
