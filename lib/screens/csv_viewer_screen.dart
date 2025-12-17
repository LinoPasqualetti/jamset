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
    // USARE L'ISTANZA databaseService
    _percorsoPdfForAppBar = databaseService.percorsoPdf;
    setState(() {});
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
    const Color coloreDettagliPrimari = Colors.teal;
    const Color coloreDettagliSecondari = Colors.black54;
    final Color coloreVolume = Colors.red.shade800;
    final Color coloreStrumento = Colors.blue.shade900;

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
                      TextSpan(text: strumento, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: coloreStrumento)),
                      if (autore.isNotEmpty && autore != 'N/D') ...[
                        const TextSpan(text: ' - ', style: TextStyle(color: coloreDettagliSecondari)),
                        TextSpan(text: autore, style: const TextStyle(fontStyle: FontStyle.italic, color: coloreDettagliSecondari)),
                      ],
                      if (numPag.isNotEmpty && numPag != 'N/D') ...[
                        const TextSpan(text: ' a Pag: ', style: TextStyle(fontWeight: FontWeight.w500, color: coloreDettagliSecondari)),
                        TextSpan(text: numPag, style: const TextStyle(fontWeight: FontWeight.normal, color: coloreDettagliPrimari)),
                      ],
                      if (volume.isNotEmpty && volume != 'N/D') ...[
                        const TextSpan(text: ' del Volume: ', style: TextStyle(fontWeight: FontWeight.w500, color: coloreDettagliSecondari)),
                        TextSpan(text: volume, style: TextStyle(fontWeight: FontWeight.normal, color: coloreVolume)),
                      ],
                      if (provenienza.isNotEmpty && provenienza != 'N/D') ...[
                        const TextSpan(text: ' Prov: ', style: TextStyle(fontWeight: FontWeight.w500, color: coloreDettagliSecondari)),
                        TextSpan(text: provenienza, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                      ],
                      const TextSpan(text: ' Mat: ', style: TextStyle(fontWeight: FontWeight.w500, color: coloreDettagliSecondari)),
                      TextSpan(text: tipoMulti.isNotEmpty ? tipoMulti : "N/D", style: const TextStyle(fontWeight: FontWeight.normal, color: coloreDettagliPrimari)),
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
}
