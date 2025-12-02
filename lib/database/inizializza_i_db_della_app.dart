// lib/database/inizializza_i_db_della_app.dart - VERSIONE COMPLETA CON POPOLAMENTO
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Import delle variabili globali di jamsetgemini
import '../main.dart'; // Importa gPercorsoPdf, dbGlobale, etc.

const String _dbGlobaleName = 'DBGlobale_seed.db';
const String _vecchioDbName = 'VecchioDb.db';

/// ===================================================================
/// FUNZIONE PER POPOLARE VecchioDb DA ASSET MASTER
/// ===================================================================
Future<void> _popolaVecchioDbDaMaster(Database db) async {
  debugPrint("POPOLAMENTO VecchioDb da asset master...");

  try {
    // 1. Carica il DB master dagli assets in un file temporaneo
    debugPrint("  1. Caricamento asset: 'assets/databases/$_vecchioDbName'");
    final ByteData data = await rootBundle.load('assets/databases/$_vecchioDbName');
    final tempAssetDbPath = p.join((await getTemporaryDirectory()).path, "vecchio_master_temp.db");
    await File(tempAssetDbPath).writeAsBytes(data.buffer.asUint8List(), flush: true);
    debugPrint("  1. Asset master copiato in: $tempAssetDbPath");

    Database? masterDb;
    try {
      // 2. Apri il DB master temporaneo in sola lettura
      masterDb = await openReadOnlyDatabase(tempAssetDbPath);
      debugPrint("  2. Database master temporaneo aperto in sola lettura.");

      // 3. Determina la tabella sorgente in base alla piattaforma
      final sourceTableName = Platform.isAndroid ? 'spartiti_andr' : 'spartiti';
      debugPrint("  3. Piattaforma: ${Platform.operatingSystem}. Tabella sorgente: '$sourceTableName'");

      // 4. Leggi i dati dalla tabella sorgente
      final dataToInsert = await masterDb.query(sourceTableName);
      debugPrint("  4. Letti ${dataToInsert.length} record da '$sourceTableName'.");

      // 5. Inserisci i dati nel VecchioDb
      await db.transaction((txn) async {
        debugPrint("  5. Avvio transazione per inserire i dati...");

        // 5a. Crea la tabella spartiti se non esiste
        await txn.execute('''
          CREATE TABLE IF NOT EXISTS spartiti (
            id_univoco_globale INTEGER PRIMARY KEY AUTOINCREMENT,
            IdBra INTEGER UNIQUE,
            titolo TEXT,
            autore TEXT,
            strumento TEXT,
            volume TEXT,
            PercRadice TEXT,
            PercResto TEXT,
            PrimoLink TEXT,
            TipoMulti TEXT,
            TipoDocu TEXT,
            ArchivioProvenienza TEXT,
            NumPag INTEGER,
            NumOrig INTEGER,
            IdVolume TEXT,
            IdAutore TEXT
          )
        ''');
        debugPrint("      - Tabella 'spartiti' creata/verificata.");

        // 5b. Inserisci i dati in blocco
        final batch = txn.batch();
        for (final row in dataToInsert) {
          batch.insert('spartiti', row, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
        final result = await batch.commit(noResult: false);
        debugPrint("      - Inserimento in blocco completato. Righe inserite: ${result.length}.");
      });
      debugPrint("  5. Transazione completata con successo.");

    } finally {
      // 6. Pulizia
      await masterDb?.close();
      await deleteDatabase(tempAssetDbPath);
      debugPrint("  6. Risorse temporanee rilasciate.");
    }

    debugPrint("POPOLAMENTO VecchioDb COMPLETATO!");

  } catch (e, s) {
    debugPrint("### ERRORE in _popolaVecchioDbDaMaster: $e ###");
    debugPrint("### STACK TRACE: $s ###");
    rethrow;
  }
}

/// ===================================================================
/// FUNZIONE PRINCIPALE PER CORREZIONE PERCORSI PDF
/// ===================================================================
Future<String> _getPlatformCorrectedPdfPath(String percorsoOriginale) async {
  if (percorsoOriginale.isEmpty) {
    return await _getDefaultPdfPath();
  }

  final bool isWindowsPath = percorsoOriginale.contains(r'\') ||
      percorsoOriginale.startsWith(RegExp(r'[A-Z]:\\'));

  debugPrint('CORREZIONE PERCORSO:');
  debugPrint('  Originale: $percorsoOriginale');
  debugPrint('  Piattaforma: ${Platform.operatingSystem}');
  debugPrint('  È percorso Windows? $isWindowsPath');

  if (Platform.isAndroid || Platform.isIOS) {
    if (isWindowsPath) {
      debugPrint('  ATTENZIONE: Percorso Windows rilevato su mobile. Correzione in corso...');
      return await _getDefaultPdfPath();
    }

    try {
      final dir = Directory(percorsoOriginale);
      if (await dir.exists()) {
        debugPrint('  √ Percorso mobile valido: $percorsoOriginale');
        return percorsoOriginale;
      } else {
        debugPrint('  ⚠ Percorso non valido, usando default');
        return await _getDefaultPdfPath();
      }
    } catch (e) {
      debugPrint('  Errore verifica percorso: $e');
      return await _getDefaultPdfPath();
    }

  } else if (Platform.isWindows) {
    if (!isWindowsPath && percorsoOriginale.contains('/')) {
      final percorsoCorretto = percorsoOriginale.replaceAll('/', r'\');
      debugPrint('  Convertito Unix→Windows: $percorsoCorretto');
      return percorsoCorretto;
    }

    debugPrint('  √ Percorso Windows valido: $percorsoOriginale');
    return percorsoOriginale;

  } else {
    if (isWindowsPath) {
      final percorsoCorretto = percorsoOriginale.replaceAll(r'\', '/');
      debugPrint('  Convertito Windows→Unix: $percorsoCorretto');
      return percorsoCorretto;
    }

    debugPrint('  √ Percorso Unix valido: $percorsoOriginale');
    return percorsoOriginale;
  }
}

/// RESTITUISCE IL PERCORSO PDF PREIMPOSTATO PER LA PIATTAFORMA
Future<String> _getDefaultPdfPath() async {
  debugPrint('CREAZIONE PERCORSO DEFAULT per ${Platform.operatingSystem}');

  if (Platform.isAndroid) {
    try {
      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        final percorso = p.join(externalDir.path, 'JamsetPDF');
        debugPrint('  Android: Storage esterno → $percorso');
        return percorso;
      }
    } catch (e) {
      debugPrint('  Android storage esterno non disponibile: $e');
    }

    final appDocDir = await getApplicationDocumentsDirectory();
    final percorso = p.join(appDocDir.path, 'JamsetPDF');
    debugPrint('  Android: Directory app → $percorso');
    return percorso;

  } else if (Platform.isIOS) {
    final appDocDir = await getApplicationDocumentsDirectory();
    final percorso = p.join(appDocDir.path, 'JamsetPDF');
    debugPrint('  iOS: Directory app → $percorso');
    return percorso;

  } else if (Platform.isWindows) {
    final percorso = r'C:\JamsetPDF';
    debugPrint('  Windows: → $percorso');
    return percorso;

  } else if (Platform.isMacOS) {
    final percorso = '/Users/Shared/JamsetPDF';
    debugPrint('  macOS: → $percorso');
    return percorso;

  } else {
    final percorso = '/var/JamsetPDF';
    debugPrint('  Linux/Altro: → $percorso');
    return percorso;
  }
}

/// ===================================================================
/// FUNZIONE "GUARDIANO" PRINCIPALE - COMPLETA
/// ===================================================================
Future<void> inizializzaIDbDellaApp() async {
  try {
    debugPrint("========================================");
    debugPrint("INIZIALIZZAZIONE DB jamsetgemini");
    debugPrint("Piattaforma: ${Platform.operatingSystem}");
    debugPrint("Timestamp: ${DateTime.now()}");
    debugPrint("========================================");

    // --- FASE 1: OTTIENI LA DIRECTORY CORRETTA ---
    final supportDir = await getApplicationSupportDirectory();
    gDatabasePath = supportDir.path;
    debugPrint("Directory support: $gDatabasePath");

    // --- FASE 2: VECCHIODB.DB (CON POPOLAMENTO AUTOMATICO) ---
    debugPrint("FASE 1: Database VecchioDb.db...");
    final vecchioDbPath = p.join(gDatabasePath, _vecchioDbName);
    debugPrint("Percorso VecchioDb: $vecchioDbPath");

    // Creazione del VecchioDb con popolamento automatico
    dbVecchio = await openDatabase(
      vecchioDbPath,
      version: 1,
      onCreate: (db, version) async {
        debugPrint("VecchioDb.db non trovato. Creazione e popolamento...");

        // Prima crea la struttura
        await _creaStrutturaVecchioDb(db);

        // Poi popola da asset master
        await _popolaVecchioDbDaMaster(db);

        // Infine setup FTS
        await _setupDatabase(db, "VecchioDb");
      },
      onOpen: (db) async {
        debugPrint("VecchioDb.db aperto. Setup...");
        await _setupDatabase(db, "VecchioDb");
      },
    );

    debugPrint("VecchioDb.db pronto.");

    // --- FASE 3: DATABASE GLOBALE ---
    debugPrint("FASE 2: Database globale...");
    final dbGlobalePath = p.join(gDatabasePath, _dbGlobaleName);
    debugPrint("Percorso DB globale: $dbGlobalePath");

    // Se il DB non esiste, copialo dagli assets
    if (!await databaseExists(dbGlobalePath)) {
      debugPrint("DB globale non trovato. Copia da asset...");
      try {
        final ByteData data = await rootBundle.load('assets/databases/$_dbGlobaleName');
        await File(dbGlobalePath).writeAsBytes(data.buffer.asUint8List(), flush: true);
        debugPrint("DB globale copiato con successo");
      } catch (e) {
        debugPrint("ERRORE copia DB: $e - Creo DB vuoto");
        dbGlobale = await openDatabase(dbGlobalePath, version: 1, onCreate: _creaDbGlobaleVuoto);
      }
    }

    // Apri il database globale
    dbGlobale = await openDatabase(dbGlobalePath);
    debugPrint("DB globale aperto");

    // --- FASE 4: CORREZIONE PERCORSO PDF E CONFIGURAZIONI ---
    debugPrint("FASE 3: Configurazioni di sistema...");

    // Verifica se la tabella DatiSistremaApp esiste
    final tabelle = await dbGlobale!.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='DatiSistremaApp'"
    );

    if (tabelle.isEmpty) {
      debugPrint("Tabella DatiSistremaApp non trovata. Creazione...");
      await _creaDbGlobaleVuoto(dbGlobale!, 1);
    }

    // Leggi le configurazioni
    final datiSistema = await dbGlobale!.query('DatiSistremaApp', limit: 1);

    if (datiSistema.isNotEmpty) {
      final percorsoDalDB = datiSistema.first['PercorsoPdf'] as String? ?? '';
      final idCatalogoAttivo = datiSistema.first['id_catalogo_attivo'] as int? ?? 1;

      // CORREZIONE PERCORSO
      gPercorsoPdf = await _getPlatformCorrectedPdfPath(percorsoDalDB);

      debugPrint("Percorso dal DB: $percorsoDalDB");
      debugPrint("Percorso corretto: $gPercorsoPdf");
      debugPrint("ID catalogo attivo: $idCatalogoAttivo");

      // Aggiorna il DB se necessario
      if (gPercorsoPdf != percorsoDalDB) {
        await dbGlobale!.update(
          'DatiSistremaApp',
          {'PercorsoPdf': gPercorsoPdf},
        );
        debugPrint("Percorso aggiornato nel DB");
      }

      // Leggi il nome del catalogo attivo
      final catalogoInfo = await dbGlobale!.query(
          'elenco_cataloghi',
          where: 'id = ?',
          whereArgs: [idCatalogoAttivo],
          limit: 1
      );

      if (catalogoInfo.isNotEmpty) {
        gActiveCatalogDbName = catalogoInfo.first['nome_file_db'] as String;
        debugPrint("Nome file catalogo: $gActiveCatalogDbName");
      } else {
        gActiveCatalogDbName = 'catalogo_principale.db';
        debugPrint("Catalogo non trovato, usando default: $gActiveCatalogDbName");
      }

    } else {
      debugPrint("Tabella DatiSistremaApp vuota. Inserisco default...");
      final percorsoDefault = await _getDefaultPdfPath();
      gPercorsoPdf = percorsoDefault;
      gActiveCatalogDbName = 'catalogo_principale.db';

      await dbGlobale!.insert('DatiSistremaApp', {
        'SistemaOperativo': Platform.operatingSystem,
        'PercorsoPdf': percorsoDefault,
        'Percorsodatabase': gDatabasePath,
        'id_catalogo_attivo': 1,
      });

      await dbGlobale!.insert('elenco_cataloghi', {
        'nome': 'Catalogo Principale',
        'nome_file_db': gActiveCatalogDbName,
        'descrizione': 'Catalogo predefinito'
      });

      debugPrint("Configurazioni di default inserite");
    }

    // --- FASE 5: CATALOGO ATTIVO ---
    debugPrint("FASE 4: Catalogo attivo...");
    debugPrint("Nome file catalogo: $gActiveCatalogDbName");

    final catalogoPath = p.join(gDatabasePath, gActiveCatalogDbName);
    debugPrint("Percorso catalogo: $catalogoPath");

    // Se il catalogo non esiste, crea un DB vuoto
    if (!await databaseExists(catalogoPath)) {
      debugPrint("Catalogo non trovato. Creazione DB vuoto...");
      dbCatalogoAttivo = await openDatabase(
          catalogoPath,
          version: 1,
          onCreate: _creaCatalogoVuoto
      );
      debugPrint("Catalogo vuoto creato");
    } else {
      dbCatalogoAttivo = await openDatabase(catalogoPath);
      debugPrint("Catalogo esistente aperto");
    }

    // Setup FTS
    await _setupDatabase(dbCatalogoAttivo!, gActiveCatalogDbName);
    debugPrint("Catalogo attivo configurato");

    // =========================================
    debugPrint("========================================");
    debugPrint("INIZIALIZZAZIONE COMPLETATA");
    debugPrint("Piattaforma: ${Platform.operatingSystem}");
    debugPrint("Percorso PDF: $gPercorsoPdf");
    debugPrint("Percorso DB: $gDatabasePath");
    debugPrint("Catalogo Attivo: $gActiveCatalogDbName");
    debugPrint("========================================");

  } catch (e, s) {
    debugPrint("### ERRORE FATALE INIZIALIZZAZIONE: $e ###");
    debugPrint("### STACK TRACE: $s ###");

    // Fallback
    final defaultDir = await getApplicationDocumentsDirectory();
    gPercorsoPdf = p.join(defaultDir.path, 'JamsetPDF');
    gDatabasePath = defaultDir.path;
    gActiveCatalogDbName = 'catalogo_principale.db';

    debugPrint("Fallback impostato:");
    debugPrint("Percorso PDF: $gPercorsoPdf");
    debugPrint("Percorso DB: $gDatabasePath");

    rethrow;
  }
}

/// ===================================================================
/// FUNZIONI DI SUPPORTO
/// ===================================================================

// Crea struttura del VecchioDb
Future<void> _creaStrutturaVecchioDb(Database db) async {
  debugPrint("Creazione struttura VecchioDb...");

  await db.execute('''
    CREATE TABLE IF NOT EXISTS spartiti (
      id_univoco_globale INTEGER PRIMARY KEY AUTOINCREMENT,
      IdBra INTEGER UNIQUE,
      titolo TEXT,
      autore TEXT,
      strumento TEXT,
      volume TEXT,
      PercRadice TEXT,
      PercResto TEXT,
      PrimoLink TEXT,
      TipoMulti TEXT,
      TipoDocu TEXT,
      ArchivioProvenienza TEXT,
      NumPag INTEGER,
      NumOrig INTEGER,
      IdVolume TEXT,
      IdAutore TEXT
    )
  ''');

  debugPrint("Struttura VecchioDb creata");
}

// Crea un DB globale vuoto
Future<void> _creaDbGlobaleVuoto(Database db, int version) async {
  debugPrint("Creazione DB globale vuoto...");

  await db.execute('''
    CREATE TABLE IF NOT EXISTS DatiSistremaApp (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      SistemaOperativo TEXT,
      PercorsoPdf TEXT,
      Percorsodatabase TEXT,
      id_catalogo_attivo INTEGER DEFAULT 1
    )
  ''');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS elenco_cataloghi (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      nome TEXT,
      nome_file_db TEXT,
      descrizione TEXT
    )
  ''');

  debugPrint("Tabelle DB globale create");
}

// Crea un catalogo vuoto
Future<void> _creaCatalogoVuoto(Database db, int version) async {
  debugPrint("Creazione catalogo vuoto...");

  await db.execute('''
    CREATE TABLE IF NOT EXISTS spartiti (
      IdBra INTEGER PRIMARY KEY,
      titolo TEXT,
      autore TEXT,
      strumento TEXT,
      volume TEXT,
      PercRadice TEXT,
      PercResto TEXT,
      PrimoLink TEXT,
      TipoMulti TEXT,
      TipoDocu TEXT,
      ArchivioProvenienza TEXT,
      NumPag INTEGER,
      NumOrig INTEGER,
      IdVolume TEXT,
      IdAutore TEXT
    )
  ''');

  debugPrint("Tabella spartiti creata");
}

// Setup database con FTS
Future<void> _setupDatabase(Database db, String dbName) async {
  try {
    debugPrint("[$dbName] Setup database...");

    // Normalizzazione percorsi per non-Windows
    if (!Platform.isWindows) {
      debugPrint("   [$dbName] Normalizzazione percorsi...");
      await db.rawUpdate("UPDATE spartiti SET percResto = REPLACE(percResto, '\\\\', '/')");
    }

    // Verifica se FTS esiste
    final ftsTable = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='spartiti_fts'"
    );

    if (ftsTable.isEmpty) {
      debugPrint("   [$dbName] Creazione FTS...");

      await db.execute('''
        CREATE VIRTUAL TABLE spartiti_fts USING fts5(
          titolo, 
          autore, 
          strumento,
          content="spartiti", 
          content_rowid="IdBra"
        )
      ''');

      // Popola FTS se ci sono dati
      final countResult = await db.rawQuery('SELECT COUNT(*) as count FROM spartiti');
      final count = countResult.first['count'] as int? ?? 0;

      if (count > 0) {
        await db.execute('INSERT INTO spartiti_fts(rowid, titolo, autore, strumento) SELECT IdBra, titolo, autore, strumento FROM spartiti');
        debugPrint("   [$dbName] FTS popolato con $count record");
      }

      debugPrint("   [$dbName] FTS creato");
    } else {
      debugPrint("   [$dbName] FTS già esistente");
    }

  } catch (e) {
    debugPrint("### [$dbName] ERRORE setup: $e ###");
  }
}

/// ===================================================================
/// FUNZIONE PER CANCELLARE DB VECCHI E MIGRARE
/// ===================================================================
Future<void> migraDatabaseVecchi() async {
  debugPrint("=== MIGRAZIONE DATABASE VECCHI ===");

  try {
    final documentsDir = await getApplicationDocumentsDirectory();
    final supportDir = await getApplicationSupportDirectory();

    // File DB vecchi in Documents
    final vecchiFiles = [
      'DBGlobale.db',
      'jamset.db',
      'VecchioDb.db',
    ];

    for (var fileName in vecchiFiles) {
      final vecchioPath = p.join(documentsDir.path, fileName);
      final nuovoPath = p.join(supportDir.path, fileName);

      final vecchioFile = File(vecchioPath);
      if (await vecchioFile.exists()) {
        debugPrint("Trovato: $vecchioPath");

        // Copia al nuovo percorso
        await vecchioFile.copy(nuovoPath);
        debugPrint("Copiato a: $nuovoPath");

        // Opzionale: cancella il vecchio
        // await vecchioFile.delete();
        // debugPrint("Vecchio file cancellato");
      }
    }

    debugPrint("Migrazione completata");

  } catch (e) {
    debugPrint("Errore migrazione: $e");
  }
}