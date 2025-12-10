// lib/database/inizializza_i_db_della_app.dart - VERSIONE COMPLETA CORRETTA
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';// lib/database/inizializza_i_db_della_app.dart - VERSIONE CON SEQUENZA OTTIMALE
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
/// 1. FUNZIONI PER GESTIONE PERCORSI PDF
/// ===================================================================

/// Ottiene il percorso PDF predefinito per la piattaforma corrente
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

/// Corregge il percorso PDF in base alla piattaforma corrente
Future<String> _getPlatformCorrectedPdfPath(String percorsoOriginale) async {
  if (percorsoOriginale.isEmpty) {
    return await _getDefaultSystemWidePath();
  }

  final bool isWindowsPath = percorsoOriginale.contains(r'\') ||
      percorsoOriginale.startsWith(RegExp(r'[A-Z]:\\'));

  if (Platform.isAndroid || Platform.isIOS) {
    // Su Android/iOS: se il percorso è in formato Windows, usa il predefinito
    if (isWindowsPath) {
      return await _getDefaultSystemWidePath();
    }
    // Altrimenti verifica se esiste
    try {
      final dir = Directory(percorsoOriginale);
      if (await dir.exists()) return percorsoOriginale;
    } catch (e) {}
    return await _getDefaultSystemWidePath();
  } else if (Platform.isWindows) {
    // Su Windows: converte / in \
    if (!isWindowsPath && percorsoOriginale.contains('/')) {
      return percorsoOriginale.replaceAll('/', r'\');
    }
    return percorsoOriginale;
  } else {
    // Su Linux/macOS: converte \ in /
    if (isWindowsPath) {
      return percorsoOriginale.replaceAll(r'\', '/');
    }
    return percorsoOriginale;
  }
}

/// ===================================================================
/// 2. CREAZIONE E POPOLAMENTO TABELLA SPARTITI
/// ===================================================================

/// Crea la tabella spartiti con struttura corretta
Future<void> _creaTabellaSpartiti(Database db) async {
  debugPrint("🏗️  Creazione tabella spartiti...");

  await db.execute('''
    CREATE TABLE IF NOT EXISTS spartiti (
      id_univoco_globale INTEGER PRIMARY KEY AUTOINCREMENT,
      IdBra TEXT UNIQUE NOT NULL,
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

  debugPrint("✅ Tabella spartiti creata");
}

/// Crea FTS semplice sui 4 campi - VERSIONE CON SEQUENZA OTTIMALE
Future<void> _creaIndiciFTS(Database db) async {
  debugPrint("🔍 Configurazione sistema FTS (sequenza ottimale)...");

  try {
    // Verifica se FTS esiste già
    final ftsEsiste = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='spartiti_fts'"
    );

    if (ftsEsiste.isNotEmpty) {
      debugPrint("⚠️ Tabella FTS già presente, la elimino e ricreo...");
      await _eliminaFTSCompleto(db);
    }

    // ============ SEQUENZA OTTIMALE ============
    // 1. PRIMA crea i TRIGGER (su tabella spartiti vuota)
    debugPrint("  1. Creazione trigger FTS...");

    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS spartiti_ai_fts AFTER INSERT ON spartiti BEGIN
        INSERT INTO spartiti_fts(rowid, titolo, autore, volume, ArchivioProvenienza)
        VALUES (NEW.id_univoco_globale, NEW.titolo, NEW.autore, NEW.volume, NEW.ArchivioProvenienza);
      END;
    ''');

    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS spartiti_au_fts AFTER UPDATE ON spartiti BEGIN
        UPDATE spartiti_fts 
        SET titolo = NEW.titolo, 
            autore = NEW.autore, 
            volume = NEW.volume, 
            ArchivioProvenienza = NEW.ArchivioProvenienza
        WHERE rowid = OLD.id_univoco_globale;
      END;
    ''');

    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS spartiti_ad_fts AFTER DELETE ON spartiti BEGIN
        DELETE FROM spartiti_fts WHERE rowid = OLD.id_univoco_globale;
      END;
    ''');

    debugPrint("     ✅ Trigger FTS creati");

    // 2. POI crea la tabella FTS (vuota)
    debugPrint("  2. Creazione tabella FTS vuota...");

    // Prova prima con content (per popolamento automatico)
    try {
      await db.execute('''
        CREATE VIRTUAL TABLE spartiti_fts USING fts5(
          titolo,
          autore,
          volume,
          ArchivioProvenienza,
          content='spartiti',
          content_rowid='id_univoco_globale'
        )
      ''');
      debugPrint("     ✅ Tabella FTS creata con content (popolamento automatico)");
    } catch (e) {
      // Fallback: crea senza content (popolamento manuale)
      debugPrint("     ⚠️ FTS con content fallito, creo senza: $e");
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

    debugPrint("🎯 Sistema FTS configurato: i trigger popoleranno automaticamente l'indice");

  } catch (e) {
    debugPrint("❌ Errore configurazione FTS: $e");
    throw Exception("Impossibile configurare FTS: $e");
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
    debugPrint("⚠️ Errore eliminazione FTS: $e");
  }
}

/// Verifica e sincronizza FTS se necessario
Future<void> _verificaESincronizzaFTS(Database db) async {
  try {
    debugPrint("🔍 Verifica sincronizzazione FTS...");

    // 1. Verifica trigger FTS
    final triggerFTS = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='trigger' AND name LIKE '%fts%'"
    );

    if (triggerFTS.isEmpty) {
      debugPrint("❌ Trigger FTS mancanti! Ricostruisco sistema completo...");
      await _eliminaFTSCompleto(db);
      await _creaIndiciFTS(db);

      // Riconta per popolare manualmente
      final countSpartiti = await db.rawQuery("SELECT COUNT(*) as c FROM spartiti");
      final totalSpartiti = countSpartiti.first['c'] as int? ?? 0;

      if (totalSpartiti > 0) {
        debugPrint("🔄 Popolamento manuale FTS per $totalSpartiti record...");
        await db.execute('''
          INSERT INTO spartiti_fts(rowid, titolo, autore, volume, ArchivioProvenienza)
          SELECT 
            id_univoco_globale,
            COALESCE(titolo, ''),
            COALESCE(autore, ''),
            COALESCE(volume, ''),
            COALESCE(ArchivioProvenienza, '')
          FROM spartiti
        ''');
      }

      return;
    }

    debugPrint("✅ Trigger FTS trovati: ${triggerFTS.length}");

    // 2. Conta record in spartiti
    final countSpartiti = await db.rawQuery("SELECT COUNT(*) as c FROM spartiti");
    final totalSpartiti = countSpartiti.first['c'] as int? ?? 0;

    // 3. Conta record in FTS
    final countFTS = await db.rawQuery("SELECT COUNT(*) as c FROM spartiti_fts");
    final totalFTS = countFTS.first['c'] as int? ?? 0;

    debugPrint("   Record spartiti: $totalSpartiti");
    debugPrint("   Record FTS: $totalFTS");

    if (totalSpartiti == 0) {
      debugPrint("   ⚠️ Tabella spartiti vuota, FTS non necessario");
      return;
    }

    if (totalFTS == 0) {
      debugPrint("   🔄 FTS vuoto, popolo manualmente...");
      await db.execute('''
        INSERT INTO spartiti_fts(rowid, titolo, autore, volume, ArchivioProvenienza)
        SELECT 
          id_univoco_globale,
          COALESCE(titolo, ''),
          COALESCE(autore, ''),
          COALESCE(volume, ''),
          COALESCE(ArchivioProvenienza, '')
        FROM spartiti
      ''');
      debugPrint("     ✅ FTS popolato manualmente");

    } else if (totalFTS != totalSpartiti) {
      debugPrint("   🔄 FTS non sincronizzato ($totalFTS/$totalSpartiti), risincronizzo...");
      await _eliminaFTSCompleto(db);
      await _creaIndiciFTS(db);

      await db.execute('''
        INSERT INTO spartiti_fts(rowid, titolo, autore, volume, ArchivioProvenienza)
        SELECT 
          id_univoco_globale,
          COALESCE(titolo, ''),
          COALESCE(autore, ''),
          COALESCE(volume, ''),
          COALESCE(ArchivioProvenienza, '')
        FROM spartiti
      ''');
      debugPrint("     ✅ FTS risincronizzato");

    } else {
      debugPrint("   ✅ FTS conteggio OK");

      // 4. Verifica QUALITÀ sincronizzazione (controlla differenze)
      debugPrint("   🔍 Verifica qualità sincronizzazione...");
      final differenze = await db.rawQuery('''
        SELECT COUNT(*) as c FROM spartiti s
        WHERE NOT EXISTS (
          SELECT 1 FROM spartiti_fts f 
          WHERE f.rowid = s.id_univoco_globale
        )
      ''');

      final diffCount = differenze.first['c'] as int? ?? 0;
      if (diffCount > 0) {
        debugPrint("   ⚠️ $diffCount record non sincronizzati! Ricostruisco...");
        await _eliminaFTSCompleto(db);
        await _creaIndiciFTS(db);

        await db.execute('''
          INSERT INTO spartiti_fts(rowid, titolo, autore, volume, ArchivioProvenienza)
          SELECT 
            id_univoco_globale,
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
    debugPrint("❌ Errore verifica FTS: $e");
    // Se c'è errore, ricostruisci completamente
    try {
      await _eliminaFTSCompleto(db);
      await _creaIndiciFTS(db);

      final countSpartiti = await db.rawQuery("SELECT COUNT(*) as c FROM spartiti");
      final totalSpartiti = countSpartiti.first['c'] as int? ?? 0;

      if (totalSpartiti > 0) {
        await db.execute('''
          INSERT INTO spartiti_fts(rowid, titolo, autore, volume, ArchivioProvenienza)
          SELECT 
            id_univoco_globale,
            COALESCE(titolo, ''),
            COALESCE(autore, ''),
            COALESCE(volume, ''),
            COALESCE(ArchivioProvenienza, '')
          FROM spartiti
        ''');
      }

      debugPrint("✅ FTS ricostruito dopo errore");
    } catch (e2) {
      debugPrint("❌ Errore critico ricostruzione FTS: $e2");
    }
  }
}

/// Test rapido per verificare che FTS funzioni
Future<void> _testFTSRapido(Database db) async {
  try {
    debugPrint("🧪 Test rapido FTS...");

    // Prova con parole comuni nella musica
    final paroleTest = ['jazz', 'blues', 'piano', 'guitar', 'song'];

    for (final parola in paroleTest) {
      try {
        final risultati = await db.rawQuery(
            "SELECT COUNT(*) as c FROM spartiti_fts WHERE spartiti_fts MATCH ?",
            [parola]
        );
        final count = risultati.first['c'] as int? ?? 0;
        if (count > 0) {
          debugPrint("   ✅ FTS funziona: '$parola' → $count risultati");
          return;
        }
      } catch (e) {
        // Ignora errori di singole parole
      }
    }

    debugPrint("   ⚠️ Nessun test positivo, verifica manualmente");

  } catch (e) {
    debugPrint("   ❌ Test FTS fallito: $e");
  }
}

/// Importa dati dal database asset nella tabella spartiti
Future<int> _importaDatiDaAsset(Database db) async {
  debugPrint("📥 Importazione dati da database asset...");

  try {
    // 1. Carica il DB master dagli assets
    final ByteData data = await rootBundle.load('assets/databases/$_vecchioDbName');
    final tempAssetDbPath = p.join((await getTemporaryDirectory()).path, "vecchio_master_temp.db");
    await File(tempAssetDbPath).writeAsBytes(data.buffer.asUint8List(), flush: true);

    Database? masterDb;
    int recordImportati = 0;

    try {
      // 2. Apri DB master
      masterDb = await openReadOnlyDatabase(tempAssetDbPath);

      // 3. Determina tabella sorgente in base al SO
      final sourceTable = Platform.isWindows ? 'spartiti' : 'spartiti_andr';
      debugPrint("   Tabella sorgente: '$sourceTable'");

      // 4. Leggi i dati dalla tabella corretta
      List<Map<String, dynamic>> dataToInsert;
      try {
        dataToInsert = await masterDb.query(sourceTable);
      } catch (e) {
        debugPrint("   ⚠️ Tabella '$sourceTable' non trovata, prova fallback...");
        // Fallback all'altra tabella
        final fallbackTable = Platform.isWindows ? 'spartiti_andr' : 'spartiti';
        dataToInsert = await masterDb.query(fallbackTable);
      }

      debugPrint("   Letti ${dataToInsert.length} record da asset");

      if (dataToInsert.isEmpty) {
        debugPrint("   ⚠️ Nessun dato trovato nella tabella");
        return 0;
      }

      // 5. Inserisci dati in blocchi (i trigger popoleranno automaticamente FTS)
      final chunkSize = 100;
      for (var i = 0; i < dataToInsert.length; i += chunkSize) {
        final end = (i + chunkSize < dataToInsert.length) ? i + chunkSize : dataToInsert.length;
        final chunk = dataToInsert.sublist(i, end);

        await db.transaction((txn) async {
          final batch = txn.batch();
          for (final row in chunk) {
            // Assicurati che id_univoco_globale sia presente
            final rowCopy = Map<String, dynamic>.from(row);
            if (!rowCopy.containsKey('id_univoco_globale')) {
              rowCopy['id_univoco_globale'] = null; // AUTOINCREMENT gestirà
            }

            batch.insert('spartiti', rowCopy,
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
          await batch.commit(noResult: true);
        });

        recordImportati += chunk.length;

        // Progresso
        if (i % 500 == 0) {
          final progress = ((i / dataToInsert.length) * 100).toStringAsFixed(1);
          debugPrint("   Progresso: $progress% ($recordImportati record)");
          await Future.delayed(Duration.zero);
        }
      }

      debugPrint("✅ Importati $recordImportati record da asset");
      debugPrint("   ℹ️  I trigger hanno popolato automaticamente l'FTS");

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
    debugPrint("❌ Errore importazione dati: $e");
    return 0;
  }
}

/// ===================================================================
/// 3. GESTIONE DB GLOBALE
/// ===================================================================

/// Crea struttura DBGlobale vuota
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

  debugPrint("✅ Struttura DBGlobale creata (v$version)");
}

/// Inizializza DBGlobale con valori predefiniti
Future<void> _inizializzaDbGlobale(Database db) async {
  debugPrint("📝 Inizializzazione DBGlobale...");

  // Verifica se DatiSistremaApp ha record
  final datiEsistenti = await db.query('DatiSistremaApp', limit: 1);

  if (datiEsistenti.isEmpty) {
    // Inserisci dati predefiniti
    final percorsoPdf = await _getDefaultSystemWidePath();

    await db.insert('DatiSistremaApp', {
      'SistemaOperativo': Platform.operatingSystem,
      'PercorsoPdf': percorsoPdf,
      'Percorsodatabase': gDatabasePath,
      'id_catalogo_attivo': 1, // Sempre 1
    });

    await db.insert('elenco_cataloghi', {
      'nome': 'Catalogo Principale',
      'nome_file_db': _vecchioDbName,
      'descrizione': 'Catalogo predefinito'
    });

    debugPrint("✅ DBGlobale inizializzato con valori predefiniti");
    debugPrint("   Percorso PDF: $percorsoPdf");
    debugPrint("   id_catalogo_attivo: 1");
  } else {
    // Aggiorna percorso PDF se necessario
    final percorsoDalDB = datiEsistenti.first['PercorsoPdf'] as String? ?? '';
    final percorsoCorretto = await _getPlatformCorrectedPdfPath(percorsoDalDB);

    if (percorsoCorretto != percorsoDalDB) {
      await db.update('DatiSistremaApp', {
        'PercorsoPdf': percorsoCorretto,
        'SistemaOperativo': Platform.operatingSystem
      });
      debugPrint("🔄 Percorso PDF corretto: $percorsoDalDB → $percorsoCorretto");
    }

    // Assicura che id_catalogo_attivo sia 1
    final idCatalogo = datiEsistenti.first['id_catalogo_attivo'] as int? ?? 1;
    if (idCatalogo != 1) {
      await db.update('DatiSistremaApp', {'id_catalogo_attivo': 1});
      debugPrint("🔄 id_catalogo_attivo corretto a 1");
    }
  }
}

/// ===================================================================
/// 4. FUNZIONE PRINCIPALE DI INIZIALIZZAZIONE - SEQUENZA OTTIMALE
/// ===================================================================
Future<void> inizializzaIDbDellaApp() async {
  if (_isInitializing) {
    debugPrint("⚠️ Inizializzazione già in corso, attendo...");
    await _initializationCompleter?.future;
    return;
  }

  _isInitializing = true;
  _initializationCompleter = Completer<void>();

  try {
    debugPrint("\n" + "="*60);
    debugPrint("🚀 INIZIALIZZAZIONE JAMSETGEMINI - SEQUENZA OTTIMALE");
    debugPrint("Piattaforma: ${Platform.operatingSystem}");
    debugPrint("Data: ${DateTime.now()}");
    debugPrint("="*60);

    // 1. Ottieni directory support
    final supportDir = await getApplicationSupportDirectory();
    gDatabasePath = supportDir.path;
    debugPrint("📁 Directory support: $gDatabasePath");

    // 2. GESTIONE VECCHIODB.DB - CON SEQUENZA OTTIMALE
    debugPrint("\n🎵 Database principale: $_vecchioDbName");
    final vecchioDbPath = p.join(gDatabasePath, _vecchioDbName);

    if (!await databaseExists(vecchioDbPath)) {
      // ============ NUOVO DATABASE: SEQUENZA OTTIMALE ============
      debugPrint("📋 Crea nuovo database (sequenza ottimale)...");
      dbVecchio = await openDatabase(
          vecchioDbPath,
          version: 1,
          onCreate: (Database db, int version) async {
            // 1. PRIMA: Crea tabella spartiti (struttura)
            await _creaTabellaSpartiti(db);
          }
      );

      // ============ SEQUENZA OTTIMALE COMPLETA ============
      debugPrint("\n🔧 APPLICAZIONE SEQUENZA OTTIMALE:");
      debugPrint("  1. ✅ Tabella spartiti creata");

      // 2. POI: Crea trigger + FTS (PRIMA di importare dati)
      debugPrint("  2. 🔧 Configurazione sistema FTS...");
      await _creaIndiciFTS(dbVecchio!);
      debugPrint("     ✅ Trigger FTS creati");
      debugPrint("     ✅ Tabella FTS vuota creata");

      // 3. INFINE: Importa dati → trigger popolano automaticamente FTS!
      debugPrint("  3. 📥 Importazione dati (trigger attivi)...");
      final recordImportati = await _importaDatiDaAsset(dbVecchio!);

      if (recordImportati > 0) {
        debugPrint("     ✅ $recordImportati record importati");

        // Verifica che i trigger abbiano funzionato
        final countFTS = await dbVecchio!.rawQuery("SELECT COUNT(*) as c FROM spartiti_fts");
        final totalFTS = countFTS.first['c'] as int? ?? 0;

        if (totalFTS == recordImportati) {
          debugPrint("     🎯 FTS popolato automaticamente dai trigger: $totalFTS record");
        } else {
          debugPrint("     ⚠️ Trigger parziali: FTS ha $totalFTS/$recordImportati record");
          // Fallback: popola manualmente se i trigger non hanno funzionato
          if (totalFTS == 0) {
            debugPrint("     🔄 Popolamento manuale FTS...");
            await dbVecchio!.execute('''
              INSERT INTO spartiti_fts(rowid, titolo, autore, volume, ArchivioProvenienza)
              SELECT 
                id_univoco_globale,
                COALESCE(titolo, ''),
                COALESCE(autore, ''),
                COALESCE(volume, ''),
                COALESCE(ArchivioProvenienza, '')
              FROM spartiti
            ''');
            debugPrint("     ✅ FTS popolato manualmente");
          }
        }
      } else {
        debugPrint("     ⚠️ Nessun dato importato");
      }

    } else {
      // ============ DATABASE ESISTENTE ============
      debugPrint("📁 Database esistente trovato...");
      dbVecchio = await openDatabase(vecchioDbPath);


      // Verifica se tabella spartiti esiste
      final tabelle = await dbVecchio!.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='spartiti'"
      );

      if (tabelle.isEmpty) {
        debugPrint("⚠️ Tabella spartiti non trovata, applico sequenza ottimale...");
        // Database esiste ma non ha tabella spartiti? Strano, ma ricreiamo
        await _creaTabellaSpartiti(dbVecchio!);
        await _creaIndiciFTS(dbVecchio!);
        final recordImportati = await _importaDatiDaAsset(dbVecchio!);
        debugPrint("✅ Database riparato: $recordImportati record importati");
      } else {
        // Database esiste e ha struttura: verifica e sincronizza FTS
        debugPrint("✅ Tabella spartiti presente");
        await _verificaESincronizzaFTS(dbVecchio!);
      }
    }

    debugPrint("✅ Database principale pronto e sincronizzato");

    // 3. GESTIONE DB GLOBALE
    debugPrint("\n🌍 Database globale: $_dbGlobaleName");
    final dbGlobalePath = p.join(gDatabasePath, _dbGlobaleName);

    if (!await databaseExists(dbGlobalePath)) {
      // Copia da asset se esiste
      try {
        debugPrint("📋 Copia DBGlobale da asset...");
        final ByteData data = await rootBundle.load('assets/databases/$_dbGlobaleName');
        await File(dbGlobalePath).writeAsBytes(data.buffer.asUint8List(), flush: true);
        debugPrint("✅ DBGlobale copiato da asset");
      } catch (e) {
        // Crea vuoto se non esiste in asset
        debugPrint("⚠️ DBGlobale non in asset, creo vuoto...");
        dbGlobale = await openDatabase(
            dbGlobalePath,
            version: 1,
            onCreate: _creaDbGlobaleVuoto
        );
      }
    }

    if (dbGlobale == null) {
      dbGlobale = await openDatabase(dbGlobalePath);
    }

    // Inizializza DBGlobale
    await _inizializzaDbGlobale(dbGlobale!);

    // Leggi configurazione
    final datiSistema = await dbGlobale!.query('DatiSistremaApp', limit: 1);
    if (datiSistema.isNotEmpty) {
      gPercorsoPdf = datiSistema.first['PercorsoPdf'] as String? ?? '';
      final idCatalogoAttivo = datiSistema.first['id_catalogo_attivo'] as int? ?? 1;

      // Leggi catalogo attivo
      final catalogoInfo = await dbGlobale!.query(
          'elenco_cataloghi',
          where: 'id = ?',
          whereArgs: [idCatalogoAttivo],
          limit: 1
      );

      if (catalogoInfo.isNotEmpty) {
        gActiveCatalogDbName = catalogoInfo.first['nome_file_db'] as String;
      } else {
        gActiveCatalogDbName = _vecchioDbName;
        debugPrint("⚠️ Catalogo non trovato, uso database principale");
      }
    }

    debugPrint("🎯 Percorso PDF: $gPercorsoPdf");
    debugPrint("🎯 Catalogo attivo: $gActiveCatalogDbName");

    // 4. CATALOGO ATTIVO
    final catalogoPath = p.join(gDatabasePath, gActiveCatalogDbName);

    if (gActiveCatalogDbName != _vecchioDbName && !await databaseExists(catalogoPath)) {
      debugPrint("📂 Catalogo attivo non trovato, uso database principale");
      gActiveCatalogDbName = _vecchioDbName;
    }

    if (gActiveCatalogDbName == _vecchioDbName) {
      dbCatalogoAttivo = dbVecchio;
    } else {
      dbCatalogoAttivo = await openDatabase(catalogoPath);
    }

    // 5. CREA DIRECTORY PDF SE NON ESISTE
    try {
      final pdfDir = Directory(gPercorsoPdf);
      if (!await pdfDir.exists()) {
        await pdfDir.create(recursive: true);
        debugPrint("📁 Directory PDF creata: $gPercorsoPdf");
      } else {
        debugPrint("📁 Directory PDF già esistente: $gPercorsoPdf");
      }
    } catch (e) {
      debugPrint("⚠️ Impossibile creare directory PDF: $e");
    }

    debugPrint("\n" + "="*60);
    debugPrint("✅ INIZIALIZZAZIONE COMPLETATA CON SUCCESSO");
    debugPrint("   Piattaforma: ${Platform.operatingSystem}");
    debugPrint("   Percorso PDF: $gPercorsoPdf");
    debugPrint("   Catalogo: $gActiveCatalogDbName");
    debugPrint("   FTS: Configurato con sequenza ottimale");
    debugPrint("="*60);

    _initializationCompleter?.complete();

  } catch (e, s) {
    debugPrint("\n❌ ERRORE INIZIALIZZAZIONE:");
    debugPrint("$e");
    debugPrint("$s");
    _initializationCompleter?.completeError(e);
    rethrow;
  } finally {
    _isInitializing = false;
  }
}

/// ===================================================================
/// 5. FUNZIONI DI RICERCA (CORRETTE per struttura reale)
/// ===================================================================

/// Ricerca FTS corretta
Future<List<Map<String, dynamic>>> cercaSpartitiFTS(String query, {String? strumento}) async {
  if (dbVecchio == null) return [];

  try {
    String ftsQuery = query.trim();
    if (ftsQuery.isEmpty) {
      return await cercaSpartitiSemplice('', strumento: strumento);
    }

    // QUERY CORRETTA
    var sql = '''
      SELECT DISTINCT 
        NumPag, 
        titolo, 
        volume, 
        ArchivioProvenienza,
        strumento,
        autore,
        PrimoLInk,
        PercResto,
        TipoMulti,
        id_univoco_globale
      FROM spartiti
      WHERE id_univoco_globale IN (
        SELECT rowid FROM spartiti_fts 
        WHERE spartiti_fts MATCH ?
      )
    ''';

    var params = [ftsQuery];

    if (strumento != null && strumento.isNotEmpty) {
      sql += ' AND strumento = ?';
      params.add(strumento);
    }

    sql += ' ORDER BY titolo COLLATE NOCASE ASC LIMIT 100';

    final risultati = await dbVecchio!.rawQuery(sql, params);
    debugPrint("🔍 Ricerca FTS: '$query' → ${risultati.length} risultati");
    return risultati;

  } catch (e) {
    debugPrint("❌ Errore ricerca FTS: $e");
    return await cercaSpartitiSemplice(query, strumento: strumento);
  }
}

/// Ricerca alternativa (fallback)
Future<List<Map<String, dynamic>>> cercaSpartitiSemplice(String query, {String? strumento}) async {
  if (dbVecchio == null) return [];

  try {
    var sql = '''
      SELECT DISTINCT 
        NumPag,
        titolo,
        volume,
        ArchivioProvenienza,
        strumento,
        autore,
        PrimoLInk,
        PercResto,
        TipoMulti,
        id_univoco_globale
      FROM spartiti
      WHERE (titolo LIKE ? OR autore LIKE ? OR volume LIKE ?)
    ''';

    var params = ['%$query%', '%$query%', '%$query%'];

    if (strumento != null && strumento.isNotEmpty) {
      sql += ' AND strumento = ?';
      params.add(strumento);
    }

    sql += ' ORDER BY titolo COLLATE NOCASE ASC LIMIT 100';

    final risultati = await dbVecchio!.rawQuery(sql, params);
    debugPrint("🔍 Ricerca semplice: '$query' → ${risultati.length} risultati");
    return risultati;

  } catch (e) {
    debugPrint("❌ Errore ricerca semplice: $e");
    return [];
  }
}

/// Funzione per rigenerare FTS manualmente
Future<bool> rigeneraFTSManualmente() async {
  if (dbVecchio == null) return false;

  try {
    debugPrint("🔄 Rigenerazione manuale FTS (sequenza ottimale)...");
    await _creaIndiciFTS(dbVecchio!);

    // Popola manualmente dopo ricreazione
    await dbVecchio!.execute('''
      INSERT INTO spartiti_fts(rowid, titolo, autore, volume, ArchivioProvenienza)
      SELECT 
        id_univoco_globale,
        COALESCE(titolo, ''),
        COALESCE(autore, ''),
        COALESCE(volume, ''),
        COALESCE(ArchivioProvenienza, '')
      FROM spartiti
    ''');

    debugPrint("✅ FTS rigenerato con successo");
    return true;
  } catch (e) {
    debugPrint("❌ Errore rigenerazione FTS: $e");
    return false;
  }
}

/// Diagnostica database
Future<Map<String, dynamic>> diagnosticaDatabase() async {
  final risultato = <String, dynamic>{
    'piattaforma': Platform.operatingSystem,
    'percorso_pdf': gPercorsoPdf,
    'database_path': gDatabasePath,
    'catalogo_attivo': gActiveCatalogDbName,
  };

  if (dbVecchio != null) {
    try {
      // Conta record spartiti
      final countSpartiti = await dbVecchio!.rawQuery("SELECT COUNT(*) as c FROM spartiti");
      risultato['record_spartiti'] = countSpartiti.first['c'];

      // Conta record FTS
      final countFTS = await dbVecchio!.rawQuery("SELECT COUNT(*) as c FROM spartiti_fts");
      risultato['record_fts'] = countFTS.first['c'];

      // Test FTS
      final testFTS = await dbVecchio!.rawQuery(
          "SELECT COUNT(*) as c FROM spartiti_fts WHERE spartiti_fts MATCH 'jazz'"
      );
      risultato['test_fts_jazz'] = testFTS.first['c'];

      // Verifica trigger
      final trigger = await dbVecchio!.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='trigger' AND name LIKE '%fts%'"
      );
      risultato['trigger_fts'] = trigger.length;

    } catch (e) {
      risultato['errore_diagnostica'] = e.toString();
    }
  }

  return risultato;
}

