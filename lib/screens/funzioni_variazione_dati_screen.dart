/// funzioni_variazione_dati_screen.dart
///  Gestione di una lista di documenti (PDF o Altro) governata da unaa ricerca sul DB di catalogo corrente
///  RICERCA DEI VALORI ATTUALMENTE TRAMITE UN BOX CONTENENTE UNA QUERY
///  EMISSIONE DEL RESULTSET CON ATTIVAZIONE DELLA VISUALIZZAZIONE ONTAP
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:data_table_2/data_table_2.dart';

import 'package:jamsetgemini/main.dart';
import 'package:jamsetgemini/platform/opener_platform_interface.dart';

class FunzioniVariazioneDatiScreen extends StatefulWidget {
  const FunzioniVariazioneDatiScreen({super.key});

  @override
  State<FunzioniVariazioneDatiScreen> createState() =>
      _FunzioniVariazioneDatiScreenState();
}

class _FunzioniVariazioneDatiScreenState extends State<FunzioniVariazioneDatiScreen> with AutomaticKeepAliveClientMixin {
  bool _isLoading = true;
  bool _isQueryRunning = false;
  String? _error;
  List<Map<String, dynamic>> _queryResults = [];
  List<String> _tableFields = [];

  Duration? _dbQueryTime;
  Duration? _uiBuildTime;

  late final TextEditingController _sqlController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    final String defaultQuery = """
select distinct Numpag,a.titolo,a.volume,percradice||percresto||a.Volume as PerApertura,a.ArchivioProvenienza, strumento,primolink, percradice,percresto 
from spartiti a
JOIN spartiti_fts fts on a.idBra=fts.rowid
 where a.tipoMulti like 'PD%' and spartiti_fts match 'girl ipanema'
order by a.titolo,a.strumento
""";

    _sqlController = TextEditingController(text: defaultQuery);
    _loadTableInfo();
  }

  @override
  void dispose() {
    _sqlController.dispose();
    super.dispose();
  }

  Future<void> _loadTableInfo() async {
    if (dbCatalogoAttivo == null) {
      setState(() {
        _error = "Database non disponibile. Controllare l\'errore all\'avvio.";
        _isLoading = false;
      });
      return;
    }
    try {
      final tableInfo = await dbCatalogoAttivo!.rawQuery('PRAGMA table_info(spartiti);');
      final fields = tableInfo.map((row) => row['name'] as String).toList();
      if (mounted) {
        setState(() {
          _tableFields = fields;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Errore nel leggere la struttura della tabella: \n${e.toString()}";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _executeQuery() async {
    if (dbCatalogoAttivo == null || _isQueryRunning) return;

    setState(() {
      _isQueryRunning = true;
      _error = null;
      _dbQueryTime = null;
      _uiBuildTime = null;
    });

    try {
      final dbStopwatch = Stopwatch()..start();
      final results = await dbCatalogoAttivo!.rawQuery(_sqlController.text);
      dbStopwatch.stop();

      if (mounted) {
        final uiStopwatch = Stopwatch()..start();
        setState(() {
          _queryResults = results;
          _isQueryRunning = false;
          _dbQueryTime = dbStopwatch.elapsed;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          uiStopwatch.stop();
          if (mounted) {
            setState(() {
              _uiBuildTime = uiStopwatch.elapsed;
            });
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Errore esecuzione query: \n${e.toString()}";
          _queryResults = [];
          _isQueryRunning = false;
        });
      }
    }
  }

  Future<void> _openPdfFromRow(Map<String, dynamic> rowData) async {
    final lowerCaseRowData = {for (var k in rowData.keys) k.toLowerCase(): rowData[k]};

    if (!lowerCaseRowData.containsKey('perapertura') || !lowerCaseRowData.containsKey('numpag')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('ERRORE: La query deve contenere le colonne "PerApertura" e "Numpag" per poter aprire il PDF.'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    final filePath = lowerCaseRowData['perapertura'] as String?;
    final pageNum = lowerCaseRowData['numpag'];

    if (filePath == null || filePath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('ERRORE: Il percorso del file (PerApertura) è vuoto o nullo.'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    final page = int.tryParse(pageNum?.toString() ?? '1') ?? 1;

    // --- PRINT DI DEBUG ---
    print('--- [DB CONTEXT] Tentativo di apertura ---');
    print('Path: $filePath');
    print('Pagina: $page');
    // ---------------------

    await OpenerPlatformInterface.instance.openPdf(
      context: context,
      filePath: filePath,
      page: page,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && dbCatalogoAttivo == null) {
      return Center(child: SelectableText(_error!, style: const TextStyle(color: Colors.red)));
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("Tabella attiva: spartiti", style: TextStyle(fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
          const SizedBox(height: 10),
          TextField(
            controller: _sqlController,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Comando SQL', border: OutlineInputBorder()),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.blueAccent),
          ),
          const SizedBox(height: 5),
          _buildQueryControls(),
          const Divider(),
          Expanded(
            child: _buildResultsSection(),
          ),
        ],
      ),
    );
  }

  Widget _buildQueryControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: _isQueryRunning ? null : _executeQuery,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Esegui Query'),
            ),
            const SizedBox(width: 16),
            if (!_isQueryRunning && _queryResults.isNotEmpty)
              Text('Trovati: ${_queryResults.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        if (_dbQueryTime != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Text(
              'Tempo Query DB (ricerca+sort+transfer): ${_dbQueryTime!.inMilliseconds} ms',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _dbQueryTime!.inMilliseconds > 500 ? Colors.red : Colors.green,
              ),
            ),
          ),
        if (_uiBuildTime != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Text(
              'Tempo Costruzione UI (DataTable2): ${_uiBuildTime!.inMilliseconds} ms',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _uiBuildTime!.inMilliseconds > 200 ? Colors.orange.shade800 : Colors.green,
              ),
            ),
          ),

      ],
    );
  }

  Widget _buildResultsSection() {
    if (_isQueryRunning) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: SelectableText(_error!, style: const TextStyle(color: Colors.blue)));
    if (_queryResults.isEmpty) return const Center(child: Text('Nessun risultato o query non ancora eseguita.'));

    final columnKeys = _queryResults.first.keys.toList();
    return DataTable2(
      columnSpacing: 10,
      horizontalMargin: 10,
      minWidth: 2000,
      columns: columnKeys.map((key) {
        ColumnSize size;
        switch (key.toLowerCase()) {
          case 'perapertura': size = ColumnSize.M; break;
          case 'numpag': size = ColumnSize.S; break;
          case 'titolo': size = ColumnSize.L; break;
          default: size = ColumnSize.M;
        }
        return DataColumn2(label: Text(key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), size: size);
      }).toList(),
      rows: _queryResults.map((row) {
        return DataRow2(
          onTap: () => _openPdfFromRow(row),
          cells: row.values.map((cell) => DataCell(SelectableText(cell?.toString() ?? 'NULL', style: const TextStyle(fontSize: 11)))).toList(),
        );
      }).toList(),
    );
  }
}
