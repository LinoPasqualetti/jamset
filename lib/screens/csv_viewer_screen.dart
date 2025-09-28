// lib/screens/csv_viewer_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'dart:convert';
// Rimuovi questo se non lo usi più: import 'package:jamset/screens/device_selection_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
//Pacchetti per apertura files (PDF o altri) e per i percorsi
import 'package:open_filex/open_filex.dart'; // Per aprire file
// Per aprire URL
// Per manipolare i percorsi, aggiungi path: ^X.Y.Z a pubspec.yaml
// ... altri import
import 'package:url_launcher/url_launcher.dart'; // NECESSARIO PER url_launcher per aprire file su Browser

class CsvViewerScreen extends StatefulWidget {
  const CsvViewerScreen({super.key});

  @override
  State<CsvViewerScreen> createState() => _CsvViewerScreenState();
} // <--- Assicurati che questa parentesi chiuda CsvViewerScreen

class _CsvViewerScreenState extends State<CsvViewerScreen> {

  //TextEditingController _searchController = TextEditingController();final TextEditingController _cercaTitoloController = TextEditingController();
  final TextEditingController _cercaTitoloController = TextEditingController();
  final TextEditingController _cercaAutoreController = TextEditingController();
  List<List<dynamic>> _csvData = [];
  List<List<dynamic>> _filteredCsvData = [];
  // Rimuovi o rinomina il vecchio _searchController se non serve più per una ricerca generica

  // Potresti voler mantenere anche le stringhe di query separate
  String _queryTitolo = '';
  String _queryAutore = '';
//  final TextEditingController _searchController = TextEditingController();
  String _basePdfPath = ""; // Variabile per memorizzare il path base dei PDF
  // NUOVE VARIABILI PER LA MAPPATURA DINAMICA DELLE COLONNE
  bool _csvHasHeaders = true; // o come la gestisci
  Map<String, int> _columnIndexMap = {};
  List<String> _csvHeaders = []; // Per tenere traccia delle intestazioni effettive
  // Nomi delle colonne che CERCHI nel CSV (devono corrispondere a quelli nel tuo file)
  // !! AGGIUNGI O VERIFICA QUESTE RIGHE !!
  //final bool _csvHasHeaders = true; // Valore predefinito, puoi cambiarlo o impostarlo diversamente

  // INDICI FISSI (usati SE _csvHasHeaders è false)

// Aggiungi altre chiavi se ti servono altri campi in modo dinamico// Campi per CSV con INTESTAZIONE
  static const String keyTitolo = 'Titolo'; // Adatta questi nomi ESATTAMENTE a come sono nel tuo CSV
  static const String keyNumPag = 'NumPag';
  static const String keyVolume = 'Volume';
  static const String keyPercRadice = 'PercRadice';
  static const String keyPercResto = 'PercResto';
  static const String keyAutore = 'Autore';
  static const String keyStrumento = 'strumento';
  static const String keyIdBra = 'IdBra'; // Adattamento ESATTAMENTE a come sono nel tuo CSV
  static const String keyPrimoLink = 'PrimoLink';
  static const String keyNumOrig = 'NumOrig';
  static const String keyTipoDocu = 'TipoDocu';
  static const String keyArchivioProvenienza = 'ArchivioProvenienza';
  static const String keyTipoMulti = 'TipoMulti';
  static const String keyIdVolume = 'IdVolume';

  String? get $numPag => null;
// Aggiungi altre chiavi se ti servono altri campi in modo dinamico
  // All'interno della classe _CsvViewerScreenState:
  String _getCellValue(List<dynamic> row, String columnKey, {String defaultValue = 'N/D'}) {
    // Usa la chiave normalizzata (minuscola) se la tua mappa è stata creata con chiavi minuscole
    String normalizedKey = columnKey; // O columnKey.toLowerCase() se le chiavi nella mappa sono minuscole
    // e le costanti key... sono usate direttamente come arrivano.
    // Dipende da come hai implementato _createColumnIndexMap.
    // Coerenza è la chiave.

    if (_columnIndexMap.containsKey(normalizedKey)) { // o _columnIndexMap.containsKey(columnKey)
      int? colIndex = _columnIndexMap[normalizedKey]; // o _columnIndexMap[columnKey]
      if (colIndex != null && colIndex < row.length && row[colIndex] != null) {
        return row[colIndex].toString();
      }
    }
    return defaultValue;
  }
// All'interno della classe _CsvViewerScreenState:
//Inizio trattamento CSV con INTESTAZIONE
  // All'interno della classe _CsvViewerScreenState:

  Map<String, int> _createColumnIndexMap(List<String> headers) {
    final Map<String, int> map = {};
    for (int i = 0; i < headers.length; i++) {
      // Normalizza l'header dal CSV (es. minuscolo, trim)
      // È importante che la normalizzazione qui sia consistente con come
      // ti aspetti che le tue 'key...' corrispondano.
      // Se le tue 'key...' sono CaseSensitive e esattamente come nel CSV,
      // potresti omettere .toLowerCase(). Ma è più robusto normalizzare.
      String headerFromFile = headers[i].toString().trim(); // Potresti voler fare anche .toLowerCase()
      // se le tue key... sono tutte minuscole
      // o se vuoi un match case-insensitive.
      // Per ora, lo lascio così, assumendo che
      // le tue key... debbano matchare esattamente (case sensitive)
      // le intestazioni del CSV dopo il trim.
      // O, meglio ancora, normalizza entrambe a minuscolo.

      // Se le tue costanti 'key...' sono definite con capitalizzazione specifica
      // (es. keyTitolo = 'Titolo') e vuoi fare un confronto case-insensitive,
      // allora converti sia headerFromFile sia la costante key a minuscolo prima del confronto.
      // Esempio con normalizzazione a minuscolo (più robusto):
      String normalizedHeaderFromFile = headerFromFile.toLowerCase();

      if (normalizedHeaderFromFile == keyIdBra.toLowerCase()) {
        map[keyIdBra] = i;
      } else if (normalizedHeaderFromFile == keyTipoMulti.toLowerCase()) map[keyTipoMulti] = i;
      else if (normalizedHeaderFromFile == keyTipoDocu.toLowerCase()) map[keyTipoDocu] = i;
      else if (normalizedHeaderFromFile == keyTitolo.toLowerCase()) map[keyTitolo] = i;
      else if (normalizedHeaderFromFile == keyAutore.toLowerCase()) map[keyAutore] = i;
      // La tua keyStrumento è 'strumento'. Se nel CSV l'header è 'strumento',
      // questo non farà match a meno che l'header del CSV non sia esattamente 'Strum' (case insensitive).
      // Devi essere consistente.
      else if (normalizedHeaderFromFile == keyStrumento.toLowerCase()) map[keyStrumento] = i;
      else if (normalizedHeaderFromFile == keyArchivioProvenienza.toLowerCase()) map[keyArchivioProvenienza] = i;
      else if (normalizedHeaderFromFile == keyVolume.toLowerCase()) map[keyVolume] = i;
      else if (normalizedHeaderFromFile == keyNumPag.toLowerCase()) map[keyNumPag] = i;
      else if (normalizedHeaderFromFile == keyNumOrig.toLowerCase()) map[keyNumOrig] = i;
      else if (normalizedHeaderFromFile == keyPrimoLink.toLowerCase()) map[keyPrimoLink] = i;
      else if (normalizedHeaderFromFile == keyIdVolume.toLowerCase()) map[keyIdVolume] = i;
      else if (normalizedHeaderFromFile == keyPercRadice.toLowerCase()) map[keyPercRadice] = i;
      else if (normalizedHeaderFromFile == keyPercResto.toLowerCase()) map[keyPercResto] = i;
    }

    // Debugging opzionale:
    if (headers.isNotEmpty && map.isEmpty) {
      print("ATTENZIONE: _columnIndexMap è vuota ma il CSV aveva intestazioni. Controllare la corrispondenza tra le 'key...' definite e le intestazioni effettive nel file CSV.");
      print("Intestazioni dal CSV (normalizzate): ${headers.map((h) => h.toString().trim().toLowerCase()).toList()}");
      print("Chiavi attese (normalizzate): ${[keyIdBra, keyTipoMulti, keyTipoDocu, keyTitolo, keyAutore, keyStrumento, keyArchivioProvenienza, keyVolume, keyNumPag, keyNumOrig, keyPrimoLink, keyIdVolume].map((k) => k.toLowerCase()).toList()}");
    } else if (headers.isNotEmpty && !map.containsKey(keyTitolo)) { // Esempio di controllo per una colonna essenziale
      print("ATTENZIONE: La colonna '$keyTitolo' non è stata trovata/mappata dalle intestazioni del CSV.");
      print("Intestazioni dal CSV: $headers");
    }
    return map;
  }
//Inizio PDF SU BROWSER
  Future<void> _openPdfInExternalBrowser(String localPdfPath, String pageNumberStr) async { // Rinominata per chiarezza e per evitare conflitti se ci fosse già openPdfInBrowser
    int? pageNumber = int.tryParse(pageNumberStr);
    if (pageNumber == null || pageNumber < 1) {
      print('Numero di pagina non valido: $pageNumberStr');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Numero di pagina non valido: $pageNumberStr')),
        );
      }
      return;
    }

    // Non c'è più bisogno di: String formattedPath = localPdfPath.replaceAll(r'\', '/');
    // Uri.file lo gestisce.

    Uri fileUri;
    // NOTA: Platform.isWindows non è affidabile per il web per determinare il formato del path.
    // Se il path viene DAL CSV ed è in formato Windows (P:\...), allora Uri.file con windows:true
    // è corretto anche se Flutter è compilato per web, perché stai interpretando un path *esterno*.
    // Tuttavia, l'accesso diretto a 'file:///' da un'app web è problematico.
    // Questa logica è più pensata per mobile/desktop che lanciano un browser esterno.
    if (!kIsWeb && Platform.isWindows) {
      fileUri = Uri.file(localPdfPath, windows: true);
    } else if (kIsWeb) {
      // Per il web, se il localPdfPath è un path del filesystem locale dell'utente (es. "P:\..."),
      // questo TENTATIVO di aprirlo direttamente in un browser esterno con file:///
      // probabilmente fallirà a causa delle policy di sicurezza del browser.
      // È più un costrutto per "se il browser *potesse* accedere a questo path locale".
      // Per Windows path style sul web, è comunque utile windows:true per la corretta formattazione dell'URI
      // nel caso (improbabile) che il browser lo permetta.
      // Dovrai assicurarti che localPdfPath sia già URL encoded se contiene spazi, ecc.
      // o che sia un path che Uri.file può gestire correttamente.
      // Spesso, per i file locali sul web, l'utente li seleziona, e ottieni bytes o un blob URL.
      print("Tentativo di costruire un URI file:// per il web. L'accesso diretto potrebbe essere bloccato dal browser.");
      // Assumiamo che se è web e il path è stile Windows, vogliamo windows:true
      // Questo è speculativo per il web con `file:///`
      if (localPdfPath.contains(r'\') && localPdfPath.contains(':')) { // heuristica per path windows
        fileUri = Uri.file(localPdfPath, windows: true);
      } else {
        fileUri = Uri.parse(localPdfPath); // Se è già un URL o un path stile Unix
      }
    }
    else { // Per altre piattaforme desktop/mobile non Windows
      fileUri = Uri.file(localPdfPath);
    }


    final Uri urlWithPage = fileUri.replace(fragment: 'page=$pageNumber');
    print('Attempting to launch URL: ${urlWithPage.toString()}');

    if (await canLaunchUrl(urlWithPage)) {
      await launchUrl(
        urlWithPage,
        mode: LaunchMode.externalApplication,
      );
    } else {
      print('Could not launch ${urlWithPage.toString()}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossibile aprire il link: ${urlWithPage.toString()}')),
        );
      }
    }
  }
//Fine PDF SU Browser
//Fine trattamento CSV con INTESTAZIONE
  String _getValueFromRow(List<dynamic> row, String columnKeyOrIdentifier, {String defaultValue = 'N/D'}) {
    if (_csvHasHeaders) {
      // MODALITÀ 1: CSV CON INTESTAZIONE
      // columnKeyOrIdentifier è una CHIAVE (es. keyTitolo)
      // Usiamo _columnIndexMap per trovare l'indice numerico corretto.
      if (_columnIndexMap.containsKey(columnKeyOrIdentifier)) {
        int? colIndex = _columnIndexMap[columnKeyOrIdentifier];
        if (colIndex != null && colIndex < row.length && row[colIndex] != null) {
          return row[colIndex].toString();
        }
      }
    } else {
      // MODALITÀ 2: CSV SENZA INTESTAZIONE (CAMPI POSIZIONALI)
      // columnKeyOrIdentifier è un IDENTIFICATORE LOGICO che usiamo nello switch
      // per mappare all'INDICE FISSO corretto.

    }
    return defaultValue; // Valore di fallback se tutto il resto fallisce
  }

  @override
  void initState() {
    super.initState();
    // NON aggiungere listener ai controller se il filtro è solo via bottone
  }

  @override
  void dispose() {
    _cercaTitoloController.dispose();
    _cercaAutoreController.dispose();
    super.dispose();
  }
  //Future<void> (_pickAndLoadCsv) async
  Future<void> _pickAndLoadCsv() async
  {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null) {
        String fileContent;

        if (kIsWeb) {
          final bytes = result.files.single.bytes!;
          try {
            fileContent = utf8.decode(bytes);
          } catch (e) {
            fileContent = latin1.decode(bytes);
          }
        } else {
          final filePath = result.files.single.path!;
          final file = File(filePath);
          try {
            fileContent = await file.readAsString(encoding: utf8);
          } catch (e) {
            fileContent = await file.readAsString(encoding: latin1);
          }
        }
               //Inizio trattamento CSV con intestazioni
        final allRowsFromFile = const CsvToListConverter(fieldDelimiter: ';').convert(fileContent);

        if (allRowsFromFile.isEmpty) {
          setState(() {
            _csvData = [];
            _filteredCsvData = [];
            _columnIndexMap = {};
            _csvHeaders = [];
          });
          // Potresti voler mostrare un messaggio qui
          return;
        }

        if (_csvHasHeaders) {
          if (allRowsFromFile.isNotEmpty) { // Controlla se c'è almeno una riga per l'intestazione
            _csvHeaders = List<String>.from(allRowsFromFile[0].map((h) => h.toString().trim())); // Aggiunto .trim()
            _columnIndexMap = _createColumnIndexMap(_csvHeaders);
            if (allRowsFromFile.length > 1) {
              _csvData = allRowsFromFile.sublist(1);
            } else {
              _csvData = []; // Solo intestazione, nessun dato
            }
          } else { // File vuoto, gestito sopra, ma per sicurezza
            _csvHeaders = [];
            _columnIndexMap = {};
            _csvData = [];
          }
        } else {
          _csvHeaders = []; // Nessuna intestazione
          _columnIndexMap = {}; // Non usata per l'accesso primario
          _csvData = allRowsFromFile;
        }

        setState(() {
          //_csvData = fields; // Rimuovi questa riga
          _filteredCsvData = List<List<dynamic>>.from(_csvData);
        });


        //Fine trattamento CSV con intestazioni


        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File CSV caricato con successo!')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nessun file selezionato.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore durante il caricamento del file: $e')),
        );
      }
    }
  }
  /// Filtro del CSV (o del ResultSetVecchia versione con un campo
 //void _filterData() {
 //   final query = _searchController.text.toLowerCase();
  //setState(() {
 //     if (query.isEmpty) {
 //       _filteredCsvData = _csvData;
 //     } else {
 //       _filteredCsvData = _csvData.where((row) {
 //         final titolo = row.length > 3 ? row[3].toString().toLowerCase() : '';
 //         final autore = row.length > 4 ? row[4].toString().toLowerCase() : '';
 //         return titolo.contains(query) || autore.contains(query);
 //       }).toList();
 //     }
 //   });
 // }
// All'interno della classe _CsvViewerScreenState

// Assicurati che queste costanti (chiavi delle colonne) siano definite correttamente
// static const String keyTitolo = 'Titolo';
// static const String keyAutore = 'Autore';

  void _filterData() {
    // Le query _queryTitolo e _queryAutore sono già state aggiornate
    // e convertite in minuscolo dal onPressed del bottone "Filtra".

    setState(() {
      // Se entrambi i campi di ricerca sono vuoti, mostra tutti i dati
      if (_queryTitolo.isEmpty && _queryAutore.isEmpty) {
        _filteredCsvData = List.from(_csvData);
      } else {
        _filteredCsvData = _csvData.where((row) {
          // Estrai i valori dalla riga usando le chiavi
          final String titoloInRow = _getValueFromRow(
            row,
            keyTitolo,
            defaultValue: '',
          ).toLowerCase();

          final String autoreInRow = _getValueFromRow(
            row,
            keyAutore,
            defaultValue: '',
          ).toLowerCase();

          // Logica di filtro:
          bool corrispondeTitolo = true; // Assume vero se il campo di ricerca titolo è vuoto
          if (_queryTitolo.isNotEmpty) {
            corrispondeTitolo = titoloInRow.contains(_queryTitolo);
          }

          bool corrispondeAutore = true; // Assume vero se il campo di ricerca autore è vuoto
          if (_queryAutore.isNotEmpty) {
            corrispondeAutore = autoreInRow.contains(_queryAutore);
          }

          // La riga deve corrispondere a entrambi i criteri di ricerca (se specificati)
          return corrispondeTitolo && corrispondeAutore;

        }).toList();
      }
    });
  }


    // Opzionale: scrolla la lista all'inizio dopo aver filtrato, se hai molti elementi
    // if (_scrollController.hasClients) {
    //   _scrollController.jumpTo(0.0);
    // }
  //}


  // Funzione chiamata quando si preme il bottone "Apri PDF"
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
    required String link, // se hai anche un link diretto dal CSV colonna 10
    // }) {
    // dA QUI
  }) async   {
    String nomeFileDaVolume = volume.endsWith('.pdf') ? volume : '$volume.pdf';
    String finalPath = kIsWeb ? "Non applicabile per web" : '$_basePdfPath$nomeFileDaVolume';
    //i campi sel sono relativi agli elementi della riga selezionata in apri pdf
    // ;
    ///ESTRAE I Dati Selezionati
    String SelTitolo = titolo;
    String SelVolume = volume;
    String SelNumPag = NumPag;
    String SelNumOrig = NumOrig;
    String SelLink = link;
    String SelIdBra = idBra;
    String SelTipoMulti = TipoMulti;
    String SelTipoDocu = TipoDocu;
    String SelStrumento = strumento;
    String SelProvenienza = Provenienza;
    String SelBasePdfPath = _basePdfPath;
    String SelfinalPath = finalPath;
    String Prova2 = 'Prova2';
    String nomeFile;
    String nomeFileEstratto = ""; // Variabile per il nome file estratto da SelLink
    String percorsoDirectoryEstratta = ""; // Variabile per la directory estratta da SelLink
    String percorsoPdfDaAprireNelDialogo = ""; // Questa sarà la variabile che contiene il path WEB da aprire



    // TRATTAMENTO nomeFile Inizio
    // --- INIZIO LOGICA DI ESTRAZIONE nomeFile (CON ESTENSIONE .pdf) ---

    String SelPercorso = link; // Usa il parametro 'link' passato alla funzione
    if (SelPercorso.startsWith('#')) {
      SelPercorso = SelPercorso.substring(1);
    }
    if (SelPercorso.endsWith('#')) {
      SelPercorso = SelPercorso.substring(0, SelPercorso.length - 1);
    }
// Ora SelPercorso è, ad esempio, "P:\PDF REAL BOOK\BookC\COLOBK.PDF"

    int ultimoBackslashIndex = SelPercorso.lastIndexOf(r'\');

    if (ultimoBackslashIndex != -1) {
      // Prendi tutto ciò che viene dopo l'ultimo backslash
      nomeFile = SelPercorso.substring(ultimoBackslashIndex + 1);
    } else {
      // Non ci sono backslash, quindi si presume che SelPercorso sia solo il nome del file (con o senza estensione)
      nomeFile = SelPercorso;
    }
    SelPercorso = SelPercorso.substring(0, SelPercorso.length - nomeFile.length);

// Verifica opzionale se vuoi assicurarti che termini con .pdf (case-insensitive)
// e gestire casi in cui non lo fa, ma per ora questo estrae il nome file completo.
// Se il 'link' originale non avesse avuto .pdf, nomeFile qui non lo avrebbe.

// Se vuoi ASSICURARTI che nomeFile finisca con .pdf e l'originale lo aveva,
// e la pulizia non l'ha tolto, questa logica sopra dovrebbe già funzionare.
// Se il link originale NON AVESSE .pdf, e tu volessi aggiungerlo, sarebbe un'altra logica.
// Ma dalla tua domanda, sembra che tu voglia PRESERVARE .pdf se c'è.
    print("InizioAzione Chiama Apertura PDF _handleOpenPdfAction"); // con parametri
    print("Stringa originale (link): $link");
    print("Percorso pulito: $SelPercorso");
    print("Nomefile estratto (CON estensione) campo nomeFile: $nomeFile"); // Dovrebbe essere COLOBK.PDF

// --- FINE LOGICA DI ESTRAZIONE nomeFile (CON ESTENSIONE .pdf) ---



    //  Fine trattamento nomeFile
    print('Vediamo cos è SelTitolo $SelTitolo');
    print('Vediamo cos è SelVolume $SelVolume');
    print('Vediamo cos è SelNumPag $SelNumPag');
    print('Vediamo cos è SelNumOrig $SelNumOrig');
    print('Vediamo cos è SelLink $SelLink');
    print('Vediamo cos è SelIdBra $SelIdBra');
    print('Vediamo cos è SelTipoMulti $SelTipoMulti');
    print('Vediamo cos è SelTipoDocu $SelTipoDocu');
    print('Vediamo cos è SelStrumento $SelStrumento');
    print('Vediamo cos è SelProvenienza $SelProvenienza');
    print('Vediamo cos è SelBasePdfPath $SelBasePdfPath');
    print('Vediamo cos è FinalPath $finalPath');
    print('--- Azione Chiama Apertura PDF _handleOpenPdfAction ---');
    print('Tetolo: $titolo');
    print('Volume (come nome file?): $nomeFileDaVolume');
    print('Numero Pagina (da usare con lettore PDF): $NumPag');
    print('Numero Originale: $NumOrig');
    print('Path Base Configurato: $_basePdfPath');
    //print('Path PDF Calcolato (esempio): $finalPath');
    print('Link diretto da CSV: $link');
    // dA QUI

    // fino a qui
    // TODO: Implementare l'apertura effettiva del PDF con un package come `open_file` o `url_launcher` (per link)
    // Esempio con open_file (necessita del package aggiunto a pubspec.yaml):
    // if (!kIsWeb && File(finalPath).existsSync()) {
    //   try {
    //     await OpenFile.open(finalPath);
    //     // Se il tuo lettore PDF supporta l'apertura a una pagina specifica tramite argomenti,
    //     // dovresti investigare come fare con OpenFile o un altro package.
    //     // Per `url_launcher` su desktop potrebbe essere possibile con alcuni schemi URI.
    //   } catch (e) {
    //     ScaffoldMessenger.of(context).showSnackBar(
    //       SnackBar(content: Text('Errore apertura PDF: $e')),
    //     );
    //   }
    // } else if (kIsWeb) {
    //   // Per il web, se hai un link diretto nella colonna 10 del CSV:
    //   // if (link.isNotEmpty && Uri.tryParse(link)?.hasAbsolutePath == true) {
    //   //   await launchUrl(Uri.parse(link));
    //   // } else {
    //   //   ScaffoldMessenger.of(context).showSnackBar(
    //   //     const SnackBar(content: Text('Link non valido o PDF non disponibile per il web.')),
    //   //   );
    //   // }
    // }
    // else {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     SnackBar(content: Text('PDF non trovato al percorso: $finalPath')),
    //   );
    // }
    ///// per estrarre i dati da link

    ///// fine per estrarre i dati da Link


    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Dati per PDF: Titolo: $titolo, Volume: $volume, Pag: $NumPag. Path base: $_basePdfPath'),
        //duration: const Duration(seconds: 10),
      ),
    );
//Da qui emettere un nuovo dialogBox o schermo per verificare gli elementi per costruire il giusto nome di FilePd
// Titolo ( da ewsporre ) Volume (da esporre) NumPag (da potere variara) Percorso (da modificare) Valore iniziale =
    Prova2 =SelPercorso + nomeFile;
    SelBasePdfPath = r'c:\Fantasia\';
    print('Campo composto da SelPercorso + nomeFile:   $Prova2');
    print ('Directory da variare:  $SelBasePdfPath');
    print('TitoloBrano: $SelTitolo');
    print('Strumento contiene $SelStrumento');
    print('Volume $SelVolume');
// --- INIZIO NUOVO AlertDialog ---
    // (Questa è circa la tua riga 213, dopo i print)
    if (mounted) {
      // Controller se avevi campi editabili prima, se ora sono solo visualizzabili
      // e selezionabili, i controller potrebbero non essere necessari per questi specifici campi.
      // Ma se altri campi sono ancora editabili (come nel mio esempio precedente),
      // i loro controller rimangono.
      TextEditingController searchController = TextEditingController(text: Prova2); // <--- INIZIALIZZA QUI
      await showDialog(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Dettagli Brano Selezionato'), // O usa SelectableText anche qui se vuoi
            content: SingleChildScrollView(
              child: ListBody(
                children: <Widget>[
                  const Text("Titolo:") , //
                  SelectableText(SelTitolo.isNotEmpty ? SelTitolo : "N/D"),
                  const SizedBox(height: 8),

                  const Text("Cartella SelPercorso:"), // Etichetta
                  SelectableText(SelPercorso.isNotEmpty ? SelPercorso : "N/D"),
                  const SizedBox(height: 8),

                  const Text("Percorso Finale:"), // Etichetta
                  SelectableText(SelPercorso.isNotEmpty ? SelPercorso : "N/D"),
                  const SizedBox(height: 8),

                  const Text("Nome del File: nomeFile"), // Etichetta
                  SelectableText(nomeFile.isNotEmpty ? nomeFile : "N/D"),
                  const SizedBox(height: 8),

                  const Text('Altro Nome del File: nomeFileDaVolume :"'), // Etichetta
                  SelectableText(nomeFileDaVolume.isNotEmpty ? nomeFileDaVolume : "N/D"),
                  const SizedBox(height: 8),

                  const Text("Pagina:"), // Etichetta
                  SelectableText(SelNumPag.isNotEmpty ? SelNumPag : "N/D"),
                  const SizedBox(height: 8),


                  const Text("Link Originale:"), // Etichetta
                  SelectableText(SelLink.isNotEmpty ? SelLink : "N/A"),
                  const SizedBox(height: 8),
                  TextField(
                    controller: searchController, // _searchController ora contiene il testo di Prova2
                    decoration: InputDecoration(
                      // Se vuoi ancora usare Prova2 nell'hintText, va bene, ma
                      // l'hintText appare solo se il campo è vuoto.
                      // Il testo effettivo nel campo sarà quello di Prova2 grazie al controller.
                      hintText: 'Nome del PDF Proposto (inizialmente: $Prova2)',
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
                child: const Text('Ritorna alla lista'),
                onPressed: () {
                  // Azione per tornare indietro: chiude semplicemente questo dialogo.
                  // L'utente tornerà alla schermata precedente che mostrava la lista.
                  Navigator.of(dialogContext).pop('ritorna_alla_lista'); // Chiude il dialogo
                  // Puoi passare un valore per identificare l'azione se necessario
                },
              ),
              const SizedBox(width: 8), // Aggiunge un po' di spazio tra i bottoni (opzionale)
              ElevatedButton( // Ho cambiato in ElevatedButton per distinguerlo, ma puoi usare TextButton
                child: const Text('Visualizza PDF'),
                onPressed: () async  {
                  // RECUPERA IL VALORE CORRENTE DAL TEXTFIELD TRAMITE IL SUO CONTROLLER
                  String percorsoPdfDaAprire = searchController.text.trim(); // .trim() per rimuovere spazi bianchi inutili

                  // Puoi anche recuperare il valore della pagina se hai un campo per quello
                  // String paginaDaAprire = paginaController.text.trim();
////%%%%%%%%%%%%%%%%%%%%%%%%%% CARTELLA SU TCL NXTPaper (non ha una scheda e dunque questo è il percorso)
                //   files /storage/emulated/0/JamsetPDF
////%%%%%%%%%%%%%%%%%%%%%%%%%% CARTELLA SU TCL NXTPaper (non ha una scheda e dunque questo è il percorso)
                  print('Bottone "Visualizza PDF" premuto. Percorso PDF da usare: $percorsoPdfDaAprire');
                  print('Pagina da aprire: $SelNumPag');
/// Inizia qui la chiamata a visualizza WEB un if per verifica con if (kIsWeb) {

                  Uri fileUri;
                  // NOTA: Platform.isWindows non è affidabile per il web per determinare il formato del path.
                  // Se il path viene DAL CSV ed è in formato Windows (P:\...), allora Uri.file con windows:true
                  // è corretto anche se Flutter è compilato per web, perché stai interpretando un path *esterno*.
                  // Tuttavia, l'accesso diretto a 'file:///' da un'app web è problematico.
                  // Questa logica è più pensata per mobile/desktop che lanciano un browser esterno.
                  if (!kIsWeb && Platform.isWindows) {
                    fileUri = Uri.file(percorsoPdfDaAprire, windows: true);
                  } else if (kIsWeb) {
                    // Per il web, se il localPdfPath è un path del filesystem locale dell'utente (es. "P:\..."),
                    // questo TENTATIVO di aprirlo direttamente in un browser esterno con file:///
                    // probabilmente fallirà a causa delle policy di sicurezza del browser.
                    // È più un costrutto per "se il browser *potesse* accedere a questo path locale".
                    // Per Windows path style sul web, è comunque utile windows:true per la corretta formattazione dell'URI
                    // nel caso (improbabile) che il browser lo permetta.
                    // Dovrai assicurarti che localPdfPath sia già URL encoded se contiene spazi, ecc.
                    // o che sia un path che Uri.file può gestire correttamente.
                    // Spesso, per i file locali sul web, l'utente li seleziona, e ottieni bytes o un blob URL.
                    print("Tentativo di costruire un URI file:// per il web. L'accesso diretto potrebbe essere bloccato dal browser.");
                    // Assumiamo che se è web e il path è stile Windows, vogliamo windows:true
                    // Questo è speculativo per il web con `file:///`
                    if (percorsoPdfDaAprire.contains(r'\') && percorsoPdfDaAprire.contains(':')) { // heuristica per path windows
                      fileUri = Uri.file(percorsoPdfDaAprire, windows: true);
                      percorsoPdfDaAprire = fileUri.toString();
                      print('Percorso PDF Rielaborato per WEB : $percorsoPdfDaAprire');
                    } else {
                      fileUri = Uri.parse(percorsoPdfDaAprire);// Se è già un URL o un path stile Unix

                      //percorsoPdfDaAprire = fileUri;
                      percorsoPdfDaAprire = fileUri.toString();
                      print('Percorso PDF Rielaborato per WEB : $percorsoPdfDaAprire');

                    }
                  }
                  final OpenResult result
                  = await OpenFilex.open(percorsoPdfDaAprire);

                  if (result.type != ResultType.done) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Impossibile aprire il PDF: ${result.message}')),
                      );
                    }
                  } else {
                    // Opzionale: puoi mostrare un messaggio di successo o non fare nulla
                    // perché l'app esterna si sarà aperta.
                  }

                  /// Finisce qui la chiamata a visualizza WEB un if per verifica con if (kIsWeb) {
                  // }
                  // Chiudi il dialogo e passa i dati necessari per l'azione successiva.
                  // Puoi passare una Map per strutturare meglio i dati.
                  Navigator.of(dialogContext).pop({
                    'azione': 'visualizza_pdf',
                    'percorso': percorsoPdfDaAprire,
                    // 'pagina': paginaDaAprire, // Se hai anche la pagina
                  });
                },
              ),
              // Se avevi un bottone Annulla e vuoi mantenerlo:
              // TextButton(
              //   child: const Text('Annulla Modifiche'), // O semplicemente 'Chiudi'
              //   onPressed: () {
              //     Navigator.of(dialogContext).pop(); // Chiude il dialogo senza fare altro
              //   },
              // ),
            ],

          );
        },
      );
    }

  }

  // Funzione per chiedere all'utente il path base (esempio)
// All'interno della classe _CsvViewerScreenState

  Future<void> _askForBasePath({
    String? currentTitolo,   // Parametro per il titolo del brano
    String? currentVolume,   // Parametro per il volume
    String? currentNumPag,    // Parametro per il numero di pagina
  }) async {
    if (kIsWeb) return;

    TextEditingController pathController = TextEditingController(text: _basePdfPath);
    String? newPath = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        String dialogTitleText; // Variabile locale per il testo del titolo

        // --- USA I PARAMETRI DELLA FUNZIONE QUI ---
        if (currentTitolo != null && currentTitolo.isNotEmpty) {
          // Se currentTitolo è fornito, usalo per un titolo più specifico
          String volumeInfo = "";
          if (currentVolume != null && currentVolume.isNotEmpty) {
            volumeInfo = "dal volume: $currentVolume";
            if (currentNumPag != null && currentNumPag.isNotEmpty) {
              volumeInfo += " (Pag. $currentNumPag)";
            }
          }
          dialogTitleText =
          'Brano Selezionato:\n'
              '$currentTitolo\n' // <-- USA currentTitolo
              '$volumeInfo\n\n'
              'Imposta il percorso base dei PDF:';
        } else if (_basePdfPath.isNotEmpty) {
          // Se non c'è un brano specifico, ma il path è già stato configurato
          dialogTitleText = 'Path base PDF attuale:\n$_basePdfPath\n\nModifica o conferma:';
        } else {
          // Caso base: nessuna info specifica, path non configurato
          dialogTitleText = 'Configura Percorso Base PDF';
        }

        return AlertDialog(
          title: Text(dialogTitleText), // Usa la variabile locale costruita
          content: TextField(
            controller: pathController,
            decoration: InputDecoration( // <-- RIMUOVI 'const'
                hintText:
                'Brano Selezionato:\n  Tit : $currentTitolo \n  Vol : $currentVolume \n  Pag : $currentNumPag \n'

              //decoration: const InputDecoration(hintText:
              //'Brano Selezionato:\n  Tit : $currentTitolo \n  Vol : $currentVolume \n  Pag : $currentNumPag \n'
              //"Es. C:\\Spartuti\\ o /sdcard/Spartiti/"
            ),
            autofocus: true,
            maxLines: null, // Permette più righe se il testo del titolo è lungo
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Annulla'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Salva'),
              onPressed: () {
                Navigator.of(context).pop(pathController.text);
              },
            ),
          ],
        );
      },
    );


    if (newPath != null && newPath.isNotEmpty) {
      // --- INIZIO MODIFICA ---
      // Creiamo una nuova variabile locale 'String' (non-nullable).
      // Dato che siamo dentro il blocco if, newPath qui è sicuramente non null
      // e non vuoto, quindi questa assegnazione è sicura.
      String pathDefinitivo = newPath;
      // --- FINE MODIFICA ---

      String S = Platform.isWindows ? '\\' : '/';
      if (!pathDefinitivo.endsWith(S)) { // Usiamo pathDefinitivo
        pathDefinitivo += S;          // Usiamo pathDefinitivo
      }

      setState(() {
        // Assegniamo pathDefinitivo (che è String) a _basePdfPath (che è String)
        _basePdfPath = pathDefinitivo; // <-- QUESTA DOVREBBE ESSERE LA NUOVA RIGA 295
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Percorso base PDF impostato a: $pathDefinitivo')), // Usiamo pathDefinitivo
        );
      }
    }
  }

   // @override
   // void initState() {
   //   super.initState();
      // NON aggiungere listener ai controller se il filtro è solo via bottone
    //}

    //@override
    //void dispose() {
    //  _cercaTitoloController.dispose();
    //  _cercaAutoreController.dispose();
    //  super.dispose();
    //}

  // qui c'era la vecchia logica con un solo campo@override
  @override
  Widget build(BuildContext context) {
    // Rivedi questo intero blocco con attenzione per errori di sintassi
    return
    ////INIZIO Immagine di background
      Stack(
      children: <Widget>[
      Positioned.fill( // Fa sì che l'immagine riempia lo Stack
        child: Image.asset(
          'assets/images/SherlockCerca2.png', // IL TUO PERCORSO PER L'IMMAGINE DI SHERLOCK
          fit: BoxFit.cover, // Prova diverse opzioni di BoxFit (cover, contain, fill, etc.)
          // per vedere quale si adatta meglio al tuo caso d'uso.
          // Opzionale: puoi aggiungere un colore di sovrapposizione per scurire/schiarire
          // o colorare l'immagine se il testo sopra è difficile da leggere.
          // color: Colors.black.withOpacity(0.3),
          // colorBlendMode: BlendMode.darken,
        ),
      ),
    ////FINE  Immagine di background

      Scaffold(
      appBar: AppBar(
        title: const Text('Spartiti Visualizzatore'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(120.0),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: _cercaTitoloController,
                  decoration: const InputDecoration(
                    labelText: 'Cerca per Titolo',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _cercaAutoreController,
                  decoration: const InputDecoration(
                    labelText: 'Cerca per Autore',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.search),
                  label: const Text('Filtra'),
                  onPressed: () {
                    _queryTitolo = _cercaTitoloController.text.toLowerCase();
                    _queryAutore = _cercaAutoreController.text.toLowerCase();
                    _filterData();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
     // body: _csvData.isEmpty
        body: _csvData.isEmpty ? _buildEmptyState() : _buildCsvList(),

    floatingActionButton: _csvData.isNotEmpty
          ? FloatingActionButton.extended(
        onPressed: _pickAndLoadCsv,
        label: const Text('Nuovo CSV'),
        icon: const Icon(Icons.file_upload),
      )
        : null,
      ),
      ],
    );
  }

// Estrai questi metodi per una migliore leggibilità del build
  Widget _buildEmptyState() {
    // ... la tua logica per lo stato vuoto
    return Container( // AVVOLGI CON CONTAINER
      color: Colors.blueGrey ,
      height: double.infinity,// IMPOSTA IL COLORE DI BACKGROUND DESIDERATO QUI
      // Puoi usare Colors.amber, Colors.tealAccent.withOpacity(0.5), ecc.
    child:Center(
      child: Padding(
    padding: const EdgeInsets.all(16.0),
    child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget> [
        Image.asset(
            'assets/images/SherlockCerca2.png',
            height: 400,
            width: 500,
            fit: BoxFit.contain ,
            errorBuilder: (context, error, stackTrace) {
              return const Text('Errore caricamento immagine SherlockCerca2');
            }
        ),

    const SizedBox(height: 16), // Aggiungi spazio se necessario
    const Text(
    'Carica un elenco Brani Musicali (CSV) per visualizzarne il contenuto.',
    textAlign: TextAlign.center,
    style: TextStyle(fontSize: 16),
    ),
        const SizedBox(height: 24),
        const Text(
          'Nessun file CSV caricato.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: const Icon(Icons.upload_file_outlined),
          label: const Text('Carica File CSV'),
          onPressed: _pickAndLoadCsv,
        ),

    ],
    ),
    ),
    ),

    );

  }

    Widget _buildCsvList() {
      // ... la tua logica per ListView.builder con _filteredCsvData
      return ListView.builder(
        itemCount: _filteredCsvData.length,
        itemBuilder: (context, index) {
          final row = _filteredCsvData[index];
          // USA _getValueFromRow per estrarre i dati in modo dinamico
          final String idBra = _getValueFromRow(row, keyIdBra);
          final String tipoMulti = _getValueFromRow(row, keyTipoMulti);
          final String tipoDocu = _getValueFromRow(row, keyTipoDocu);
          final String titolo = _getValueFromRow(row, keyTitolo);
          final String autore = _getValueFromRow(row, keyAutore);
          final String strumento = _getValueFromRow(row, keyStrumento);
          final String provenienza = _getValueFromRow(row, keyArchivioProvenienza);
          final String volume = _getValueFromRow(row, keyVolume);
          final String PercRadice = _getValueFromRow(row, keyPercRadice);
          final String PercResto = _getValueFromRow(row, keyPercResto);
          final String numPag = _getValueFromRow(row, keyNumPag);
          final String numOrig = _getValueFromRow(row, keyNumOrig);
          final String link = _getValueFromRow(row, keyPrimoLink, defaultValue: '');
          final Color rowBackgroundColor = index.isEven
              ? Colors.white
              : const Color(0xFFF0F4F8);
          const Color coloreTitolo = Colors.black87;
          const Color coloreDettagliPrimari = Colors.teal;
          const Color coloreDettagliSecondari = Colors.black54;

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 1.0),
            color: rowBackgroundColor,
            elevation: 1.0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 2.0),
              child: Row(
                children: [
                  Expanded(
                    child: ClipRect(
                      child: RichText(
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        text: TextSpan(
                          text: "$strumento ",
                          style: const TextStyle( // Aggiunto const
                            fontSize: 14,
                            color: Colors.red,
                          ),
                          children: <TextSpan>[
                            const TextSpan(text: 'Tit: ', style: TextStyle(fontWeight: FontWeight.w500, color: coloreDettagliSecondari)), // Aggiunto const
                            TextSpan(text: titolo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: coloreTitolo)), // Aggiunto const
                            if (numPag.isNotEmpty) ...[
                              const TextSpan(text: ' A Pag: ', style: TextStyle(fontWeight: FontWeight.w500, color: coloreDettagliSecondari)), // Aggiunto const
                              TextSpan(text: numPag, style: const TextStyle(fontWeight: FontWeight.normal, color: coloreDettagliPrimari)), // Aggiunto const
                            ],
                            if (volume.isNotEmpty) ...[
                              const TextSpan(text: ' del Volume: ', style: TextStyle(fontWeight: FontWeight.w500, color: coloreDettagliSecondari)), // Aggiunto const
                              TextSpan(text: volume, style: const TextStyle(fontWeight: FontWeight.normal, color: coloreDettagliPrimari)), // Aggiunto const
                            ],
                            if (provenienza.isNotEmpty) ...[
                              const TextSpan(text: ' Prov: ', style: TextStyle(fontWeight: FontWeight.w500, color: coloreDettagliSecondari)), // Aggiunto const
                              TextSpan(text: provenienza, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: coloreTitolo)), // Aggiunto const
                            ],
                            const TextSpan(text: ' Mat: ', style: TextStyle(fontWeight: FontWeight.w500, color: coloreDettagliSecondari)), // Aggiunto const
                            TextSpan(text: tipoMulti.isNotEmpty ? tipoMulti : "N/D", style: const TextStyle(fontWeight: FontWeight.normal, color: coloreDettagliPrimari)), // Aggiunto const
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (titolo != 'N/D' && volume != 'N/D')
                    IconButton(
                      icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.redAccent),
                      tooltip: 'Apri File',
                      onPressed: () {
                        _handleOpenPdfAction(
                          titolo: titolo,
                          volume: volume,
                          NumPag: numPag,
                          NumOrig: numOrig,
                          idBra: idBra,
                          TipoMulti: tipoMulti,
                          TipoDocu: tipoDocu,
                          strumento: strumento,
                          Provenienza: provenienza,
                          link: link,
                        );
                      },
                    ),
                  if (!kIsWeb)
                    IconButton(
                      icon: const Icon(Icons.settings_outlined),
                      tooltip: 'Configura Path PDF',
                      onPressed: () {
                        _askForBasePath(
                          currentTitolo: titolo,
                          currentVolume: volume,
                          currentNumPag: numPag,
                        );
                      },
                    ),
                ],
              ),
            ),
          );
        },
      ); // Fine del ListView.builder
    } // Fine del metodo _buildCsvList
 // print("Fine caricamento Lista Brani");
}