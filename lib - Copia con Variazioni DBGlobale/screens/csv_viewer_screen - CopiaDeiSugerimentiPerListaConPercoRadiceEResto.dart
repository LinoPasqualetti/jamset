import 'dart:convert'; // Necessario per utf8, latin1
import 'dart:io';     // Necessario per File e Platform (se usi Platform.pathSeparator)
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart'; // Se stai ancora usando FilePicker per CSV
import 'package:csv/csv.dart';                // Per CsvToListConverter
//Pacchetti per apertura files (PDF o altri) e per i percorsi
import 'package:open_filex/open_filex.dart'; // Per aprire file
// Per aprire URL
// Per manipolare i percorsi, aggiungi path: ^X.Y.Z a pubspec.yaml
// ... altri import
import 'package:url_launcher/url_launcher.dart'; // NECESSARIO PER url_launcher per aprire file su Browser

// Aggiungi altri import necessari (es. per sqflite, path_provider, open_file, ecc.)


//****************************************************************************
//  INSERISCI QUI la definizione della classe Brano e dell'enum DataSourceOrigin
//****************************************************************************

enum DataSourceOrigin { csv, sqlite, unknown }

class Brano {
  // Sezione 1: Campi}
  final String? id_univoco_globale;
  final String IdBra;
  final String titolo;
  final String autore;
final String strumento;
final String volume;
final String PercRadice;
final String PercResto;
final String PrimoLink;
final String TipoMulti;
final String TipoDocu;
final String ArchivioProvenienza;
final String NumPag;
final String NumOrig;
final String idVolume;
final String idAutore;
// ... tutti gli altri campi di Brano ...
final DataSourceOrigin dataSource;

  Brano({
    this.id_univoco_globale,
    required this.IdBra,
    required this.titolo,
    required this.autore,    // ... altri parametri del costruttore ...
    required this.strumento,
    required this.volume,
    required this.PercRadice,
    required this.PercResto,
    required this.PrimoLink,
    required this.TipoMulti,
    required this.TipoDocu,
    required this.ArchivioProvenienza,
    required this.NumPag,
    required this.NumOrig,
    required this.idVolume,
    required this.idAutore,
    required this.dataSource,
  });

  String get percorsoCompletoPdf {
    // ... la tua logica per costruire il percorso ...
    String percorsoFinale = "";
    if (PercRadice.isNotEmpty) {
      // ... (come definito prima) ...
    }
    // ... (resto della logica) ...
    return percorsoFinale.isEmpty ? PrimoLink : percorsoFinale; // Semplificazione
  }

  // factory Brano.fromCsvRow(List<dynamic> row, Map<String, int> columnIndexMap, List<String> csvHeaders, bool csvHasHeaders) {

  factory Brano.fromCsvRow(List<dynamic> row, Map<String, int> columnIndexMap) { // Rimosso csvHeaders e csvHasHeaders da qui se non servono più per altro
// Semplificazione di getCsvField: non serve più fixedIndex
    String getCsvField(String key, {String defaultValue = ''}) {
      int? colIdx = columnIndexMap[key]; // La mappa dovrebbe usare le chiavi normalizzate (es. _CsvViewerScreenState.keyTitolo)
      if (colIdx != null && colIdx < row.length && row[colIdx] != null) {
        return row[colIdx].toString().trim();
      }
      // Avviso opzionale se una chiave attesa non viene trovata nella riga o nella mappa
      // print("CSV WARN: Chiave '$key' non trovata in columnIndexMap o valore nullo/fuori range per la riga corrente.");
      return defaultValue.trim();
    }

  factory Brano.fromSqliteMap(Map<String, dynamic> map) {
    // ... implementazione del factory per SQLite ...
    String getString(String key, {String defaultValue = ''}) => map[key]?.toString() ?? defaultValue;
    // Chiamata al costruttore Brano
// Ora passiamo solo le chiavi a getCsvField
      return Brano(
        idUnivocoGlobale: null,
        IdBra: getCsvField(_CsvViewerScreenState.keyIdBra),
        titolo: getCsvField(_CsvViewerScreenState.keyTitolo),
        autore: getCsvField(_CsvViewerScreenState.keyAutore),
        strumento: getCsvField(_CsvViewerScreenState.keyStrumento),
        volume: getCsvField(_CsvViewerScreenState.keyVolume),
        PercRadice: getCsvField(_CsvViewerScreenState.keyPercRadice),
        PercResto: getCsvField(_CsvViewerScreenState.keyPercResto),
        PrimoLink: getCsvField(_CsvViewerScreenState.keyPrimoLink),
        TipoMulti: getCsvField(_CsvViewerScreenState.keyTipoMulti),
        TipoDocu: getCsvField(_CsvViewerScreenState.keyTipoDocu),
        ArchivioProvenienza: getCsvField(_CsvViewerScreenState.keyArchivioProvenienza),
        NumPag: getCsvField(_CsvViewerScreenState.keyNumPag),
        NumOrig: getCsvField(_CsvViewerScreenState.keyNumOrig),
        idVolume: getCsvField(_CsvViewerScreenState.keyIdVolume),
        idAutore: getCsvField(_CsvViewerScreenState.keyIdAutore), // Assicurati che keyIdAutore sia definito
        dataSource: DataSourceOrigin.csv,
      );
  }
}


// La tua classe StatefulWidget (CsvViewerScreen)
class CsvViewerScreen extends void StatefulWidget {
  // ... (tuo codice esistente) ...
  // Potresti passare qui il percorso del CSV iniziale o parametri del DB
  const CsvViewerScreen({Key? key /*, altri parametri */}) : super(key: key);

  @override
  _CsvViewerScreenState createState() => _CsvViewerScreenState();
}


//********************************************************************************
//  MODIFICHE E AGGIUNTE PRINCIPALI SARANNO ALL'INTERNO DI QUESTA CLASSE
//********************************************************************************
class _CsvViewerScreenState extends void State<CsvViewerScreen> {

  // Controller per i filtri (come li avevi definiti)
  final TextEditingController titoloFilterController = TextEditingController();
  // ... _archivioFilterController, _volumeFilterController, ecc. ...
  final TextEditingController autoreFilterController = TextEditingController();
  late List<TextEditingController> filterControllers;

  // Nuove liste per gestire gli oggetti Brano
  List<Brano> tuttiIBani = [];
  List<Brano> braniFiltrati = [];

  bool isLoading = false;
  final bool csvHasHeaders = true; // Mantieni la tua logica per questo

  // Le tue costanti per le chiavi e gli indici fissi del CSV.
  // Queste sono FONDAMENTALI per Brano.fromCsvRow
  // ESEMPIO (assicurati che corrispondano al tuo codice e alle necessità)
  const String keyidUnivocoGlobale = 'id_univoco_globale';
  const String keyIdBra = 'IdBra';
  const String keyTitolo = 'Titolo';
  const String keyAutore = 'Autore';
  const String keyStrumento = 'strumento'; // Occhio al case
  const String keyVolume = 'Volume';
  const String keyPercRadice = 'PercRadice';
  const String keyPercResto = 'PercResto';
  const String keyArchivioProvenienza = 'ArchivioProvenienza';
  const String keyTipoMulti = 'TipoMulti';
  const String keyPrimoLink = 'PrimoLink'; // Corrisponde al CSV? O era PrimoLink?
  const String keyNumPag = 'NumPag';
  const String keyTipoDocu = 'TipoDocu';
  const String keyNumOrig = 'NumOrig';
  const String keyIdVolume = 'IdVolume';
  const String keyIdAutore = 'IdAutore';

  // DA AGGIUNGERE SE SERVONO E SE ESISTONO NEL CSV:
  // static const String keyPercRadice = 'PercRadice';
  // static const String keyPercResto = 'PercResto';
  // static const String keyIdAutore = 'IdAutore';


  // Indici fissi (usati se _csvHasHeaders è false, o come fallback)
  // ESEMPIO (adatta ai tuoi indici effettivi)
  /*
  static const int fixedIndexIdBra = 0; // Adatta questo e i seguenti!
  static const int fixedIndexTitolo = 1;
  static const int fixedIndexAutore = 2;
  static const int fixedIndexStrumento = 7; // Esempio
  static const int fixedIndexVolume = 2; // Esempio, sembra duplicato con autore
  static const int fixedIndexPercRadice = 3;
  static const int fixedIndexPercResto = 4;
  static const int fixedIndexProvenienza = 10;
  static const int fixedIndexTipoMulti = 8;
  static const int fixedIndexPrimoLink = 9;
  static const int fixedIndexNumPag = 3;
  static const int fixedIndexTipoDocu = 9; // Esempio, duplicato
  static const int fixedIndexNumOrig = 4;
  static const int fixedIndexIdVolume = -1; // Se non presente o non usato come fisso
  static const int fixedIndexIdAutore = -1; // Se non presente o non usato come fisso
  */
  // DA AGGIUNGERE:
  // static const int fixedIndexPercRadice = ...;
  // static const int fixedIndexPercResto = ...;
  // static const int fixedIndexIdAutore = ...;


  @override
  void initState() {
    super.initState();
    filterControllers = [
      titoloFilterController,
      _archivioFilterController, // Assicurati di averli dichiarati tutti
      _volumeFilterController,
      _strumentoFilterController,
      _TipoMultiFilterController,
      autoreFilterController,
    ];
    for (var controller in filterControllers) {
      controller.addListener(applyFiltersAndSort);
    }
    loadAllDataSources(); // Chiamata per caricare i dati all'inizio
  }

  @override
  void dispose() {
    for (var controller in filterControllers) {
      controller.removeListener(applyFiltersAndSort);
      controller.dispose();
    }
    super.dispose();
  }

  // >>> INSERISCI QUI LE FUNZIONI:
  // >>> _loadAllDataSources
  // >>> _loadBraniFromCsv (che usa _createColumnIndexMap)
  // >>> _createColumnIndexMap (assicurati che sia completa)
  // >>> _loadBraniFromSqlite
  // >>> _unisciEDeduplica
  // >>> _applyFiltersAndSort (modificata per lavorare con List<Brano>)
  // >>> _getCellValue NON SERVE PIU' direttamente qui se i factory di Brano gestiscono l'accesso

  // Esempio di _loadAllDataSources (come fornito prima)
  Future<void> loadAllDataSources() async {
    // ... (codice come prima) ...
  }

  // Esempio di _loadBraniFromCsv (come fornito prima)
  Future<List<Brano>> loadBraniFromCsv() async {
    // ... (codice come prima, assicurati di usare FilePicker o un altro metodo per ottenere il CSV) ...
    // ... e che chiami Brano.fromCsvRow con i parametri corretti (columnIndexMap, csvHeaders, _csvHasHeaders)
    List<Brano> brani = [];
    // Logica per caricare e processare il CSV...
    // Esempio:
    // FilePickerResult? result = await FilePicker.platform.pickFiles(...);
    // if (result != null) {
    //   ... leggi fileContent ...
    //   final allRowsFromFile = CsvToListConverter(fieldDelimiter: ';').convert(fileContent);
    //   if (allRowsFromFile.isNotEmpty) {
    //     List<String> currentCsvHeaders = _csvHasHeaders ? List<String>.from(allRowsFromFile[0].map((h) => h.toString().trim())) : [];
    //     Map<String, int> currentColumnIndexMap = _csvHasHeaders ? _createColumnIndexMap(currentCsvHeaders) : {};
    //     List<List<dynamic>> dataRows = _csvHasHeaders ? (allRowsFromFile.length > 1 ? allRowsFromFile.sublist(1) : []) : allRowsFromFile;
    //
    //     for (final row in dataRows) {
    //       brani.add(Brano.fromCsvRow(row, currentColumnIndexMap, currentCsvHeaders, _csvHasHeaders));
    //     }
    //   }
    // }
    print("TODO: Implementare correttamente _loadBraniFromCsv in _CsvViewerScreenState");
    return brani;
  }

  Map<String, int> createColumnIndexMap(List<String> headers) {
    final Map<String, int> map = {};
    for (int i = 0; i < headers.length; i++) {
      String headerFromFile = headers[i].toString().trim().toLowerCase();
      // Mappa TUTTE le chiavi che ti servono dal CSV
      if (headerFromFile == keyIdBra.toLowerCase()) {
        map[keyIdBra] = i;
      } else if (headerFromFile == keyTitolo.toLowerCase()) map[keyTitolo] = i;
      // ... e così via per TUTTE le costanti 'key...'
      // else if (headerFromFile == keyPercRadice.toLowerCase()) map[keyPercRadice] = i; // Esempio
    }
    // Aggiungi qui i warning di debug se le chiavi importanti non sono trovate
    return map;
  }

  Future<List<Brano>> loadBraniFromSqlite() async {
    // ... (codice come prima, con la tua logica di accesso a SQLite) ...
    print("TODO: Implementare _loadBraniFromSqlite in _CsvViewerScreenState");
    return []; // Placeholder
  }

  List<Brano> unisciEDeduplica(List<Brano> lista1, List<Brano> lista2) {
    // ... (codice come prima) ...
    Map<String, Brano> mappaUnica = {};
    // ...
    return mappaUnica.values.toList();
  }

  void applyFiltersAndSort() {
    // ... (codice come prima, ma ora opera su List<Brano> e accede alle proprietà degli oggetti Brano) ...
    // Esempio per il filtro titolo:
    // bool titoloMatch = titoloQuery.isEmpty || brano.titolo.toLowerCase().contains(titoloQuery);
    // Esempio per l'ordinamento:
    // int compareTitolo = a.titolo.toLowerCase().compareTo(b.titolo.toLowerCase());
    print("TODO: Implementare _applyFiltersAndSort per operare su List<Brano>");
    setState(() {
      braniFiltrati = tuttiIBani.where((brano) => true).toList(); // Placeholder, applica filtri reali
      braniFiltrati.sort((a,b)=> a.titolo.compareTo(b.titolo)); // Placeholder, applica sort reale
    });
  }


  // Metodo build (come lo avevi, ma ora usa _braniFiltrati List<Brano>)
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Visualizzatore Spartiti (Unificato)'),
      ),
      body: Column(
        children: [
          // >>> INSERISCI QUI i TextField per i filtri (come prima)
          // _buildFilterTextField(_titoloFilterController, "Titolo", "Filtra titolo..."),
          // ... e gli altri ...
          // ElevatedButton(onPressed: (){ for(var c in _filterControllers) c.clear(); }, child: Text("Resetta")),

          if (isLoading)
            CircularProgressIndicator()
          else if (braniFiltrati.isEmpty)
            Center(child: Text('Nessun brano da visualizzare o caricare i dati.'))
          else
            Expanded(
              child: ListView.builder(
                itemCount: braniFiltrati.length,
                itemBuilder: (context, index) {
                  final brano = braniFiltrati[index];
                  return ListTile(
                    title: Text(brano.titolo.isNotEmpty ? brano.titolo : "N/D"),
                    subtitle: Text("Autore: ${brano.autore} - Strumento: ${brano.strumento}"),
                    trailing: Text("Pag: ${brano.NumPag}"),
                    onTap: () {
                      // Azione per aprire il PDF
                      // Usa brano.percorsoCompletoPdf e brano.NumPag
                      print('Apri PDF: ${brano.percorsoCompletoPdf} a pagina ${brano.NumPag}');
                      // Chiama la tua funzione per aprire il PDF (es. _apriPdfDialog)
                      // passando le informazioni necessarie dall'oggetto 'brano'.
                      mostraDialogDettagliEApertura(context, brano);
                    },
                  );
                },
              ),
            ),
        ],
      ),
      // floatingActionButton: FloatingActionButton( // Esempio per ricaricare CSV
      //   onPressed: () async {
      //     List<Brano> braniCsv = await _loadBraniFromCsv();
      //     List<Brano> braniSqliteAttuali = _tuttiIBani.where((b) => b.dataSource == DataSourceOrigin.sqlite).toList();
      //     _tuttiIBani = _unisciEDeduplica(braniCsv, braniSqliteAttuali);
      //     _applyFiltersAndSort();
      //   },
      //   child: Icon(Icons.file_upload),
      //   tooltip: "Carica/Aggiorna CSV",
      // ),
    );
  }

  // >>> INSERISCI QUI la funzione _mostraDialogDettagliEApertura (o come l'hai chiamata)
  // Questa funzione ora riceverà un oggetto Brano
  void mostraDialogDettagliEApertura(BuildContext context, Brano brano) {
    // Il path da aprire ora viene da brano.percorsoCompletoPdf
    String percorsoPdfDaAprireNelDialogo = brano.percorsoCompletoPdf;
    String paginaDaAprire = brano.NumPag;

    // Ricicla la logica del tuo showDialog esistente,
    // ma popola i campi con le proprietà dell'oggetto 'brano'.
    // Esempio:
    // SelectableText(brano.titolo.isNotEmpty ? brano.titolo : "N/D"),
    // SelectableText(brano.PercRadice),
    // SelectableText(brano.PercResto),
    // ...
    // Il TextField per modificare il percorso potrebbe usare un controller
    // inizializzato con brano.percorsoCompletoPdf.
    TextEditingController pathController = TextEditingController(text: percorsoPdfDaAprireNelDialogo);

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Dettagli Brano: ${brano.titolo}'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text("Autore: ${brano.autore}"),
                Text("Strumento: ${brano.strumento}"),
                Text("Volume: ${brano.volume}"),
                Text("Pagina: $paginaDaAprire"),
                SizedBox(height: 10),
                Text("Percorso PDF Proposto:"),
                TextField(
                  controller: pathController,
                  decoration: InputDecoration(
                    hintText: 'Percorso del PDF',
                  ),
                ),
                // Aggiungi altri dettagli se vuoi
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Annulla'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            ElevatedButton(
              child: Text('Visualizza PDF'),
              onPressed: () async {
                String percorsoFinaleDaUsare = pathController.text.trim();
                // Chiama la tua funzione che lancia l'URL o apre il file
                // es. _launchUrl(percorsoFinaleDaUsare, paginaDaAprire);
                print('Azione Visualizza PDF: $percorsoFinaleDaUsare, Pag: $paginaDaAprire');
                // Qui dovrai integrare la tua logica di _launchUrl o simile
                // Esempio:
                // if (kIsWeb) { await launchUrl(Uri.parse(percorsoFinaleDaUsare)); }
                // else { OpenFile.open(percorsoFinaleDaUsare); }
                Navigator.of(dialogContext).pop(); // Chiudi il dialogo dopo l'azione
              },
            ),
          ],
        );
      },
    );
  }

}
