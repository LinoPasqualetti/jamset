// lib/screens/funzioni_variazione_dati_screen.dart - VERSIONE CORRETTA
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

    // Lista di operatori FTS che l'utente potrebbe usare intenzionalmente
    final ftsOperators = [' OR ', ' AND ', ' NOT ', ' NEAR(', '*', '"', '(', ')', '-'];

    // Controlla se l'utente sta usando operatori avanzati
    final hasAdvancedOperators = ftsOperators.any((op) => text.contains(op));

    if (hasAdvancedOperators) {
      // L'utente sa cosa sta facendo, lascia il testo com'è
      debugPrint('🔧 Ricerca avanzata rilevata, testo lasciato invariato');
      return text;
    }

    // Splitta in parole, filtra vuoti e pulisci
    final words = text.split(' ')
        .where((word) => word.trim().isNotEmpty)
        .map((word) => word.trim())
        .toList();

    if (words.isEmpty) return '';

    // Se è una singola parola, aggiungi wildcard finale se non c'è già
    if (words.length == 1) {
      final word = words[0];
      // Aggiungi wildcard finale se:
      // 1. La parola ha almeno 3 caratteri
      // 2. Non termina già con wildcard
      // 3. Non contiene altri operatori speciali
      if (word.length >= 3 &&
          !word.endsWith('*') &&
          !word.contains('"') &&
          !word.contains('(') &&
          !word.contains(')')) {
        return '$word*';
      }
      return word;
    }

    // Per più parole: unisci con AND e aggiungi wildcard alle parole lunghe
    final processedWords = words.map((word) {
      // Aggiungi wildcard finale alle parole con almeno 3 caratteri
      if (word.length >= 3 &&
          !word.endsWith('*') &&
          !word.contains('"')) {
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

      // 1. RICERCA FTS CON AND SU TUTTE LE PAROLE
      if (_ricercaController.text.isNotEmpty) {
        final ftsQuery = _buildFtsQuery(_ricercaController.text);

        whereClauses.add('a.id_univoco_globale IN (SELECT rowid FROM spartiti_fts WHERE spartiti_fts MATCH ?)');
        whereArgs.add(ftsQuery);
      }

      // 2. FILTRI LIKE
      if (_tipoMultiController.text.isNotEmpty) {
        whereClauses.add('a.tipoMulti LIKE ?');
        whereArgs.add(_tipoMultiController.text);
      }
      if (_volumeController.text.isNotEmpty) {
        whereClauses.add('a.volume LIKE ?');
        whereArgs.add(_volumeController.text);
      }
      if (_provenienzaController.text.isNotEmpty) {
        whereClauses.add('a.ArchivioProvenienza LIKE ?');
        whereArgs.add(_provenienzaController.text);
      }
      if (_strumentoController.text.isNotEmpty) {
        whereClauses.add('a.strumento LIKE ?');
        whereArgs.add(_strumentoController.text);
      }

      // 3. COSTRUISCI QUERY FINALE
      String whereStatement = whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';

      final sanitizedPercorsoPdf = gPercorsoPdf.replaceAll("'", "''");

      final sql = """
        SELECT DISTINCT 
          a.titolo,
          a.NumPag,
          a.volume,
          a.ArchivioProvenienza,
          a.strumento,
          a.autore,
          a.PrimoLink,
          a.PercResto,
          a.TipoMulti,
          a.id_univoco_globale,
          '$sanitizedPercorsoPdf' as percradice,
          '$sanitizedPercorsoPdf' || COALESCE(a.PercResto, '') || '/' || a.Volume as PerApertura
        FROM spartiti a
        $whereStatement
        AND (a.TipoMulti IS NULL OR a.TipoMulti LIKE 'PDF%' OR a.TipoMulti LIKE 'PD%')
        ORDER BY a.titolo COLLATE NOCASE, a.strumento
        LIMIT 100
      """;

      // DEBUG DETTAGLIATO
      debugPrint("\n" + "="*80);
      debugPrint("🔍 RICERCA ESEGUITA:");
      debugPrint("="*80);
      debugPrint("Testo ricerca: ${_ricercaController.text}");
      debugPrint("Query FTS generata: ${whereArgs.isNotEmpty ? whereArgs[0] : 'Nessuna'}");
      debugPrint("SQL completo: $sql");
      debugPrint("="*80);

      final dbStopwatch = Stopwatch()..start();
      final results = await dbCatalogoAttivo!.rawQuery(sql, whereArgs);
      dbStopwatch.stop();

      // Normalizza percorsi per il display
      final normalizedResults = results.map((row) {
        final newRow = Map<String, dynamic>.from(row);

        // Normalizza PercResto
        if (newRow.containsKey('PercResto') && newRow['PercResto'] != null) {
          newRow['PercResto'] = _normalizePath(newRow['PercResto'] as String);
        }

        // Normalizza PerApertura
        if (newRow.containsKey('PerApertura') && newRow['PerApertura'] != null) {
          newRow['PerApertura'] = _normalizePath(newRow['PerApertura'] as String);
        }

        return newRow;
      }).toList();

      if (mounted) {
        final uiStopwatch = Stopwatch()..start();
        setState(() {
          _queryResults = normalizedResults;
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

      // Usa PerApertura se disponibile
      String? filePath = lowerCaseRowData['perapertura'] as String?;
      final pageNum = lowerCaseRowData['numpag'];

      if (filePath == null || filePath.isEmpty) {
        // Fallback: costruisci da componenti
        final percResto = lowerCaseRowData['percresto'] as String? ?? '';
        final volume = lowerCaseRowData['volume'] as String? ?? '';

        if (volume.isEmpty) {
          _showError('Volume non specificato');
          return;
        }

        filePath = _buildPdfPath(gPercorsoPdf, percResto, volume);
      }

      final page = int.tryParse(pageNum?.toString().trim() ?? '1') ?? 1;

      debugPrint('📂 Apertura PDF:');
      debugPrint('   Percorso: $filePath');
      debugPrint('   Pagina: $page');

      await OpenerPlatformInterface.instance.openPdf(
        context: context,
        filePath: filePath,
        page: page,
      );

    } catch (e) {
      debugPrint('❌ Errore apertura PDF: $e');
      _showError('Impossibile aprire il PDF: ${e.toString()}');
    }
  }

  String _buildPdfPath(String basePath, String percResto, String volume) {
    // Normalizza percorsi
    String cleanBase = _normalizePath(basePath);
    String cleanResto = _normalizePath(percResto);
    String cleanVolume = volume.trim();

    // Costruisci con separatori corretti
    if (Platform.isWindows) {
      return '$cleanBase\\$cleanResto\\$cleanVolume'
          .replaceAll(r'\\', r'\')
          .replaceAll('//', r'\');
    } else {
      return '$cleanBase/$cleanResto/$cleanVolume'
          .replaceAll(r'\', '/')
          .replaceAll('//', '/');
    }
  }

  String _normalizePath(String path) {
    String normalized = path.trim();

    if (Platform.isWindows) {
      normalized = normalized.replaceAll('/', r'\');
      // Rimuovi backslash iniziali/finali
      while (normalized.startsWith(r'\')) {
        normalized = normalized.substring(1);
      }
      while (normalized.endsWith(r'\')) {
        normalized = normalized.substring(0, normalized.length - 1);
      }
    } else {
      normalized = normalized.replaceAll(r'\', '/');
      // Rimuovi slash iniziali/finali
      while (normalized.startsWith('/')) {
        normalized = normalized.substring(1);
      }
      while (normalized.endsWith('/')) {
        normalized = normalized.substring(0, normalized.length - 1);
      }
    }

    return normalized;
  }

  void _showError(String message) {
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

  // ================================================
  // UI COMPONENTS
  // ================================================

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
            // Pulsante ricerca principale
            FilledButton.icon(
              onPressed: _isQueryRunning ? null : _executeQuery,
              icon: _isQueryRunning
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.search, size: 18),
              label: Text(_isQueryRunning ? 'Ricerca...' : 'Cerca Spartiti'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
              ),
            ),

            const SizedBox(width: 12),

            // Pulsante pulisci
            OutlinedButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.clear_all, size: 18),
              label: const Text('Pulisci Filtri'),
            ),

            const Spacer(),

            // Contatore risultati
            if (!_isQueryRunning && _queryResults.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green[100]!),
                ),
                child: Text(
                  '${_queryResults.length} risultati',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 8),

        // Timing info
        if (_dbQueryTime != null || _uiBuildTime != null)
          Wrap(
            spacing: 12,
            children: [
              if (_dbQueryTime != null)
                _buildTimingChip(
                  icon: Icons.timer,
                  label: 'DB: ${_dbQueryTime!.inMilliseconds}ms',
                  color: _dbQueryTime!.inMilliseconds > 500 ? Colors.orange : Colors.green,
                ),
              if (_uiBuildTime != null)
                _buildTimingChip(
                  icon: Icons.dashboard,
                  label: 'UI: ${_uiBuildTime!.inMilliseconds}ms',
                  color: _uiBuildTime!.inMilliseconds > 100 ? Colors.orange : Colors.green,
                ),
            ],
          ),

        // Messaggio errore
        if (_error != null && !_isQueryRunning) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.red[100]!),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
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
        Text(
          label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
        ),
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

    if (_error != null && _queryResults.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              SelectableText(
                _error!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _executeQuery,
                icon: const Icon(Icons.refresh),
                label: const Text('Riprova Ricerca'),
              ),
            ],
          ),
        ),
      );
    }

    if (_queryResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              _ricercaController.text.isEmpty
                  ? 'Inserisci un termine di ricerca'
                  : 'Nessun risultato trovato',
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Prova con criteri diversi o usa wildcard (%)',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Colonne da mostrare (priorità)
    final preferredColumns = ['titolo', 'strumento', 'volume', 'ArchivioProvenienza', 'NumPag'];
    final availableColumns = _queryResults.first.keys
        .where((key) => preferredColumns.contains(key.toLowerCase()))
        .toList();

    // Se mancano colonne preferite, aggiungi altre disponibili
    if (availableColumns.length < 3) {
      availableColumns.addAll(
          _queryResults.first.keys
              .where((key) => !availableColumns.contains(key))
              .take(3 - availableColumns.length)
      );
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: DataTable2(
          columnSpacing: 12,
          horizontalMargin: 12,
          minWidth: 1000,
          showCheckboxColumn: false,
          sortAscending: true,
          columns: availableColumns.map((key) {
            return DataColumn2(
              label: Text(
                _formatColumnName(key),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
              size: _getColumnSize(key),
            );
          }).toList(),

          rows: _queryResults.map((row) {
            return DataRow2(
              onTap: () => _openPdfFromRow(row),
              color: WidgetStateProperty.resolveWith<Color?>((states) {
                if (states.contains(WidgetState.hovered)) {
                  return Colors.blue[50];
                }
                return null;
              }),
              cells: availableColumns.map((column) {
                final value = row[column]?.toString() ?? '';
                final isPage = column.toLowerCase() == 'numpag';
                final isTitle = column.toLowerCase() == 'titolo';

                return DataCell(
                  Tooltip(
                    message: value,
                    child: SelectableText(
                      value.length > 30 ? '${value.substring(0, 30)}...' : value,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isTitle ? FontWeight.w500 : FontWeight.normal,
                        color: isPage ? Colors.green[700] : null,
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          }).toList(),
        ),
      ),
    );
  }

  String _formatColumnName(String column) {
    final names = {
      'titolo': 'Titolo',
      'strumento': 'Strumento',
      'volume': 'Volume',
      'archivioprovenienza': 'Provenienza',
      'numpag': 'Pagina',
      'autore': 'Autore',
      'percresto': 'Percorso',
      'perapertura': 'File PDF',
      'tipoMulti': 'Tipo',
    };
    return names[column.toLowerCase()] ?? column;
  }

  ColumnSize _getColumnSize(String column) {
    switch (column.toLowerCase()) {
      case 'titolo': return ColumnSize.L;
      case 'perapertura': return ColumnSize.L;
      case 'volume': case 'archivioprovenienza': return ColumnSize.M;
      case 'strumento': case 'numpag': case 'tipoMulti': return ColumnSize.S;
      default: return ColumnSize.M;
    }
  }
}