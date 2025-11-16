ElevatedButton(
child: const Text('3. Gestore Interno (Jamset)'),
onPressed: ()
async {
async {
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
inCasoDiSuccesso: (percorsoDelFile)
async {
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