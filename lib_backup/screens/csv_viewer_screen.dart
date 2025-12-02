// lib/screens/csv_viewer_screen.dart - VERSIONE CORRETTA E COMPLETA
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:jamsetgemini/main.dart';
import 'package:jamsetgemini/platform/opener_platform_interface.dart';
import 'package:jamsetgemini/utils/file_opener.dart';

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

  Map<String, int> _columnIndexMap = {};
  List<String> _csvHeaders = [];
  String _percorsoPdfForAppBar = 'Caricamento...';

  @override
  void initState() {
    super.initState();
    _loadGlobalConfig();
  }

  Future<void> _loadGlobalConfig() async {
    if (dbGlobale != null) {
      try {
        final configData = await dbGlobale!.query('DatiSistremaApp', columns: ['PercorsoPdf'], limit: 1);
        if (mounted && configData.isNotEmpty) {
          setState(() {
            _percorsoPdfForAppBar = configData.first['PercorsoPdf'] as String? ?? 'Non impostato';
          });
        }
      } catch (e) {
        if (mounted) setState(() => _percorsoPdfForAppBar = 'Errore');
      }
    } else {
      if (mounted) setState(() => _percorsoPdfForAppBar = 'DB non disp.');
    }
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
                TextField(controller: _cercaAutoreController, decoration: const InputDecoration(labelText: 'Autore', isDense: true)),
                const SizedBox(height: 8),
                TextField(controller: _cercaProvenienzaController, decoration: const InputDecoration(labelText: 'Provenienza', isDense: true)),
                const SizedBox(height: 8),
                TextField(controller: _cercaVolumeController, decoration: const InputDecoration(labelText: 'Volume', isDense: true)),
                const SizedBox(height: 8),
                TextField(controller: _cercaTipoMultiController, decoration: const InputDecoration(labelText: 'TipoMulti', isDense: true)),
                const SizedBox(height: 8),
                TextField(controller: _cercaStrumentoController, decoration: const InputDecoration(labelText: 'Strumento', isDense: true)),
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

  /// ================================================
  /// FUNZIONE PER COSTRUIRE PERCORSI PDF CORRETTI
  /// ================================================
  String _buildCorrectPdfPath(String basePath, String percResto, String volume) {
    // Debug iniziale
    print('🔧 _buildCorrectPdfPath chiamata:');
    print('   Base: "$basePath"');
    print('   PercResto: "$percResto"');
    print('   Volume: "$volume"');
    print('   Piattaforma: ${Platform.operatingSystem}');

    // Normalizza i percorsi
    String cleanBase = basePath.trim();
    String cleanResto = percResto.trim();
    String cleanVolume = volume.trim();

    // CASO 1: SU WINDOWS
    if (Platform.isWindows) {
      // Normalizza separatori Windows
      cleanBase = cleanBase.replaceAll('/', r'\');
      cleanResto = cleanResto.replaceAll('/', r'\');

      // Rimuovi slash finale da base se presente
      if (cleanBase.endsWith(r'\')) {
        cleanBase = cleanBase.substring(0, cleanBase.length - 1);
        print('   Windows: rimosso \\ finale da base');
      }

      // Rimuovi slash iniziale da resto se presente
      if (cleanResto.startsWith(r'\')) {
        cleanResto = cleanResto.substring(1);
        print('   Windows: rimosso \\ iniziale da percResto');
      }

      // Costruisci il percorso Windows-style
      final result = '$cleanBase\\$cleanResto\\$cleanVolume';
      print('   Windows risultato: "$result"');
      return result;
    }
    // CASO 2: SU ANDROID/IOS/LINUX/MAC
    else {
      // Normalizza separatori Unix
      cleanBase = cleanBase.replaceAll(r'\', '/');
      cleanResto = cleanResto.replaceAll(r'\', '/');

      // Rimuovi slash finale da base se presente
      if (cleanBase.endsWith('/')) {
        cleanBase = cleanBase.substring(0, cleanBase.length - 1);
        print('   Unix: rimosso / finale da base');
      }

      // Rimuovi slash iniziale da resto se presente
      if (cleanResto.startsWith('/')) {
        cleanResto = cleanResto.substring(1);
        print('   Unix: rimosso / iniziale da percResto');
      }

      // Costruisci il percorso Unix-style
      final result = '$cleanBase/$cleanResto/$cleanVolume';
      print('   Unix risultato: "$result"');
      return result;
    }
  }

  /// Funzione alternativa che usa path.join ma normalizza prima
  String _buildPdfPathWithJoin(String basePath, String percResto, String volume) {
    print('🔧 _buildPdfPathWithJoin:');

    // Normalizza separatori
    String normalizedBase = basePath.trim();
    String normalizedResto = percResto.trim();

    // Sostituisci doppi separatori
    normalizedBase = normalizedBase.replaceAll(r'\\', r'\').replaceAll('//', '/');
    normalizedResto = normalizedResto.replaceAll(r'\\', r'\').replaceAll('//', '/');

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
    final result = p.join(normalizedBase, normalizedResto, volume);
    print('   Result with join: "$result"');
    return result;
  }

  void _openFileFromRow(Map<String, dynamic> rowData) async {
    final volume = rowData['Volume'] as String? ?? '';
    final numPag = rowData['NumPag'] as String? ?? '';
    final percResto = rowData['PercResto'] as String? ?? '';
    final tipoMulti = rowData['TipoMulti'] as String? ?? 'PDF';

    final page = int.tryParse(numPag) ?? 1;

    // CORREZIONE: Non assegnare il risultato a una variabile se è void
    await FileOpener.openFile(
      context: context,
      percResto: percResto,
      volume: volume,
      tipoMulti: tipoMulti,
      page: page,
    );
  }

  void _handleOpenPdfAction({
    required String volume,
    required String numPag,
    required String percResto,
    required String tipoMulti,
  }) async {
    final page = int.tryParse(numPag) ?? 1;

    // CORREZIONE: Non restituire valori da questa funzione
    await FileOpener.openFile(
      context: context,
      percResto: percResto,
      volume: volume,
      tipoMulti: tipoMulti,
      page: page,
    );
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  String _getCellValue(List<dynamic> row, String columnKey, {String defaultValue = 'N/D'}) {
    if (_columnIndexMap.containsKey(columnKey)) {
      int? colIndex = _columnIndexMap[columnKey];
      if (colIndex != null && colIndex < row.length && row[colIndex] != null) {
        return row[colIndex].toString();
      }
    }
    return defaultValue;
  }

  Map<String, int> _createColumnIndexMap(List<String> headers) {
    final Map<String, int> map = {};
    for (int i = 0; i < headers.length; i++) {
      String headerFromFile = headers[i].toString().trim().toLowerCase();
      const keys = {
        'idbra': 'IdBra', 'tipomulti': 'TipoMulti', 'tipodocu': 'TipoDocu',
        'titolo': 'Titolo', 'autore': 'Autore', 'strumento': 'strumento',
        'archivioprovenienza': 'ArchivioProvenienza', 'volume': 'Volume',
        'numpag': 'NumPag', 'numorig': 'NumOrig', 'primolink': 'PrimoLink',
        'idvolume': 'IdVolume', 'percradice': 'PercRadice', 'percresto': 'PercResto'
      };
      if (keys.containsKey(headerFromFile)) {
        map[keys[headerFromFile]!] = i;
      }
    }
    return map;
  }

  Future<void> _pickAndLoadCsv() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null) {
        String fileContent;
        if (kIsWeb) {
          final bytes = result.files.single.bytes!;
          fileContent = utf8.decode(bytes, allowMalformed: true);
        } else {
          final file = File(result.files.single.path!);
          try {
            fileContent = await file.readAsString(encoding: utf8);
          } on FileSystemException {
            fileContent = await file.readAsString(encoding: latin1);
          }
        }

        String delimiter = ';';
        if (fileContent.isNotEmpty) {
          final firstLine = fileContent.split('\n')[0];
          if (','.allMatches(firstLine).length > ';'.allMatches(firstLine).length) {
            delimiter = ',';
          }
        }

        final allRowsFromFile = CsvToListConverter(fieldDelimiter: delimiter).convert(fileContent);

        if (allRowsFromFile.isEmpty) {
          _csvData = [];
          _filteredCsvData = [];
        } else {
          _csvHeaders = allRowsFromFile[0].map((h) => h.toString()).toList();
          _columnIndexMap = _createColumnIndexMap(_csvHeaders);
          _csvData = allRowsFromFile.length > 1 ? allRowsFromFile.sublist(1) : [];
          _filteredCsvData = List<List<dynamic>>.from(_csvData);
        }
        setState(() {});
      }
    } catch (e) {
      print("ERRORE DURANTE IL CARICAMENTO DEL CSV: $e");
      _showErrorSnackBar('Errore nel caricamento CSV: ${e.toString()}');
    }
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: SelectableText(
          'CSV Viewer - Cartella: $_percorsoPdfForAppBar',
          style: const TextStyle(fontSize: 14),
          maxLines: 2,
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
                        print('Nessun filtro applicato.');
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickAndLoadCsv,
        label: const Text('Carica CSV'),
        icon: const Icon(Icons.file_upload),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Carica un file CSV per iniziare'),
          ElevatedButton.icon(
            icon: const Icon(Icons.upload_file),
            label: const Text('Carica CSV'),
            onPressed: _pickAndLoadCsv,
          ),
          const SizedBox(height: 20),
          Text(
            'Configurazione attuale:',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          SelectableText(
            'Percorso PDF: ${gPercorsoPdf.isNotEmpty ? gPercorsoPdf : "NON CONFIGURATO"}',
            style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
          ),
          SelectableText(
            'Piattaforma: ${Platform.operatingSystem}',
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildCsvList() {
    return Container(
      color: Colors.grey[100],
      child: ListView.builder(
        itemCount: _filteredCsvData.length,
        itemBuilder: (context, index) {
          final currentRow = _filteredCsvData[index];

          final titolo = _getCellValue(currentRow, 'Titolo');
          final strumento = _getCellValue(currentRow, 'strumento');
          final volume = _getCellValue(currentRow, 'Volume');
          final numPag = _getCellValue(currentRow, 'NumPag');
          final provenienza = _getCellValue(currentRow, 'ArchivioProvenienza');
          final tipoMulti = _getCellValue(currentRow, 'TipoMulti', defaultValue: 'PDF');
          final percResto = _getCellValue(currentRow, 'PercResto');
          final autore = _getCellValue(currentRow, 'Autore');

          // Controlla se mostrare l'header del titolo (gruppo)
          bool showTitleHeader = index == 0;
          if (index > 0) {
            final prevRow = _filteredCsvData[index - 1];
            final prevTitolo = _getCellValue(prevRow, 'Titolo');
            showTitleHeader = titolo != prevTitolo;
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header del titolo (se cambiato)
              if (showTitleHeader)
                Container(
                  padding: const EdgeInsets.all(12.0),
                  color: Colors.blueGrey[50],
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          titolo,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.blueGrey,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (autore.isNotEmpty && autore != 'N/D')
                        Text(
                          '($autore)',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),

              // Tile principale
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                elevation: 2,
                child: ListTile(
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Strumento: $strumento',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text('Volume: $volume • Pagina: $numPag'),
                      Text('Provenienza: $provenienza'),
                      Text('Tipo: $tipoMulti'),
                    ],
                  ),
                  subtitle: percResto.isNotEmpty && percResto != 'N/D'
                      ? Text(
                    'Percorso: $percResto',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontFamily: 'monospace',
                    ),
                  )
                      : null,
                  trailing: IconButton(
                    icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                    tooltip: 'Apri File',
                    onPressed: () {
                      _handleOpenPdfAction(
                        volume: volume,
                        numPag: numPag,
                        percResto: percResto,
                        tipoMulti: tipoMulti,
                      );
                    },
                  ),
                  onTap: () {
                    // Creare mappa dei dati per _openFileFromRow
                    Map<String, dynamic> rowData = {
                      'Volume': volume,
                      'NumPag': numPag,
                      'PercResto': percResto,
                      'TipoMulti': tipoMulti,
                      'strumento': strumento,
                      'Titolo': titolo,
                      'Autore': autore,
                      'ArchivioProvenienza': provenienza,
                    };
                    _openFileFromRow(rowData);
                  },
                ),
              ),

              // Divisore tra gli item (opzionale)
              const Divider(height: 1, thickness: 0.5),
            ],
          );
        },
      ),
    );
  }
}