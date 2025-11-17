// lib/screens/csv_viewer_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:jamset/file_path_validator.dart';
import 'package:jamset/main.dart'; // <-- IMPORT PER VARIABILI GLOBALI
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:jamset/platform/opener_platform_interface.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

class CsvViewerScreen extends StatefulWidget {
  const CsvViewerScreen({super.key});

  @override
  State<CsvViewerScreen> createState() => _CsvViewerScreenState();
}

class _CsvViewerScreenState extends State<CsvViewerScreen>
  with AutomaticKeepAliveClientMixin<CsvViewerScreen> {

  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  String _lastWords = '';

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

  String Laricerca ='';

  Map<String, int> _columnIndexMap = {};
  List<String> _csvHeaders = [];

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _requestStoragePermission();
  }

  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
  }

  void _startListening() async {
    await _speechToText.listen(
      onResult: (result) => _onSpeechResult(result.recognizedWords),
      localeId: 'it_IT',
    );
    setState(() {});
  }

  void _stopListening() async {
    await _speechToText.stop();
    setState(() {});
  }

  void _onSpeechResult(String result) {
    setState(() {
      _lastWords = result;
      _cercaTitoloController.text = _lastWords;
    });
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

  Future<void> _requestStoragePermission() async {
    if (kIsWeb || !Platform.isAndroid) return;
    var status = await Permission.manageExternalStorage.status;
    if (!status.isGranted) {
      status = await Permission.manageExternalStorage.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Per funzionare, l\'app necessita dell\'accesso a tutti i file.')),
          );
        }
        await openAppSettings();
      }
    }
  }

  void _handleOpenPdfAction({
    required String titolo,    required String volume,
    required String NumPag,    required String NumOrig,
    required String idBra,     required String TipoMulti,
    required String TipoDocu,  required String strumento,
    required String Provenienza, required String link,
  }) async {
    String nomeFileDaVolume = volume;
    String SelTitolo = titolo;
    String SelNumPag = NumPag;
    String SelLink = link;
    String Prova2;
    String nomeFile;

    String SelPercorso = link;
    if (SelPercorso.startsWith('#')) SelPercorso = SelPercorso.substring(1);
    if (SelPercorso.endsWith('#')) SelPercorso = SelPercorso.substring(0, SelPercorso.length - 1);

    int ultimoBackslashIndex = SelPercorso.lastIndexOf(r'\');
    if (ultimoBackslashIndex != -1) {
      nomeFile = SelPercorso.substring(ultimoBackslashIndex + 1);
    } else {
      nomeFile = SelPercorso;
    }
    SelPercorso = SelPercorso.substring(0, SelPercorso.length - nomeFile.length);

    Prova2 = SelPercorso + nomeFile;

    if (mounted) {
      await showDialog(
        context: context,
        builder: (BuildContext dialogContext) {
          final TextEditingController searchController = TextEditingController(text: Prova2);

          String directoryBaseFinale = '';
          String PercorsoPulito = '';
          int indiceSequenza = Prova2.indexOf(":\\");
          int indiceFine = Prova2.indexOf(nomeFileDaVolume);

          if (indiceSequenza != -1 && indiceFine != -1) {
            directoryBaseFinale = Prova2.substring(0, indiceSequenza + 2);
            PercorsoPulito = Prova2.substring(indiceSequenza + 2, indiceFine);
          } else {
            directoryBaseFinale = "";
            PercorsoPulito = Prova2;
          }

          return AlertDialog(
            title: const Text('Dettagli Brano Selezionato'),
            content: SingleChildScrollView(
              child: ListBody(
                children: <Widget>[
                  const Text("Titolo:"),
                  SelectableText(SelTitolo.isNotEmpty ? SelTitolo : "N/D"),
                  const SizedBox(height: 8),
                  const Text("Cartella:"),
                  SelectableText(SelPercorso.isNotEmpty ? SelPercorso : "N/D"),
                  const SizedBox(height: 8),
                  const Text("Nome File:"),
                  SelectableText(nomeFile.isNotEmpty ? nomeFile : "N/D"),
                  const SizedBox(height: 8),
                  const Text('Pagina:'),
                  SelectableText(SelNumPag.isNotEmpty ? SelNumPag : "N/D"),
                  const SizedBox(height: 8),
                  const Text("Link Originale:"),
                  SelectableText(SelLink.isNotEmpty ? SelLink : "N/A"),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Annulla'),
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
              ElevatedButton(
                child: const Text('Visualizza PDF'),
                onPressed: () async {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (BuildContext loadingContext) => const Center(child: CircularProgressIndicator()),
                  );
                  await _VerificaFile(
                    context: context,
                    basePathDaDati: directoryBaseFinale,
                    subPathDaDati: PercorsoPulito,      
                    fileNameDaDati: nomeFileDaVolume,
                    inCasoDiSuccesso: (percorsoDelFile) async {
                      Navigator.of(context, rootNavigator: true).pop();
                      if (!mounted) return;
                      await OpenerPlatformInterface.instance.openPdf(
                        context: context,
                        filePath: percorsoDelFile,
                        page: int.tryParse(SelNumPag) ?? 1,
                      );
                    },
                    inCasoDiFallimento: (percorsoTentato) {
                      Navigator.of(context, rootNavigator: true).pop();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("File NON trovato: $percorsoTentato"), backgroundColor: Colors.red),
                      );
                    },
                  );
                },
              ),
            ],
          );
        },
      );
    }
  }

  // --- LOGICA DI VERIFICA UNIFICATA ---
  Future<void> _VerificaFile({
    required BuildContext context,
    required String basePathDaDati, // Questo viene dal CSV (obsoleto)
    required String subPathDaDati,
    required String fileNameDaDati,
    required Function(String percorsoTrovato) inCasoDiSuccesso,
    required Function(String percorsoTentato) inCasoDiFallimento,
  }) async {
    String percorsoFinaleDaAprire = "N/A";
    bool risorsaEsiste = false;

    try {
      if (kIsWeb) {
        // Logica web invariata
        String baseUrlWeb = "http://192.168.1.100/JamsetPDF";
        String percorsoRelativo = '$subPathDaDati$fileNameDaDati'.replaceAll(r'\', '/');
        if (percorsoRelativo.startsWith('/')) {
          percorsoRelativo = percorsoRelativo.substring(1);
        }
        percorsoFinaleDaAprire = "$baseUrlWeb/${Uri.encodeFull(percorsoRelativo)}";
        final response = await http.head(Uri.parse(percorsoFinaleDaAprire));
        risorsaEsiste = (response.statusCode == 200);
      } else {
        // Logica nativa che usa la configurazione globale
        if (gPercorsoPdf.isEmpty) {
          inCasoDiFallimento("Percorso PDF non configurato nelle Impostazioni.");
          return;
        }

        FilePathResult risultatoNativo = await ValidaPercorso.checkGenericFilePath(
          basePath: gPercorsoPdf, // <-- USA LA VARIABILE GLOBALE
          subPath: subPathDaDati,
          fileNameWithExtension: fileNameDaDati,
        );
        risorsaEsiste = risultatoNativo.isSuccess;
        percorsoFinaleDaAprire = risultatoNativo.fullPath ?? "Percorso non generato";
      }
    } catch (e) {
      percorsoFinaleDaAprire = "Errore: $e";
      risorsaEsiste = false;
    }

    if (risorsaEsiste) {
      inCasoDiSuccesso(percorsoFinaleDaAprire);
    } else {
      inCasoDiFallimento(percorsoFinaleDaAprire);
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
        title: Text('Spartiti Visualizzatore $Laricerca'),
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
                      icon: Icon(_speechToText.isListening ? Icons.mic_off : Icons.mic, color: Colors.black),
                      tooltip: 'Ricerca Vocale',
                      onPressed: !_speechEnabled ? null : (_speechToText.isNotListening ? _startListening : _stopListening),
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
                        print('Nessun filtro  applicato.');
                      } else
                      { Laricerca = "Applicato filtro su:";
                      if (_queryTitolo.isNotEmpty) {  Laricerca += " Titolo   $_queryTitolo -";}
                      if (_queryAutore.isNotEmpty) { Laricerca += " Autore   $_queryAutore - ";}
                      if (_queryProvenienza.isNotEmpty) { Laricerca += " Provenienza $_queryProvenienza - ";}
                      if (_queryVolume.isNotEmpty) { Laricerca += " Volume $_queryVolume - " ;}
                      if (_queryTipoMulti.isNotEmpty) { Laricerca += " TipoMulti $_queryTipoMulti - ";}
                      if (_queryStrumento.isNotEmpty) { Laricerca += " Strumento $_queryStrumento - ";}
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
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
        Center(
        child: SizedBox(
          width: 300,
          height: 400,
          child: Image.asset(
            'assets/images/SherlockInBibliotecaAllaPicasso.jpg',
            fit: BoxFit.cover,
          ),
        ),
      ),
      _csvData.isEmpty ? _buildEmptyState() : _buildCsvList(),
      ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickAndLoadCsv,
        label: const Text('Nuovo CSV'),
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
        ],
      ),
    );
  }

  Widget _buildCsvList() {
    return Container(
      color: Colors.grey[200],
      child: ListView.builder(
        itemCount: _filteredCsvData.length,
        itemBuilder: (context, index) {
          final row = _filteredCsvData[index];

          final titolo = _getCellValue(row, 'Titolo');
          final strumento = _getCellValue(row, 'strumento');
          final volume = _getCellValue(row, 'Volume');
          final numPag = _getCellValue(row, 'NumPag');
          final provenienza = _getCellValue(row, 'ArchivioProvenienza');
          final tipoMulti = _getCellValue(row, 'TipoMulti');

          bool showTitleHeader = false;
          if (index == 0) {
            showTitleHeader = true;
          } else {
            final previousRow = _filteredCsvData[index - 1];
            final String currentTitleClean = titolo.trim().toLowerCase();
            final String previousTitleClean = _getCellValue(previousRow, 'Titolo').trim().toLowerCase();
            if (currentTitleClean != previousTitleClean) {
              showTitleHeader = true;
            }
          }

          final strumentoListTile = ListTile(
            dense: true,
            tileColor: Colors.white,
            title: RichText(
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: DefaultTextStyle.of(context).style,
                children: <TextSpan>[
                  if (strumento.isNotEmpty)
                    TextSpan(
                      text: '$strumento ',
                      style: const TextStyle(color: Colors.green),
                    ),
                  if (numPag.isNotEmpty)
                    TextSpan(
                      text: 'Pag: $numPag del ',
                      style: const TextStyle(color: Colors.black, fontStyle: FontStyle.italic),
                    ),
                  if (volume.isNotEmpty)
                    TextSpan(
                      text: 'Vol: $volume ',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  if (provenienza.isNotEmpty)
                    TextSpan(text: '($provenienza) ',
          style: const TextStyle(color: Colors.redAccent),
                    ),
                  if (tipoMulti.isNotEmpty) TextSpan(text: '$tipoMulti '),
                ],
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
              tooltip: 'Apri PDF',
              onPressed: () {
                final numOrig = _getCellValue(row, 'NumOrig');
                final idBra = _getCellValue(row, 'IdBra');
                final tipoDocu = _getCellValue(row, 'TipoDocu');
                final link = _getCellValue(row, 'PrimoLink');

                _handleOpenPdfAction(
                  titolo: titolo, volume: volume, NumPag: numPag,
                  NumOrig: numOrig, idBra: idBra, TipoMulti: tipoMulti,
                  TipoDocu: tipoDocu, strumento: strumento,
                  Provenienza: provenienza, link: link,
                );
              },
            ),
          );

          if (showTitleHeader) {
            return Card(
              margin: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 0),
              elevation: 4.0,
              clipBehavior: Clip.antiAlias,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8.0),
                  topRight: Radius.circular(8.0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    color: Colors.blueGrey,
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                    child: Text(
                      titolo.trim(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const Divider(height: 1, thickness: 1, color: Colors.grey),
                  strumentoListTile,
                ],
              ),
            );
          } else {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: Colors.grey[300]!, width: 1.0),
                    left: BorderSide(color: Colors.grey[400]!, width: 1.0),
                    right: BorderSide(color: Colors.grey[400]!, width: 1.0),
                    bottom: BorderSide(color: Colors.grey[400]!, width: 1.0),
                  ),
                ),
                child: strumentoListTile,
              ),
            );
          }
        },
      ),
    );
  }
}
