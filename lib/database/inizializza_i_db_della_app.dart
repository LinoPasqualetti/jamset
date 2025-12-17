// lib/database/inizializza_i_db_della_app.dart - VERSIONE CON SEQUENZA OTTIMALE
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
  debugPrint('PERCORSO SYSTEM-WIDE per \${Platform.operatingSystem}');

  final defaultPaths = {
    'android': '/storage/emulated/0/JamsetPDF/',
    'windows': r'C:\\JamsetPDF\\',
    'linux': '/var/lib/jamsetgemini/pdf/',
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

/// Corregge il percorso PDF in base alla piattaforma corrente
Future<String> _getPlatformCorrectedPdfPath(String percorsoOriginale) async {
  if (percorsoOriginale.isEmpty) {
    return await _getDefaultSystemWidePath();
  }

  final bool isWindowsPath = percorsoOriginale.contains(r'\\') ||
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
    // Su Windows: converte / in \\
    if (!isWindowsPath && percorsoOriginale.contains('/')) {
      return percorsoOriginale.replaceAll('/', r'\\');
    }
    return percorsoOriginale;
  } else {
    // Su Linux/macOS: converte \\ in /
    if (isWindowsPath) {
      return percorsoOriginale.replaceAll(r'\\', '/');
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

    debugPrint("🎯 Sistema FTS configurato: i trigger popoleranno automaticamente l'indice");

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
        debugPrint("🔄 Popolamento manuale FTS per \$totalSpartiti record...");
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
      debugPrint("   🔄 FTS non sincronizzato (\$totalFTS/\$totalSpartiti), risincronizzo...");
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
        debugPrint("   ⚠️ \$diffCount record non sincronizzati! Ricostruisco...");
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
    debugPrint("❌ Errore verifica FTS: \$e");
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
      debugPrint("❌ Errore critico ricostruzione FTS: \$e2");
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

/// Importa dati dal database asset nella tabella spartiti
Future<int> _importaDatiDaAsset(Database db) async {
  debugPrint("📥 Importazione dati da database asset...");

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
        // Fallback all'altra tabella
        final fallbackTable = Platform.isWindows ? 'spartiti_andr' : 'spartiti';
        dataToInsert = await masterDb.query(fallbackTable);
      }

      debugPrint("   Letti \${dataToInsert.length} record da asset");

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
          debugPrint("   Progresso: \$progress% (\$recordImportati record)");
          await Future.delayed(Duration.zero);
        }
      }

      debugPrint("✅ Importati \$recordImportati record da asset");
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
    debugPrint("❌ Errore importazione dati: \$e");
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

  debugPrint("✅ Struttura DBGlobale creata (v\$version)");
}

/// Inizializza DBGlobale con valori predefiniti
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
