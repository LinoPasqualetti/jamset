// lib/screens/funzioni_variazione_dati_screen.dart - VERSIONE CON NUOVA VISUALIZZAZIONE
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:path/path.dart' as p;

import 'package:jamsetgemini/main.dart';
import 'package:jamsetgemini/platform/opener_platform_interface.dart';
import 'package:jamsetgemini/utils/file_opener.dart';

class FunzioniVariazioneDatiScreen extends StatefulWidget {
  const FunzioniVariazioneDatiScreen({super.key});

  @override
  State<FunzioniVariazioneDatiScreen> createState() =>
      _FunzioniVariazioneDatiScreenState();
}

class _FunzioniVariazioneDatiScreenState extends State<FunzioniVariazioneDatiScreen>
    with AutomaticKeepAliveClientMixin {
  bool _isQueryRunning = false;
  String? _error;
  List<Map<String, dynamic>> _queryResults = [];

  Duration? _dbQueryTime;
  Duration? _uiBuildTime;

  // Controller per i campi di ricerca
  late final TextEditingController _ricercaController;
  late final TextEditingController _strumentoController;
  late final TextEditingController _volumeController;
  late final TextEditingController _provenienzaController;
  late final TextEditingController _tipoMultiController;

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
  }

  @override
  void dispose() {
    _ricercaController.dispose();
    _strumentoController.dispose();
    _volumeController.dispose();
    _provenienzaController.dispose();
    _tipoMultiController.dispose();
    super.dispose();
  }

  // ================================================
  // FUNZIONI HELPER PRIVATE
  // ================================================

  String _buildFtsQuery(String searchText) {
    final text = searchText.trim();
    if (text.isEmpty) return '';

    final ftsOperators = [' OR ', ' AND ', ' NOT ', ' NEAR(', '*', '"', '(', ')', '-'];
    final hasAdvancedOperators = ftsOperators.any((op) => text.contains(op));

    if (hasAdvancedOperators) {
      debugPrint('🔧 Ricerca avanzata rilevata, testo lasciato invariato');
      return text;
    }

    final words = text.split(' ')
        .where((word) => word.trim().isNotEmpty)
        .map((word) => word.trim())
        .toList();

    if (words.isEmpty) return '';

    if (words.length == 1) {
      final word = words[0];
      if (word.length >= 3 && !word.endsWith('*') && !word.contains('"')) {
        return '$word*';
      }
      return word;
    }

    final processedWords = words.map((word) {
      if (word.length >= 3 && !word.endsWith('*') && !word.contains('"')) {
        return '$word*';
      }
      return word;
    }).toList();

    final ftsQuery = processedWords.join(' AND ');
    debugPrint('🔧 Ricerca trasformata: "$text" -> "$ftsQuery"');
    return ftsQuery;
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
      final whereClauses = <String>[];
      final whereArgs = <dynamic>[];

      if (_ricercaController.text.isNotEmpty) {
        final ftsQuery = _buildFtsQuery(_ricercaController.text);
        if (ftsQuery.isNotEmpty) {
            whereClauses.add('a.id_univoco_globale IN (SELECT rowid FROM spartiti_fts WHERE spartiti_fts MATCH ?)');
            whereArgs.add(ftsQuery);
        }
      }

      if (_tipoMultiController.text.isNotEmpty) {
        whereClauses.add('a.TipoMulti LIKE ?');
        whereArgs.add('%${_tipoMultiController.text}%');
      }
      if (_volumeController.text.isNotEmpty) {
        whereClauses.add('a.volume LIKE ?');
        whereArgs.add('%${_volumeController.text}%');
      }
      if (_provenienzaController.text.isNotEmpty) {
        whereClauses.add('a.ArchivioProvenienza LIKE ?');
        whereArgs.add('%${_provenienzaController.text}%');
      }
      if (_strumentoController.text.isNotEmpty) {
        whereClauses.add('a.strumento LIKE ?');
        whereArgs.add('%${_strumentoController.text}%');
      }

      String whereStatement = whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';

      final sql = """
        SELECT DISTINCT 
          a.titolo, a.NumPag, a.volume, a.ArchivioProvenienza, a.strumento, a.autore, 
          a.PrimoLink, a.PercResto, a.TipoMulti, a.id_univoco_globale
        FROM spartiti a
        $whereStatement
        ORDER BY a.titolo COLLATE NOCASE, a.strumento
        LIMIT 200
      """;

      debugPrint("\n" + "="*80);
      debugPrint("🔍 RICERCA ESEGUITA:");
      debugPrint("="*80);
      debugPrint("SQL: $sql");
      debugPrint("Args: $whereArgs");
      debugPrint("="*80);

      final dbStopwatch = Stopwatch()..start();
      final results = await dbCatalogoAttivo!.rawQuery(sql, whereArgs);
      dbStopwatch.stop();

      if (mounted) {
        final uiStopwatch = Stopwatch()..start();
        setState(() {
          _queryResults = results;
          _isQueryRunning = false;
          _dbQueryTime = dbStopwatch.elapsed;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() => _uiBuildTime = uiStopwatch.elapsed);
          }
        });
      }

      debugPrint('✅ Risultati: ${results.length} record in ${dbStopwatch.elapsedMilliseconds}ms');

    } catch (e) {
      debugPrint('❌ Errore ricerca: $e');
      if (mounted) {
        setState(() {
          _error = "Errore ricerca: ${e.toString()}";
          _queryResults = [];
          _isQueryRunning = false;
        });
      }
    }
  }

  Future<void> _openPdfFromRow(Map<String, dynamic> rowData) async {
    try {
      final lowerCaseRowData = {for (var k in rowData.keys) k.toLowerCase(): rowData[k]};

      final percResto = lowerCaseRowData['percresto'] as String? ?? '';
      final volume = lowerCaseRowData['volume'] as String? ?? '';
      final tipoMulti = lowerCaseRowData['tipomulti'] as String? ?? 'PDF';
      final pageNum = lowerCaseRowData['numpag'];

      if (volume.isEmpty) {
        _showError('Volume non specificato per questo record.');
        return;
      }

      final page = int.tryParse(pageNum?.toString().trim() ?? '1') ?? 1;

      await FileOpener.openFile(
          context: context,
          percResto: percResto,
          volume: volume,
          tipoMulti: tipoMulti,
          page: page
      );

    } catch (e) {
      debugPrint('❌ Errore apertura PDF: $e');
      _showError('Impossibile aprire il PDF: ${e.toString()}');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _clearFilters() {
    setState(() {
      _ricercaController.clear();
      _strumentoController.clear();
      _volumeController.clear();
      _provenienzaController.clear();
      _tipoMultiController.clear();
      _queryResults.clear();
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSearchPanel(),
            const SizedBox(height: 10),
            _buildQueryControls(),
            const Divider(),
            Expanded(
              child: _buildResultsSection(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Ricerca Testuale (FTS)', style: TextStyle(fontWeight: FontWeight.bold)),
        TextField(
          controller: _ricercaController,
          decoration: const InputDecoration(
            hintText: 'Es: girl ipanema (cerca ENTRAMBE le parole)',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onSubmitted: (_) => _executeQuery(),
        ),
        const SizedBox(height: 8),
        const Text('Filtri (usare % per wildcard LIKE)', style: TextStyle(fontWeight: FontWeight.bold)),
        Row(
          children: [
            Expanded(child: _buildFilterField(_strumentoController, 'Strumento')),
            const SizedBox(width: 8),
            Expanded(child: _buildFilterField(_volumeController, 'Volume')),
            const SizedBox(width: 8),
            Expanded(child: _buildFilterField(_provenienzaController, 'Provenienza')),
            const SizedBox(width: 8),
            Expanded(child: _buildFilterField(_tipoMultiController, 'TipoMulti')),
          ],
        )
      ],
    );
  }

  Widget _buildFilterField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
    );
  }

  Widget _buildQueryControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            FilledButton.icon(
              onPressed: _isQueryRunning ? null : _executeQuery,
              icon: _isQueryRunning
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
                  : const Icon(Icons.search, size: 18),
              label: Text(_isQueryRunning ? 'Ricerca...' : 'Cerca Spartiti'),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.clear_all, size: 18),
              label: const Text('Pulisci Filtri'),
            ),
            const Spacer(),
            if (!_isQueryRunning && _queryResults.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green[100]!),
                ),
                child: Text('${_queryResults.length} risultati',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green,)
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_dbQueryTime != null || _uiBuildTime != null)
          Wrap(
            spacing: 12,
            children: [
              if (_dbQueryTime != null) _buildTimingChip(icon: Icons.timer, label: 'DB: ${_dbQueryTime!.inMilliseconds}ms', color: _dbQueryTime!.inMilliseconds > 500 ? Colors.orange : Colors.green),
              if (_uiBuildTime != null) _buildTimingChip(icon: Icons.dashboard, label: 'UI: ${_uiBuildTime!.inMilliseconds}ms', color: _uiBuildTime!.inMilliseconds > 100 ? Colors.orange : Colors.green),
            ],
          ),
        if (_error != null && !_isQueryRunning) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.red[100]!)),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12))),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTimingChip({required IconData icon, required String label, required Color color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildResultsSection() {
    if (_isQueryRunning) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Ricerca in corso...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (_error != null) {
        return Center(
            child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        const Text('Errore nella ricerca', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        SelectableText(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                    ],
                ),
            ),
        );
    }

    if (_queryResults.isEmpty) {
      return const Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
                Icon(Icons.search_off, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('Nessun risultato. Inizia una nuova ricerca.', style: TextStyle(fontSize: 16, color: Colors.grey)),
            ],
        ),
      );
    }

    // ========= NUOVA VISUALIZZAZIONE =========
    const Color coloreTitolo = Colors.black87;
    const Color coloreDettagliPrimari = Colors.teal;
    const Color coloreDettagliSecondari = Colors.black54;
    final Color coloreVolume = Colors.red.shade800;

    return ListView.builder(
      itemCount: _queryResults.length,
      itemBuilder: (context, index) {
        final currentRow = _queryResults[index];

        // Estrai tutti i dati necessari per la riga
        final titolo = currentRow['titolo'] as String? ?? 'N/D';
        final strumento = currentRow['strumento'] as String? ?? 'N/D';
        final volume = currentRow['volume'] as String? ?? '';
        final numPag = (currentRow['NumPag'] ?? '').toString();
        final provenienza = currentRow['ArchivioProvenienza'] as String? ?? '';
        final tipoMulti = currentRow['TipoMulti'] as String? ?? 'PDF';

        // Logica per mostrare l'header solo se il titolo cambia
        bool showTitleHeader = false;
        if (index == 0) {
          showTitleHeader = true;
        } else {
          final prevRow = _queryResults[index - 1];
          final prevTitolo = prevRow['titolo'] as String? ?? '';
          if (titolo.toUpperCase() != prevTitolo.toUpperCase()) {
            showTitleHeader = true;
          }
        }

        final Color rowBackgroundColor = index.isEven
            ? Colors.white
            : const Color(0xFFF0F4F8);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. HEADER DI GRUPPO o SEGNAPOSTO
            if (showTitleHeader)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                color: Colors.indigo[800], 
                child: Text(
                  titolo.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              )
            else
              // Segnaposto per mantenere allineamento e separazione
              const Divider(height: 1, thickness: 1, indent: 16, endIndent: 16),

            // 2. RIGA DI DETTAGLIO (cliccabile)
            InkWell(
              onTap: () => _openPdfFromRow(currentRow),
              child: Container(
                color: rowBackgroundColor,
                padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 12.0),
                child: Text.rich(
                  TextSpan(
                    style: const TextStyle(fontSize: 13.0, color: Colors.black87), 
                    children: <TextSpan>[
                      const TextSpan(text: 'Strumento: ', style: TextStyle(fontWeight: FontWeight.w500, color: coloreDettagliSecondari)),
                      TextSpan(text: strumento, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: coloreTitolo)),
                      if (numPag.isNotEmpty && numPag != 'N/D') ...[
                        const TextSpan(text: ' a Pag: ', style: TextStyle(fontWeight: FontWeight.w500, color: coloreDettagliSecondari)),
                        TextSpan(text: numPag, style: const TextStyle(fontWeight: FontWeight.normal, color: coloreDettagliPrimari)),
                      ],
                      if (volume.isNotEmpty && volume != 'N/D') ...[
                        const TextSpan(text: ' del Volume: ', style: TextStyle(fontWeight: FontWeight.w500, color: coloreDettagliSecondari)),
                        TextSpan(text: volume, style: TextStyle(fontWeight: FontWeight.bold, color: coloreVolume)),
                      ],
                      if (provenienza.isNotEmpty && provenienza != 'N/D') ...[
                        const TextSpan(text: ' Prov: ', style: TextStyle(fontWeight: FontWeight.w500, color: coloreDettagliSecondari)),
                        TextSpan(text: provenienza, style: const TextStyle(fontWeight: FontWeight.normal, fontStyle: FontStyle.italic, color: Colors.black54)),
                      ],
                      const TextSpan(text: ' Mat: ', style: TextStyle(fontWeight: FontWeight.w500, color: coloreDettagliSecondari)),
                      TextSpan(text: tipoMulti.isNotEmpty ? tipoMulti : "N/D", style: const TextStyle(fontWeight: FontWeight.normal, color: coloreDettagliPrimari)),
                    ],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
