// lib/screens/csv_viewer_screen.dart - VERSIONE AGGIORNATA CON CORREZIONE CARTELLA CACHE
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart'; // AGGIUNTO
import 'package:livescore/main.dart';
import 'package:livescore/utils/file_opener.dart';

class CsvViewerScreen extends StatefulWidget {
  const CsvViewerScreen({super.key});

  @override
  State<CsvViewerScreen> createState() => _CsvViewerScreenState();
}

class _CsvViewerScreenState extends State<CsvViewerScreen>
    with AutomaticKeepAliveClientMixin<CsvViewerScreen> {

  final TextEditingController _cercaTitoloController = TextEditingController();
  final TextEditingController _cercaAutoreController = TextEditingController();
  final TextEditingController _cercaProvenienzaController = TextEditingController();
  final TextEditingController _cercaVolumeController = TextEditingController();
  final TextEditingController _cercaTipoMultiController = TextEditingController();
  final TextEditingController _cercaStrumentoController = TextEditingController();

  List<List<dynamic>> _csvData = [];
  List<List<dynamic>> _filteredCsvData = [];

  String _queryTitolo = '';
  String _queryAutore = '';
  String _queryProvenienza = '';
  String _queryVolume = '';
  String _queryTipoMulti = '';
  String _queryStrumento = '';

  String Laricerca = '';
  String _currentFilePath = '';

  Map<String, int> _columnIndexMap = {};
  List<String> _csvHeaders = [];
  String _percorsoPdfForAppBar = 'Caricamento...';

  List<String> _tempCsvFiles = [];
  String? _selectedTempFile;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadGlobalConfig();
    if (!kIsWeb) {
      _loadTempCsvFiles();
    }
  }

  Future<void> _loadGlobalConfig() async {
    _percorsoPdfForAppBar = databaseService.percorsoPdf;
    setState(() {});
  }

  Future<void> _loadTempCsvFiles() async {
    if (kIsWeb) return;

    try {
      // 🔥 MODIFICATO: Usa getTemporaryDirectory() invece di percorso hardcoded
      final tempDir = await getTemporaryDirectory();
      print("🔍 Cercando file CSV in: ${tempDir.path}");

      if (await tempDir.exists()) {
        final files = await tempDir.list().toList();

        _tempCsvFiles = files
            .where((entity) => entity is File &&
            (entity.path.toLowerCase().endsWith('.csv') ||
                entity.path.toLowerCase().endsWith('.txt')))
            .map((entity) => entity.path)
            .toList();

        // Ordina per data di modifica (più recenti prima)
        _tempCsvFiles.sort((a, b) {
          try {
            final fileA = File(a);
            final fileB = File(b);
            final statA = fileA.statSync();
            final statB = fileB.statSync();
            return statB.modified.compareTo(statA.modified);
          } catch (e) {
            return 0;
          }
        });

        print("✅ Trovati ${_tempCsvFiles.length} file CSV nella cache");
        for (final file in _tempCsvFiles) {
          print("   - ${p.basename(file)}");
        }

        setState(() {});
      } else {
        print("❌ La directory temporanea non esiste: ${tempDir.path}");
      }
    } catch (e) {
      print("❌ ERRORE NELLA LETTURA DELLA CARTELLA TEMP: $e");
    }
  }

  Future<void> _loadCsvFile(String filePath, {bool isTempFile = false}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      print("═══════════════════════════════════════════════════");
      print("🎯 CARICAMENTO CSV DA: $filePath");
      print("📁 File esiste? ${await File(filePath).exists()}");

      final file = File(filePath);
      if (!await file.exists()) {
        // 🔥 TENTATIVO ALTERNATIVO: Cerca nella cache
        final tempDir = await getTemporaryDirectory();
        final fileName = p.basename(filePath);
        final cachePath = p.join(tempDir.path, fileName);

        print("🔄 Tentativo percorso alternativo: $cachePath");

        if (await File(cachePath).exists()) {
          print("✅ File trovato nella cache!");
          await _loadCsvFile(cachePath, isTempFile: isTempFile);
          return;
        }

        _showSnackBar('File non trovato: ${p.basename(filePath)}');
        return;
      }

      // Leggi il file con encoding corretto
      String fileContent;
      try {
        fileContent = await file.readAsString(encoding: latin1);
      } catch (e) {
        try {
          fileContent = await file.readAsString(encoding: utf8);
        } catch (e2) {
          fileContent = await file.readAsString();
        }
      }

      // Normalizza fine riga
      fileContent = fileContent.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

      print("\n📄 ANTEPRIMA FILE:");
      final allLines = fileContent.split('\n');
      for (int i = 0; i < 3 && i < allLines.length; i++) {
        String line = allLines[i].trim();
        if (line.isNotEmpty) {
          String preview = line.length > 100 ? line.substring(0, 100) + '...' : line;
          print("Linea $i: $preview");
        }
      }

      // PARSING MANUALE
      print("\n⚙️  INIZIO PARSING MANUALE...");
      List<List<String>> allRowsFromFile = [];
      List<String> lines = fileContent.split('\n');
      int lineCount = 0;

      for (String line in lines) {
        lineCount++;
        if (line.trim().isEmpty) continue;

        // PARSING con punto e virgola come delimiter
        List<String> row = _parseCsvLine(line, ';');

        // Pulisci i campi
        for (int i = 0; i < row.length; i++) {
          row[i] = row[i].trim();
          // Rimuovi eventuali doppi apici all'inizio e alla fine
          if (row[i].startsWith('"') && row[i].endsWith('"')) {
            row[i] = row[i].substring(1, row[i].length - 1);
          }
        }

        allRowsFromFile.add(row);
      }

      print("✅ PARSING COMPLETATO: ${allRowsFromFile.length} righe totali");

      if (allRowsFromFile.isEmpty) {
        _showSnackBar('File CSV vuoto o non valido');
        _resetCsvData();
        return;
      }

      // DETECT HEADER - Logica migliorata
      bool hasHeader = false;
      List<String> potentialHeaders = allRowsFromFile[0];

      // Controlla se la prima riga sembra un header
      if (potentialHeaders.isNotEmpty) {
        int headerLikeCount = 0;
        List<String> headerIndicators = ['id', 'titolo', 'autore', 'strumento', 'volume', 'pagina', 'perc', 'tipo', 'link'];

        for (String cell in potentialHeaders) {
          String cellLower = cell.toLowerCase();
          for (String indicator in headerIndicators) {
            if (cellLower.contains(indicator)) {
              headerLikeCount++;
              break;
            }
          }
        }

        // Se almeno 2 celle sembrano header, consideralo come header
        hasHeader = headerLikeCount >= 2;
      }

      if (hasHeader) {
        print("✅ RILEVATO HEADER nella prima riga");
        _csvHeaders = potentialHeaders;
        _csvData = allRowsFromFile.length > 1
            ? allRowsFromFile.sublist(1).cast<List<dynamic>>()
            : [];
      } else {
        print("⚠️  HEADER NON RILEVATO - la prima riga contiene dati");
        // Crea header generico
        _csvHeaders = List.generate(potentialHeaders.length, (index) => 'Colonna $index');
        _csvData = allRowsFromFile.cast<List<dynamic>>();
      }

      // Crea mappa colonne
      _columnIndexMap = _createColumnIndexMap(_csvHeaders);

      _filteredCsvData = List<List<dynamic>>.from(_csvData);
      _currentFilePath = p.basename(filePath);

      // Statistiche
      print("\n📊 STATISTICHE CARICAMENTO:");
      print("File: $_currentFilePath");
      print("Colonne: ${_csvHeaders.length}");
      print("Righe dati: ${_csvData.length}");
      print("Dimensione file: ${await file.length()} bytes");

      _showSnackBar('✅ File caricato: $_currentFilePath (${_csvData.length} righe)');

      if (isTempFile) {
        _selectedTempFile = filePath;
      }

      setState(() {});

    } catch (e, stackTrace) {
      print("❌ ERRORE DURANTE IL CARICAMENTO DEL CSV: $e");
      print("Stack trace: $stackTrace");
      _showSnackBar('❌ Errore: ${e.toString().split('\n').first}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 🔥 NUOVO METODO: Carica il file CSV più recente automaticamente
  Future<void> _loadMostRecentCsv() async {
    if (kIsWeb) return;

    try {
      final tempDir = await getTemporaryDirectory();
      final files = await tempDir.list().toList();

      final csvFiles = files
          .where((entity) => entity is File &&
          entity.path.toLowerCase().endsWith('.csv'))
          .cast<File>()
          .toList();

      if (csvFiles.isEmpty) {
        print("ℹ️ Nessun file CSV trovato nella cache");
        return;
      }

      // Trova il file più recente
      csvFiles.sort((a, b) {
        final statA = a.statSync();
        final statB = b.statSync();
        return statB.modified.compareTo(statA.modified);
      });

      final mostRecentFile = csvFiles.first;
      print("🔄 Caricamento automatico del file più recente: ${mostRecentFile.path}");

      await _loadCsvFile(mostRecentFile.path, isTempFile: true);

    } catch (e) {
      print("❌ Errore nel caricamento automatico: $e");
    }
  }

  List<String> _parseCsvLine(String line, String delimiter) {
    List<String> result = [];
    StringBuffer currentField = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      String char = line[i];

      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          // Quote doppia dentro le quote: "" -> "
          currentField.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == delimiter && !inQuotes) {
        // Fine campo
        result.add(currentField.toString());
        currentField.clear();
      } else {
        currentField.write(char);
      }
    }

    // Aggiungi l'ultimo campo
    result.add(currentField.toString());

    return result;
  }

  Map<String, int> _createColumnIndexMap(List<String> headers) {
    final Map<String, int> map = {};
    for (int i = 0; i < headers.length; i++) {
      String headerFromFile = headers[i].toString().trim().toLowerCase();

      // Mappatura completa come nel vecchio codice
      const keys = {
        'idbra': 'IdBra',
        'tipomulti': 'TipoMulti',
        'tipodocu': 'TipoDocu',
        'titolo': 'Titolo',
        'autore': 'Autore',
        'strumento': 'strumento',
        'archivioprovenienza': 'ArchivioProvenienza',
        'volume': 'Volume',
        'numpag': 'NumPag',
        'numorig': 'NumOrig',
        'primolink': 'PrimoLink',
        'idvolume': 'IdVolume',
        'percradice': 'PercRadice',
        'percresto': 'PercResto'
      };

      // Controlla ogni possibile chiave
      keys.forEach((key, value) {
        if (headerFromFile.contains(key) && !map.containsKey(value)) {
          map[value] = i;
          print("  Mappato: '$headerFromFile' -> $value (colonna $i)");
        }
      });
    }

    // Debug mappa
    print("\n🗺️  MAPPA COLONNE FINALE:");
    map.forEach((key, value) {
      String headerName = value < headers.length ? headers[value] : 'N/A';
      print("  $key -> colonna $value ('$headerName')");
    });

    return map;
  }

  String _getCellValue(List<dynamic> row, String columnKey, {String defaultValue = 'N/D'}) {
    if (_columnIndexMap.containsKey(columnKey)) {
      int colIndex = _columnIndexMap[columnKey]!;
      if (colIndex < row.length && row[colIndex] != null) {
        String value = row[colIndex].toString().trim();
        return value.isNotEmpty ? value : defaultValue;
      }
    }
    return defaultValue;
  }

  void _resetCsvData() {
    _csvData = [];
    _filteredCsvData = [];
    _csvHeaders = [];
    _columnIndexMap = {};
    _currentFilePath = '';
    _selectedTempFile = null;
  }

  Future<void> _pickAndLoadCsv() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        if (kIsWeb) {
          final bytes = result.files.first.bytes!;
          String content;
          try {
            content = latin1.decode(bytes);
          } catch (e) {
            content = utf8.decode(bytes);
          }
          final fileName = result.files.first.name;
          await _processCsvContent(content, fileName);
        } else {
          final filePath = result.files.first.path!;
          await _loadCsvFile(filePath);
        }
      }
    } catch (e) {
      print("❌ ERRORE NEL FILE PICKER: $e");
      _showSnackBar('Errore nella selezione file: $e');
    }
  }

  Future<void> _processCsvContent(String fileContent, String fileName) async {
    try {
      // Normalizza
      fileContent = fileContent.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

      // PARSING manuale per consistenza
      List<List<String>> allRowsFromFile = [];
      List<String> lines = fileContent.split('\n');

      for (String line in lines) {
        if (line.trim().isEmpty) continue;
        List<String> row = _parseCsvLine(line, ';');
        allRowsFromFile.add(row);
      }

      if (allRowsFromFile.isEmpty) {
        _showSnackBar('File CSV vuoto');
        return;
      }

      // Detect header
      bool hasHeader = false;
      List<String> firstRow = allRowsFromFile[0];

      int headerLikeCount = 0;
      List<String> headerIndicators = ['id', 'titolo', 'autore', 'strumento'];
      for (String cell in firstRow) {
        String cellLower = cell.toLowerCase();
        for (String indicator in headerIndicators) {
          if (cellLower.contains(indicator)) {
            headerLikeCount++;
            break;
          }
        }
      }

      hasHeader = headerLikeCount >= 2;

      if (hasHeader) {
        _csvHeaders = firstRow;
        _csvData = allRowsFromFile.length > 1
            ? allRowsFromFile.sublist(1).cast<List<dynamic>>()
            : [];
      } else {
        _csvHeaders = List.generate(firstRow.length, (index) => 'Colonna $index');
        _csvData = allRowsFromFile.cast<List<dynamic>>();
      }

      _columnIndexMap = _createColumnIndexMap(_csvHeaders);
      _filteredCsvData = List.from(_csvData);
      _currentFilePath = fileName;

      _showSnackBar('✅ File caricato: $fileName (${_csvData.length} righe)');

      setState(() {});
    } catch (e) {
      print("❌ ERRORE PROCESSING CSV: $e");
      _showSnackBar('Errore nel processare il file');
    }
  }

  Future<void> _showTempFilesDialog() async {
    if (_tempCsvFiles.isEmpty) {
      await _loadTempCsvFiles();
      if (_tempCsvFiles.isEmpty) {
        _showSnackBar('Nessun file CSV trovato nella cartella cache');
        return;
      }
    }

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('File CSV dalla cartella Cache'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _tempCsvFiles.length,
              itemBuilder: (context, index) {
                final filePath = _tempCsvFiles[index];
                final fileName = p.basename(filePath);
                final file = File(filePath);
                String fileInfo = '';

                try {
                  final stat = file.statSync();
                  final size = stat.size;
                  final modified = stat.modified;
                  fileInfo = '${_formatBytes(size)} - ${modified.toLocal().toString().substring(0, 16)}';
                } catch (e) {
                  fileInfo = 'Dimensione non disponibile';
                }

                return Card(
                  margin: EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    title: Text(fileName, overflow: TextOverflow.ellipsis),
                    subtitle: Text(fileInfo),
                    trailing: _selectedTempFile == filePath
                        ? const Icon(Icons.check, color: Colors.green)
                        : null,
                    onTap: () async {
                      Navigator.of(context).pop();
                      await _loadCsvFile(filePath, isTempFile: true);
                    },
                  ),
                );
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Annulla'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('Aggiorna lista'),
              onPressed: () async {
                await _loadTempCsvFiles();
                if (mounted) setState(() {});
              },
            ),
            ElevatedButton(
              child: const Text('Carica più recente'),
              onPressed: () async {
                Navigator.of(context).pop();
                await _loadMostRecentCsv();
              },
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }

  @override
  void dispose() {
    _cercaTitoloController.dispose();
    _cercaAutoreController.dispose();
    _cercaProvenienzaController.dispose();
    _cercaVolumeController.dispose();
    _cercaTipoMultiController.dispose();
    _cercaStrumentoController.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  Future<void> _showAdvancedFiltersDialog() async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Filtri Avanzati'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: _cercaAutoreController,
                  decoration: const InputDecoration(labelText: 'Autore', isDense: true),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _cercaProvenienzaController,
                  decoration: const InputDecoration(labelText: 'Provenienza', isDense: true),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _cercaVolumeController,
                  decoration: const InputDecoration(labelText: 'Volume', isDense: true),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _cercaTipoMultiController,
                  decoration: const InputDecoration(labelText: 'TipoMulti', isDense: true),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _cercaStrumentoController,
                  decoration: const InputDecoration(labelText: 'Strumento', isDense: true),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Annulla'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('Applica'),
              onPressed: () {
                setState(() {
                  _queryAutore = _cercaAutoreController.text.toLowerCase();
                  _queryProvenienza = _cercaProvenienzaController.text.toLowerCase();
                  _queryVolume = _cercaVolumeController.text.toLowerCase();
                  _queryTipoMulti = _cercaTipoMultiController.text.toLowerCase();
                  _queryStrumento = _cercaStrumentoController.text.toLowerCase();
                });
                _filterData();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _openFileFromRow(Map<String, dynamic> rowData) async {
    final volume = rowData['Volume'] as String? ?? '';
    final numPag = rowData['NumPag'] as String? ?? '';
    final percResto = rowData['PercResto'] as String? ?? '';
    final tipoMulti = rowData['TipoMulti'] as String? ?? 'PDF';

    final page = int.tryParse(numPag) ?? 1;

    await FileOpener.openFile(
      context: context,
      percResto: percResto,
      volume: volume,
      tipoMulti: tipoMulti,
      page: page,
    );
  }

  Widget _buildCsvList() {
    const Color coloreDettagliPrimari = Colors.teal;
    const Color coloreDettagliSecondari = Colors.black54;
    final Color coloreVolume = Colors.red.shade800;
    final Color coloreStrumento = Colors.blue.shade900;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView.builder(
      itemCount: _filteredCsvData.length,
      itemBuilder: (context, index) {
        final currentRow = _filteredCsvData[index];

        final titolo = _getCellValue(currentRow, 'Titolo');
        final strumento = _getCellValue(currentRow, 'strumento');
        final autore = _getCellValue(currentRow, 'Autore', defaultValue: '');
        final volume = _getCellValue(currentRow, 'Volume');
        final numPag = _getCellValue(currentRow, 'NumPag');
        final provenienza = _getCellValue(currentRow, 'ArchivioProvenienza');
        final tipoMulti = _getCellValue(currentRow, 'TipoMulti', defaultValue: 'PDF');
        final percResto = _getCellValue(currentRow, 'PercResto');

        // Determina se mostrare l'header del titolo (raggruppamento)
        bool showTitleHeader = false;
        if (index == 0) {
          showTitleHeader = true;
        } else {
          final prevRow = _filteredCsvData[index - 1];
          final prevTitolo = _getCellValue(prevRow, 'Titolo');
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
            if (showTitleHeader)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                color: Colors.indigo,
                child: Text(
                  titolo.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            InkWell(
              onTap: () {
                Map<String, dynamic> rowData = {
                  'Volume': volume,
                  'NumPag': numPag,
                  'PercResto': percResto,
                  'TipoMulti': tipoMulti,
                };
                _openFileFromRow(rowData);
              },
              child: Container(
                color: rowBackgroundColor,
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Text.rich(
                  TextSpan(
                    style: const TextStyle(fontSize: 12.0),
                    children: <TextSpan>[
                      TextSpan(
                          text: strumento,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: coloreStrumento
                          )
                      ),
                      if (autore.isNotEmpty && autore != 'N/D') ...[
                        const TextSpan(
                            text: ' - ',
                            style: TextStyle(color: coloreDettagliSecondari)
                        ),
                        TextSpan(
                            text: autore,
                            style: const TextStyle(
                                fontStyle: FontStyle.italic,
                                color: coloreDettagliSecondari
                            )
                        ),
                      ],
                      if (numPag.isNotEmpty && numPag != 'N/D') ...[
                        const TextSpan(
                            text: ' a Pag: ',
                            style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: coloreDettagliSecondari
                            )
                        ),
                        TextSpan(
                            text: numPag,
                            style: const TextStyle(
                                fontWeight: FontWeight.normal,
                                color: coloreDettagliPrimari
                            )
                        ),
                      ],
                      if (volume.isNotEmpty && volume != 'N/D') ...[
                        const TextSpan(
                            text: ' del Volume: ',
                            style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: coloreDettagliSecondari
                            )
                        ),
                        TextSpan(
                            text: volume,
                            style: TextStyle(
                                fontWeight: FontWeight.normal,
                                color: coloreVolume
                            )
                        ),
                      ],
                      if (provenienza.isNotEmpty && provenienza != 'N/D') ...[
                        const TextSpan(
                            text: ' Prov: ',
                            style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: coloreDettagliSecondari
                            )
                        ),
                        TextSpan(
                            text: provenienza,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.black87
                            )
                        ),
                      ],
                      const TextSpan(
                          text: ' Mat: ',
                          style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: coloreDettagliSecondari
                          )
                      ),
                      TextSpan(
                          text: tipoMulti.isNotEmpty ? tipoMulti : "N/D",
                          style: const TextStyle(
                              fontWeight: FontWeight.normal,
                              color: coloreDettagliPrimari
                          )
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1, thickness: 1.0, color: Colors.black12),
          ],
        );
      },
    );
  }

  void _filterData() {
    setState(() {
      if (_queryTitolo.isEmpty && _queryAutore.isEmpty && _queryProvenienza.isEmpty &&
          _queryVolume.isEmpty && _queryTipoMulti.isEmpty && _queryStrumento.isEmpty) {
        _filteredCsvData = List.from(_csvData);
      } else {
        _filteredCsvData = _csvData.where((row) {
          final titolo = _getCellValue(row, 'Titolo', defaultValue: '').toLowerCase();
          final autore = _getCellValue(row, 'Autore', defaultValue: '').toLowerCase();
          final provenienza = _getCellValue(row, 'ArchivioProvenienza', defaultValue: '').toLowerCase();
          final volume = _getCellValue(row, 'Volume', defaultValue: '').toLowerCase();
          final tipoMulti = _getCellValue(row, 'TipoMulti', defaultValue: '').toLowerCase();
          final strumento = _getCellValue(row, 'strumento', defaultValue: '').toLowerCase();

          return (_queryTitolo.isEmpty || titolo.contains(_queryTitolo)) &&
              (_queryAutore.isEmpty || autore.contains(_queryAutore)) &&
              (_queryProvenienza.isEmpty || provenienza.contains(_queryProvenienza)) &&
              (_queryVolume.isEmpty || volume.contains(_queryVolume)) &&
              (_queryTipoMulti.isEmpty || tipoMulti.contains(_queryTipoMulti)) &&
              (_queryStrumento.isEmpty || strumento.contains(_queryStrumento));
        }).toList();
      }
    });
  }

  void _clearAllData() {
    setState(() {
      _csvData = [];
      _filteredCsvData = [];
      _csvHeaders = [];
      _columnIndexMap = {};
      _currentFilePath = '';
      _selectedTempFile = null;

      _cercaTitoloController.clear();
      _cercaAutoreController.clear();
      _cercaProvenienzaController.clear();
      _cercaVolumeController.clear();
      _cercaTipoMultiController.clear();
      _cercaStrumentoController.clear();

      _queryTitolo = '';
      _queryAutore = '';
      _queryProvenienza = '';
      _queryVolume = '';
      _queryTipoMulti = '';
      _queryStrumento = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              'CSV Viewer - Cartella: $_percorsoPdfForAppBar',
              style: const TextStyle(fontSize: 12),
              maxLines: 1,
            ),
            if (_currentFilePath.isNotEmpty)
              SelectableText(
                'File: $_currentFilePath (${_csvData.length} righe)',
                style: const TextStyle(fontSize: 10, color: Colors.white70),
                maxLines: 1,
              ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110.0),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _cercaTitoloController,
                        decoration: const InputDecoration(labelText: 'Titolo', isDense: true),
                        onSubmitted: (_) {
                          setState(() { _queryTitolo = _cercaTitoloController.text.toLowerCase(); });
                          _filterData();
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.filter_list_alt, color: Colors.blue),
                      tooltip: 'Filtri Avanzati',
                      onPressed: _showAdvancedFiltersDialog,
                    ),
                  ],
                ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.search),
                    label: const Text('Filtra'),
                    onPressed: () {
                      setState(() {
                        _queryTitolo = _cercaTitoloController.text.toLowerCase();
                        _queryAutore = _cercaAutoreController.text.toLowerCase();
                        _queryProvenienza = _cercaProvenienzaController.text.toLowerCase();
                        _queryVolume = _cercaVolumeController.text.toLowerCase();
                        _queryTipoMulti = _cercaTipoMultiController.text.toLowerCase();
                        _queryStrumento = _cercaStrumentoController.text.toLowerCase();
                      });
                      if (_queryTitolo.isEmpty && _queryAutore.isEmpty && _queryProvenienza.isEmpty
                          && _queryVolume.isEmpty && _queryTipoMulti.isEmpty && _queryStrumento.isEmpty)
                      {
                        Laricerca = '';
                      } else {
                        Laricerca = "Filtro:";
                        if (_queryTitolo.isNotEmpty) Laricerca += " Titolo ";
                        if (_queryAutore.isNotEmpty) Laricerca += " Autore ";
                        if (_queryProvenienza.isNotEmpty) Laricerca += " Provenienza ";
                        if (_queryVolume.isNotEmpty) Laricerca += " Volume ";
                        if (_queryTipoMulti.isNotEmpty) Laricerca += " TipoMulti ";
                        if (_queryStrumento.isNotEmpty) Laricerca += " Strumento ";
                      }
                      _filterData();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _csvData.isEmpty ? _buildEmptyState() : _buildCsvList(),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!kIsWeb)
            FloatingActionButton.small(
              onPressed: _showTempFilesDialog,
              heroTag: 'temp_files',
              child: const Icon(Icons.folder_open),
              tooltip: 'File dalla cartella Cache',
            ),
          const SizedBox(height: 8),
          FloatingActionButton(
            onPressed: _pickAndLoadCsv,
            heroTag: 'pick_file',
            child: const Icon(Icons.file_upload),
            tooltip: 'Carica file CSV',
          ),
          if (_csvData.isNotEmpty) ...[
            const SizedBox(height: 8),
            FloatingActionButton.small(
              onPressed: _clearAllData,
              heroTag: 'clear_data',
              backgroundColor: Colors.red,
              child: const Icon(Icons.clear),
              tooltip: 'Pulisci tutto',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.insert_drive_file, size: 64, color: Colors.grey),
            const SizedBox(height: 20),
            const Text(
              'Nessun file CSV caricato',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Carica un file CSV per iniziare',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 30),
            if (!kIsWeb) ...[
              ElevatedButton.icon(
                icon: const Icon(Icons.folder_open),
                label: const Text('Carica dalla cartella Cache'),
                onPressed: _showTempFilesDialog,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(250, 50),
                ),
              ),
              const SizedBox(height: 15),
              ElevatedButton.icon(
                icon: const Icon(Icons.autorenew),
                label: const Text('Carica automaticamente più recente'),
                onPressed: _loadMostRecentCsv,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(250, 50),
                  backgroundColor: Colors.green,
                ),
              ),
              const SizedBox(height: 15),
            ],
            ElevatedButton.icon(
              icon: const Icon(Icons.file_upload),
              label: const Text('Seleziona file CSV'),
              onPressed: _pickAndLoadCsv,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(250, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}