// dentro il pulsante 'Verifica di Esistenza'

await _VerificaFile(
context: context,
// ...altri parametri...

// --- AZIONE IN CASO DI SUCCESSO ---
inCasoDiSuccesso: (percorsoDelFile)
{
if (mounted) Navigator.of(context).pop(); // Chiudi il caricamento
print("SUCCESSO dalla chiamata! Il file si trova in: $percorsoDelFile");

// ---> LOGICA CORRETTA SPOSTATA QUI <---
setState(() { // Usa setState o setStateDialog del tuo dialogo
Prova2 = percorsoDelFile;
searchController.text = percorsoDelFile; // Aggiorna anche il campo di testo!
});
print('Azione DOPO il successo: Prova2 ora è: $Prova2');
// Qui puoi chiamare la funzione che APRE EFFETTIVAMENTE il file
// _apriPdfConLauncher(Prova2);
},
// --- AZIONE IN CASO DI FALLIMENTO ---
inCasoDiFallimento: (percorsoTentato)
{
if (mounted) Navigator.of(context).pop(); // Chiudi il caricamento
print("FALLIMENTO dalla chiamata! Impossibile trovare il file in: $percorsoTentato");

// ---> LOGICA CORRETTA SPOSTATA QUI <---
setState(() { // Usa setState o setStateDialog del tuo dialogo
Prova2 = percorsoTentato;
searchController.text = percorsoTentato; // Aggiorna anche il campo di testo!
});
print('Azione DOPO il fallimento: Prova2 ora è: $Prova2');
},
);

// --- ASSICURATI CHE QUI SOTTO NON CI SIA PIÙ NIENTE ---
}, // Fine onPressed
