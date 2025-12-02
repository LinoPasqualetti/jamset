import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:data_table_2/data_table_2.dart';

import 'package:jamsetgemini/main.dart'; // Import corretto

class ListaSpartitiCatalogoScreen extends StatefulWidget {
  final int catalogoId;
  final String nomeCatalogo;
  final String dbName;

  const ListaSpartitiCatalogoScreen({
    super.key,
    required this.catalogoId,
    required this.nomeCatalogo,
    required this.dbName,
  });

  @override
  State<ListaSpartitiCatalogoScreen> createState() => _ListaSpartitiCatalogoScreenState();
}

class _ListaSpartitiCatalogoScreenState extends State<ListaSpartitiCatalogoScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _spartiti = [];

  @override
  void initState() {
    super.initState();
    _loadSpartiti();
  }

  // Logica adattata per Jamset
  Future<void> _loadSpartiti() async {
    print('--- Caricamento spartiti per: ${widget.dbName} ---');
    try {
      // Il DB è già aperto e disponibile in dbCatalogoAttivo
      if (dbCatalogoAttivo == null) {
        throw Exception('Il database del catalogo attivo non è disponibile.');
      }
      
      final data = await dbCatalogoAttivo!.query('spartiti', limit: 50);
      print('[OK] Trovati ${data.length} record.');

      if (mounted) {
        setState(() {
          _spartiti = data;
          _isLoading = false;
        });
      }
    } catch (e) {
       print('--- ERRORE: _loadSpartiti ---\n$e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Spartiti in: ${widget.nomeCatalogo}'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Padding(padding: const EdgeInsets.all(16.0), child: SelectableText('Errore: $_error')));
    }
    if (_spartiti.isEmpty) {
      return const Center(child: Text('Nessuno spartito trovato in questo catalogo.'));
    }

    final columns = _spartiti.first.keys.map((key) {
      return DataColumn2(label: Text(key, style: const TextStyle(fontWeight: FontWeight.bold)));
    }).toList();

    final rows = _spartiti.map((row) {
      return DataRow(cells: row.values.map((cell) {
        return DataCell(SelectableText(cell?.toString() ?? 'NULL'));
      }).toList());
    }).toList();

    return DataTable2(
      columnSpacing: 12,
      horizontalMargin: 12,
      minWidth: 1500,
      columns: columns,
      rows: rows,
    );
  }
}
