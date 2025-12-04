/// funzioni_variazione_dati_screen.dart - VERSIONE CORRETTA CON QUERY FIX
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:path/path.dart' as p;

import 'package:jamsetgemini/main.dart';
import 'package:jamsetgemini/platform/opener_platform_interface.dart';
import 'package:jamsetgemini/utils/file_opener.dart';  // Aggiungi import

class FunzioniVariazioneDatiScreen extends StatefulWidget {
  const FunzioniVariazioneDatiScreen({super.key});

  @override
  State<FunzioniVariazioneDatiScreen> createState() =>
      _FunzioniVariazioneDatiScreenState();
}

class _FunzioniVariazioneDatiScreenState extends State<FunzioniVariazioneDatiScreen>
    with AutomaticKeepAliveClientMixin {
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

    // QUERY ORIGINALE ESATTA
    final String defaultQuery = """
             SELECT DISTINCT   Numpag,  a.titolo,  a.volume,  a.ArchivioProvenienza,  a.strumento,  
             primolink,'${gPercorsoPdf}' percradice,  percresto,
            '${gPercorsoPdf}'||percresto||a.Volume as PerApertura
             FROM spartiti a JOIN spartiti_fts fts ON a.idBra = fts.rowid WHERE a.tipoMulti LIKE 'PD%'
             AND spartiti_fts MATCH 'girl ipanema'ORDER BY a.titolo, a.strumento """  ;

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
    // Normalizza le chiavi a lowercase
    final lowerCaseRowData = {for (var k in rowData.keys) k.toLowerCase(): rowData[k]};

    // VERIFICA I CAMPI NECESSARI (NON PIÙ PerApertura!)
    if (!lowerCaseRowData.containsKey('percresto') ||
        !lowerCaseRowData.containsKey('volume')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('ERRORE: La query deve contenere: PercResto e Volume'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    final percResto = lowerCaseRowData['percresto'] as String?;
    final volume = lowerCaseRowData['volume'] as String?;
    final pageNum = lowerCaseRowData['numpag'];

    if (percResto == null || percResto.isEmpty || volume == null || volume.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('ERRORE: PercResto o Volume sono vuoti.'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    final page = int.tryParse(pageNum?.toString() ?? '1') ?? 1;

    // --- LOGICA UNIFICATA: USA SEMPRE gPercorsoPdf COME BASE ---
    if (gPercorsoPdf.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('ERRORE: Percorso PDF non configurato. Vai nelle Impostazioni.'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    // Costruisci il percorso corretto
    final fullPath = _buildCorrectPdfPath(gPercorsoPdf, percResto, volume);

    // --- DEBUG DETTAGLIATO ---
    print('=== APERTURA PDF DA RICERCA FTS ===');
    print('Piattaforma: ${Platform.operatingSystem}');
    print('gPercorsoPdf: $gPercorsoPdf');
    print('PercResto: $percResto');
    print('Volume: $volume');
    print('Path finale: $fullPath');
    print('Pagina: $page');

    // Verifica se il file esiste
    try {
      final file = File(fullPath);
      final exists = await file.exists();
      print('📄 File esiste? $exists');

      if (!exists) {
        print('🔍 DEBUG percorsi alternativi:');

        // 1. Prova con path.join (come fa csv_viewer)
        final pathJoinResult = p.join(gPercorsoPdf, percResto, volume);
        print('   Path.join: $pathJoinResult');
        print('   Path.join esiste? ${await File(pathJoinResult).exists()}');

        // 2. Prova con percorsi normalizzati
        final normalized = _normalizeAndJoin(gPercorsoPdf, percResto, volume);
        print('   Normalizzato: $normalized');
        print('   Normalizzato esiste? ${await File(normalized).exists()}');
      }
    } catch (e) {
      print('❌ Errore verifica file: $e');
    }

    await OpenerPlatformInterface.instance.openPdf(
      context: context,
      filePath: fullPath,
      page: page,
    );
  }

// FUNZIONE DI SUPPORTO PER COSTRUIRE PERCORSI CORRETTI
  String _buildCorrectPdfPath(String basePath, String percResto, String volume) {
    // Normalizza i percorsi
    String cleanBase = basePath.trim();
    String cleanResto = percResto.trim();
    String cleanVolume = volume.trim();

    // Su Windows
    if (Platform.isWindows) {
      // Rimuovi slash finale da base
      if (cleanBase.endsWith(r'\')) {
        cleanBase = cleanBase.substring(0, cleanBase.length - 1);
      }

      // Rimuovi slash iniziale da resto se presente
      if (cleanResto.startsWith(r'\')) {
        cleanResto = cleanResto.substring(1);
      }

      // Costruisci il percorso Windows-style
      return '$cleanBase\\$cleanResto\\$cleanVolume';
    }
    // Su altri OS
    else {
      // Rimuovi slash finale da base
      if (cleanBase.endsWith('/')) {
        cleanBase = cleanBase.substring(0, cleanBase.length - 1);
      }

      // Rimuovi slash iniziale da resto se presente
      if (cleanResto.startsWith('/')) {
        cleanResto = cleanResto.substring(1);
      }

      // Costruisci il percorso Unix-style
      return '$cleanBase/$cleanResto/$cleanVolume';
    }
  }

// Alternativa con path.join ma normalizzata
  String _normalizeAndJoin(String basePath, String percResto, String volume) {
    // Normalizza separatori
    String normalizedBase = basePath.replaceAll(r'\\', r'\').replaceAll('//', '/');
    String normalizedResto = percResto.replaceAll(r'\\', r'\').replaceAll('//', '/');

    // Rimuovi slash finale da base
    if (Platform.isWindows && normalizedBase.endsWith(r'\')) {
      normalizedBase = normalizedBase.substring(0, normalizedBase.length - 1);
    } else if (!Platform.isWindows && normalizedBase.endsWith('/')) {
      normalizedBase = normalizedBase.substring(0, normalizedBase.length - 1);
    }

    // Rimuovi slash iniziale da resto
    if (normalizedResto.startsWith('/') || normalizedResto.startsWith(r'\')) {
      normalizedResto = normalizedResto.substring(1);
    }

    // Usa path.join
    return p.join(normalizedBase, normalizedResto, volume);
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
          const Text("Tabella attiva: spartiti",
              style: TextStyle(fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
          const SizedBox(height: 10),
          const Text("NOTA: I percorsi vengono corretti automaticamente per la piattaforma",
              style: TextStyle(fontSize: 12, color: Colors.blue)),
          const SizedBox(height: 5),
          TextField(
            controller: _sqlController,
            maxLines: 5,
            decoration: const InputDecoration(
                labelText: 'Comando SQL',
                border: OutlineInputBorder(),
                hintText: 'La query deve includere: PerApertura, NumPag, PercRadice, PercResto, Volume'
            ),
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
              Text('Trovati: ${_queryResults.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        if (_dbQueryTime != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Text(
              'Tempo Query DB: ${_dbQueryTime!.inMilliseconds} ms',
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
              'Tempo Costruzione UI: ${_uiBuildTime!.inMilliseconds} ms',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _uiBuildTime!.inMilliseconds > 200 ? Colors.orange.shade800 : Colors.green,
              ),
            ),
          ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: () {
            // Query di esempio che funziona correttamente
            _sqlController.text = """

            SELECT DISTINCT   Numpag,  a.titolo,  a.volume,  a.ArchivioProvenienza,  a.strumento,
            primolink,'${gPercorsoPdf}' percradice,  percresto,
            '${gPercorsoPdf}'||percresto||a.Volume as PerApertura
            FROM spartiti a JOIN spartiti_fts fts ON a.idBra = fts.rowid WHERE a.tipoMulti LIKE 'PD%'
            AND spartiti_fts MATCH 'girl ipanema'ORDER BY a.titolo, a.strumento """  ;
          },
          icon: const Icon(Icons.lightbulb_outline),
          label: const Text('Query di Esempio'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[50],
            foregroundColor: Colors.blue,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Configurazione attuale:',
          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
        ),
        Text(
          'Percorso PDF: ${gPercorsoPdf.isNotEmpty ? gPercorsoPdf : "NON CONFIGURATO"}',
          style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.blue),
        ),
        Text(
          'Piattaforma: ${Platform.operatingSystem}',
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
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
          case 'perapertura': size = ColumnSize.L; break;
          case 'percradice': size = ColumnSize.M; break;
          case 'percresto': size = ColumnSize.M; break;
          case 'numpag': size = ColumnSize.S; break;
          case 'titolo': size = ColumnSize.L; break;
          case 'volume': size = ColumnSize.M; break;
          case 'archivioprovenienza': size = ColumnSize.M; break;
          default: size = ColumnSize.M;
        }
        return DataColumn2(
            label: Text(key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            size: size
        );
      }).toList(),
      rows: _queryResults.map((row) {
        return DataRow2(
          onTap: () => _openPdfFromRow(row),
          cells: row.entries.map((entry) {
            final cellValue = entry.value?.toString() ?? 'NULL';
            final isPath = entry.key.toLowerCase().contains('perc') ||
                entry.key.toLowerCase().contains('perapertura');

            return DataCell(
              Tooltip(
                message: isPath ? 'Clicca per aprire PDF\nPath: $cellValue' : cellValue,
                child: SelectableText(
                  cellValue.length > 50 ? '${cellValue.substring(0, 50)}...' : cellValue,
                  style: TextStyle(
                    fontSize: 11,
                    color: isPath ? Colors.blue : null,
                    fontFamily: isPath ? 'monospace' : null,
                    fontWeight: entry.key.toLowerCase() == 'titolo' ? FontWeight.bold : null,
                  ),
                ),
              ),
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}