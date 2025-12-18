import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;

import 'package:jamsetgemini/main.dart';
import 'package:jamsetgemini/screens/lista_spartiti_catalogo.dart';

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
  bool _isActive = false;
  bool _isSaving = false;
  bool _isPopulating = false; // Stato per l'importazione dati

  @override
  void initState() {
    super.initState();
    _isNewRecord = widget.initialData == null;

    _controllers = {
      'id': TextEditingController(),
      'nome_catalogo': TextEditingController(),
      'descrizione': TextEditingController(),
      'nome_file_db': TextEditingController(),
      'FilesPath': TextEditingController(text: gPercorsoPdf), 
      'data_creazione': TextEditingController(),
      'data_ultimo_aggiornamento': TextEditingController(),
      'conteggio_brani': TextEditingController(),
    };

    if (!_isNewRecord) {
      widget.initialData!.forEach((key, value) {
        if (_controllers.containsKey(key)) {
          _controllers[key]?.text = value?.toString() ?? '';
        }
      });
      _checkIfActive();
    } else {
      _controllers['data_creazione']?.text = DateTime.now().toIso8601String();
      _controllers['conteggio_brani']?.text = '0';
      _controllers['nome_file_db']?.text = 'nuovo_catalogo.db';
    }
  }

  @override
  void dispose() {
    _controllers.forEach((key, controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _checkIfActive() async {
    if (databaseService.dbGlobale == null) return;
    try {
      final activeCatalog = await databaseService.dbGlobale!.query('DatiSistremaApp', columns: ['id_catalogo_attivo'], limit: 1);
      if (activeCatalog.isNotEmpty) {
        final activeId = activeCatalog.first['id_catalogo_attivo'] as int? ?? 0;
        final currentId = int.tryParse(_controllers['id']!.text) ?? 0;
        if (mounted) setState(() => _isActive = (activeId == currentId));
      }
    } catch (e) {
      debugPrint('Errore nel controllo catalogo attivo: $e');
    }
  }

  Future<void> _popolaDaMaster() async {
    final dbName = _controllers['nome_file_db']!.text;
    if (dbName.isEmpty) return;

    setState(() => _isPopulating = true);
    try {
      debugPrint("🚀 Avvio popolamento catalogo $dbName da master...");
      final count = await databaseService.populateCatalogFromMaster(dbName);
      
      if (mounted) {
        setState(() {
          _controllers['conteggio_brani']!.text = count.toString();
          _isPopulating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Importazione completata! $count brani aggiunti.'), backgroundColor: Colors.teal)
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPopulating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore durante il popolamento: $e'), backgroundColor: Colors.red)
        );
      }
    }
  }

  Future<void> _activateCatalog() async {
    if (databaseService.dbGlobale == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Attiva Catalogo'),
        content: Text('Vuoi attivare il catalogo "${_controllers['nome_catalogo']!.text}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annulla')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Attiva', style: TextStyle(color: Colors.green))),
        ],
      ),
    ) ?? false;

    if (!confirmed) return;
    setState(() => _isSaving = true);

    try {
      await databaseService.dbGlobale!.update(
          'DatiSistremaApp', 
          {'id_catalogo_attivo': int.parse(_controllers['id']!.text)},
          where: 'id = ?',
          whereArgs: [1]
      );

      await databaseService.reloadConfig();
      gActiveCatalogDbName = databaseService.activeCatalogDbName;

      if (mounted) {
        setState(() => _isActive = true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Catalogo attivato!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveData() async {
    if (!_formKey.currentState!.validate() || databaseService.dbGlobale == null) return;
    setState(() => _isSaving = true);

    try {
      final db = databaseService.dbGlobale!;
      String fileName = _controllers['nome_file_db']!.text.trim();
      if (!fileName.endsWith('.db')) fileName = '$fileName.db';

      Map<String, dynamic> dataToSave = {
        'nome_catalogo': _controllers['nome_catalogo']!.text,
        'nome_file_db': fileName,
        'descrizione': _controllers['descrizione']!.text,
        'data_ultimo_aggiornamento': DateTime.now().toIso8601String(),
      };

      if (_isNewRecord) {
        dataToSave['data_creazione'] = _controllers['data_creazione']!.text;
        dataToSave['conteggio_brani'] = 0;
        final newId = await db.insert('elenco_cataloghi', dataToSave);
        await databaseService.createCatalogoDatabase(fileName);
        
        if (widget.totalCataloghi == 0) {
          await db.update('DatiSistremaApp', {'id_catalogo_attivo': newId}, where: 'id = 1');
          await databaseService.reloadConfig();
          gActiveCatalogDbName = databaseService.activeCatalogDbName;
        }
      } else {
        await db.update('elenco_cataloghi', dataToSave, where: 'id = ?', whereArgs: [_controllers['id']!.text]);
      }

      await databaseService.synchronizeCatalogs();

      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dati salvati!'), backgroundColor: Colors.green));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNewRecord ? 'Nuovo Catalogo' : 'Varia Catalogo'),
        actions: [
          if (!_isNewRecord && !_isActive)
            IconButton(icon: const Icon(Icons.check_circle_outline, color: Colors.green), onPressed: _activateCatalog, tooltip: 'Attiva'),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              ..._controllers.entries.map((entry) {
                final key = entry.key;
                bool isReadOnly = ['id', 'data_creazione', 'data_ultimo_aggiornamento', 'conteggio_brani', 'FilesPath'].contains(key);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: TextFormField(
                    controller: entry.value,
                    readOnly: isReadOnly,
                    decoration: InputDecoration(
                      labelText: key.toUpperCase(), 
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) => (!isReadOnly && (v == null || v.isEmpty)) ? 'Obbligatorio' : null,
                  ),
                );
              }).toList(),
              
              if (!_isNewRecord)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: ElevatedButton.icon(
                    onPressed: _isPopulating ? null : _popolaDaMaster,
                    icon: _isPopulating ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.download),
                    label: Text(_isPopulating ? 'IMPORTAZIONE IN CORSO...' : 'POPOLA DATI DA MASTER'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700, 
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50)
                    ),
                  ),
                ),

              if (!_isNewRecord)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ListaSpartitiCatalogoScreen(
                            catalogoId: int.parse(_controllers['id']!.text),
                            nomeCatalogo: _controllers['nome_catalogo']!.text,
                            dbName: _controllers['nome_file_db']!.text,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.playlist_play),
                    label: const Text('VERIFICA E APRI CATALOGO'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal, 
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50)
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSaving ? null : _saveData,
        label: const Text('SALVA'),
        icon: const Icon(Icons.save),
      ),
    );
  }
}
