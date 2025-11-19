import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'main.dart'; // Per le variabili globali
import 'database_utils.dart';

const String _dbGlobaleName = 'DBGlobale_seed.db';
const String _vecchioDbName = 'VecchioDb.db';
const String _primoVuotoName = 'PrimoVuoto.db';

/// Funzione "Guardiano" onnipotente e riutilizzabile.
/// Ad ogni avvio, si assicura che i DB esistano, li sana se necessario,
/// scrive la configurazione di default se mancante, e apre il catalogo attivo.
Future<void> inizializzaIDbDellaApp() async {
  try {
    final supportDir = await getApplicationSupportDirectory();

    // Fase 1: Assicura l'esistenza e la coerenza dei 3 DB fondamentali.
    await initDatabase(_dbGlobaleName);
    await initDatabase(_vecchioDbName);

    final primoVuotoPath = p.join(supportDir.path, _primoVuotoName);
    if (!await databaseExists(primoVuotoPath)) {
      print("INFO: Creazione di $_primoVuotoName non trovato...");
      const createStatement = 'CREATE TABLE $gSpartitiTableName ( id_univoco_globale INTEGER UNIQUE, IdBra TEXT,titolo TEXT, autore TEXT,strumento TEXT, volume TEXT,PercRadice TEXT, PercResto TEXT, PrimoLInk  TEXT, TipoMulti TEXT, TipoDocu TEXT, ArchivioProvenienza TEXT, NumPag INTEGER, NumOrig INTEGER, IdVolume TEXT,IdAutore TEXT, PRIMARY KEY (id_univoco_globale AUTOINCREMENT))';
      Database dbVuoto = await openDatabase(primoVuotoPath, version: 1, onCreate: (db, version) => db.execute(createStatement));
      await dbVuoto.close();
    }

    // --- FASE 1.5: Sanificazione preventiva di VecchioDb.db ---
    final vecchioDbPath = p.join(supportDir.path, _vecchioDbName);
    Database dbDaSanificare = await openDatabase(vecchioDbPath);
    try {
        await _sanitizeVecchioDb(dbDaSanificare);
    } finally {
        await dbDaSanificare.close();
    }

    // Fase 2: Apertura, Validazione e Auto-Configurazione del DB Globale.
    gDbGlobale = await openDatabase(p.join(supportDir.path, _dbGlobaleName));
    gDbGlobalePath = gDbGlobale!.path;

    // --- LOGICA CHIRURGICA ---
    // 1. Assicura che il catalogo master (ID=1) esista e sia corretto.
    await gDbGlobale!.insert(
      'elenco_cataloghi',
      {'id': 1, 'nome_catalogo': 'Vecchio Catalogo Principale', 'descrizione': 'Catalogo di default pre-caricato.', 'nome_file_db': _vecchioDbName},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    print("INFO: Validazione del catalogo master (ID=1) completata.");

    // 2. Se DatiSistremaApp è vuoto, imposta il catalogo master come attivo.
    final datiSistemaResult = await gDbGlobale!.query('DatiSistremaApp', limit: 1);
    if (datiSistemaResult.isEmpty) {
      print("WARN: DatiSistremaApp è vuota. Imposto il catalogo di default come attivo...");
      await gDbGlobale!.insert('DatiSistremaApp', {
        'id': 1,
        'PercorsoPdf': '',
        'id_catalogo_attivo': 1,
      });
      print("INFO: Configurazione iniziale di DatiSistremaApp completata.");
    }
    
    // Fase 3: Apre il catalogo attivo basandosi sulla configurazione (ora garantita)
    final finalDatiSistema = (await gDbGlobale!.query('DatiSistremaApp', limit: 1)).first;
    gPercorsoPdf = finalDatiSistema['PercorsoPdf'] as String? ?? '';
    final idCatalogoAttivo = finalDatiSistema['id_catalogo_attivo'] as int?;
    if (idCatalogoAttivo == null) throw Exception('id_catalogo_attivo non trovato dopo la configurazione.');

    final catalogoInfoResult = await gDbGlobale!.query('elenco_cataloghi', where: 'id = ?', whereArgs: [idCatalogoAttivo], limit: 1);
    if (catalogoInfoResult.isEmpty) throw Exception('Catalogo attivo con ID $idCatalogoAttivo non trovato.');
    
    final catalogoInfo = catalogoInfoResult.first;
    gActiveCatalogDbName = catalogoInfo['nome_file_db'] as String;
    
    gDatabase = await openDatabase(p.join(supportDir.path, gActiveCatalogDbName));
    gVecchioDbPath = gDatabase!.path;

    print("***** INIZIALIZZAZIONE COMPLETATA (Guardiano Chirurgico) *****");

  } catch (e) {
    print("### ERRORE INIZIALIZZAZIONE (Guardiano): $e ###");
    gDbGlobale = null;
    gDatabase = null;
    rethrow;
  }
}

/// Controlla se in VecchioDb.db coesistono le tabelle 'spartiti' e 'spartiti_andr'
/// e, in caso, esegue una pulizia per mantenere solo la tabella 'spartiti'.
Future<void> _sanitizeVecchioDb(Database db) async {
  try {
    final spartitiExistsResult = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='spartiti'");
    final spartitiAndrExistsResult = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='spartiti_andr'");

    bool spartitiExists = spartitiExistsResult.isNotEmpty;
    bool spartitiAndrExists = spartitiAndrExistsResult.isNotEmpty;

    if (spartitiExists && spartitiAndrExists) {
        print("WARN: Rilevata vecchia versione di VecchioDb.db. Avvio pulizia...");
        if (Platform.isWindows) {
            await db.execute('DROP TABLE spartiti_andr');
        } else {
            await db.execute('DROP TABLE spartiti');
            await db.execute('ALTER TABLE spartiti_andr RENAME TO spartiti');
        }
        print("INFO: Pulizia completata. VecchioDb.db ora ha una sola tabella 'spartiti'.");
    }
  } catch (e) {
    print("### ERRORE durante la sanificazione di VecchioDb.db: $e ###");
  }
}
