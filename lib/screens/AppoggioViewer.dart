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


class CsvViewerScreen extends StatefulWidget {
  const CsvViewerScreen({super.key});

  @override
  State<CsvViewerScreen> createState() => _CsvViewerScreenState();
}

class _CsvViewerScreenState extends State<CsvViewerScreen> {
  List<List<dynamic>> _csvData = [];
  List<List<dynamic>> _filteredCsvData = [];
  final TextEditingController _searchController = TextEditingController();
  String _basePdfPath = ""; // Variabile per memorizzare il path base dei PDF

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterData);
    // TODO: Inizializza _basePdfPath qui, magari da SharedPreferences, un file di config,
    // o chiedendolo all'utente alla prima apertura o tramite un'impostazione.
    // Esempio temporaneo (DA MODIFICARE!):
    if (!kIsWeb) { // Il path ha senso solo su piattaforme non web
      // _basePdfPath = "/sdcard/Documenti/Spartiti/"; // Esempio per Android
      // _basePdfPath = "C:\\Users\\TuoNome\\Documents\\Spartiti\\"; // Esempio per Windows
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
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

        final fields = const CsvToListConverter(fieldDelimiter: ';').convert(fileContent);

        setState(() {
          _csvData = fields;
          _filteredCsvData = fields;
        });

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
  /// Filtro del CSV (o del ResultSet
  void _filterData() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredCsvData = _csvData;
      } else {
        _filteredCsvData = _csvData.where((row) {
          final titolo = row.length > 3 ? row[3].toString().toLowerCase() : '';
          final autore = row.length > 4 ? row[4].toString().toLowerCase() : '';
          return titolo.contains(query) || autore.contains(query);
        }).toList();
      }
    });
  }

  // Funzione chiamata quando si preme il bottone "Apri PDF"
  void _handleOpenPdfAction({
    required String titolo,
    required String volume,
    required String numPag,
    required String numOrig,
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
    //String Prova = 'Un piccolo test';
    ///ESTRAE I Dati Selezionati
    String SelTitolo = titolo;
    String SelVolume = volume;
    String SelNumPag = numPag;
    String SelNumOrig = numOrig;
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
    print('--- Azione Chiama Apertura PDF ---');
    print('Tetolo: $titolo');
    print('Volume (come nome file?): $nomeFileDaVolume');
    print('Numero Pagina (da usare con lettore PDF): $numPag');
    print('Numero Originale: $numOrig');
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
        content: Text('Dati per PDF: Titolo: $titolo, Volume: $volume, Pag: $numPag. Path base: $_basePdfPath'),
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
                onPressed: () {
                  // RECUPERA IL VALORE CORRENTE DAL TEXTFIELD TRAMITE IL SUO CONTROLLER
                  String percorsoPdfDaAprire = searchController.text.trim(); // .trim() per rimuovere spazi bianchi inutili

                  // Puoi anche recuperare il valore della pagina se hai un campo per quello
                  // String paginaDaAprire = paginaController.text.trim();

                  print('Bottone "Visualizza PDF" premuto. Percorso PDF da usare: $percorsoPdfDaAprire');

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



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.yellow[100],
      appBar: AppBar(
        title: const Text('Visualizzatore CSV Spartiti'),
        actions: [ // Aggiungiamo un bottone per configurare il path
          if (!kIsWeb)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Configura Path PDF',
              onPressed: _askForBasePath,
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight + 10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cerca per titolo o autore...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                contentPadding: const EdgeInsets.all(0),
                fillColor: Colors.white.withOpacity(0.9), // Leggermente trasparente per non coprire troppo
              ),
            ),
          ),
        ),
      ),
      body: _csvData.isEmpty
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Carica un elenco Brani Musicali (CSV) per visualizzarne il contenuto.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('Carica File CSV'),
                onPressed: _pickAndLoadCsv,
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    textStyle: const TextStyle(fontSize: 16)
                ),
              )
            ],
          ),
        ),
      )
          : ListView.builder(
        itemCount: _filteredCsvData.length,
        itemBuilder: (context, index) {
          final row = _filteredCsvData[index];
          // Verifica la lunghezza della riga per evitare RangeError
          final bool hasEnoughColumns = row.length >= 11; // Assumendo almeno 11 colonne per i dati necessari

          // COSTRUZIONE PER CIASCUNA RIGA CSV DEI SINGOLI CAMPI DEL BRANO (DA 0 A 10)
          final String IdBra = hasEnoughColumns && row[0] != null ? row[0].toString() : 'N/D';
          final String TipoMulti = hasEnoughColumns && row[1] != null ? row[1].toString() : 'N/D';
          final String TipoDocu = hasEnoughColumns && row[2] != null ? row[2].toString() : 'N/D';
          final String titolo = hasEnoughColumns && row[3] != null ? row[3].toString() : 'N/D';
          final String autore = hasEnoughColumns && row[4] != null ? row[4].toString() : 'N/D';
          final String strumento = hasEnoughColumns && row[5] != null ? row[5].toString() : 'N/D';
          final String Provenienza = hasEnoughColumns && row[6] != null ? row[6].toString() : 'N/D';
          final String volume = hasEnoughColumns && row[7] != null ? row[7].toString() : 'N/D'; // Nome del file PDF o parte di esso
          final String numPag = hasEnoughColumns && row[8] != null ? row[8].toString() : 'N/D'; // Pagina nel PDF
          final String numOrig = hasEnoughColumns && row[9] != null ? row[9].toString() : 'N/D'; // Pagina originale (se diversa)
          final String link = hasEnoughColumns && row[10] != null ? row[10].toString() : ''; // Link diretto (colonna 10)


          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tit-  $titolo  StrumTraspo: $strumento a pag: $numPag del volume: $volume',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 4),
                        //Text('Autore: $autore', style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                        //Text('Strumento: $strumento', style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                        //Text('Volume/File: $volume - Pag: $numPag (Orig: $numOrig)', style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                        // if (link.isNotEmpty) ...[
                        //   const SizedBox(height: 2),
                        //   Text('Link: $link', style: TextStyle(fontSize: 12, color: Colors.blue, fontStyle: FontStyle.italic)),
                        // ]
                      ],
                    ),
                  ),
                  // Bottone per l'azione
                  if(hasEnoughColumns) // Mostra il bottone solo se ci sono abbastanza dati
                    IconButton(
                      icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.redAccent),
                      tooltip: 'Apri PDF',
                      onPressed: () {
                        _handleOpenPdfAction(
                          titolo: titolo,
                          volume: volume,
                          numPag: numPag,
                          numOrig: numOrig,
                          idBra: IdBra,
                          TipoMulti: TipoMulti,
                          TipoDocu: TipoDocu,
                          strumento: strumento,
                          Provenienza: Provenienza,
                          link: link,
                          ///SOLO COPIA INIZ
                          ///    required String titolo,
                          //     required String volume,
                          //     required String numPag,
                          //     required String numOrig,
                          //     required String idBra,
                          //     required String TipoMulti,
                          //     required String TipoDocu,
                          //     required String strumento,
                          //     required String Provenienza,
                          //     required String link,
                          ///SOLO COPIA FINE
                        );
                      },
                    ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: _csvData.isEmpty ? null : FloatingActionButton.extended( // Nascondi se non ci sono dati
        onPressed: _pickAndLoadCsv,
        tooltip: 'Carica nuovo file CSV',
        icon: const Icon(Icons.upload_file_outlined),
        label: const Text("Nuovo CSV"),
      ),
    );
  }
}

