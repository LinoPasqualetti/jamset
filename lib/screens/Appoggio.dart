// All'interno del tuo widget Autocomplete
optionsBuilder: (TextEditingValue textEditingValue) {
// ... la tua logica optionsBuilder ...
// Esempio per assicurarsi che non sia vuoto e mostri qualcosa durante il test:
if (textEditingValue.text.isEmpty) {
return _opzioniProvenienza; // Mostra tutte le opzioni per il test
}
return _opzioniProvenienza.where((String option) {
return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
});
},
onSelected: (String selection) {
_cercaProvenienzaController.text = selection; // Aggiorna il TUO controller
debugPrint('[AUTOCOMPLETE onSelected] Selezione: "$selection", Controller ora: "${_cercaProvenienzaController.text}"');
},
fieldViewBuilder: (BuildContext context,
TextEditingController fieldTextEditingController, // Controller INTERNO di Autocomplete
FocusNode fieldFocusNode,
VoidCallback onFieldSubmitted) {
debugPrint('[FIELDVIEWBUILDER] Costruendo TextField. Testo attuale in _cercaProvenienzaController: "${_cercaProvenienzaController.text}"');

// LA RIGA PIÙ IMPORTANTE:
// Assicurati che il TextField usi IL TUO _cercaProvenienzaController
return TextField(
controller: _cercaProvenienzaController, // <--- USA IL TUO CONTROLLER QUI (_cercaProvenienzaController)
focusNode: fieldFocusNode,
decoration: const InputDecoration(
labelText: 'Archivio', // O 'Provenienza'
border: OutlineInputBorder(),
isDense: true,
),
onChanged: (text) {
// Questo onChanged è sul TextField che USA _cercaProvenienzaController.
// Quindi, _cercaProvenienzaController.text dovrebbe essere uguale a 'text' qui.
debugPrint('[FIELDVIEWBUILDER onChanged] Testo digitato: "$text". Testo in _cercaProvenienzaController: "${_cercaProvenienzaController.text}"');
},
);
},
optionsViewBuilder: // ... la tua logica optionsViewBuilder ...
