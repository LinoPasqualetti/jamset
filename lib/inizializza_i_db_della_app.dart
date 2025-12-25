// lib/database/inizializza_i_db_della_app.dart - VERSIONE CON IDBRA COME PK
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../main.dart';

const String _dbGlobaleName = 'DBGlobale_seed.db';
const String _vecchioDbName = 'VecchioDb.db';

bool _isInitializing = false;
Completer<void>? _initializationCompleter;

/// ===================================================================
/// 1. FUNZIONI PER GESTIONE PERCORSI PDF (INALTERATE)
/// ===================================================================

Future<String> _getDefaultSystemWidePath() async {
  debugPrint('PERCORSO SYSTEM-WIDE per \${Platform.operatingSystem}');

  final defaultPaths = {
    'android': '/storage/emulated/0/JamsetPDF/',
    'windows': r'C:\\JamsetPDF\\',
    'linux': '/var/lib/livescore/pdf/',
    'macos': '/Library/Application Support/JamsetPDF/',
  };

  final os = Platform.operatingSystem.toLowerCase();
  final defaultPath = defaultPaths[os];

  if (defaultPath != null) {
    debugPrint('  Percorso predefinito: \$defaultPath');
    return defaultPath;
  }

  if (Platform.isIOS) {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'JamsetPDF');
    debugPrint('  iOS: Sandbox app → \$path');
    return path;
  }

  return 'JamsetPDF';
}

Future<String> _getPlatformCorrectedPdfPath(String percorsoOriginale) async {
  if (percorsoOriginale.isEmpty) {
    return await _getDefaultSystemWidePath();
  }

  final bool isWindowsPath = percorsoOriginale.contains(r'\\') ||
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
      return percorsoOriginale.replaceAll('/', r'\\');
    }
    return percorsoOriginale;
  } else {
    if (isWindowsPath) {
      return percorsoOriginale.replaceAll(r'\\', '/');
    }
    return percorsoOriginale;
  }
}

/// ===================================================================
/// 2. CREAZIONE E POPOLAMENTO TABELLA SPARTITI - MODIFICATO
/// ===================================================================

/// Crea la tabella spartiti con IdBra come chiave primaria
Future<void> _creaTabellaSpartiti(Database db) async {
  debugPrint("🏗️  Creazione tabella spartiti (IdBra come PRIMARY KEY)...");

  await db.execute('''
    CREATE TABLE IF NOT EXISTS spartiti (
      IdBra INTEGER PRIMARY KEY,  -- MODIFICATO: INTEGER PRIMARY KEY (no AUTOINCREMENT)
      titolo TEXT,
      autore TEXT,
      strumento TEXT,
      volume TEXT,
      PercRadice TEXT,
      PercResto TEXT,
      PrimoLInk TEXT,
      TipoMulti TEXT,
      TipoDocu TEXT,
      ArchivioProvenienza TEXT,
      NumPag INTEGER,
      NumOrig INTEGER,
      IdVolume TEXT,
      IdAutore TEXT
    )
  ''');

  debugPrint("✅ Tabella spartiti creata con IdBra INTEGER PRIMARY KEY");
}

/// Crea FTS con content_rowid = 'IdBra'
Future<void> _creaIndiciFTS(Database db) async {
  debugPrint("🔍 Configurazione sistema FTS (IdBra come content_rowid)...");

  try {
    // Verifica se FTS esiste già
    final ftsEsiste = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='spartiti_fts'"
    );

    if (ftsEsiste.isNotEmpty) {
      debugPrint("⚠️ Tabella FTS già presente, la elimino e ricreo...");
      await _eliminaFTSCompleto(db);
    }

    // 1. PRIMA crea la tabella FTS con content_rowid = 'IdBra'
    debugPrint("  1. Creazione tabella FTS...");

    try {
      await db.execute('''
        CREATE VIRTUAL TABLE spartiti_fts USING fts5(
          titolo,
          autore,
          volume,
          ArchivioProvenienza,
          content='spartiti',
          content_rowid='IdBra'  -- MODIFICATO: usa IdBra invece di id_univoco_globale
        )
      ''');
      debugPrint("     ✅ Tabella FTS creata con content_rowid='IdBra'");
    } catch (e) {
      debugPrint("     ⚠️ FTS con content fallito, creo senza: \$e");
      await db.execute('''
        CREATE VIRTUAL TABLE spartiti_fts USING fts5(
          titolo,
          autore,
          volume,
          ArchivioProvenienza
        )
      ''');
      debugPrint("     ✅ Tabella FTS creata senza content");
    }

    // 2. POI crea i TRIGGER che usano IdBra
    debugPrint("  2. Creazione trigger FTS...");

    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS spartiti_ai_fts AFTER INSERT ON spartiti BEGIN
        INSERT INTO spartiti_fts(IdBra, titolo, autore, volume, ArchivioProvenienza)
        VALUES (NEW.IdBra, NEW.titolo, NEW.autore, NEW.volume, NEW.ArchivioProvenienza);
      END;
    ''');

    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS spartiti_au_fts AFTER UPDATE ON spartiti BEGIN
        UPDATE spartiti_fts 
        SET titolo = NEW.titolo, 
            autore = NEW.autore, 
            volume = NEW.volume, 
            ArchivioProvenienza = NEW.ArchivioProvenienza
        WHERE IdBra = OLD.IdBra;
      END;
    ''');

    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS spartiti_ad_fts AFTER DELETE ON spartiti BEGIN
        DELETE FROM spartiti_fts WHERE IdBra = OLD.IdBra;
      END;
    ''');

    debugPrint("     ✅ Trigger FTS creati (usano IdBra)");

    debugPrint("🎯 Sistema FTS configurato con IdBra come chiave");

  } catch (e) {
    debugPrint("❌ Errore configurazione FTS: \$e");
    throw Exception("Impossibile configurare FTS: \$e");
  }
}

/// Elimina completamente tutto l'FTS e i trigger
Future<void> _eliminaFTSCompleto(Database db) async {
  try {
    // Elimina prima i trigger
    await db.execute("DROP TRIGGER IF EXISTS spartiti_ai_fts");
    await db.execute("DROP TRIGGER IF EXISTS spartiti_au_fts");
    await db.execute("DROP TRIGGER IF EXISTS spartiti_ad_fts");

    // Poi le tabelle FTS
    await db.execute("DROP TABLE IF EXISTS spartiti_fts");
    await db.execute("DROP TABLE IF EXISTS spartiti_fts_data");
    await db.execute("DROP TABLE IF EXISTS spartiti_fts_idx");
    await db.execute("DROP TABLE IF EXISTS spartiti_fts_docsize");
    await db.execute("DROP TABLE IF EXISTS spartiti_fts_config");

    debugPrint("✅ Sistema FTS eliminato (tabelle + trigger)");
  } catch (e) {
    debugPrint("⚠️ Errore eliminazione FTS: \$e");
  }
}

/// Verifica e sincronizza FTS usando IdBra
Future<void> _verificaESincronizzaFTS(Database db) async {
  try {
    debugPrint("🔍 Verifica sincronizzazione FTS (IdBra)...");

    // 1. Verifica trigger FTS
    final triggerFTS = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='trigger' AND name LIKE '%fts%'"
    );

    if (triggerFTS.isEmpty) {
      debugPrint("❌ Trigger FTS mancanti! Ricostruisco sistema completo...");
      await _eliminaFTSCompleto(db);
      await _creaIndiciFTS(db);

      // Popola manualmente usando IdBra
      final countSpartiti = await db.rawQuery("SELECT COUNT(*) as c FROM spartiti");
      final totalSpartiti = countSpartiti.first['c'] as int? ?? 0;

      if (totalSpartiti > 0) {
        debugPrint("🔄 Popolamento manuale FTS per \$totalSpartiti record (usando IdBra)...");
        await db.execute('''
          INSERT INTO spartiti_fts(IdBra, titolo, autore, volume, ArchivioProvenienza)
          SELECT 
            IdBra,  -- MODIFICATO: usa IdBra invece di id_univoco_globale
            COALESCE(titolo, ''),
            COALESCE(autore, ''),
            COALESCE(volume, ''),
            COALESCE(ArchivioProvenienza, '')
          FROM spartiti
        ''');
      }

      return;
    }

    debugPrint("✅ Trigger FTS trovati: \${triggerFTS.length}");

    // 2. Conta record in spartiti
    final countSpartiti = await db.rawQuery("SELECT COUNT(*) as c FROM spartiti");
    final totalSpartiti = countSpartiti.first['c'] as int? ?? 0;

    // 3. Conta record in FTS
    final countFTS = await db.rawQuery("SELECT COUNT(*) as c FROM spartiti_fts");
    final totalFTS = countFTS.first['c'] as int? ?? 0;

    debugPrint("   Record spartiti: \$totalSpartiti");
    debugPrint("   Record FTS: \$totalFTS");

    if (totalSpartiti == 0) {
      debugPrint("   ⚠️ Tabella spartiti vuota, FTS non necessario");
      return;
    }

    if (totalFTS == 0) {
      debugPrint("   🔄 FTS vuoto, popolo manualmente (usando IdBra)...");
      await db.execute('''
        INSERT INTO spartiti_fts(IdBra, titolo, autore, volume, ArchivioProvenienza)
        SELECT 
          IdBra,
          COALESCE(titolo, ''),
          COALESCE(autore, ''),
          COALESCE(volume, ''),
          COALESCE(ArchivioProvenienza, '')
        FROM spartiti
      ''');
      debugPrint("     ✅ FTS popolato manualmente");

    } else if (totalFTS != totalSpartiti) {
      debugPrint("   🔄 FTS non sincronizzato (\$totalFTS/\$totalSpartiti), risincronizzo...");
      await _eliminaFTSCompleto(db);
      await _creaIndiciFTS(db);

      await db.execute('''
        INSERT INTO spartiti_fts(IdBra, titolo, autore, volume, ArchivioProvenienza)
        SELECT 
          IdBra,
          COALESCE(titolo, ''),
          COALESCE(autore, ''),
          COALESCE(volume, ''),
          COALESCE(ArchivioProvenienza, '')
        FROM spartiti
      ''');
      debugPrint("     ✅ FTS risincronizzato");

    } else {
      debugPrint("   ✅ FTS conteggio OK");

      // 4. Verifica QUALITÀ sincronizzazione usando IdBra
      debugPrint("   🔍 Verifica qualità sincronizzazione (IdBra)...");
      final differenze = await db.rawQuery('''
        SELECT COUNT(*) as c FROM spartiti s
        WHERE NOT EXISTS (
          SELECT 1 FROM spartiti_fts f 
          WHERE f.IdBra = s.IdBra  -- MODIFICATO
        )
      ''');

      final diffCount = differenze.first['c'] as int? ?? 0;
      if (diffCount > 0) {
        debugPrint("   ⚠️ \$diffCount record non sincronizzati! Ricostruisco...");
        await _eliminaFTSCompleto(db);
        await _creaIndiciFTS(db);

        await db.execute('''
          INSERT INTO spartiti_fts(IdBra, titolo, autore, volume, ArchivioProvenienza)
          SELECT 
            IdBra,
            COALESCE(titolo, ''),
            COALESCE(autore, ''),
            COALESCE(volume, ''),
            COALESCE(ArchivioProvenienza, '')
          FROM spartiti
        ''');
        debugPrint("     ✅ FTS ricostruito per qualità");
      } else {
        debugPrint("   ✅ FTS perfettamente sincronizzato");
      }
    }

    // Test rapido FTS
    await _testFTSRapido(db);

  } catch (e) {
    debugPrint("❌ Errore verifica FTS: \$e");
    try {
      await _eliminaFTSCompleto(db);
      await _creaIndiciFTS(db);

      final countSpartiti = await db.rawQuery("SELECT COUNT(*) as c FROM spartiti");
      final totalSpartiti = countSpartiti.first['c'] as int? ?? 0;

      if (totalSpartiti > 0) {
        await db.execute('''
          INSERT INTO spartiti_fts(IdBra, titolo, autore, volume, ArchivioProvenienza)
          SELECT 
            IdBra,
            COALESCE(titolo, ''),
            COALESCE(autore, ''),
            COALESCE(volume, ''),
            COALESCE(ArchivioProvenienza, '')
          FROM spartiti
        ''');
      }

      debugPrint("✅ FTS ricostruito dopo errore");
    } catch (e2) {
      debugPrint("❌ Errore critico ricostruzione FTS: \$e2");
    }
  }
}

/// Test rapido per verificare che FTS funzioni
Future<void> _testFTSRapido(Database db) async {
  try {
    debugPrint("🧪 Test rapido FTS...");

    final paroleTest = ['jazz', 'blues', 'piano', 'guitar', 'song'];

    for (final parola in paroleTest) {
      try {
        final risultati = await db.rawQuery(
            "SELECT COUNT(*) as c FROM spartiti_fts WHERE spartiti_fts MATCH ?",
            [parola]
        );
        final count = risultati.first['c'] as int? ?? 0;
        if (count > 0) {
          debugPrint("   ✅ FTS funziona: '\$parola' → \$count risultati");
          return;
        }
      } catch (e) {
        // Ignora errori di singole parole
      }
    }

    debugPrint("   ⚠️ Nessun test positivo, verifica manualmente");

  } catch (e) {
    debugPrint("   ❌ Test FTS fallito: \$e");
  }
}

/// Importa dati dal database asset nella tabella spartiti - MODIFICATO
Future<int> _importaDatiDaAsset(Database db) async {
  debugPrint("📥 Importazione dati da database asset (conversione IdBra)...");

  try {
    // 1. Carica il DB master dagli assets
    final ByteData data = await rootBundle.load('assets/databases/\$_vecchioDbName');
    final tempAssetDbPath = p.join((await getTemporaryDirectory()).path, "vecchio_master_temp.db");
    await File(tempAssetDbPath).writeAsBytes(data.buffer.asUint8List(), flush: true);

    Database? masterDb;
    int recordImportati = 0;

    try {
      // 2. Apri DB master
      masterDb = await openReadOnlyDatabase(tempAssetDbPath);

      // 3. Determina tabella sorgente in base al SO
      final sourceTable = Platform.isWindows ? 'spartiti' : 'spartiti_andr';
      debugPrint("   Tabella sorgente: '\$sourceTable'");

      // 4. Leggi i dati dalla tabella corretta
      List<Map<String, dynamic>> dataToInsert;
      try {
        dataToInsert = await masterDb.query(sourceTable);
      } catch (e) {
        debugPrint("   ⚠️ Tabella '\$sourceTable' non trovata, prova fallback...");
        final fallbackTable = Platform.isWindows ? 'spartiti_andr' : 'spartiti';
        dataToInsert = await masterDb.query(fallbackTable);
      }

      debugPrint("   Letti \${dataToInsert.length} record da asset");

      if (dataToInsert.isEmpty) {
        debugPrint("   ⚠️ Nessun dato trovato nella tabella");
        return 0;
      }

      // 5. Inserisci dati con conversione IdBra
      final chunkSize = 100;
      for (var i = 0; i < dataToInsert.length; i += chunkSize) {
        final end = (i + chunkSize < dataToInsert.length) ? i + chunkSize : dataToInsert.length;
        final chunk = dataToInsert.sublist(i, end);

        await db.transaction((txn) async {
          final batch = txn.batch();
          for (final row in chunk) {
            // MODIFICA: Prepara i dati con IdBra convertito
            final rowCopy = Map<String, dynamic>.from(row);

            // 1. Gestisci IdBra: converte TEXT a INTEGER se possibile
            if (rowCopy.containsKey('IdBra')) {
              final idBraValue = rowCopy['IdBra'];
              if (idBraValue is String && idBraValue.isNotEmpty) {
                // Prova a convertire in intero
                final parsed = int.tryParse(idBraValue);
                if (parsed != null) {
                  rowCopy['IdBra'] = parsed;
                } else {
                  // Se non è numerico, usa hash o genera nuovo ID
                  debugPrint("   ⚠️ IdBra non numerico: '\$idBraValue', genero nuovo ID");
                  rowCopy.remove('IdBra'); // Lascia che il database generi un nuovo ID
                }
              }
            }

            // 2. Rimuovi id_univoco_globale (non più usato)
            rowCopy.remove('id_univoco_globale');

            // Inserisci
            batch.insert('spartiti', rowCopy,
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
          await batch.commit(noResult: true);
        });

        recordImportati += chunk.length;

        // Progresso
        if (i % 500 == 0) {
          final progress = ((i / dataToInsert.length) * 100).toStringAsFixed(1);
          debugPrint("   Progresso: \$progress% (\$recordImportati record)");
          await Future.delayed(Duration.zero);
        }
      }

      debugPrint("✅ Importati \$recordImportati record da asset");
      debugPrint("   ℹ️  I trigger hanno popolato automaticamente l'FTS con IdBra");

      return recordImportati;

    } finally {
      await masterDb?.close();
      try {
        await deleteDatabase(tempAssetDbPath);
      } catch (e) {
        // Ignora errori di cancellazione
      }
    }

  } catch (e) {
    debugPrint("❌ Errore importazione dati: \$e");
    return 0;
  }
}

/// ===================================================================
/// 3. GESTIONE DB GLOBALE (INALTERATA)
/// ===================================================================

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

  debugPrint("✅ Struttura DBGlobale creata (v\$version)");
}

Future<void> _inizializzaDbGlobale(Database db) async {
  final percorsoDefault = await _getDefaultSystemWidePath();
  final dbPath = db.path.substring(0, db.path.lastIndexOf('/'));

  await db.insert('DatiSistremaApp', {
    'SistemaOperativo': Platform.operatingSystem,
    'PercorsoPdf': percorsoDefault,
    'Percorsodatabase': dbPath,
    'id_catalogo_attivo': 1,
  });

  await db.insert('elenco_cataloghi', {
    'nome': 'Catalogo Principale',
    'nome_file_db': _vecchioDbName,
    'descrizione': 'Catalogo predefinito importato da asset'
  });

  debugPrint("✅ DBGlobale inizializzato con valori di default");
}

/// ===================================================================
/// 4. FUNZIONI PRINCIPALI (CON MODIFICHE MINIME)
/// ===================================================================

Future<Database> openReadOnlyDatabase(String path) async {
  return await openDatabase(
    path,
    version: 1,
    readOnly: true,
  );
}

/// Punto di ingresso principale - inizializza tutti i database
Future<void> initializeAppDatabases() async {
  if (_isInitializing) {
    debugPrint("⏳ Inizializzazione già in corso, attendo...");
    await _initializationCompleter?.future;
    return;
  }

  _isInitializing = true;
  _initializationCompleter = Completer<void>();

  try {
    debugPrint("🚀 INIZIALIZZAZIONE DATABASE DELL'APP");

    final appDir = await getApplicationDocumentsDirectory();
    final dbGlobalePath = p.join(appDir.path, _dbGlobaleName);
    final vecchioDbPath = p.join(appDir.path, _vecchioDbName);

    // Apri o crea DBGlobale
    final dbGlobale = await openDatabase(
      dbGlobalePath,
      version: 1,
      onCreate: _creaDbGlobaleVuoto,
    );

    // Inizializza DBGlobale se vuoto
    final countGlobale = await dbGlobale.rawQuery(
        "SELECT COUNT(*) as c FROM DatiSistremaApp"
    );
    if ((countGlobale.first['c'] as int? ?? 0) == 0) {
      await _inizializzaDbGlobale(dbGlobale);
    }

    // Verifica se VecchioDb esiste già
    final vecchioDbEsiste = await File(vecchioDbPath).exists();

    if (!vecchioDbEsiste) {
      debugPrint("🆕 Database spartiti non trovato, creazione nuova struttura...");

      // Crea nuovo database
      final vecchioDb = await openDatabase(
        vecchioDbPath,
        version: 2,
        onCreate: (db, version) async {
          await _creaTabellaSpartiti(db);
          await _creaIndiciFTS(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          debugPrint("🔄 Upgrade database: \$oldVersion → \$newVersion");
          if (oldVersion < 2) {
            // Migrazione alla versione con IdBra come PK
            await _migraAVersione2(db);
          }
        },
      );

      // Importa dati dagli asset
      await _importaDatiDaAsset(vecchioDb);

      await vecchioDb.close();
      debugPrint("✅ Nuovo database spartiti creato e popolato");
    } else {
      debugPrint("✅ Database spartiti già esistente, verifico struttura...");

      final vecchioDb = await openDatabase(
        vecchioDbPath,
        version: 2,
        onUpgrade: (db, oldVersion, newVersion) async {
          debugPrint("🔄 Upgrade database: \$oldVersion → \$newVersion");
          if (oldVersion < 2) {
            await _migraAVersione2(db);
          }
        },
      );

      // Verifica e sincronizza FTS
      await _verificaESincronizzaFTS(vecchioDb);
      await vecchioDb.close();
    }

    await dbGlobale.close();

    debugPrint("🎉 INIZIALIZZAZIONE COMPLETATA CON SUCCESSO");

  } catch (e) {
    debugPrint("❌ ERRORE CRITICO durante inizializzazione: \$e");
    rethrow;
  } finally {
    _isInitializing = false;
    _initializationCompleter?.complete();
    _initializationCompleter = null;
  }
}

/// Migrazione alla versione 2: rimozione id_univoco_globale, IdBra come PK
Future<void> _migraAVersione2(Database db) async {
  debugPrint("🔄 Migrazione alla versione 2: IdBra come PRIMARY KEY...");

  try {
    // 1. Verifica se la tabella spartiti esiste già
    final tableExists = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='spartiti'"
    );

    if (tableExists.isEmpty) {
      debugPrint("   Tabella spartiti non esiste, creo nuova struttura");
      await _creaTabellaSpartiti(db);
      return;
    }

    // 2. Controlla se la tabella ha già la nuova struttura
    final tableInfo = await db.rawQuery("PRAGMA table_info(spartiti)");
    bool hasIdUnivocoGlobale = false;
    bool hasIdBra = false;
    bool idBraIsIntegerPK = false;

    for (final column in tableInfo) {
      final name = column['name'] as String;
      final type = column['type'] as String;
      final pk = column['pk'] as int? ?? 0;

      if (name == ''
          '') {
        hasIdUnivocoGlobale = true;
      }
      if (name == 'IdBra') {
        hasIdBra = true;
        if (type.toUpperCase().contains('INT') && pk == 1) {
          idBraIsIntegerPK = true;
        }
      }
    }

    if (idBraIsIntegerPK) {
      debugPrint("   ✅ Struttura già aggiornata (IdBra INTEGER PRIMARY KEY)");
      return;
    }

    // 3. Backup dati esistenti
    debugPrint("   📋 Backup dati esistenti...");
    await db.execute('CREATE TABLE spartiti_backup AS SELECT * FROM spartiti');

    // 4. Elimina FTS e trigger vecchi
    debugPrint("   🗑️  Eliminazione sistema FTS vecchio...");
    await _eliminaFTSCompleto(db);

    // 5. Elimina tabella vecchia
    debugPrint("   🗑️  Eliminazione tabella spartiti vecchia...");
    await db.execute('DROP TABLE IF EXISTS spartiti');

    // 6. Crea nuova tabella con IdBra come PK
    debugPrint("   🏗️  Creazione nuova struttura...");
    await _creaTabellaSpartiti(db);

    // 7. Ripristina dati
    debugPrint("   📤 Ripristino dati...");

    // Conta record da ripristinare
    final countBackup = await db.rawQuery("SELECT COUNT(*) as c FROM spartiti_backup");
    final totalRecords = countBackup.first['c'] as int? ?? 0;

    if (totalRecords > 0) {
      debugPrint("   🔄 Ripristino \$totalRecords record...");

      // Inserisci in blocchi
      final chunkSize = 100;
      final totalChunks = (totalRecords / chunkSize).ceil();

      for (var chunk = 0; chunk < totalChunks; chunk++) {
        final offset = chunk * chunkSize;
        final rows = await db.rawQuery(
            "SELECT * FROM spartiti_backup LIMIT \$chunkSize OFFSET \$offset"
        );

        if (rows.isEmpty) break;

        await db.transaction((txn) async {
          final batch = txn.batch();
          for (final row in rows) {
            final rowCopy = Map<String, dynamic>.from(row);

            // Converti IdBra se necessario
            if (rowCopy.containsKey('IdBra')) {
              final idBraValue = rowCopy['IdBra'];
              if (idBraValue is String && idBraValue.isNotEmpty) {
                final parsed = int.tryParse(idBraValue);
                if (parsed != null) {
                  rowCopy['IdBra'] = parsed;
                } else {
                  // Se non è numerico, genera nuovo ID
                  rowCopy.remove('IdBra');
                }
              }
            }

            // Rimuovi id_univoco_globale
            rowCopy.remove('id_univoco_globale');

            batch.insert('spartiti', rowCopy,
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
          await batch.commit(noResult: true);
        });

        final progress = ((chunk + 1) / totalChunks * 100).toStringAsFixed(1);
        debugPrint("   Progresso migrazione: \$progress%");
        await Future.delayed(Duration.zero);
      }
    }

    // 8. Crea nuovo sistema FTS
    debugPrint("   🔍 Creazione nuovo sistema FTS...");
    await _creaIndiciFTS(db);

    // Popola FTS
    final countSpartiti = await db.rawQuery("SELECT COUNT(*) as c FROM spartiti");
    final totalSpartiti = countSpartiti.first['c'] as int? ?? 0;

    if (totalSpartiti > 0) {
      debugPrint("   🔄 Popolamento FTS per \$totalSpartiti record...");
      await db.execute('''
        INSERT INTO spartiti_fts(IdBra, titolo, autore, volume, ArchivioProvenienza)
        SELECT 
          IdBra,
          COALESCE(titolo, ''),
          COALESCE(autore, ''),
          COALESCE(volume, ''),
          COALESCE(ArchivioProvenienza, '')
        FROM spartiti
      ''');
    }

    // 9. Elimina backup
    debugPrint("   🧹 Pulizia backup...");
    await db.execute('DROP TABLE IF EXISTS spartiti_backup');

    debugPrint("   ✅ Migrazione versione 2 completata con successo");

  } catch (e) {
    debugPrint("❌ Errore durante migrazione a versione 2: \$e");
    rethrow;
  }
}