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
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
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
  with AutomaticKeepAliveClientMixin<CsvViewerScreen> { // <--- MODIFICA 1

  // Keys for storing base PDF paths in shared preferences.
  static const String _windowsBasePathKey = 'base_pdf_path_windows';
  static const String _mobileBasePathKey = 'base_pdf_path_mobile';
// Aggiungi queste variabili all'inizio della classe _CsvViewerScreenState
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  String _lastWords = '';
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
// Aggiungi questo metodo nella classe, ad esempio dopo il costruttore
  // SOSTITUISCI ENTRAMBI I VECCHI initState CON QUESTO UNICO BLOCCO
  @override    void initState() {
    super.initState();
    // Chiamiamo tutti i metodi di inizializzazione necessari qui
    _initSpeech();                 // Inizializza il riconoscimento vocale
    _requestStoragePermission();   // Richiedi i permessi per lo storage
    _loadPreferences();            // Carica le preferenze salvate (importante aggiungerlo qui!)
  }


  /// Inizializza il motore di riconoscimento vocale
  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
  }

  /// Gestisce l'inizio dell'ascolto
// Metodo _startListening aggiornato
  void _startListening() async {
    await _speechToText.listen(
      onResult: (result) => _onSpeechResult(result.recognizedWords), // <-- Usa result.recognizedWords
      localeId: 'it_IT', // Opzionale: specifica la lingua italiana
    );
    setState(() {});
  }

  /// Gestisce la fine dell'ascolto
  void _stopListening() async {
    await _speechToText.stop();
    setState(() {});
  }

  /// Callback che viene chiamata quando viene riconosciuto del parlato
// NUOVO CODICE - COMPATIBILE CON speech_to_text 7.x
  void _onSpeechResult(String result) { // <-- La modifica chiave è qui!
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


  // --- MODIFICA FONDAMENTALE N°2 ---
  // Dice a Flutter di mantenere questo stato in memoria.
  @override
  bool get wantKeepAlive => true;
  // ---------------------------------

  // AGGIUNGI QUESTO METODO ALL'INTERNO DELLA TUA CLASSE _CsvViewerScreenState

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
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Applica'),
              onPressed: () {
                // Aggiorna le query e filtra
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

// ORA VIENE IL TUO METODO build()

//...

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
                     // Navigator.of(dialogContext).pop(); // Close main dialog
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
    // --- MODIFICA FONDAMENTALE N°3 ---
    // Registra questo widget per la conservazione dello stato.
    super.build(context);
    // ---------------------------------
    return Scaffold(
      // Rimuoviamo il backgroundColor: Colors.transparent dal Scaffold,
      // perché lo sfondo sarà gestito dal body.
      appBar: AppBar(
        title: Text('Spartiti Visualizzatore $Laricerca'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110.0),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 12.0), // Aggiunto un po' di padding sopra
            child: Column(
              // --- MODIFICA FONDAMENTALE ---
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              // --------------------------
              children: [
                // 1. RIGA SUPERIORE CON TITOLO, MICROFONO E FILTRI
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
                      icon: Icon(
                        _speechToText.isListening ? Icons.mic_off : Icons.mic,
                        color: Colors.black, // <-- AGGIUNGI QUESTO COLORE
                      ),
                      tooltip: 'Ricerca Vocale',
                      onPressed: !_speechEnabled ? null : (_speechToText.isNotListening ? _startListening : _stopListening),
                    ),
                    // Pulsante Filtri Avanzati
                    IconButton(
                      icon: const Icon(
                        Icons.filter_list_alt,
                        color: Colors.blue, // <-- AGGIUNGI QUESTO COLORE
                      ),
                      tooltip: 'Filtri Avanzati',
                      onPressed: _showAdvancedFiltersDialog,
                    ),
                  ],
                ),

                // --- SPACER RIMOSSO ---

                // 2. BOTTONE "FILTRA" PRINCIPALE
                SizedBox( // Avvolgiamo il bottone in un SizedBox per dargli una larghezza
                  width: double.infinity, // Occupa tutta la larghezza
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
                      { // <--- AGGIUNTO _queryProvenienza
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

      // --- INIZIO DELLA MODIFICA FONDAMENTALE ---
      body: SafeArea( // 1. AVVOLGIAMO IL BODY CON SAFEAREA
        child: Stack( // 2. LO STACK ORA È DENTRO SAFEAREA
          fit: StackFit.expand, // 3. DICIAMO ALLO STACK DI ESPANDERSI PER RIEMPIRE L'AREA SICURA
          children: <Widget>
        [
// Immagine di Sfondo dentro un Container centrato
        Center( // <-- WIDGET
        child: Container( // <-- WIDGET AGGIUNTO PER DIMENSIONARE
          width: 300,  // Larghezza desiderata
          height: 400, // Altezza desiderata
          child: Image.asset(
            'assets/images/SherlockInBibliotecaAllaPicasso.jpg',
            fit: BoxFit.cover,
          ),
        ),
      ),
// Contenuto sopra l'immagine
      _csvData.isEmpty ? _buildEmptyState() : _buildCsvList(),
      ],
        ),
      ),
      // --- FINE DELLA MODIFICA ---
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickAndLoadCsv,
        label: const Text('Nuovo CSV'),
        icon: const Icon(Icons.file_upload),
      ),
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
  /// Builds the list view to display the filtered CSV data.
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
                  // --- MODIFICA 1: Usiamo un Divider per coerenza ---
                  // Invece di Divider(height: 0), che è invisibile,
                  // usiamo un Divider con altezza 1 per disegnare la linea.
                  const Divider(height: 1, thickness: 1, color: Colors.grey),
                  // ----------------------------------------------------
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
                    // --- MODIFICA 2: Aggiungiamo un BORDO SUPERIORE ---
                    top: BorderSide(color: Colors.grey[300]!, width: 1.0), // Linea di separazione superiore
                    // --------------------------------------------------
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
