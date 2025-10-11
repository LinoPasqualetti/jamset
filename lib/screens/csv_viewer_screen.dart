// lib/screens/csv_viewer_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import 'package:jamset/file_path_validator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:jamset/platform/opener_platform_interface.dart';
import 'package:permission_handler/permission_handler.dart'; // Importa permission_handler

/// A screen that allows users to view and filter data from a CSV file.
///
/// Users can load a CSV file from their device, filter its content based on
/// multiple criteria, and open associated PDF files.
class CsvViewerScreen extends StatefulWidget {
  /// Creates a [CsvViewerScreen].
  const CsvViewerScreen({super.key});

  @override
  State<CsvViewerScreen> createState() => _CsvViewerScreenState();
}

/// The state for the [CsvViewerScreen].
///
/// This class manages the state of the CSV viewer, including the loaded CSV data,
/// filtering logic, and UI rendering.
class _CsvViewerScreenState extends State<CsvViewerScreen>
{
  // Keys for storing base PDF paths in shared preferences.
  static const String _windowsBasePathKey = 'base_pdf_path_windows';
  static const String _mobileBasePathKey = 'base_pdf_path_mobile';

  /// The base path for PDF files, loaded from shared preferences.
  String? _basePdfPath;

  // Controllers for the text fields used for filtering.
  final TextEditingController _cercaTitoloController = TextEditingController();
  final TextEditingController _cercaAutoreController = TextEditingController();
  final TextEditingController _cercaProvenienzaController = TextEditingController();
  final TextEditingController _cercaVolumeController = TextEditingController();
  final TextEditingController _cercaTipoMultiController = TextEditingController();
  final TextEditingController _cercaStrumentoController = TextEditingController();

  /// The raw data loaded from the CSV file.
  List<List<dynamic>> _csvData = [];

  /// The filtered CSV data to be displayed in the list.
  List<List<dynamic>> _filteredCsvData = [];

  // Query strings for filtering the CSV data.
  String _queryTitolo = '';
  String _queryAutore = '';
  String _queryProvenienza = '';
  String _queryVolume = '';
  String _queryTipoMulti = '';
  String _queryStrumento = '';

  String Laricerca ='';

  // Options for dropdowns or autocompletion (currently unused in UI).
  final List<String> _opzioniProvenienza = [
    'Aebers', 'Bigband', 'Griglie', 'Hal Leonard', 'BiaB', 'Realbook', 'Soli',
  ];
  final List<String> _opzioniTipoMulti = [
    'BiaB', 'Com', 'Dir', 'Fin', 'Pdf', 'Xml', 'Sib', 'Mid', 'Mp3',
  ];
  final List<String> _opzioniStrumento = [
    'C', 'Bb', 'Eb', 'BAS',
  ];

  /// Indicates whether the CSV file has a header row.
  final bool _csvHasHeaders = true;

  /// A map of column names to their indices in the CSV file.
  Map<String, int> _columnIndexMap = {};

  /// The headers from the CSV file.
  List<String> _csvHeaders = [];

  @override
  void initState() {
    super.initState();
    _requestStoragePermission(); // Richiedi i permessi all'avvio della schermata
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

  /// Richiede i permessi per accedere allo storage esterno su Android.
  Future<void> _requestStoragePermission() async {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }

    print("--- DEBUG PERMESSI ---");
    // Per Android 11+ è richiesto questo permesso speciale per accedere a tutte le cartelle.
    var status = await Permission.manageExternalStorage.status;
    print("Stato iniziale del permesso manageExternalStorage: $status");

    if (!status.isGranted) {
      print("Permesso non concesso. Richiesta in corso...");
      status = await Permission.manageExternalStorage.request();
      print("Stato del permesso dopo la richiesta: $status");

      if (!status.isGranted) {
        print("Permesso negato. Apertura delle impostazioni dell'app.");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Per funzionare, l\'app necessita dell\'accesso a tutti i file.')),
          );
        }
        // Se il permesso viene negato, si apre la pagina delle impostazioni dell'app
        // per consentire all'utente di concederlo manualmente.
        await openAppSettings();
      }
    }
    print("---------------------");
  }

  /// Loads the base PDF path from shared preferences based on the platform.
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    String keyToLoad;
    String defaultValue;

    if (Platform.isWindows) {
      keyToLoad = _windowsBasePathKey;
      defaultValue = 'C:\\JamsetPDF';
    } else if (Platform.isAndroid || Platform.isIOS) {
      keyToLoad = _mobileBasePathKey;
      defaultValue = '/storage/emulated/0/JamsetPDF';
    } else {
      keyToLoad = 'base_pdf_path_generic';
      defaultValue = '/';
    }

    setState(() {
      _basePdfPath = prefs.getString(keyToLoad) ?? defaultValue;
    });
    print("Preferenze caricate per ${Platform.operatingSystem}. Percorso Radice: $_basePdfPath");
  }

  /// Handles the action to open a PDF file associated with a CSV row.
  ///
  /// This method displays a dialog with details about the selected item and
  /// provides options to view or verify the PDF file.
  void _handleOpenPdfAction({
    required String titolo,
    required String volume,
    required String NumPag,
    required String NumOrig,
    required String idBra,
    required String TipoMulti,
    required String TipoDocu,
    required String strumento,
    required String Provenienza,
    required String link,
  }) async {
    print("--- DEBUG APERTURA PDF ---");
    print("Tentativo di aprire il PDF: $volume");
    
    String nomeFileDaVolume = volume;
    String SelTitolo = titolo;
    String SelVolume = volume;
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

          // ===================================================================
          // =================== START OF CORRECT CALCULATION BLOCK =============
          // ===================================================================
          // We calculate the paths ONCE here, making them visible to all
          // the code below in this builder.
          final TextEditingController searchController = TextEditingController(text: Prova2);

          String directoryBaseFinale = '';
          String PercorsoPulito = '';
          int indiceSequenza = Prova2.indexOf(":\\");
          int indiceFine = Prova2.indexOf(nomeFileDaVolume);

          if (indiceSequenza != -1 && indiceFine != -1) {
            directoryBaseFinale = Prova2.substring(0, indiceSequenza + 2); // E.g., "C:\" or "P:\"
            PercorsoPulito = Prova2.substring(indiceSequenza + 2, indiceFine);
          } else {
            directoryBaseFinale = "";
            PercorsoPulito = Prova2;
          }
          // ===================================================================
          // ==================== END OF CORRECT CALCULATION BLOCK ==============
          // ===================================================================

          return AlertDialog(
            title: const Text('Dettagli Brano Selezionato'),
            content: SingleChildScrollView(
              child: ListBody(
                children: <Widget>[
                  const Text("--SelTitolo--Titolo:"),
                  SelectableText(SelTitolo.isNotEmpty ? SelTitolo : "N/D"),
                  const SizedBox(height: 8),
                  const Text("--SelPercorso--Cartella SelPercorso:"),
                  SelectableText(SelPercorso.isNotEmpty ? SelPercorso : "N/D"),
                  const SizedBox(height: 8),
                  const Text("--nomeFile-- Nome del File: "),
                  SelectableText(nomeFile.isNotEmpty ? nomeFile : "N/D"),
                  const SizedBox(height: 8),
                  const Text('--nomeFileDaVolume--Altro Nome del File: "'),
                  SelectableText(nomeFileDaVolume.isNotEmpty ? nomeFileDaVolume : "N/D"),
                  const SizedBox(height: 8),
                  const Text("--SelNumPag-- Pagina:"),
                  SelectableText(SelNumPag.isNotEmpty ? SelNumPag : "N/D"),
                  const SizedBox(height: 8),
                  const Text("--SelLink--Link Originale:"),
                  SelectableText(SelLink.isNotEmpty ? SelLink : "N/A"),
                  const SizedBox(height: 8),
                  const Text("--Prova2-- Il percorso daattivare:"),
                  TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: '--Prova2--Nome del PDF Proposto',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
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
                    basePathDaDati: directoryBaseFinale, // Now visible here
                    subPathDaDati: PercorsoPulito,       // Now visible here
                    fileNameDaDati: nomeFileDaVolume,
                    inCasoDiSuccesso: (percorsoDelFile) async {
                      Navigator.of(context, rootNavigator: true).pop(); // Close loading
                      if (!mounted) return;
                      await OpenerPlatformInterface.instance.openPdf(
                        context: context,
                        filePath: percorsoDelFile,
                        page: int.tryParse(SelNumPag) ?? 1,
                      );
                      Navigator.of(dialogContext).pop(); // Close main dialog
                    },
                    inCasoDiFallimento: (percorsoTentato) {
                      Navigator.of(context, rootNavigator: true).pop(); // Close loading
                      if (!mounted) return;
                      setState(() {
                        // Prova2 cannot be updated here, but the controller can
                        searchController.text = percorsoTentato;
                      });
                    },
                  );
                },
              ),
              ElevatedButton(
                child: const Text('Verifica Esistenza'),
                onPressed: () async {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (BuildContext loadingContext) => const Center(child: CircularProgressIndicator()),
                  );
                  await _VerificaFile(
                    context: context,
                    basePathDaDati: directoryBaseFinale, // Now visible here
                    subPathDaDati: PercorsoPulito,       // Now visible here
                    fileNameDaDati: nomeFileDaVolume,
                    inCasoDiSuccesso: (percorsoDelFile) async {
                      Navigator.of(context, rootNavigator: true).pop(); // Close loading
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("File trovato: $percorsoDelFile"), backgroundColor: Colors.green),
                      );
                    },
                    inCasoDiFallimento: (percorsoTentato) {
                      Navigator.of(context, rootNavigator: true).pop(); // Close loading
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("File NON trovato: $percorsoTentato"), backgroundColor: Colors.red),
                      );
                      setState(() {
                        searchController.text = percorsoTentato;
                      });
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

  /// Verifies the existence of a file.
  ///
  /// This method checks for the existence of a file on the local file system
  /// or a web server, depending on the platform.
  Future<void> _VerificaFile({
    required BuildContext context,
    required String basePathDaDati,
    required String subPathDaDati,
    required String fileNameDaDati,
    required Function(String percorsoTrovato) inCasoDiSuccesso,
    required Function(String percorsoTentato) inCasoDiFallimento,
  }) async {
    String percorsoFinaleDaAprire = "N/A";
    bool risorsaEsiste = false;

    try {
      if (kIsWeb) {
        String baseUrlWeb = "http://192.168.1.100/JamsetPDF";
        String percorsoRelativo = '$subPathDaDati$fileNameDaDati'.replaceAll(r'\', '/');
        if (percorsoRelativo.startsWith('/')) {
          percorsoRelativo = percorsoRelativo.substring(1);
        }
        percorsoFinaleDaAprire = "$baseUrlWeb/${Uri.encodeFull(percorsoRelativo)}";
        final response = await http.head(Uri.parse(percorsoFinaleDaAprire));
        risorsaEsiste = (response.statusCode == 200);
      } else {
        String basePathTecnico;
        if (Platform.isWindows) {
          basePathTecnico = r'C:\JamsetPDF';
        } else {
          basePathTecnico = '/storage/emulated/0/JamsetPDF';
        }

        FilePathResult risultatoNativo = await ValidaPercorso.checkGenericFilePath(
          basePath: basePathTecnico,
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

  // The rest of the functions (_pickAndLoadCsv, _filterData, build, etc.) remain the same.
  // Make sure there are no other syntax errors in those parts.
  // ... (paste the rest of your file here, from _pickAndLoadCsv onwards)

  // For safety, here is the rest of the code as you provided it

  /// Gets a cell value from a CSV row by column key.
  String _getCellValue(List<dynamic> row, String columnKey, {String defaultValue = 'N/D'}) {
    if (_columnIndexMap.containsKey(columnKey)) {
      int? colIndex = _columnIndexMap[columnKey];
      if (colIndex != null && colIndex < row.length && row[colIndex] != null) {
        return row[colIndex].toString();
      }
    }
    return defaultValue;
  }

  /// Creates a map of column names to their indices.
  Map<String, int> _createColumnIndexMap(List<String> headers) {
    final Map<String, int> map = {};
    for (int i = 0; i < headers.length; i++) {
      String headerFromFile = headers[i].toString().trim().toLowerCase();
      // Direct mapping based on constant keys
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

  /// Picks a CSV file using the file picker and loads its content.
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
          // --- Logica di gestione della codifica ---
          try {
            // 1. Prova a leggere come UTF-8 (standard)
            fileContent = await file.readAsString(encoding: utf8);
            print("File letto con successo usando la codifica UTF-8.");
          } on FileSystemException {
            // 2. Se fallisce, prova con latin1 (comune per file da Windows/DB)
            print("Lettura come UTF-8 fallita. Tentativo con latin1.");
            fileContent = await file.readAsString(encoding: latin1);
            print("File letto con successo usando la codifica di fallback latin1.");
          }
        }

        // --- Logica di rilevamento automatico del delimitatore ---
        String delimiter = ';'; // Default
        if (fileContent.isNotEmpty) {
          final firstLine = fileContent.split('\n')[0];
          int commaCount = ','.allMatches(firstLine).length;
          int semicolonCount = ';'.allMatches(firstLine).length;
          
          if (commaCount > semicolonCount) {
            delimiter = ',';
          }
        }
        print("--- RILEVAMENTO DELIMITATORE ---");
        print("Delimitatore rilevato: '$delimiter'");
        print("-------------------------------");
        // --- Fine logica ---

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
      // Handle error
      print("ERRORE DURANTE IL CARICAMENTO DEL CSV: $e");
    }
  }

  /// Filters the CSV data based on the query strings.
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
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: Image.asset('assets/images/SherlockCerca2.png', fit: BoxFit.cover),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text('Spartiti Visualizzatore $Laricerca'),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(180.0),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Filters...
                    Row(
                      children: [
                        Expanded(child: TextField(controller: _cercaTitoloController, decoration: const InputDecoration(labelText: 'Titolo'))),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(controller: _cercaAutoreController, decoration: const InputDecoration(labelText: 'Autore'))),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: _cercaProvenienzaController, decoration: const InputDecoration(labelText: 'Provenienza'))),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(controller: _cercaVolumeController, decoration: const InputDecoration(labelText: 'Volume'))),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: _cercaTipoMultiController, decoration: const InputDecoration(labelText: 'TipoMulti'))),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(controller: _cercaStrumentoController, decoration: const InputDecoration(labelText: 'Strumento'))),
                      ],
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.search),
                      label: const Text('Filtra'),
                      onPressed: () {
                        _queryTitolo = _cercaTitoloController.text.toLowerCase();
                        _queryAutore = _cercaAutoreController.text.toLowerCase();
                        _queryProvenienza = _cercaProvenienzaController.text.toLowerCase();
                        _queryVolume = _cercaVolumeController.text.toLowerCase();
                        _queryTipoMulti = _cercaTipoMultiController.text.toLowerCase();
                        _queryStrumento = _cercaStrumentoController.text.toLowerCase();
                        _filterData();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          body: _csvData.isEmpty ? _buildEmptyState() : _buildCsvList(),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _pickAndLoadCsv,
            label: const Text('Nuovo CSV'),
            icon: const Icon(Icons.file_upload),
          ),
        ),
      ],
    );
  }

  /// Builds the widget to display when no CSV file is loaded.
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

  /// Builds the list view to display the filtered CSV data.
  Widget _buildCsvList() {
    return ListView.builder(
      itemCount: _filteredCsvData.length,
      itemBuilder: (context, index) {
        final row = _filteredCsvData[index];
        final titolo = _getCellValue(row, 'Titolo');
        final volume = _getCellValue(row, 'Volume');
        final numPag = _getCellValue(row, 'NumPag');
        final numOrig = _getCellValue(row, 'NumOrig');
        final idBra = _getCellValue(row, 'IdBra');
        final tipoMulti = _getCellValue(row, 'TipoMulti');
        final tipoDocu = _getCellValue(row, 'TipoDocu');
        final strumento = _getCellValue(row, 'strumento');
        final provenienza = _getCellValue(row, 'ArchivioProvenienza');
        final link = _getCellValue(row, 'PrimoLink');

        return Card(
          child: ListTile(
            title: Text(titolo),
            subtitle: Text('Volume: $volume - Pag: $numPag'),
            trailing: IconButton(
              icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
              onPressed: () => _handleOpenPdfAction(
                titolo: titolo, volume: volume, NumPag: numPag, NumOrig: numOrig,
                idBra: idBra, TipoMulti: tipoMulti, TipoDocu: tipoDocu,
                strumento: strumento, Provenienza: provenienza, link: link,
              ),
            ),
          ),
        );
      },
    );
  }
}
