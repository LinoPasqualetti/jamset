import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:jamset/main.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class VariazioneDatiGeneraliScreen extends StatefulWidget {
  const VariazioneDatiGeneraliScreen({super.key});

  @override
  State<VariazioneDatiGeneraliScreen> createState() => _VariazioneDatiGeneraliScreenState();
}

class _VariazioneDatiGeneraliScreenState extends State<VariazioneDatiGeneraliScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  String? _error;

  final Map<String, TextEditingController> _controllers = {};
  List<Map<String, dynamic>> _elencoCataloghi = [];
  int? _selectedCatalogoId;
  String _dbPathForAppBar = 'Caricamento...';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      if (dbGlobale == null) throw Exception('Database globale non inizializzato.');

      _dbPathForAppBar = dbGlobale!.path;

      final datiSistema = await dbGlobale!.query('DatiSistremaApp', limit: 1);
      if (datiSistema.isEmpty) throw Exception('Tabella DatiSistremaApp è vuota.');
      final dataRow = datiSistema.first;

      _elencoCataloghi = await dbGlobale!.query('elenco_cataloghi');

      dataRow.forEach((key, value) {
        _controllers[key] = TextEditingController(text: value?.toString() ?? '');
      });

      _controllers['SistemaOperativo']?.text = Platform.operatingSystem;
      _controllers['TipoInterfaccia']?.text = (kIsWeb) ? 'Web' : 'Nativa';

      setState(() {
        _selectedCatalogoId = dataRow['id_catalogo_attivo'] as int?;
        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

   Future<void> _saveData() async {
    if (_formKey.currentState!.validate() && dbGlobale != null) {
      try {
        Map<String, dynamic> dataToSave = {};
        _controllers.forEach((key, controller) {
          if (key != 'SistemaOperativo' && key != 'TipoInterfaccia') {
             dataToSave[key] = controller.text;
          }
        });
        dataToSave['id_catalogo_attivo'] = _selectedCatalogoId;

        await dbGlobale!.update('DatiSistremaApp', dataToSave);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Dati salvati. Riavvia l\'app per rendere effettive le modifiche al catalogo.'), backgroundColor: Colors.green),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Errore nel salvataggio: $e'), backgroundColor: Colors.red),
          );
        }
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(appBar: AppBar(title: const Text("Varia Dati Sistema")), body: const Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(appBar: AppBar(title: const Text("Errore")), body: Center(child: Text(_error!)));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Variazione Dati di Sistema'),
        backgroundColor: Colors.indigo,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SelectableText( // <-- MODIFICA
                  'Tabella: DatiSistremaApp',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
                SelectableText( // <-- MODIFICA
                  'Collocazione: $_dbPathForAppBar',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: _controllers.entries.map((entry) {
              final key = entry.key;
              final controller = entry.value;

              if (key == 'PercorsoDatabase') {
                return const SizedBox.shrink();
              }

              if (key == 'id_catalogo_attivo') {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: DropdownButtonFormField<int>(
                    value: _selectedCatalogoId,
                    items: _elencoCataloghi.map((catalogo) {
                      return DropdownMenuItem<int>(
                        value: catalogo['id'] as int,
                        child: Text('${catalogo['nome_catalogo']} (ID: ${catalogo['id']})'),
                      );
                    }).toList(),
                    onChanged: (newValue) => setState(() => _selectedCatalogoId = newValue),
                    decoration: const InputDecoration(labelText: 'Catalogo Attivo', border: OutlineInputBorder()),
                  ),
                );
              }
              
              final bool isReadOnly = (key == 'SistemaOperativo' || key == 'TipoInterfaccia');

              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: TextFormField(
                  controller: controller,
                  readOnly: isReadOnly,
                  decoration: InputDecoration(
                    labelText: key,
                    border: const OutlineInputBorder(),
                    filled: isReadOnly,
                    fillColor: isReadOnly ? Colors.grey[200] : null,
                    suffixIcon: key == 'PercorsoPdf' 
                        ? IconButton(icon: const Icon(Icons.folder_open), onPressed: () => _pickFolder(key)) 
                        : null,
                  ),
                ),
              );
            }).toList(),
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
