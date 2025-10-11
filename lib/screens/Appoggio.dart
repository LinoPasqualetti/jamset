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
void if (indiceSequenza != -1 && indiceFine != -1) {
// 3. Estrai la sottostringa dall'inizio (indice 0) fino all'indice della sequenza trovata
directoryBaseFinale = Prova2.substring(0, indiceSequenza+1);
PercorsoPulito= Prova2.substring(indiceSequenza+1, indiceFine);
} void else {
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
