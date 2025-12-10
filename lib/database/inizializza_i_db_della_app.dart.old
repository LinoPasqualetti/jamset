// lib/database/inizializza_i_db_della_app.dart - VERSIONE CON FTS ASINCRONO
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

// Import delle variabili globali di jamsetgemini
import '../main.dart'; // Importa gPercorsoPdf, dbGlobale, etc.

const String _dbGlobaleName = 'DBGlobale_seed.db';
const String _vecchioDbName = 'VecchioDb.db';

// Variabile per tracciare lo stato di inizializzazione
bool _isInitializing = false;
Completer<void>? _initializationCompleter;

/// ===================================================================
/// CREAZIONE INDICI FTS OTTIMIZZATA PER ANDROID
/// ===================================================================
Future<void> _creaIndiciFTSOttimizzati(Database db) async {
  debugPrint("Creazione indici FTS ottimizzati...");

  try {
    // 1. Verifica se la tabella FTS esiste già
    final existingTables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='spartiti_fts'"
    );

    if (existingTables.isNotEmpty) {
      debugPrint("  Tabella FTS già esistente.");
      return;
    }

    // 2. Per Android: tokenizer specifico
    if (Platform.isAndroid) {
      await db.execute('''
        CREATE VIRTUAL TABLE spartiti_fts 
        USING fts5(
          titolo,
          autore,
          strumento,
          volume,
          ArchivioProvenienza,
          content='spartiti',
          content_rowid='id_univoco_globale',
          tokenize='unicode61'
        )
      ''');
      debugPrint("  FTS Android creato (unicode61).");
    } else {
      // Altre piattaforme: FTS standard
      await db.execute('''
        CREATE VIRTUAL TABLE spartiti_fts 
        USING fts5(
          titolo,
          autore,
          strumento,
          volume,
          ArchivioProvenienza,
          content='spartiti',
          content_rowid='id_univoco_globale'
        )
      ''');
      debugPrint("  FTS standard creato.");
    }

    // 3. Popola FTS con i dati esistenti (in background se molti dati)
    final countResult = await db.rawQuery("SELECT COUNT(*) as count FROM spartiti");
    final recordCount = countResult.first['count'] as int? ?? 0;

    if (recordCount > 1000) {
      // Per grandi database, popola in background
      debugPrint("  Popolamento FTS in background ($recordCount record)...");
      Future.microtask(() async {
        try {
          await db.execute('''
            INSERT INTO spartiti_fts(rowid, titolo, autore, strumento, volume, ArchivioProvenienza)
            SELECT id_univoco_globale, 
                   COALESCE(titolo, ''),
                   COALESCE(autore, ''),
                   COALESCE(strumento, ''),
                   COALESCE(volume, ''),
                   COALESCE(ArchivioProvenienza, '')
            FROM spartiti
          ''');
          debugPrint("  FTS popolato con $recordCount record.");
        } catch (e) {
          debugPrint("  Errore popolamento FTS: $e");
        }
      });
    } else if (recordCount > 0) {
      // Per piccoli database, popola immediatamente
      debugPrint("  Popolamento FTS immediato ($recordCount record)...");
      await db.execute('''
        INSERT INTO spartiti_fts(rowid, titolo, autore, strumento, volume, ArchivioProvenienza)
        SELECT id_univoco_globale, 
               COALESCE(titolo, ''),
               COALESCE(autore, ''),
               COALESCE(strumento, ''),
               COALESCE(volume, ''),
               COALESCE(ArchivioProvenienza, '')
        FROM spartiti
      ''');
      debugPrint("  FTS popolato.");
    }

    debugPrint("  Indici FTS creati con successo.");

  } catch (e, s) {
    debugPrint("### ERRORE creazione FTS: $e ###");
    debugPrint("### STACK TRACE: $s ###");
    // Non blocchiamo l'app se FTS fallisce
  }
}

/// ===================================================================
/// FUNZIONE ASINCRONA PER POPOLARE VecchioDb CON FTS
/// ===================================================================
Future<void> _popolaVecchioDbDaMaster(Database db) async {
  debugPrint("POPOLAMENTO VecchioDb da asset master...");

  await Future.delayed(Duration.zero);

  try {
    // 1. Carica il DB master
    debugPrint("  1. Caricamento asset...");
    final ByteData data = await rootBundle.load('assets/databases/$_vecchioDbName');
    final tempAssetDbPath = p.join((await getTemporaryDirectory()).path, "vecchio_master_temp.db");
    await File(tempAssetDbPath).writeAsBytes(data.buffer.asUint8List(), flush: true);

    Database? masterDb;
    try {
      // 2. Apri DB master
      masterDb = await openReadOnlyDatabase(tempAssetDbPath);

      // 3. Determina tabella sorgente
      final sourceTableName = Platform.isWindows ? 'spartiti' : 'spartiti_andr';
      debugPrint("  3. Tabella sorgente: '$sourceTableName'");

      // 4. Leggi i dati
      List<Map<String, dynamic>> dataToInsert;
      try {
        dataToInsert = await masterDb.query(sourceTableName);
      } catch (e) {
        final fallbackTable = Platform.isWindows ? 'spartiti_andr' : 'spartiti';
        dataToInsert = await masterDb.query(fallbackTable);
      }

      debugPrint("  4. Letti ${dataToInsert.length} record.");

      // 5. Inserisci in blocchi
      await _insertDataInChunks(db, dataToInsert, chunkSize: 100);

      // 6. Crea indici FTS DOPO l'inserimento (asincrono)
      debugPrint("  5. Avvio creazione indici FTS in background...");
      Future.microtask(() async {
        try {
          await _creaIndiciFTSOttimizzati(db);
          debugPrint("  5. Indicizzazione FTS completata.");
        } catch (e) {
          debugPrint("  5. Errore indicizzazione FTS: $e");
        }
      });

    } finally {
      await masterDb?.close();
      await deleteDatabase(tempAssetDbPath);
    }

    debugPrint("POPOLAMENTO VecchioDb COMPLETATO!");

  } catch (e, s) {
    debugPrint("### ERRORE in _popolaVecchioDbDaMaster: $e ###");
    debugPrint("### STACK TRACE: $s ###");
    rethrow;
  }
}

/// Inserisce dati in blocchi
Future<void> _insertDataInChunks(
    Database db,
    List<Map<String, dynamic>> data,
    {int chunkSize = 100}
    ) async {
  if (data.isEmpty) return;

  debugPrint("  Inserimento in blocchi di $chunkSize (totale: ${data.length})...");

  for (var i = 0; i < data.length; i += chunkSize) {
    final end = (i + chunkSize < data.length) ? i + chunkSize : data.length;
    final chunk = data.sublist(i, end);

    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final row in chunk) {
        batch.insert('spartiti', row, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await batch.commit(noResult: true);
    });

    // Rilascia controllo UI periodicamente
    if (i % 500 == 0) {
      await Future.delayed(Duration.zero);
      final progress = ((i / data.length) * 100).toStringAsFixed(1);
      debugPrint("    Progresso: $progress%");
    }
  }
}

/// ===================================================================
/// RESTANTE DEL CODICE (uguale al precedente ma aggiornato)
/// ===================================================================

Future<String> _getDefaultSystemWidePath() async {
  debugPrint('PERCORSO SYSTEM-WIDE per ${Platform.operatingSystem}');

  final defaultPaths = {
    'android': '/storage/emulated/0/JamsetPDF/',
    'windows': r'C:\JamsetPDF\',
    'linux': '/var/lib/jamsetgemini/pdf/',
    'macos': '/Library/Application Support/JamsetPDF/',
  };

  final os = Platform.operatingSystem.toLowerCase();
  final defaultPath = defaultPaths[os];

  if (defaultPath != null) {
    debugPrint('  Percorso predefinito: $defaultPath');
    return defaultPath;
  }

  if (Platform.isIOS) {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'JamsetPDF');
    debugPrint('  iOS: Sandbox app → $path');
    return path;
  }

  return 'JamsetPDF';
}

Future<String> _getPlatformCorrectedPdfPath(String percorsoOriginale) async {
  if (percorsoOriginale.isEmpty) {
    return await _getDefaultSystemWidePath();
  }

  final bool isWindowsPath = percorsoOriginale.contains(r'\') ||
      percorsoOriginale.startsWith(RegExp(r'[A-Z]:\\'));

  if (Platform.isAndroid || Platform.isIOS) {
    if (isWindowsPath) {
      return await _getDefaultSystemWidePath();
    }
    try {
      final dir = Directory(percorsoOriginale);
      if (await dir.exists()) return percorsoOriginale;
    } catch (e) {}
    return await _getDefaultSystemWidePath();
  } else if (Platform.isWindows) {
    if (!isWindowsPath && percorsoOriginale.contains('/')) {
      return percorsoOriginale.replaceAll('/', r'\');
    }
    return percorsoOriginale;
  } else {
    if (isWindowsPath) {
      return percorsoOriginale.replaceAll(r'\', '/');
    }
    return percorsoOriginale;
  }
}

/// ===================================================================
/// FUNZIONE PRINCIPALE AGGIORNATA
/// ===================================================================
Future<void> inizializzaIDbDellaApp() async {
  if (_isInitializing && _initializationCompleter != null) {
    return _initializationCompleter!.future;
  }

  _isInitializing = true;
  _initializationCompleter = Completer<void>();

  try {
    debugPrint("========================================");
    debugPrint("INIZIALIZZAZIONE DB jamsetgemini");
    debugPrint("Piattaforma: ${Platform.operatingSystem}");
    debugPrint("Timestamp: ${DateTime.now()}");
    debugPrint("========================================");

    // --- FASE 1: DIRECTORY ---
    final supportDir = await getApplicationSupportDirectory();
    gDatabasePath = supportDir.path;
    debugPrint("Directory support: $gDatabasePath");

    await Future.delayed(Duration.zero);

    // --- FASE 2: VECCHIODB.DB CON FTS ---
    debugPrint("FASE 1: Database VecchioDb.db...");
    final vecchioDbPath = p.join(gDatabasePath, _vecchioDbName);

    dbVecchio = await openDatabase(
      vecchioDbPath,
      version: 2, // Incrementata per FTS
      onCreate: (db, version) async {
        debugPrint("VecchioDb.db: creazione struttura...");
        await _creaStrutturaVecchioDb(db);

        // Popolamento in background
        Future.microtask(() async {
          try {
            await _popolaVecchioDbDaMaster(db);
            debugPrint("VecchioDb.db: popolamento completato.");
          } catch (e) {
            debugPrint("VecchioDb.db: errore popolamento: $e");
          }
        });

        await _setupDatabase(db, "VecchioDb");
      },
      onOpen: (db) async {
        debugPrint("VecchioDb.db: setup e verifica FTS...");
        await _setupDatabase(db, "VecchioDb");
        // Verifica se FTS esiste, altrimenti crea
        await _verificaECreaFTS(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        debugPrint("Upgrade VecchioDb da v$oldVersion a v$newVersion");
        if (oldVersion < 2) {
          await _creaIndiciFTSOttimizzati(db);
        }
      },
    );

    debugPrint("VecchioDb.db pronto.");

    // --- FASI 3-6: RESTANTE INIZIALIZZAZIONE (come prima) ---
    // [Mantieni il codice originale per DB globale, percorso PDF, catalogo, etc.]

    final dbGlobalePath = p.join(gDatabasePath, _dbGlobaleName);

    if (!await databaseExists(dbGlobalePath)) {
      try {
        final ByteData data = await rootBundle.load('assets/databases/$_dbGlobaleName');
        await File(dbGlobalePath).writeAsBytes(data.buffer.asUint8List(), flush: true);
      } catch (e) {
        dbGlobale = await openDatabase(dbGlobalePath, version: 1, onCreate: _creaDbGlobaleVuoto);
      }
    }

    dbGlobale = await openDatabase(dbGlobalePath);

    // Configura percorso PDF
    final tabelle = await dbGlobale!.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='DatiSistremaApp'"
    );

    if (tabelle.isEmpty) {
      await _creaDbGlobaleVuoto(dbGlobale!, 1);
    }

    final datiSistema = await dbGlobale!.query('DatiSistremaApp', limit: 1);
    if (datiSistema.isNotEmpty) {
      final percorsoDalDB = datiSistema.first['PercorsoPdf'] as String? ?? '';
      final idCatalogoAttivo = datiSistema.first['id_catalogo_attivo'] as int? ?? 1;

      if (percorsoDalDB.isEmpty) {
        gPercorsoPdf = await _getDefaultSystemWidePath();
        await dbGlobale!.update('DatiSistremaApp', {'PercorsoPdf': gPercorsoPdf});
      } else {
        gPercorsoPdf = await _getPlatformCorrectedPdfPath(percorsoDalDB);
        if (gPercorsoPdf != percorsoDalDB) {
          await dbGlobale!.update('DatiSistremaApp', {'PercorsoPdf': gPercorsoPdf});
        }
      }

      final catalogoInfo = await dbGlobale!.query(
          'elenco_cataloghi',
          where: 'id = ?',
          whereArgs: [idCatalogoAttivo],
          limit: 1
      );

      gActiveCatalogDbName = catalogoInfo.isNotEmpty
          ? catalogoInfo.first['nome_file_db'] as String
          : 'catalogo_principale.db';
    } else {
      gPercorsoPdf = await _getDefaultSystemWidePath();
      gActiveCatalogDbName = 'catalogo_principale.db';

      await dbGlobale!.insert('DatiSistremaApp', {
        'SistemaOperativo': Platform.operatingSystem,
        'PercorsoPdf': gPercorsoPdf,
        'Percorsodatabase': gDatabasePath,
        'id_catalogo_attivo': 1,
      });

      await dbGlobale!.insert('elenco_cataloghi', {
        'nome': 'Catalogo Principale',
        'nome_file_db': gActiveCatalogDbName,
        'descrizione': 'Catalogo predefinito'
      });
    }

    // Catalogo attivo
    final catalogoPath = p.join(gDatabasePath, gActiveCatalogDbName);

    if (!await databaseExists(catalogoPath)) {
      dbCatalogoAttivo = await openDatabase(
          catalogoPath,
          version: 1,
          onCreate: _creaCatalogoVuoto
      );
    } else {
      dbCatalogoAttivo = await openDatabase(catalogoPath);
    }

    await _setupDatabase(dbCatalogoAttivo!, gActiveCatalogDbName);

    // Crea directory PDF
    try {
      final pdfDir = Directory(gPercorsoPdf);
      if (!await pdfDir.exists()) {
        await pdfDir.create(recursive: true);
      }
    } catch (e) {
      debugPrint("Errore creazione directory PDF: $e");
    }

    debugPrint("========================================");
    debugPrint("INIZIALIZZAZIONE COMPLETATA");
    debugPrint("Percorso PDF: $gPercorsoPdf");
    debugPrint("========================================");

    _initializationCompleter!.complete();

  } catch (e, s) {
    debugPrint("### ERRORE INIZIALIZZAZIONE: $e ###");
    debugPrint("### STACK TRACE: $s ###");
    _initializationCompleter!.completeError(e);
    rethrow;
  } finally {
    _isInitializing = false;
  }
}

/// Verifica e crea FTS se necessario
Future<void> _verificaECreaFTS(Database db) async {
  try {
    final existingTables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='spartiti_fts'"
    );

    if (existingTables.isEmpty) {
      debugPrint("FTS non trovato, creazione...");
      await _creaIndiciFTSOttimizzati(db);
    } else {
      debugPrint("FTS già presente.");
    }
  } catch (e) {
    debugPrint("Errore verifica FTS: $e");
  }
}

/// ===================================================================
/// FUNZIONI DI SUPPORTO
/// ===================================================================

Future<void> _creaStrutturaVecchioDb(Database db) async {
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
}

Future<void> _creaDbGlobaleVuoto(Database db, int version) async {
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
}

Future<void> _creaCatalogoVuoto(Database db, int version) async {
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
}

Future<void> _setupDatabase(Database db, String dbName) async {
  try {
    await db.execute('PRAGMA journal_mode = WAL');
    await db.execute('PRAGMA synchronous = NORMAL');
  } catch (e) {
    debugPrint("Errore setup PRAGMA: $e");
  }
}

bool isInitializationInProgress() => _isInitializing;
Future<void> waitForInitialization() => _initializationCompleter?.future ?? Future.value();