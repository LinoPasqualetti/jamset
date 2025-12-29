///  dichiarazione_file_volume_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:livescore/main.dart';

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

  // 🔥 NUOVO: File dalla cache
  List<Map<String, dynamic>> _tempCsvFiles = [];
  String? _selectedTempFile;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCataloghi();
    _loadTempCsvFiles();
  }

  Future<void> _loadCataloghi() async {
    final list = await databaseService.getAvailableVolumes();
    setState(() {
      _cataloghiDisponibili = list;
      if (list.isNotEmpty) {
        _selectedCatalogDbName = gActiveCatalogDbName.isNotEmpty ? gActiveCatalogDbName : list.first['nome_file_db'];
      }
    });
  }

  // 🔥 NUOVO METODO: Carica file dalla cache
  Future<void> _loadTempCsvFiles() async {
    try {
      // Usa il metodo che abbiamo aggiunto al DatabaseService
      _tempCsvFiles = await databaseService.getTempCsvFiles();
      setState(() {});
    } catch (e) {
      debugPrint('Errore caricamento file cache: $e');
    }
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
          _selectedTempFile = null; // Resetta selezione cache
          _selectedFileType = 'CSV';
        });
      }
    } catch (e) {
      debugPrint('Errore pick file: $e');
    }
  }

  // 🔥 NUOVO METODO: Seleziona file dalla cache
  Future<void> _pickFileFromCache() async {
    if (_tempCsvFiles.isEmpty) {
      await _loadTempCsvFiles();
      if (_tempCsvFiles.isEmpty) {
        _showSnackBar('Nessun file CSV trovato nella cache', isError: true);
        return;
      }
    }

    // Mostra dialog per selezionare
    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('File dalla Cache'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: Column(
            children: [
              // Intestazione
              const Padding(
                padding: EdgeInsets.only(bottom: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text('Nome', style: TextStyle(fontWeight: FontWeight.bold))),
                    Text('Dimensione', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              // Lista file
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _tempCsvFiles.length,
                  itemBuilder: (context, index) {
                    final file = _tempCsvFiles[index];
                    final isSelected = _selectedTempFile == file['path'];

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: isSelected ? Colors.blue[50] : null,
                      child: ListTile(
                        title: Text(
                          file['name'],
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text('${file['sizeFormatted']} - ${file['dateFormatted']}'),
                        trailing: isSelected
                            ? const Icon(Icons.check, color: Colors.green)
                            : null,
                        onTap: () => Navigator.pop(context, file),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _loadTempCsvFiles();
              setState(() {});
            },
            child: const Text('Aggiorna'),
          ),
        ],
      ),
    );

    if (selected != null) {
      setState(() {
        _selectedTempFile = selected['path'];
        _selectedFilePath = selected['path'];
        _selectedFileType = 'CSV dalla Cache';
      });
      _showSnackBar('File selezionato: ${selected['name']}');
    }
  }

  Future<void> _importFile() async {
    String? fileToImport;

    // Determina quale file usare
    if (_selectedTempFile != null) {
      fileToImport = _selectedTempFile;
    } else if (_selectedFilePath != null) {
      fileToImport = _selectedFilePath;
    }

    if (fileToImport == null || _selectedCatalogDbName == null) {
      _showSnackBar('Seleziona un file e un catalogo di destinazione', isError: true);
      return;
    }

    // Verifica che il file esista
    final file = File(fileToImport);
    if (!await file.exists()) {
      _showSnackBar('Il file selezionato non esiste più', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      debugPrint("🚀 Avvio importazione CSV in $_selectedCatalogDbName...");
      debugPrint("📁 File: $fileToImport");

      final count = await databaseService.importFromCsv(fileToImport, _selectedCatalogDbName!);

      if (mounted) {
        setState(() => _isLoading = false);
        _showSuccessDialog(count);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Errore durante l\'importazione: $e', isError: true);
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

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.orange,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildFileInfo() {
    if (_selectedFilePath == null) return Container();

    final fileName = _selectedTempFile != null
        ? p.basename(_selectedTempFile!)
        : _selectedFilePath != null
        ? p.basename(_selectedFilePath!)
        : 'Nessun file';

    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'File selezionato:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  _selectedTempFile != null ? Icons.cached : Icons.file_open,
                  color: Colors.blue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    fileName,
                    style: const TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_selectedTempFile != null)
                  Chip(
                    label: const Text('Cache', style: TextStyle(color: Colors.white, fontSize: 10)),
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            if (_selectedFilePath != null)
              Text(
                'Percorso: ${_selectedFilePath!.substring(0, _selectedFilePath!.length > 50 ? 50 : _selectedFilePath!.length)}...',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCacheInfo() {
    if (_tempCsvFiles.isEmpty) return Container();

    return Card(
      color: Colors.green[50],
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.info, size: 16, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'File disponibili nella cache:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._tempCsvFiles.take(2).map((file) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.0),
                child: Text(
                  '• ${file['name']} (${file['sizeFormatted']})',
                  style: const TextStyle(fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            if (_tempCsvFiles.length > 2)
              Text(
                '... e altri ${_tempCsvFiles.length - 2} file',
                style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
              ),
          ],
        ),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadTempCsvFiles();
              _showSnackBar('Lista cache aggiornata');
            },
            tooltip: 'Aggiorna cache',
          ),
        ],
      ),
      body: Stack(
        children: [
          Image.asset(
            'assets/images/FabbricaPerImpostazioni.jpg',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
          Container(color: Colors.black.withOpacity(0.3)),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: SingleChildScrollView(
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
                          const Text(
                            'CONFIGURAZIONE IMPORTAZIONE',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const Divider(height: 30),

                          // 🔥 MODIFICATO: SELEZIONE FILE CON DUE OPZIONI
                          const Text('1. Seleziona il file CSV:', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),

                          // Righe di pulsanti per selezione file
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _pickFile,
                                  icon: const Icon(Icons.folder_open),
                                  label: const Text('Sfoglia...'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _pickFileFromCache,
                                  icon: const Icon(Icons.cached),
                                  label: const Text('Cache'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange[800],
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 15),

                          // Informazioni file selezionato
                          if (_selectedFilePath != null) _buildFileInfo(),

                          const SizedBox(height: 15),

                          // Informazioni file cache disponibili
                          if (_tempCsvFiles.isNotEmpty) _buildCacheInfo(),

                          const SizedBox(height: 20),

                          // 2. SELEZIONE CATALOGO
                          const Text('2. Catalogo di destinazione:', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _selectedCatalogDbName,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12),
                            ),
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
                            icon: _isLoading
                                ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                                : const Icon(Icons.cloud_upload),
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
          ),

          // Overlay caricamento
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.orange),
                    SizedBox(height: 20),
                    Text(
                      'Importazione in corso...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}