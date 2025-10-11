// lib/screens/csv_viewer_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'dart:convert';
// Rimuovi questo se non lo usi più: import 'package:jamset/screens/device_selection_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
//Pacchetti per apertura files (PDF o altri) e per i percorsi
// Per aprire file
// Per aprire URL
// Per manipolare i percorsi, aggiungi path: ^X.Y.Z a pubspec.yaml
// ... altri import
import 'package:url_launcher/url_launcher.dart'; // NECESSARIO PER url_launcher per aprire file su Browser
import 'package:jamset/file_path_validator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http; // Aggiungi questo import per le chiamate HTTP

class CsvViewerScreen extends StatefulWidget {
  const CsvViewerScreen({super.key});

  @override
  State<CsvViewerScreen> createState() => _CsvViewerScreenState();
} // <--- Assicurati che questa parentesi chiuda CsvViewerScreen

class _CsvViewerScreenState extends State<CsvViewerScreen>
{
  // Chiavi univoche per salvare il percorso radice per ogni piattaforma
  static const String _windowsBasePathKey = 'base_pdf_path_windows';
  static const String _mobileBasePathKey = 'base_pdf_path_mobile';

// Questa variabile conterrà il percorso corretto per la piattaforma corrente
  String? _basePdfPath;

  //TextEditingController _searchController = TextEditingController();final TextEditingController _cercaTitoloController = TextEditingController();
  final TextEditingController _cercaTitoloController = TextEditingController();
  final TextEditingController _cercaAutoreController = TextEditingController();
  final TextEditingController _cercaProvenienzaController = TextEditingController(); // <--- Dichiarazione
  final TextEditingController _cercaVolumeController = TextEditingController();
  final TextEditingController _cercaTipoMultiController = TextEditingController();
  final TextEditingController _cercaStrumentoController = TextEditingController();
  List<List<dynamic>> _csvData = [];
  List<List<dynamic>> _filteredCsvData = [];
  String _queryTitolo = '';
  String _queryAutore = '';
  String _queryProvenienza = ''; // <--- Dichiarazione
  String _queryVolume = '';
  String _queryTipoMulti = '';
  String _queryStrumento = '';
  String Laricerca ='';
  final List<String> _opzioniProvenienza = [ // <--- Dichiarazione
    'Aebers',
    'Bigband',
    'Griglie',
    'Hal Leonard',
    'BiaB',
    'Realbook',
    'Soli',
  ];
  final List<String> _opzioniTipoMulti = [ // <--- Dichiarazione
    'BiaB',
    'Com',
    'Dir',
    'Fin',
    'Pdf',
    'Xml',
    'Sib',
    'Mid',
    'Mp3',
  ];
  final List<String> _opzioniStrumento = [ // <--- DICHIARAZIONE E INIZIALIZZAZIONE
    'C',
    'Bb',
    'Eb',
    'BAS', // Assumo sia per 'Basso'
    // Aggiungi altre tonalità/strumenti se necessario (es. 'F' per corno francese, ecc.)
  ];
//  String _basePdfPath = ""; // Variabile per memorizzare il path base dei PDF
  // NUOVE VARIABILI PER LA MAPPATURA DINAMICA DELLE COLONNE
  final bool _csvHasHeaders = true; // o come la gestisci
  Map<String, int> _columnIndexMap = {};
  List<String> _csvHeaders = []; // Per tenere traccia delle intestazioni effettive
  @override
  void initState() {
    super.initState();
  }
//  @override
  @override
  void dispose() {
    // ... dispose degli altri controller ...
    _cercaTitoloController.dispose();
    _cercaAutoreController.dispose();
    _cercaProvenienzaController.dispose();
    _cercaVolumeController.dispose();
    _cercaTipoMultiController.dispose();
    _cercaStrumentoController.dispose();
    super.dispose();
  }
  Future<void> _loadPreferences()
  async
  {
    final prefs = await SharedPreferences.getInstance();

    // Scegli quale chiave caricare in base al sistema operativo
    String keyToLoad;
    String defaultValue;

    if (Platform.isWindows) {
      keyToLoad = _windowsBasePathKey;
      defaultValue = 'C:\\JamsetPDF'; // Fornisci un default sensato per Windows
    } else if (Platform.isAndroid || Platform.isIOS) {
      keyToLoad = _mobileBasePathKey;
      defaultValue = '/storage/emulated/0/JamsetPDF'; // Fornisci un default sensato per Mobile
    } else {
      // Gestisci altre piattaforme o imposta un default generico
      keyToLoad = 'base_pdf_path_generic';
      defaultValue = '/';
    }

    // Carica il valore e imposta il default se non esiste
    setState(() {
      _basePdfPath = prefs.getString(keyToLoad) ?? defaultValue;
    });

    print("Preferenze caricate per ${Platform.operatingSystem}. Percorso Radice: $_basePdfPath");
  }
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
  }) async
  {
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
    String SelBasePdfPath = _basePdfPath ?? ''; // Se _basePdfPath è null, usa una stringa vuota
    String SelfinalPath = finalPath;
    String Prova2 = 'Prova2';
    String nomeFile;
    String nomeFileEstratto = ""; // Variabile per il nome file estratto da SelLink
    String percorsoDirectoryEstratta = ""; // Variabile per la directory estratta da SelLink
    String percorsoPdfDaAprireNelDialogo = ""; // Questa sarà la variabile che contiene il path WEB da aprire
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
    print("InizioAzione Chiama Apertura PDF _handleOpenPdfAction"); // con parametri
    print("Stringa originale (link): $link");
    print("Percorso pulito: $SelPercorso");
    print("Nomefile estratto (CON estensione) campo nomeFile: $nomeFile"); // Dovrebbe essere COLOBK.PDF
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Dati per PDF: Titolo: $titolo, Volume: $volume, Pag: $NumPag. Path base: $_basePdfPath'),
        //duration: const Duration(seconds: 15),
      ),
    );
//Da qui emettere un nuovo dialogBox o schermo per verificare gli elementi per costruire il giusto nome di FilePd
// Titolo ( da ewsporre ) Volume (da esporre) NumPag (da potere variara) Percorso (da modificare) Valore iniziale =

    Prova2 =SelPercorso + nomeFile;

    print('Rientro dalla validazione nuovo Prova2: $Prova2 '); // Non ci sono backslash, quindi si presume che SelPercorso sia solo il nome del file (con o senza estensione)
  


    SelBasePdfPath = r'c:\Fantasia\';
    print('--Prova2-- Campo composto da SelPercorso + nomeFile:   $Prova2');
    print ('--SelBasePdfPath--Directory da variare:  $SelBasePdfPath');
    print('--SelTitolo--TitoloBrano: $SelTitolo');
    print('--SelStrumento--Strumento contiene: $SelStrumento');
    print('--SelVolume--Volume: $SelVolume');
// --- INIZIO NUOVO AlertDialog ---
    // (Questa è circa la tua riga 213, dopo i print)
    if (mounted) {
      // Controller se avevi campi editabili prima, se ora sono solo visualizzabili
      // e selezionabili, i controller potrebbero non essere necessari per questi specifici campi.
      // Ma se altri campi sono ancora editabili (come nel mio esempio precedente),
      // i loro controller rimangono.
      TextEditingController searchController = TextEditingController(text: Prova2); // <--- INIZIALIZZA QUI
      await showDialog
        (
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Dettagli Brano Selezionato'), // O usa SelectableText anche qui se vuoi
            content: SingleChildScrollView(
              child: ListBody(
                children: <Widget>[
                  const Text("--SelTitolo--Titolo:") , //
                  SelectableText(SelTitolo.isNotEmpty ? SelTitolo : "N/D"),
                  const SizedBox(height: 8),

                  const Text("--SelPercorso--Cartella SelPercorso:"), // Etichetta
                  SelectableText(SelPercorso.isNotEmpty ? SelPercorso : "N/D"),
                  const SizedBox(height: 8),

                  // const Text("Percorso Finale:"), // Etichetta
                  // SelectableText(SelPercorso.isNotEmpty ? SelPercorso : "N/D"),
                  // const SizedBox(height: 8),

                  const Text("--nomeFile-- Nome del File: "), // Etichetta
                  SelectableText(nomeFile.isNotEmpty ? nomeFile : "N/D"),
                  const SizedBox(height: 8),

                  const Text('--nomeFileDaVolume--Altro Nome del File: "'), // Etichetta
                  SelectableText(nomeFileDaVolume.isNotEmpty ? nomeFileDaVolume : "N/D"),
                  const SizedBox(height: 8),

                  const Text("--SelNumPag-- Pagina:"), // Etichetta
                  SelectableText(SelNumPag.isNotEmpty ? SelNumPag : "N/D"),
                  const SizedBox(height: 8),


                  const Text("--SelLink--Link Originale:"), // Etichetta
                  SelectableText(SelLink.isNotEmpty ? SelLink : "N/A"),
                  const SizedBox(height: 8),
                  const Text("--Prova2-- Il percorso da attivare:"), // Etichetta
                  TextField(
                    controller: searchController, // _searchController ora contiene il testo di Prova2
                    decoration: InputDecoration(
                      // Se vuoi ancora usare Prova2 nell'hintText, va bene, ma
                      // l'hintText appare solo se il campo è vuoto.
                      // Il testo effettivo nel campo sarà quello di Prova2 grazie al controller.
                      hintText: '--Prova2--Nome del PDF Proposto (inizialmente: $Prova2)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),

                    ),
                  ),


                ],
              ),

            ),
            /////Modifica proposta
            // ... all'interno del builder del tuo showDialog ...
            actions: <Widget>[
              TextButton(
                child: const Text('Annulla'),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
              ),
              ElevatedButton(
                child: const Text('Visualizza PDF'),
                onPressed: () async
                {
// Il controller 'searchController' è quello che hai già definito nel dialogo.
                  String percorsoModificato = searchController.text;
                  print('Visualizza PDF Percorso Modificato: $percorsoModificato');
                  print('---Prova2-- Campo composto che compare sul da SelPercorso + nomeFile:   $Prova2');
                  final separatoreRegExp = RegExp(r'[/\\]');
                  int ultimoSeparatoreIndex = percorsoModificato.lastIndexOf(separatoreRegExp);
                  String PercorsoPulito;
                  String directoryBaseFinale;
                  directoryBaseFinale = '';
                  int indiceSequenza = Prova2.indexOf(":\\");
                  int indiceFine = Prova2.indexOf(nomeFileDaVolume);
                  if (indiceSequenza != -1 && indiceFine != -1) {
                    // 3. Estrai la sottostringa dall'inizio (indice 0) fino all'indice della sequenza trovata
                    directoryBaseFinale = Prova2.substring(0, indiceSequenza+1);
                    PercorsoPulito= Prova2.substring(indiceSequenza+1, indiceFine);
                  } else {
                    // Fallback: se la sequenza non esiste, gestisci il caso come preferisci.
                    // Potresti assegnare un valore di default o l'intera stringa.
                    directoryBaseFinale = " "; // o Prova2;
                    PercorsoPulito= Prova2;
                  }
/////// elenco dei campi d apassare a _apriFileUniversale
                  //directoryBaseFinale
                  //   required String basePathDaDati,   preso da directoryBaseFinale// Es. 'C:' dal CSV/DB
                  //   required String subPathDaDati,    preso da PercorsoPulito// Es. '\JamsetPDF\Real Books\' dal CSV/DB
                  //   required String fileNameDaDati,   preso da nomeFileDaVolume // Es. 'mio_file.pdf'
                  print('----------  Parametri per _apriFileUniversale');
                  print('A  Percorso dal TextField: $percorsoModificato');
                  print('A1 Directory Base finale: $directoryBaseFinale');
                  print('A2 Directory Base dedotta: $PercorsoPulito');
                  print('A3 Nome File dedotto: $nomeFileDaVolume');

// 3. COSTRUZIONE DEL PERCORSO FINALE IN BASE ALLA PIATTAFORMA
                  String percorsoDaAprire;
                  percorsoDaAprire = percorsoModificato;
                  /// verificare se percorsoModificato viene ricoperto
                  print('Percorso modificato da aprire: $percorsoModificato');
// chiamata a _apriFileUniversale per per la costruzione e controllo di esistenza del file indicato
// con parametri  basePathDati, subPath
                  // 2. Chiama la funzione universale, fornendo le azioni da compiere
                  await _apriFileUniversale(
                    basePathDaDati: directoryBaseFinale,
                    subPathDaDati: PercorsoPulito,
                    fileNameDaDati: nomeFileDaVolume,

                    // --- AZIONE IN CASO DI SUCCESSO ---
                    ///METTERE qui il campo di testo editabile hintText ? forse meglio quando rientra dalla prima diramazione
                    inCasoDiSuccesso: (percorsoDelFile) {
                      // 'percorsoDelFile' è la stringa che la tua funzione ha validato
                      // (es. "C:\JamsetPDF\..." su Windows o "http://.../..." sul web)

                      print("SUCCESSO dalla chiamata! Il file si trova in: $percorsoDelFile");
                      percorsoDaAprire= percorsoDelFile;
                      if (mounted) { // Assicurati che il widget sia ancora nell'albero
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('File trovato in: $percorsoDelFile')),
                        );
                      }
                      // Ora puoi usare il percorso per aprire il tuo viewer
                      // Esempio:
                      // _apriPdfViewer(percorsoDelFile, paginaDaAprire);
                    },

                    // --- AZIONE IN CASO DI FALLIMENTO ---
                    inCasoDiFallimento: (percorsoTentato) {
                      // 'percorsoTentato' è l'ultimo percorso che la funzione ha provato a usare
                      percorsoDaAprire= percorsoTentato;
                      print("FALLIMENTO dalla chiamata! Impossibile trovare il file in: $percorsoTentato");

                      // Mostra un messaggio di errore all'utente
                      if (mounted) { // Assicurati che il widget sia ancora nell'albero
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('File non trovato in: $percorsoTentato')),
                        );
                      }
                    },
                  );
///// mettiamo qui il percorso da aprire che ritorna alla chiamata
                  Prova2 = percorsoDaAprire;
                  print("Procedura di Prima  Verifica file terminata.");
// 4. APERTURA EFFETTIVA DEL FILE/URL

                  print("Procedura di verifica esistenza. Il percorso da aprire è: $Prova2");


// 5. Chiudi il dialogo dopo l'azione

                  //Togliere se si vuole uscire dalla dialog
                  //  if(mounted) Navigator.of(dialogContext).pop();

// --- FINE LOGICA ---
                },
              ),
              //// Nuovo bottone di sola verifica esistenza del file (riga 404)
              ElevatedButton(
                child: const Text('Verifica di Esistenza'),
                onPressed: () async
                {
// Il controller 'searchController' è quello che hai già definito nel dialogo.
                  String percorsoModificato = searchController.text;
                  print('Verifica di Esistenza Percorso Modificato: $percorsoModificato');
                  print('---Prova2-- Campo composto che compare sul da SelPercorso + nomeFile:   $Prova2');
                  final separatoreRegExp = RegExp(r'[/\\]');
                  int ultimoSeparatoreIndex = percorsoModificato.lastIndexOf(separatoreRegExp);
                  String PercorsoPulito;
                  String directoryBaseFinale;
                  directoryBaseFinale = '';
                  int indiceSequenza = Prova2.indexOf(":\\");
                  int indiceFine = Prova2.indexOf(nomeFileDaVolume);
                  if (indiceSequenza != -1 && indiceFine != -1) {
                    // 3. Estrai la sottostringa dall'inizio (indice 0) fino all'indice della sequenza trovata
                    directoryBaseFinale = Prova2.substring(0, indiceSequenza+1);
                    PercorsoPulito= Prova2.substring(indiceSequenza+1, indiceFine);
                  } else {
                    // Fallback: se la sequenza non esiste, gestisci il caso come preferisci.
                    // Potresti assegnare un valore di default o l'intera stringa.
                    directoryBaseFinale = " "; // o Prova2;
                    PercorsoPulito= Prova2;
                  }
/////// elenco dei campi d apassare a _VerificaFile
                  //directoryBaseFinale
                  //   required String basePathDaDati,   preso da directoryBaseFinale// Es. 'C:' dal CSV/DB
                  //   required String subPathDaDati,    preso da PercorsoPulito// Es. '\JamsetPDF\Real Books\' dal CSV/DB
                  //   required String fileNameDaDati,   preso da nomeFileDaVolume // Es. 'mio_file.pdf'
                  print('----------  Parametri per _VerificaFile');
                  print('A  Percorso dal TextField: $percorsoModificato');
                  print('A1 Directory Base finale: $directoryBaseFinale');
                  print('A2 Directory Base dedotta: $PercorsoPulito');
                  print('A3 Nome File dedotto: $nomeFileDaVolume');

// 3. COSTRUZIONE DEL PERCORSO FINALE IN BASE ALLA PIATTAFORMA
                  String percorsoDaAprire;
                  percorsoDaAprire = percorsoModificato;
                  /// verificare se percorsoModificato viene ricoperto
                  print('Chiamo VerificaFile: $directoryBaseFinale $PercorsoPulito $nomeFileDaVolume');
// chiamata a _VerificaFile per per la costruzione e controllo di esistenza del file indicato
// con parametri  basePathDati, subPath
                  // 2. Chiama la funzione universale, fornendo le azioni da compiere
                  await _VerificaFile(
                    basePathDaDati: directoryBaseFinale,
                    subPathDaDati: PercorsoPulito,
                    fileNameDaDati: nomeFileDaVolume,

                    // --- AZIONE IN CASO DI SUCCESSO ---
                    ///METTERE qui il campo di testo editabile hintText ? forse meglio quando rientra dalla prima diramazione
                    inCasoDiSuccesso: (percorsoDelFile) {
                      // 'percorsoDelFile' è la stringa che la tua funzione ha validato
                      // (es. "C:\JamsetPDF\..." su Windows o "http://.../..." sul web)

                      print("SUCCESSO dalla chiamata! Il file si trova in: $percorsoDelFile");
                      percorsoDaAprire= percorsoDelFile;
                      if (mounted) { // Assicurati che il widget sia ancora nell'albero
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('File trovato in: $percorsoDelFile')),
                        );
                      }
                      // Ora puoi usare il percorso per aprire il tuo viewer
                      // Esempio:
                      // _apriPdfViewer(percorsoDelFile, paginaDaAprire);
                    },

                    // --- AZIONE IN CASO DI FALLIMENTO ---
                    inCasoDiFallimento: (percorsoTentato) {
                      // 'percorsoTentato' è l'ultimo percorso che la funzione ha provato a usare
                      percorsoDaAprire= percorsoTentato;
                      print("FALLIMENTO dalla chiamata! Impossibile trovare il file in: $percorsoTentato");

                      // Mostra un messaggio di errore all'utente
                      if (mounted) { // Assicurati che il widget sia ancora nell'albero
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('File non trovato in: $percorsoTentato')),
                        );
                      }
                    },
                  );
///// mettiamo qui il percorso da aprire che ritorna alla chiamata
                  Prova2 = percorsoDaAprire;
                  print("Procedura di Prima  Verifica file terminata.");
                  print('Il percorso da aprire sarà: $Prova2');
// 4. APERTURA EFFETTIVA DEL FILE/URL

                  // Prova2 = finalUriToLaunch.toString();
                  print("Qui la futura chiamata alla funzione di apertura del file");
                  print("Il percorso da aprire è: $Prova2");


// 5. Chiudi il dialogo dopo l'azione

                  //Togliere se si vuole uscire dalla dialog
                  //  if(mounted) Navigator.of(dialogContext).pop();

// --- FINE LOGICA ---
                },
              ),
              //// Nuovo bottone di sola verifica esistenza del file

            ],

            /////Modifica proposta
          );
        },
      );
    }

  }
////// percorso per la costruzione e controllo di esistenza del file indicato con dati basePathDati, subPathDati, fileNameDati
  Future<void> _apriFileUniversale({
    required String basePathDaDati,   // Es. 'C:' dal CSV/DB
    required String subPathDaDati,    // Es. '\JamsetPDF\Real Books\' dal CSV/DB
    required String fileNameDaDati,   // Es. 'mio_file.pdf'
    required Function(String percorsoTrovato) inCasoDiSuccesso,
    required Function(String percorsoTentato) inCasoDiFallimento,

    //required String PercorsoCompleto, // Es. 'C:\JamsetPDF\Real Books\mio_file.pdf'

  }) async
  {

    String percorsoFinaleDaAprire;
    bool risorsaEsiste = false;

    // -----------------------------------------------------------------
    // FASE 1: GESTIONE PIATTAFORME NATIVE (Windows, Android, etc.)
    // Trasformazione e verifica di esistenza del percorso in base alla piattaforma.
    // -----------------------------------------------------------------
    if (!kIsWeb) {
      print("Siamo su una piattaforma nativa. Verifico il file system locale.");

      // Qui va la logica di "traduzione" del basePath per la piattaforma corrente
      String basePathTecnico = basePathDaDati;
      if (Platform.isAndroid || Platform.isIOS) {
        // Esempio: Sostituisci il percorso di Windows con quello corretto per Android
        basePathTecnico = '/storage/emulated/0/JamsetPDF';
//      basePathTecnico = '/storage/emulated/0/';
      } else
      {
        //// Trattamento Windows o linux/Mac
      }
      // Chiama il validatore nativo
      FilePathResult risultatoNativo = await ValidaPercorso.checkGenericFilePath(
        basePath: basePathTecnico,
        subPath: subPathDaDati,
        fileNameWithExtension: fileNameDaDati,
      );

      risorsaEsiste = risultatoNativo.isSuccess;
      percorsoFinaleDaAprire = risultatoNativo.fullPath ?? "";

      // -----------------------------------------------------------------
      // FASE 2: GESTIONE PIATTAFORMA WEB
      // -----------------------------------------------------------------
    } else
    {
      print("Siamo su una piattaforma Web. Trasformo il percorso in URL.");

// 1. Definisci l'URL di base del tuo server dove si trovano i PDF.
//    QUESTO È IL DATO DA CONFIGURARE.
      //String baseUrlWeb = "http://192.168.1.100/spartiti"; // Esempio con un IP locale
      //////////IMPORTANTISSIMO LA RADICE CHE VIENE PASSATA AL FILE finale
      String baseUrlWeb = "file:///P:"; // Esempio con file locale

// 2. RICOSTRUISCI IL PERCORSO RELATIVO COMPLETO
//    Uniamo il 'subPath' e il 'fileName' per ricreare il percorso relativo come 'Real Books\Hal Leonard...'.
//    Questo è il passo FONDAMENTALE che mancava.
      String percorsoRelativoCompleto = '$subPathDaDati$fileNameDaDati';
      print("Percorso relativo completo dai dati: $percorsoRelativoCompleto");

// 3. PULISCI IL PERCORSO RELATIVO PER RENDERLO UN URL VALIDO
//    - Sostituisci tutti i backslash '\' con gli slash '/'
//    - Codifica gli spazi e altri caratteri speciali (FONDAMENTALE!)
      String percorsoUrlSafe = Uri.encodeFull(percorsoRelativoCompleto.replaceAll(r'\', '/'));

// Rimuoviamo un eventuale slash iniziale per evitare URL doppi come "...spartiti//Real Book..."
      if (percorsoUrlSafe.startsWith('/')) {
        percorsoUrlSafe = percorsoUrlSafe.substring(1);
      }
      print("Percorso relativo pulito e codificato per URL: $percorsoUrlSafe");

// 4. COSTRUISCI L'URL FINALE
      /////COMPONE IL PERCORSO FINALE da verificare
      percorsoFinaleDaAprire = "$baseUrlWeb/$percorsoUrlSafe";
      /// si potrebbe mettere qui anche il numero pagina se non nullo ma forse ci vuole anhe quel parametro da passare alla funzione
      ///
      print("URL finale costruito: $percorsoFinaleDaAprire");

// 5. Verifica l'esistenza della risorsa web (il resto del codice rimane uguale)
      try {
        final response = await http.head(Uri.parse(percorsoFinaleDaAprire));
        if (response.statusCode == 200) {
          risorsaEsiste = true;
          print("SUCCESSO: La risorsa web esiste.");
        } else {
          risorsaEsiste = false;
          print("ERRORE: La risorsa web ha restituito lo stato ${response.statusCode}.");
        }
      } catch (e) {
        risorsaEsiste = false;
        print("ERRORE di rete durante la verifica dell'URL: $e");
      }
    }

    // -----------------------------------------------------------------
    // FASE FINALE: APERTURA
    // -----------------------------------------------------------------
    if (risorsaEsiste) {
      print("Risorsa trovata in '$percorsoFinaleDaAprire'. Procedo con l'apertura...");
      // Qui inserisci la tua logica per aprire il PDF viewer
      // es: _apriPdfViewer(percorsoFinaleDaAprire, pagina);
    } else {
      print("Fallimento: la risorsa non è stata trovata o non è accessibile.");
      // Mostra un messaggio di errore all'utente
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File non trovato in: $percorsoFinaleDaAprire')),
      );
    }
//  PercorsoCompleto=percorsoFinaleDaAprire
  }
  ///  Nuovo verificatore dell'esistenza del file'
  Future<void> _VerificaFile({
    required String basePathDaDati,   // Es. 'C:' dal CSV/DB
    required String subPathDaDati,    // Es. '\JamsetPDF\Real Books\' dal CSV/DB
    required String fileNameDaDati,   // Es. 'mio_file.pdf'
    required Function(String percorsoTrovato) inCasoDiSuccesso,
    required Function(String percorsoTentato) inCasoDiFallimento,

    //required String PercorsoCompleto, // Es. 'C:\JamsetPDF\Real Books\mio_file.pdf'

  }) async
  {

    String percorsoFinaleDaAprire;
    bool risorsaEsiste = false;
    // -----------------------------------------------------------------
    // FASE 1: GESTIONE PIATTAFORME NATIVE (Windows, Android, etc.)
    // Trasformazione e verifica di esistenza del percorso in base alla piattaforma.
    // -----------------------------------------------------------------
    print("Siamo su una piattaforma nativa. Verifico il file system locale.");
    // Qui va la logica di "traduzione" del basePath per la piattaforma corrente
    String basePathTecnico = basePathDaDati;
    if (Platform.isAndroid || Platform.isIOS) {
      // Esempio: Sostituisci il percorso di Windows con quello corretto per Android
      basePathTecnico = '/storage/emulated/0/JamsetPDF';
//      basePathTecnico = basePdfPathAndroid;
    }
    if (Platform.isWindows ) {
      // Esempio: Sostituisci il percorso di Windows con quello corretto per Android
      basePathTecnico = r'C:\JamsetPDF';
//      basePathTecnico = basePdfPathWindows;
    }
    // Chiama il validatore nativo
    print('Ricerca del file: $basePathTecnico $subPathDaDati $fileNameDaDati ');
    FilePathResult risultatoNativo = await ValidaPercorso.checkGenericFilePath(
      basePath: basePathTecnico,
      subPath: subPathDaDati,
      fileNameWithExtension: fileNameDaDati,
    );

    risorsaEsiste = risultatoNativo.isSuccess;
    percorsoFinaleDaAprire = risultatoNativo.fullPath ?? "";

    // -----------------------------------------------------------------
    // FASE 2: GESTIONE PIATTAFORMA WEB
    // -----------------------------------------------------------------


    // -----------------------------------------------------------------
    // FASE FINALE: APERTURA
    // -----------------------------------------------------------------
    if (risorsaEsiste) {
      print("Risorsa trovata in '$percorsoFinaleDaAprire'. Procedo con l'apertura...");

      // Qui inserisci la tua logica per aprire il PDF viewer
      // es: _apriPdfViewer(percorsoFinaleDaAprire, pagina);
    } else {
      print("Fallimento: la risorsa non è stata trovata o non è accessibile.");
      // Mostra un messaggio di errore all'utente
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File non trovato in: $percorsoFinaleDaAprire')),
      );
    }
    //Prova2 = percorsoFinaleDaAprire;
  }
  /// Metodo helper che raccoglie i dati e CHIAMA ValidaPercorso.
  Future<FilePathResult> _validateAndShowResult({
    required BuildContext dialogContext,
    required String basePathFromInput,
    String? subPathComponent,
    String? fileNameComponent,
    required String numeroPaginaFromCsv,
  }) async
  {
    // 1. Chiamata alla VERA funzione di validazione nel file esterno
    final FilePathResult validationResult = await ValidaPercorso.checkGenericFilePath(
      basePath: basePathFromInput,
      subPath: subPathComponent,
      fileNameWithExtension: fileNameComponent ?? '', // Passa stringa vuota se null

      // NumeroPagina: numeroPaginaFromCsv,
    );
    // 2. Mostra il risultato nello SnackBar, usando il context corretto
        {
// ---- INIZIO MODIFICA ----

// 1. Costruisci un messaggio più dettagliato per il debug
      final String snackBarMessage;
      final String? generatedPath = validationResult.fullPath;

      if (generatedPath != null && generatedPath.isNotEmpty) {
// Se il percorso è stato generato, mostralo sempre.
        snackBarMessage = "${validationResult.message}\n\nPercorso Verificato:\n$generatedPath";
      } else {
// Altrimenti, mostra solo il messaggio di errore originale.
        snackBarMessage = validationResult.message;
      }

// 2. Usa il nuovo messaggio nel Text del tuo SnackBar
      ScaffoldMessenger.of(dialogContext).showSnackBar(
        SnackBar(
          content: Text(snackBarMessage), // <-- USA IL NUOVO MESSAGGIO DETTAGLIATO
          backgroundColor: validationResult.isSuccess ? Colors.green : Colors.red,
          duration: const Duration(seconds: 20), // Aumenta la durata per avere il tempo di leggere
          action: SnackBarAction(
            label: 'OK',
            onPressed: () {
              ScaffoldMessenger.of(dialogContext).hideCurrentSnackBar();
            },
          ),
        ),
      );
      // 3. TERZA PARTE: Restituisce il risultato della validazione
      return validationResult;
// ---- FINE MODIFICA ----
    }
    // 3. (Opzionale) Se la validazione ha successo, apri il PDF
    if (validationResult.isSuccess && validationResult.fullPath != null) {
      await _openPdfInExternalBrowser(validationResult.fullPath!, numeroPaginaFromCsv);
    }
  }

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
      String headerFromFile = headers[i].toString().trim(); // Potresti voler fare anche .toLowerCase()
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

///////////////FINE NUOVO Verifica E Apertura universale del PDF su Browser
  Future<void> _openPdfInExternalBrowser(String localPdfPath, String pageNumberStr)
  async { // Rinominata per chiarezza e per evitare conflitti se ci fosse già openPdfInBrowser
    int? pageNumber = int.tryParse(pageNumberStr);
    if (pageNumber == null || pageNumber < 1) {
      print('Numero di pagina non valido: $pageNumberStr');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Numero di pagina non valido: $pageNumberStr')),
        );
      }
      //  return;
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
      /// Verificare i valori prevalenti nei file csv forniti che dovrebbero possedere
      /// il titolo e il numero pagina e anche il volume(non al'interno del CSV) forse nel DB.

    }
    return defaultValue; // Valore di fallback se tutto il resto fallisce
  }

  //Future<void> (_pickAndLoadCsv) async
  Future<void> _pickAndLoadCsv()
  async
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
          } catch (e)
          {
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
      }
      else {
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

  void _filterData() {
    // Le query _queryTitolo, _queryAutore, e _queryProvenienza sono già state aggiornate
    // e convertite in minuscolo dal onPressed del bottone "Filtra".

    setState(()
    {
      // Se TUTTI i campi di ricerca sono vuoti, mostra tutti i dati
      if (_queryTitolo.isEmpty && _queryAutore.isEmpty && _queryProvenienza.isEmpty
          && _queryVolume.isEmpty && _queryTipoMulti.isEmpty && _queryStrumento.isEmpty) { // <--- AGGIUNTO _queryProvenienza
        _filteredCsvData = List.from(_csvData);
      } else {
        _filteredCsvData = _csvData.where((row) { // Assicurati che _csvData sia la lista completa non filtrata
          // Estrai i valori dalla riga usando le chiavi
          // --- INIZIO LOGICA Titolo ---
          final String titoloInRow = _getValueFromRow( row,keyTitolo,defaultValue: '',).toLowerCase();
          // --- INIZIO LOGICA VOLUME ---
          final String volumeInRow = _getValueFromRow( row,keyVolume,defaultValue: '',).toLowerCase();
          // --- INIZIO LOGICA TIPO MULTI
          final String tipoMultiInRow = _getValueFromRow( row,keyTipoMulti,defaultValue: '',).toLowerCase();
          // --- INIZIO LOGICA STRUMENTO ---
          final String strumentoInRow = _getValueFromRow( row,keyStrumento,defaultValue: '',).toLowerCase();
          // --- INIZIO LOGICA AUTORE
          final String autoreInRow = _getValueFromRow( row,keyAutore,defaultValue: '',).toLowerCase();
          // --- INIZIO LOGICA PROVENIENZA ---
          final String provenienzaInRow = _getValueFromRow( row,keyArchivioProvenienza,defaultValue: '',).toLowerCase();

          // Logica di filtro:
          bool corrispondeTitolo = true;
          if (_queryTitolo.isNotEmpty) {
            corrispondeTitolo = titoloInRow.contains(_queryTitolo);
          }

          bool corrispondeAutore = true;
          if (_queryAutore.isNotEmpty) {
            corrispondeAutore = autoreInRow.contains(_queryAutore);
          }

          // --- INIZIO CONFRONTO PROVENIENZA ---
          bool corrispondeProvenienza = true; // Assume vero se il campo di ricerca provenienza è vuoto
          if (_queryProvenienza.isNotEmpty) {
            corrispondeProvenienza = provenienzaInRow.contains(_queryProvenienza);
          }
          // --- FINE CONFRONTO PROVENIENZA ---
          // --- INIZIO CONFRONTO VOLUME ---
          bool corrispondeVolume = true; // Assume vero se il campo di ricerca volume è vuoto
          if (_queryVolume.isNotEmpty) {
            corrispondeVolume = volumeInRow.contains(_queryVolume);
          }
          // --- FINE CONFRONTO VOLUME ---
          // --- INIZIO CONFRONTO TIPO MULTI ---
          bool corrispondeTipoMulti = true; // Assume vero se il campo di ricerca tipo multi è vuoto
          if (_queryTipoMulti.isNotEmpty) {
            corrispondeTipoMulti = tipoMultiInRow.contains(_queryTipoMulti);
          }
          // --- FINE CONFRONTO TIPO MULTI ---
          //--- INIZIO CONFRONTO STRUMENTO ---
          bool corrispondeStrumento = true; // Assume vero se il campo di ricerca strumento è vuoto
          if (_queryStrumento.isNotEmpty) {
            corrispondeStrumento = strumentoInRow.contains(_queryStrumento);
          }
          // --- FINE CONFRONTO STRUMENTO ---

          //debugPrint('Match Titolo: $corrispondeTitolo, Match Autore: $corrispondeAutore, Match Provenienza: $corrispondeProvenienza');
          //debugPrint('--------------------');

          // La riga deve corrispondere a TUTTI i criteri di ricerca specificati
          //return corrispondeTitolo && corrispondeAutore && corrispondeProvenienza; // <--- AGGIUNTO corrispondeProvenienza
          return corrispondeTitolo &&
              corrispondeAutore &&
              corrispondeProvenienza &&
              corrispondeVolume &&    // <--- AGGIUNTO
              corrispondeTipoMulti && // <--- AGGIUNTO
              corrispondeStrumento;  // <--- AGGIUNTO
        }).toList();
      }
    });
  }

  // Funzione chiamata quando si preme il bottone "Apri PDF"
  // cancellato tutto il codice di apertura del PDF

  // Funzione per chiedere all'utente il path base (esempio)
// All'interno della classe _CsvViewerScreenState

  Future<void> _askForBasePath(
      {
        String? currentTitolo,   // Parametro per il titolo del brano
        String? currentVolume,   // Parametro per il volume
        String? currentNumPag,
        String? currentPercRadice,// Parametro per la cartella radice dei file PDF
        String? currentPercResto,
        String? volumeInfo,
        String? pagInfo,
        String? currentpercorsoPdfDaAprire// Parametro per il resto della cartella dei file PDF// il numero di pagina
      })
  async {
    //if (kIsWeb) return;
    String SelPdfDaAprire = (currentpercorsoPdfDaAprire ?? '') + (currentVolume ?? '');
    String percorsoVerificato = SelPdfDaAprire;

    TextEditingController pathController = TextEditingController(text: SelPdfDaAprire );

    String? newPath = await showDialog<String>(
      context: context,
      // SOSTITUISCI IL TUO BLOCCO builder CON QUESTO CODICE COMPLETO

      builder: (BuildContext context) {
// Variabili locali al dialogo
        String? percorsoVerificato;
        String dialogTitleText; // Variabile locale per il testo del titolo
////
////
        final TextEditingController pathController = TextEditingController(text: _basePdfPath);

// 1. Inizia lo StatefulBuilder
        return StatefulBuilder(
          builder: (context, setStateDialog) { // <-- Qui viene creato il nostro setStateDialog!

// --- Da qui in poi, setStateDialog è disponibile ---

// Logica per costruire il titolo del dialogo (la tua logica va qui)
            String dialogTitleText = 'Configura Percorso'; // Titolo di default
// ... (la tua logica if/else per `dialogTitleText`) ...
            if (currentTitolo != null && currentTitolo.isNotEmpty) {
// Se currentTitolo è fornito, usalo per un titolo più specifico
              String titoloInfo = " : $currentTitolo";
              if (currentVolume != null && currentVolume.isNotEmpty) {
                volumeInfo = "dal volume: $currentVolume";
                if (currentNumPag != null && currentNumPag.isNotEmpty) {
                  pagInfo = " (Pag. $currentNumPag)";
                }
              }
              dialogTitleText =
              'Brano Selezionato:\n'
                  '$currentTitolo\n' // <-- USA currentTitolo
                  '$volumeInfo\n'
                  '$pagInfo\n'
                  'PercorsoVerificato: $percorsoVerificato '

                  'Imposta il percorso base dei PDF:';
            } else if (_basePdfPath != null && _basePdfPath!.isNotEmpty) {
//              } else if (_basePdfPath.isNotEmpty) {
// Se non c'è un brano specifico, ma il path è già stato configurato
              dialogTitleText = 'Path base PDF attuale:\n$_basePdfPath\n\nModifica o conferma:';
            } else {
// Caso base: nessuna info specifica, path non configurato
              dialogTitleText = 'Configura Percorso Base PDF';
            }

// 2. Costruisci e restituisci l'AlertDialog completo
            return AlertDialog(
              title: Text(dialogTitleText),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
// Inserisci qui tutti i tuoi widget di testo e il TextField
// Esempio:
                    Text('Percorso proposto: $SelPdfDaAprire'),
                    TextField(controller: pathController),
                    SizedBox(height: 16),

// Blocco dinamico che mostra il risultato (apparirà dopo la validazione)
                    if (percorsoVerificato != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Percorso validato:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                          SelectableText(percorsoVerificato!),
                        ],
                      ),
                  ],
                ),
              ),
              actions: <Widget>[
// Bottone Annulla
                TextButton(
                  child: const Text('Annulla'),
                  onPressed: () => Navigator.of(context).pop(),
                ),

// Bottone 2: Apri Direttamente (usa il valore dal CSV)
                TextButton(
                  child: const Text('Apri Diretto'),
                  onPressed: () async {
                    // Gestisci il caso in cui SelPdfDaAprire sia null
                    if (SelPdfDaAprire.isEmpty) {
                      // Se non c'è un percorso da aprire, non fare nulla o mostra un messaggio
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Nessun percorso diretto da aprire specificato nei dati.')),
                      );
                      return; // Interrompi l'esecuzione
                    }
                    final FilePathResult result = await _validateAndShowResult(
                      dialogContext: context,
                      basePathFromInput: currentPercRadice!, // Usa il valore modificato
                      subPathComponent: currentPercResto,
                      fileNameComponent: currentVolume,
                      numeroPaginaFromCsv: currentNumPag ?? '1',
                    );


                    setStateDialog(() {
                      percorsoVerificato = result.fullPath;
                    });
                    print("----Chiamata Apri Diretto------");
                    print("currentPercRadice   $currentPercRadice");
                    print("currentPercResto $currentPercResto");
                    print("currentVolume $currentVolume");
                    print("currentNumPag $currentNumPag");
                    print("Apri Diretto - Percorso finale: ${result.fullPath}");
                  },
                ),
// Bottone 3: Apri con Trasformazione (usa il valore dal TextField)
                TextButton(
                  child: const Text('Apri con Trasformazione'),
                  onPressed: () async {
                    final FilePathResult result = await _validateAndShowResult(
                      dialogContext: context,
                      basePathFromInput: currentPercRadice!, // Usa il valore modificato
                      subPathComponent: currentPercResto,
                      fileNameComponent: currentVolume,
                      numeroPaginaFromCsv: currentNumPag ?? '1',
                    );
// AGGIORNA L'INTERFACCIA DEL DIALOGO
// Questa chiamata ora è VALIDA perché si trova dentro il builder corretto
                    setStateDialog(() {
                      percorsoVerificato = result.fullPath;
                    });
                    print("----Chiamata Apri con Trasformazione------");
                    print("currentPercRadice   $currentPercRadice");
                    print("currentPercResto $currentPercResto");
                    print("currentVolume $currentVolume");
                    print("currentNumPag $currentNumPag");
                    print("Percorso finale trasformato: ${result.fullPath}");
                  },
                ),
              ], // Fine della lista 'actions'
            ); // <-- FINE DELL'AlertDialog
          }, // <-- FINE del builder dello StatefulBuilder
        ); // <-- FINE dello StatefulBuilder
      }, // <-- FINE del builder dello showDialog
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
          // Emette la zona alta dello schermo con Campi per il filtro del CSV
          Scaffold(
            appBar: AppBar(
              title:  Text('Spartiti Visualizzatore $Laricerca'),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(180.0), // Potrebbe essere sufficiente, da aggiustare

                // Campi per il filtro del CSV
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      // --- PRIMA RIGA DI FILTRI ---
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          // Filtro Titolo (Expanded)
                          Expanded(
                            child: TextField(
                              controller: _cercaTitoloController,
                              decoration: const InputDecoration(
                                labelText: 'Titolo',
                                border: OutlineInputBorder(),
                                isDense: true,),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Filtro Autore (Expanded)
                          Expanded(
                            child: TextField(
                              controller: _cercaAutoreController,
                              decoration: const InputDecoration(
                                labelText: 'Autore',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Filtro Archivio/Provenienza (Expanded)
                          // ...
                          Expanded(
                            child: Autocomplete<String>( // NESSUN 'controller:' QUI
                              optionsBuilder: (TextEditingValue textEditingValue) {
                                if (textEditingValue.text.isEmpty) {
                                  // Se vuoi mostrare tutte le opzioni quando il campo è vuoto:
                                  return _opzioniProvenienza;
                                  // Se NON vuoi mostrare nulla quando il campo è vuoto:
                                  // return const <String>[]; // Restituisce un iterabile vuoto
                                } else {
                                  // Filtra le opzioni se c'è del testo
                                  final Iterable<String> filteredOptions = _opzioniProvenienza.where((String option) {
                                    return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                                  });
                                  return filteredOptions;
                                }
                                // NON CI DOVREBBE ESSERE ALTRO CODICE QUI che possa essere raggiunto.
                                // L'if/else sopra copre tutti i casi.
                              },
                              onSelected: (String selection) {
                                _cercaProvenienzaController.text = selection;
                              },
                              fieldViewBuilder: (BuildContext context,
                                  TextEditingController fieldTextEditingController, // Controller INTERNO
                                  FocusNode fieldFocusNode,
                                  VoidCallback onFieldSubmitted) {
                                return TextField(
                                  controller: _cercaProvenienzaController, // <--- Il tuo controller di stato
                                  focusNode: fieldFocusNode,
// --- INIZIO DECORAZIONE DA AGGIUNGERE ---
                                  decoration: const InputDecoration(
                                    labelText: 'Provenienza (Aeber,Realbook)', // O 'Provenienza', come preferisci
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
// --- FINE DECORAZIONE DA AGGIUNGERE ---
// onChanged: (text) {
//   // Se necessario, puoi gestire onChanged qui, ad esempio per aggiornare
//   // dinamicamente le opzioni o altro stato.
// },
                                );
                              },
                              // ...
                            ),
                          ),
                          // ...

                        ],
                      ),
                      const SizedBox(height: 8), // Spazio tra le righe di filtri
                      // --- SECONDA RIGA DI FILTRI ---
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          // Filtro Volume (Expanded)
                          Expanded(
                            child: TextField(
                              controller: _cercaVolumeController, // Definisci questo controller
                              decoration: const InputDecoration(
                                labelText: 'Volume',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Filtro TipoMulti (Expanded) - Potrebbe essere Autocomplete
                          Expanded(
                            child: Autocomplete<String>( // O TextField semplice
                              optionsBuilder: (TextEditingValue textEditingValue) {
                                if (textEditingValue.text.isEmpty) return _opzioniTipoMulti;
                                return _opzioniTipoMulti.where((String option) =>
                                    option.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                              },
                              onSelected: (String selection) {
                                _cercaTipoMultiController.text = selection;
                              },
                              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                // Sincronizza _cercaTipoMultiController con questo controller interno
                                // La cosa più semplice è assegnare _cercaTipoMultiController al TextField
                                // e usare il `controller` interno di fieldViewBuilder per popolare `optionsBuilder` se necessario
                                // o gestire la sincronizzazione in onChanged.
                                // Per semplicità qui, assumo che tu voglia un TextField semplice
                                // o che tu gestisca la sincronizzazione per Autocomplete.
                                // Per Autocomplete, è meglio passare il TUO controller:
                                return TextField(
                                  controller: _cercaTipoMultiController, // Definisci questo controller
                                  focusNode: focusNode,
                                  decoration: const InputDecoration(
                                    labelText: 'TipoMulti (PDF,MUS,XML...',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Filtro Strumento (Expanded) - Potrebbe essere Autocomplete
                          Expanded(
                            child: Autocomplete<String>( // O TextField semplice
                              optionsBuilder: (TextEditingValue textEditingValue) {
                                if (textEditingValue.text.isEmpty) return _opzioniStrumento;
                                return _opzioniStrumento.where((String option) =>
                                    option.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                              },
                              onSelected: (String selection) {
                                _cercaStrumentoController.text = selection;
                              },
                              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                return TextField(
                                  controller: _cercaStrumentoController, // Definisci questo controller
                                  focusNode: focusNode,
                                  decoration: const InputDecoration(
                                    labelText: 'Strumento',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12), // Spazio prima del bottone
                      /// emette la lista dei criteri di filtro indicati
                      Center(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.search), // Assicurati di avere anche 'icon' e 'label'
                          label: const Text('Filtra'),
                          /// Bottone Filtra
                          onPressed: () {                  // <--- QUESTA PARTE È FONDAMENTALE
                            // La tua logica per aggiornare le query e chiamare _filterData()
                            //   String? Laricerca,
                            _queryTitolo = _cercaTitoloController.text.toLowerCase();
                            _queryAutore = _cercaAutoreController.text.toLowerCase();
                            _queryProvenienza = _cercaProvenienzaController.text.toLowerCase();
                            _queryVolume = _cercaVolumeController.text.toLowerCase();
                            _queryTipoMulti = _cercaTipoMultiController.text.toLowerCase();
                            _queryStrumento = _cercaStrumentoController.text.toLowerCase();
                            // DEBUG: Stampa i valori delle query PRIMA di chiamare _filterData
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

                            //  debugPrint('[FILTRA PREMUTO] Query Titolo: "$_queryTitolo"');
                            //  debugPrint('[FILTRA PREMUTO] Query Autore: "$_queryAutore"');
                            //  debugPrint('[FILTRA PREMUTO] Query Provenienza: "$_queryProvenienza"');
                            //  debugPrint('[FILTRA PREMUTO] Query Volume: "$_queryVolume"');
                            //  debugPrint('[FILTRA PREMUTO] Query TipoMulti: "$_queryTipoMulti"');
                            //  debugPrint('[FILTRA PREMUTO] Query Strumento: "$_queryStrumento"');
                            //  Laricerca = 'Tit: $_queryTitolo Aut; $_queryAutore Prov: $_queryProvenienza Vol; $_queryVolume Mult; $_queryTipoMulti Strum: $_queryStrumento';
                            debugPrint('Ricerca: $Laricerca');
                            _filterData();
                          },                               // <--- Assicurati che la virgola e la parentesi graffa di chiusura ci siano
                        ),
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
              /// Bottone Nuovo CVS
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
  Widget _buildEmptyState()
  {
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
                  'assets/images/SherlockCerca.png',
                  height: 200,
                  width: 200,
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
                /// Bottone Nuovo CVS
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
                // print("Apri File Titolo: $titolo Volume:$volume PercRadice:$PercRadice PercResto: $PercResto ");

                if (titolo != 'N/D' && volume != 'N/D')
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.redAccent),
                    tooltip: 'Apri File Direttamente',
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
                //if (!kIsWeb)
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: 'Configura Path PDF',
                  ////Bottone Configurazione Path PDF
                  onPressed: ()
                  {
                    _askForBasePath(
                      currentTitolo: titolo,
                      currentVolume: volume,
                      currentNumPag: numPag,
                      currentPercRadice: PercRadice,
                      currentPercResto: PercResto,
                      currentpercorsoPdfDaAprire: PercRadice + PercResto,

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