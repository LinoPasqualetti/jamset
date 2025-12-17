// lib/screens/dichiarazione_file_volume_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart'; // Se usi file_picker

class DichiarazioneFileVolumeScreen extends StatefulWidget {
  const DichiarazioneFileVolumeScreen({super.key});

  @override
  _DichiarazioneFileVolumeScreenState createState() => _DichiarazioneFileVolumeScreenState();
}

class _DichiarazioneFileVolumeScreenState extends State<DichiarazioneFileVolumeScreen> {
  String? _selectedFilePath;
  String? _selectedFileType;
  final TextEditingController _volumeNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  final List<String> _fileTypes = ['CSV', 'Excel', 'JSON', 'TXT'];
  bool _isLoading = false;

  @override
  void dispose() {
    _volumeNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls', 'json', 'txt'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFilePath = result.files.single.path;
          // Determina tipo file dall'estensione
          String extension = result.files.single.extension?.toLowerCase() ?? '';
          if (extension == 'csv') {
            _selectedFileType = 'CSV';
          } else if (extension == 'xlsx' || extension == 'xls') {
            _selectedFileType = 'Excel';
          } else if (extension == 'json') {
            _selectedFileType = 'JSON';
          } else if (extension == 'txt') {
            _selectedFileType = 'TXT';
          }

          // Suggerisci nome volume dal nome file
          String fileName = result.files.single.name;
          String baseName = fileName.contains('.')
              ? fileName.substring(0, fileName.lastIndexOf('.'))
              : fileName;
          _volumeNameController.text = baseName;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore durante la selezione file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _importFile() {
    if (_selectedFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleziona un file prima di procedere'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_volumeNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inserisci un nome per il volume'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Simula importazione
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'File "${_volumeNameController.text}" importato con successo!',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 4),
          backgroundColor: Colors.teal[800],
          action: SnackBarAction(
            label: 'CHIUDI',
            onPressed: () {},
            textColor: Colors.white,
          ),
        ),
      );

      // Logica di importazione reale qui
      print('Importazione file: $_selectedFilePath');
      print('Tipo: $_selectedFileType');
      print('Nome volume: ${_volumeNameController.text}');
      print('Descrizione: ${_descriptionController.text}');

      // Potresti chiamare:
      // DatabaseService().importFromFile(_selectedFilePath!, _volumeNameController.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inserisci da File'),
        backgroundColor: Colors.orange[700],
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          Image.asset(
            'assets/images/FabbricaPerImpostazioni.jpg',
            fit: BoxFit.cover,
          ),
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    elevation: 4,
                    color: Colors.white.withOpacity(0.95),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Center(
                            child: Icon(
                              Icons.file_upload,
                              size: 60,
                              color: Colors.orange,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Center(
                            child: Text(
                              'IMPORTAZIONE DATI DA FILE',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepOrange,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Divider(),
                          const SizedBox(height: 20),

                          // 1. SELEZIONE FILE
                          _buildSectionTitle('1. Seleziona il file'),
                          const SizedBox(height: 10),
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListTile(
                              leading: const Icon(Icons.insert_drive_file, color: Colors.blue),
                              title: Text(
                                _selectedFilePath ?? 'Nessun file selezionato',
                                style: TextStyle(
                                  color: _selectedFilePath != null
                                      ? Colors.blue[800]
                                      : Colors.grey,
                                  fontWeight: _selectedFilePath != null
                                      ? FontWeight.bold
                                      : null,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: _selectedFileType != null
                                  ? Text('Tipo: $_selectedFileType')
                                  : null,
                              trailing: ElevatedButton.icon(
                                icon: const Icon(Icons.folder_open),
                                label: const Text('Sfoglia'),
                                onPressed: _pickFile,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue[600],
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // 2. INFORMAZIONI VOLUME
                          _buildSectionTitle('2. Informazioni del Volume'),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _volumeNameController,
                            decoration: const InputDecoration(
                              labelText: 'Nome del Volume *',
                              prefixIcon: Icon(Icons.title),
                              border: OutlineInputBorder(),
                              hintText: 'Es: Catalogo 2024',
                            ),
                          ),
                          const SizedBox(height: 15),
                          TextFormField(
                            controller: _descriptionController,
                            decoration: const InputDecoration(
                              labelText: 'Descrizione (opzionale)',
                              prefixIcon: Icon(Icons.description),
                              border: OutlineInputBorder(),
                              hintText: 'Breve descrizione del contenuto...',
                            ),
                            maxLines: 3,
                          ),
                          const SizedBox(height: 20),

                          // 3. OPZIONI IMPORT
                          _buildSectionTitle('3. Opzioni di Importazione'),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              FilterChip(
                                label: const Text('Ignora prima riga'),
                                selected: true,
                                onSelected: (bool value) {},
                              ),
                              FilterChip(
                                label: const Text('Mantieni formattazione'),
                                selected: true,
                                onSelected: (bool value) {},
                              ),
                              FilterChip(
                                label: const Text('Validazione automatica'),
                                selected: true,
                                onSelected: (bool value) {},
                              ),
                            ],
                          ),
                          const SizedBox(height: 30),

                          // 4. PULSANTI AZIONE
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.arrow_back),
                                  label: const Text('ANNULLA'),
                                  onPressed: () => Navigator.pop(context),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey[600],
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 15),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: _isLoading
                                      ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(color: Colors.white),
                                  )
                                      : const Icon(Icons.cloud_upload),
                                  label: Text(_isLoading ? 'IMPORTING...' : 'IMPORTA'),
                                  onPressed: _isLoading ? null : _importFile,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange[700],
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 15),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Card(
                    color: Colors.white70,
                    child: Padding(
                      padding: EdgeInsets.all(15.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Formati supportati:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 10),
                          Row(
                            children: [
                              Chip(label: Text('CSV (.csv)'), backgroundColor: Colors.green),
                              SizedBox(width: 5),
                              Chip(label: Text('Excel (.xlsx, .xls)'), backgroundColor: Colors.blue),
                              SizedBox(width: 5),
                              Chip(label: Text('JSON (.json)'), backgroundColor: Colors.orange),
                            ],
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Note:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text('• Il file CSV deve utilizzare il separatore ";"'),
                          Text('• Per Excel, verrà importato il primo foglio'),
                          Text('• Dimensione massima file: 50MB'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Colors.orange,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.deepOrange,
          ),
        ),
      ],
    );
  }
}