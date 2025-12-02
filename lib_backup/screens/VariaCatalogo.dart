//////////// variaCatalogo.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import 'package:jamsetgemini/main.dart'; // 1. IMPORT CORRETTO
import 'package:jamsetgemini/screens/lista_spartiti_catalogo.dart'; // 1. IMPORT CORRETTO

class VariaCatalogoScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final int totalCataloghi;

  const VariaCatalogoScreen({super.key, this.initialData, required this.totalCataloghi});

  @override
  State<VariaCatalogoScreen> createState() => _VariaCatalogoScreenState();
}

class _VariaCatalogoScreenState extends State<VariaCatalogoScreen> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;
  bool _isNewRecord = true;

  @override
  void initState() {
    super.initState();
    _isNewRecord = widget.initialData == null;
    
    _controllers = {
      'id': TextEditingController(),
      'nome_catalogo': TextEditingController(),
      'descrizione': TextEditingController(), 
      'nome_file_db': TextEditingController(),
      'FilesPath': TextEditingController(),
      'AppPath': TextEditingController(),
      'data_creazione': TextEditingController(),
      'data_ultimo_aggiornamento': TextEditingController(),
      'conteggio_brani': TextEditingController(),
    };

    if (!_isNewRecord) {
      widget.initialData!.forEach((key, value) {
        _controllers[key]?.text = value?.toString() ?? '';
      });
    } else {
       _controllers['data_creazione']?.text = DateTime.now().toIso8601String();
       _controllers['conteggio_brani']?.text = '0';
    }
  }

  @override
  void dispose() {
    _controllers.forEach((key, controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _saveData() async {
    if (!_formKey.currentState!.validate() || dbGlobale == null) return;

    try {
      final db = dbGlobale!;
      
      Map<String, dynamic> dataToSave = {};
      _controllers.forEach((key, controller) => dataToSave[key] = controller.text);
      dataToSave['data_ultimo_aggiornamento'] = DateTime.now().toIso8601String();

      if (_isNewRecord) {
        dataToSave.remove('id');
        await db.insert('elenco_cataloghi', dataToSave, conflictAlgorithm: ConflictAlgorithm.replace);
      } else {
        await db.update('elenco_cataloghi', dataToSave, where: 'id = ?', whereArgs: [dataToSave['id']]);
      }

      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dati salvati con successo!'), backgroundColor: Colors.green));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
       if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
    }
  }

  Future<void> _deleteData() async {
    if (_isNewRecord || widget.initialData == null || dbGlobale == null) return;

    final id = widget.initialData!['id'];
    if (id == 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ERRORE: Il catalogo di default (ID 1) non può essere eliminato.'), backgroundColor: Colors.red));
      return;
    }
    if (widget.totalCataloghi <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ERRORE: Non puoi eliminare l\'ultimo catalogo rimasto.'), backgroundColor: Colors.red));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conferma Eliminazione'),
        content: Text('Sei sicuro di voler eliminare il catalogo "${widget.initialData!['nome_catalogo']}"? L\'operazione è irreversibile.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annulla')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Elimina', style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;

    if (confirmed) {
      try {
        final db = dbGlobale!;
        await db.delete('elenco_cataloghi', where: 'id = ?', whereArgs: [id]);

        if(mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Catalogo eliminato.'), backgroundColor: Colors.orange));
            Navigator.of(context).pop(true);
        }
      } catch (e) {
          if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    }
  }

  Future<void> _pickFolder(String controllerKey) async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      setState(() {
        _controllers[controllerKey]?.text = selectedDirectory;
      });
    }
  }

  Future<void> _verificaEApriCatalogo() async {
    if(widget.initialData == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ListaSpartitiCatalogoScreen(
          catalogoId: widget.initialData!['id'] as int,
          nomeCatalogo: widget.initialData!['nome_catalogo'] as String,
          dbName: widget.initialData!['nome_file_db'] as String,
        ),
      ),
    );
  }

  // --- NUOVA FUNZIONE PER MOSTRARE INFO DB ---
  void _showDbInfo() {
    final dbName = _isNewRecord ? '(nuovo catalogo)' : _controllers['nome_file_db']?.text ?? 'N/D';
    final fullPath = p.join(gDatabasePath, dbName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Informazioni Database'),
        content: SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              const Text('Nome file database del catalogo:'),
              SelectableText(dbName, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Text('Percorso completo della cartella dei DB:'),
              SelectableText(gDatabasePath, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Copia Percorso'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: gDatabasePath));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Percorso cartella copiato!')));
            },
          ),
          TextButton(
            child: const Text('Chiudi'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNewRecord ? 'Nuovo Catalogo' : 'Varia Catalogo'),
        actions: [
          // --- PULSANTE INFO AGGIUNTO ---
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showDbInfo,
            tooltip: 'Info Database',
          ),
          if (!_isNewRecord)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _deleteData,
              tooltip: 'Elimina Catalogo',
            )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ..._controllers.entries.map((entry) {
                final key = entry.key;
                final controller = entry.value;
                bool isReadOnly = ['id', 'data_creazione', 'data_ultimo_aggiornamento', 'conteggio_brani'].contains(key);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: TextFormField(
                    controller: controller,
                    readOnly: isReadOnly,
                    maxLines: key == 'descrizione' ? 3 : 1,
                    decoration: InputDecoration(
                      labelText: key,
                      border: const OutlineInputBorder(),
                      filled: isReadOnly,
                      fillColor: isReadOnly ? Colors.grey[200] : null,
                      suffixIcon: (key == 'FilesPath' || key == 'AppPath') ? IconButton(icon: const Icon(Icons.folder_open), onPressed: () => _pickFolder(key)) : null,
                    ),
                    validator: (value) {
                      if (!isReadOnly && (value == null || value.isEmpty)) {
                        return 'Questo campo non può essere vuoto';
                      }
                      return null;
                    },
                  ),
                );
              }).toList(),
              if (!_isNewRecord)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: ElevatedButton.icon(
                    onPressed: _verificaEApriCatalogo,
                    icon: const Icon(Icons.playlist_play),
                    label: const Text('Verifica e Apri Catalogo'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saveData,
        label: const Text('SALVA'),
        icon: const Icon(Icons.save),
      ),
    );
  }
}
