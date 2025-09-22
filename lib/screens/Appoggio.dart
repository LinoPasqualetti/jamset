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