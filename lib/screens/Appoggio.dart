// CORREZIONE
if (!kIsWeb)
IconButton(
icon: const Icon(Icons.settings_outlined),
tooltip: 'Configura Path PDF',
onPressed: () { // <<< AGGIUNTA FUNZIONE ANONIMA
_askForBasePath(
currentTitolo: titolo, // Assicurati che i nomi dei parametri corrispondano
currentVolume: volume, // alla definizione di _askForBasePath
currentNumPag: numPag,
);
},
),






//////// modifica alla apertura file PDF
import 'package:permission_handler/permission_handler.dart';
import 'dart:io'; // Per la classe File
// Se usi open_file o un package simile per aprire il PDF
// import 'package:open_file/open_file.dart';


Future<void> openPdfFile(String filePath) async {
// Controlla e richiedi i permessi di storage
var status = await Permission.storage.status;

// Su Android 13+ (API 33+), READ_EXTERNAL_STORAGE non ha effetto
// e devi usare permessi più granulari come Permission.photos, Permission.videos, Permission.audio
// o MANAGE_EXTERNAL_STORAGE (con le dovute cautele e giustificazioni per il Play Store).
// Per i file generici come i PDF, se non sono nella directory dell'app o in directory media pubbliche,
// SAF è spesso la via migliore, o MANAGE_EXTERNAL_STORAGE se l'app rientra nei casi d'uso consentiti.

// Questo controllo base per `Permission.storage` funziona bene per Android < 13
// o se hai `requestLegacyExternalStorage="true"` e targetSDK < 29 per un accesso più ampio (deprecato).
if (!status.isGranted) {
status = await Permission.storage.request();
}

if (status.isGranted) {
// Permesso concesso, prova ad aprire il file
print("Permesso di storage concesso. Tento di aprire: $filePath");
File pdfFile = File(filePath);
if (await pdfFile.exists()) {
print("Il file PDF esiste in: $filePath");
// Qui la tua logica per aprire il PDF
// Esempio con il package open_file:
// final result = await OpenFile.open(filePath);
// print('Risultato apertura file: ${result.type} - ${result.message}');

// Oppure, se stai solo testando l'accesso, puoi provare a leggere qualche byte:
try {
List<int> bytes = await pdfFile.readAsBytes();
print("Primi 10 bytes letti (se il file è grande): ${bytes.take(10)}");
print("File letto con successo (o almeno i primi bytes).");
// Implementa qui l'effettiva apertura con un visualizzatore
} catch (e) {
print("Errore durante la lettura del file dopo aver ottenuto i permessi: $e");
}

} else {
print("ERRORE: Il file PDF non esiste in: $filePath dopo aver ottenuto i permessi.");
}
} else if (status.isDenied) {
print("Permesso di storage negato dall'utente.");
// Mostra un messaggio all'utente che il permesso è necessario
} else if (status.isPermanentlyDenied) {
print("Permesso di storage negato permanentemente. L'utente deve abilitarlo dalle impostazioni.");
// Guida l'utente ad aprire le impostazioni dell'app
openAppSettings();
}
}

// ... (chiami openPdfFile("/storage/0000-0000/Files Musicali/Anthol-JAZZ/Griglie e melodie Jazz –ConLink.pdf"))






/////////////////&&&&&&&&&&&&&&&&& Inizio Variazione ai filtri  All'interno della classe _CsvViewerScreenState
// All'interno della classe _CsvViewerScreenState

// Controller per ogni campo di filtro
final TextEditingController _titoloFilterController = TextEditingController();
final TextEditingController _archivioFilterController = TextEditingController();
final TextEditingController _volumeFilterController = TextEditingController();
final TextEditingController _strumentoFilterController = TextEditingController();
final TextEditingController _tipoMultiFilterController = TextEditingController();
final TextEditingController _autoreFilterController = TextEditingController();

// Potremmo anche mantenere lo stato dei valori di filtro in variabili separate
// se vogliamo accedervi più facilmente senza dover sempre leggere dai controller,
// ma per ora i controller sono sufficienti.

// Lista dei controller per facilitare l'aggiunta di listener
late List<TextEditingController> _filterControllers;

@override
void initState() {
super.initState();
_loadCsvData(); // La tua funzione per caricare i dati

_filterControllers = [
_titoloFilterController,
_archivioFilterController,_volumeFilterController,
_strumentoFilterController,
_tipoMultiFilterController,
_autoreFilterController,
];

// Aggiungi listener a ogni controller per rieseguire il filtro quando cambiano
for (var controller in _filterControllers) {
controller.addListener(_applyFiltersAndSort);
}
}

@override
void dispose() {
// Rimuovi i listener e fai il dispose dei controller
for (var controller in _filterControllers) {
controller.removeListener(_applyFiltersAndSort);
controller.dispose();
}
_searchController.dispose(); // Se mantieni anche il vecchio controller di ricerca globale
super.dispose();
}

/////////////////&&&&&&&&&&&&&&&&& Fine Variazione ai filtri  All'interno della classe _CsvViewerScreenState