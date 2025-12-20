// lib/screens/funzioni_variazione_dati_screen.dart - VERSIONE RIPRISTINATA ORIGINALE
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

import 'package:jamsetgemini/main.dart';
import 'package:jamsetgemini/platform/opener_platform_interface.dart';
import 'package:jamsetgemini/utils/file_opener.dart';

class FunzioniVariazioneDatiScreen extends StatefulWidget {
  const FunzioniVariazioneDatiScreen({super.key});

  @override
  State<FunzioniVariazioneDatiScreen> createState() => _FunzioniVariazioneDatiScreenState();
}

class _FunzioniVariazioneDatiScreenState extends State<FunzioniVariazioneDatiScreen>
    with AutomaticKeepAliveClientMixin {
  bool _isQueryRunning = false;
  String? _error;
  List<Map<String, dynamic>> _queryResults = [];

  Duration? _dbQueryTime;

  late final TextEditingController _ricercaController;
  late final TextEditingController _strumentoController;
  late final TextEditingController _volumeController;
  late final TextEditingController _provenienzaController;
  late final TextEditingController _tipoMultiController;
  late final TextEditingController _autoreController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _ricercaController = TextEditingController();
    _strumentoController = TextEditingController();
    _volumeController = TextEditingController();
    _provenienzaController = TextEditingController();
    _tipoMultiController = TextEditingController();
    _autoreController = TextEditingController();
    databaseService.addListener(_onDbChange);
  }

  @override
  void dispose() {
    databaseService.removeListener(_onDbChange);
    _ricercaController.dispose();
    _strumentoController.dispose();
    _volumeController.dispose();
    _provenienzaController.dispose();
    _tipoMultiController.dispose();
    _autoreController.dispose();
    super.dispose();
  }

  void _onDbChange() { if (mounted) setState(() {}); }

  String _processSimpleSearchTerms(String searchText) {
    final text = searchText.trim();
    if (text.isEmpty) return '';
    final words = text.split(' ').where((w) => w.isNotEmpty).map((w) => w.trim()).toList();
    final processed = words.map((w) => (w.length >= 3 && !w.endsWith('*')) ? '$w*' : w).toList();
    return processed.join(' AND ');
  }

  Future<void> _executeQuery() async {
    if (databaseService.dbCatalogoAttivo == null) return;
    if (_isQueryRunning) return;

    setState(() { _isQueryRunning = true; _error = null; });

    try {
      final whereClauses = <String>[];
      final whereArgs = <dynamic>[];

      if (_ricercaController.text.isNotEmpty) {
        final searchText = _ricercaController.text.trim();
        final ftsOperators = [' OR ', ' AND ', ' NOT ', ' NEAR(', '*', '"', '(', ')', '-', ':'];
        final isAdvanced = ftsOperators.any((op) => searchText.toUpperCase().contains(op));

        String match = isAdvanced ? searchText : '(titolo:${_processSimpleSearchTerms(searchText)}) OR (autore:${_processSimpleSearchTerms(searchText)})';
        whereClauses.add('a.id_univoco_globale IN (SELECT rowid FROM spartiti_fts WHERE spartiti_fts MATCH ?)');
        whereArgs.add(match);
      }

      if (_autoreController.text.isNotEmpty) { whereClauses.add('a.autore LIKE ?'); whereArgs.add('%${_autoreController.text}%'); }
      if (_tipoMultiController.text.isNotEmpty) { whereClauses.add('a.TipoMulti LIKE ?'); whereArgs.add('%${_tipoMultiController.text}%'); }
      if (_volumeController.text.isNotEmpty) { whereClauses.add('a.volume LIKE ?'); whereArgs.add('%${_volumeController.text}%'); }
      if (_provenienzaController.text.isNotEmpty) { whereClauses.add('a.ArchivioProvenienza LIKE ?'); whereArgs.add('%${_provenienzaController.text}%'); }
      if (_strumentoController.text.isNotEmpty) { whereClauses.add('a.strumento LIKE ?'); whereArgs.add('%${_strumentoController.text}%'); }

      String where = whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';
      final sql = "SELECT DISTINCT a.* FROM spartiti a $where ORDER BY a.titolo COLLATE NOCASE, a.strumento LIMIT 200";

      final dbStopwatch = Stopwatch()..start();
      final results = await databaseService.dbCatalogoAttivo!.rawQuery(sql, whereArgs);
      dbStopwatch.stop();

      if (mounted) {
        setState(() {
          _queryResults = results;
          _isQueryRunning = false;
          _dbQueryTime = dbStopwatch.elapsed;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isQueryRunning = false; });
    }
  }

  Future<void> _openPdfFromRow(Map<String, dynamic> row) async {
    await FileOpener.openFile(
        context: context,
        percResto: row['PercResto']?.toString() ?? '',
        volume: row['volume']?.toString() ?? '',
        tipoMulti: row['TipoMulti']?.toString() ?? 'PDF',
        page: int.tryParse(row['NumPag']?.toString() ?? '1') ?? 1
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final String nomeCatalogo = databaseService.activeCatalogDbName.isEmpty ? "VecchioDb.db" : databaseService.activeCatalogDbName;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.indigo[900],
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ricerca Database', style: TextStyle(fontSize: 16)),
            Text('Catalogo: $nomeCatalogo', style: const TextStyle(fontSize: 11, color: Colors.yellowAccent)),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            TextField(
              controller: _ricercaController,
              decoration: const InputDecoration(hintText: 'Cerca brano o autore...', border: OutlineInputBorder(), isDense: true),
              onSubmitted: (_) => _executeQuery(),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                FilledButton.icon(onPressed: _executeQuery, icon: const Icon(Icons.search), label: const Text('CERCA')),
                const SizedBox(width: 8),
                OutlinedButton(onPressed: () => setState(() => _queryResults = []), child: const Text('PULISCI')),
                const SizedBox(width: 8),
                OutlinedButton.icon(onPressed: () => _showFiltersModal(context), icon: const Icon(Icons.filter_alt), label: const Text('FILTRI')),
                const Spacer(),
                if (_queryResults.isNotEmpty) Text('${_queryResults.length} brani', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
              ],
            ),
            const Divider(),
            Expanded(child: _buildResultsSection()),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsSection() {
    if (_isQueryRunning) return const Center(child: CircularProgressIndicator());
    if (_queryResults.isEmpty) return const Center(child: Text('Nessun risultato.'));

    return ListView.builder(
      itemCount: _queryResults.length,
      itemBuilder: (context, index) {
        final row = _queryResults[index];
        final titolo = row['titolo'] as String? ?? '';
        bool showHeader = index == 0 || (titolo.toUpperCase() != _queryResults[index-1]['titolo'].toString().toUpperCase());

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showHeader)
              Container(padding: const EdgeInsets.all(8), color: Colors.indigo[800], child: Text(titolo.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            InkWell(
              onTap: () => _openPdfFromRow(row),
              child: Container(
                padding: const EdgeInsets.all(12),
                color: index.isEven ? Colors.white : Colors.grey[100],
                child: Text.rich(
                  TextSpan(
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                    children: [
                      TextSpan(text: row['strumento'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                      const TextSpan(text: ' - '),
                      TextSpan(text: row['autore'] ?? '', style: const TextStyle(fontStyle: FontStyle.italic)),
                      const TextSpan(text: ' a Pag: '),
                      TextSpan(text: row['NumPag']?.toString() ?? '', style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                      const TextSpan(text: ' Vol: '),
                      TextSpan(text: row['volume'] ?? '', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showFiltersModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Filtri Avanzati', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            TextField(controller: _autoreController, decoration: const InputDecoration(labelText: 'Autore')),
            TextField(controller: _strumentoController, decoration: const InputDecoration(labelText: 'Strumento')),
            TextField(controller: _volumeController, decoration: const InputDecoration(labelText: 'Volume')),
            TextField(controller: _provenienzaController, decoration: const InputDecoration(labelText: 'Archivio')),
            TextField(controller: _tipoMultiController, decoration: const InputDecoration(labelText: 'Tipo Multimedia')),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: () { Navigator.pop(context); _executeQuery(); }, child: const Text('APPLICA FILTRI')),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
