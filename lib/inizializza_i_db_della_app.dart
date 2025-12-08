// lib/database/inizializza_i_db_della_app.dart - VERSIONE OTTIMIZZATA
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
/// DIAGNOSTICA PROBLEMI ANDROID SPECIFICI
/// ===================================================================
class DiagnosticaAndroid {
  static Future<Map<String, dynamic>> analizzaProblemiDatabase(
      String dbPath) async {
    debugPrint("🔍 DIAGNOSTICA DATABASE ANDROID");

    final risultati = {
      'problemi': [],
      'dettagli': {},
      'statistiche': {},
      'raccomandazione': 'nessun intervento'
    };

    try {
      final dbFile = File(dbPath);

      // 1. VERIFICA ESISTENZA FILE
      if (!await dbFile.exists()) {
        risultati['problemi'].add('db_mancante');
        risultati['raccomandazione'] = 'crea_nuovo_db';
        debugPrint("   ❌ Database non trovato");
        return risultati;
      }

      // 2. VERIFICA PERMESSI E ACCESSIBILITÀ
      try {
        final stat = await dbFile.stat();
        risultati['dettagli']['dimensione'] = stat.size;
        risultati['dettagli']['modificato'] = stat.modified.toString();
        risultati['dettagli']['accesso'] = stat.accessed.toString();

        debugPrint("   📊 Dimensione DB: ${stat.size} bytes");

        // File vuoto o corrotto?
        if (stat.size < 1024) { // < 1KB
          risultati['problemi'].add('db_vuoto_o_corrotto');
          debugPrint("   ⚠ Database troppo piccolo (< 1KB)");
        }
      } catch (e) {
        risultati['problemi'].add('permessi_lettura');
        debugPrint("   ❌ Problemi permessi lettura: $e");
      }

      // 3. APERTURA E ANALISI STRUTTURA
      Database? testDb;
      try {
        testDb = await openDatabase(dbPath, readOnly: true);

        // 3.1 Verifica tabelle
        final tabelle = await testDb.rawQuery(
            "SELECT name, sql FROM sqlite_master WHERE type='table'"
        );

        risultati['statistiche']['tabelle_totali'] = tabelle.length;
        risultati['dettagli']['tabelle'] = tabelle.map((t) => t['name']).toList();

        debugPrint("   📋 Tabelle trovate: ${tabelle.length}");

        // Cerca tabelle specifiche
        final hasSpartiti = tabelle.any((t) => t['name'] == 'spartiti');
        final hasFTS = tabelle.any((t) => t['name'] == 'spartiti_fts');

        if (!hasSpartiti) {
          risultati['problemi'].add('tabella_spartiti_mancante');
          debugPrint("   ❌ Tabella 'spartiti' mancante");
        }

        if (!hasFTS) {
          risultati['problemi'].add('tabella_fts_mancante');
          debugPrint("   ❌ Tabella FTS mancante");
        }

        // 3.2 Analisi tabella spartiti
        if (hasSpartiti) {
          try {
            final countSpartiti = await testDb.rawQuery(
                "SELECT COUNT(*) as c FROM spartiti"
            );
            final recordCount = countSpartiti.first['c'] as int? ?? 0;
            risultati['statistiche']['record_spartiti'] = recordCount;

            debugPrint("   📊 Record in spartiti: $recordCount");

            if (recordCount == 0) {
              risultati['problemi'].add('db_vuoto');
              debugPrint("   ⚠ Database vuoto (0 record)");
            }

            // Analisi colonne
            try {
              final colonne = await testDb.rawQuery(
                  "PRAGMA table_info(spartiti)"
              );
              risultati['statistiche']['colonne_spartiti'] = colonne.length;
              final colonneNames = colonne.map((c) => c['name']).toList();

              // Verifica colonne critiche
              final colonneCritiche = ['titolo', 'autore', 'strumento', 'volume'];
              for (final col in colonneCritiche) {
                if (!colonneNames.contains(col)) {
                  risultati['problemi'].add('colonna_${col}_mancante');
                  debugPrint("   ⚠ Colonna '$col' mancante");
                }
              }
            } catch (e) {
              debugPrint("   ⚠ Errore analisi colonne: $e");
            }
          } catch (e) {
            risultati['problemi'].add('struttura_spartiti_corretta');
            debugPrint("   ❌ Struttura tabella spartiti corrotta: $e");
          }
        }

        // 3.3 Analisi FTS
        if (hasFTS) {
          try {
            final countFTS = await testDb.rawQuery(
                "SELECT COUNT(*) as c FROM spartiti_fts"
            );
            final ftsCount = countFTS.first['c'] as int? ?? 0;
            risultati['statistiche']['record_fts'] = ftsCount;

            debugPrint("   📊 Record in FTS: $ftsCount");

            // Verifica sincronizzazione
            if (hasSpartiti) {
              final spartitiCount = risultati['statistiche']['record_spartiti'] ?? 0;
              final diff = (spartitiCount - ftsCount).abs();
              final diffPercent = spartitiCount > 0
                  ? (diff / spartitiCount * 100)
                  : 100;

              risultati['statistiche']['differenza_record'] = diff;
              risultati['statistiche']['percentuale_differenza'] = diffPercent;

              if (diffPercent > 20) {
                risultati['problemi'].add('fts_desincronizzato');
                debugPrint("   ⚠ FTS desincronizzato: $diffPercent% di differenza");
              }
            }

            // Test funzionalità FTS
            try {
              await testDb.rawQuery(
                  "SELECT 1 FROM spartiti_fts WHERE spartiti_fts MATCH 'test' LIMIT 0"
              );
              debugPrint("   ✅ FTS funzionale");
            } catch (e) {
              risultati['problemi'].add('fts_non_funzionante');
              debugPrint("   ❌ FTS non funziona: $e");
            }
          } catch (e) {
            risultati['problemi'].add('fts_corrotto');
            debugPrint("   ❌ FTS corroto: $e");
          }
        }

        // 3.4 Verifica trigger FTS
        final trigger = await testDb.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='trigger' AND name LIKE '%fts%'"
        );
        risultati['statistiche']['trigger_fts'] = trigger.length;

        if (trigger.length < 3) { // Dovrebbero esserci 3 trigger minimo
          risultati['problemi'].add('trigger_fts_mancanti');
          debugPrint("   ⚠ Trigger FTS insufficienti: ${trigger.length}");
        }

        // 3.5 Verifica integrità database
        try {
          final integrity = await testDb.rawQuery("PRAGMA integrity_check");
          final result = integrity.first['integrity_check'] as String?;
          if (result != null && result.toLowerCase() != 'ok') {
            risultati['problemi'].add('integrita_compromessa');
            debugPrint("   ❌ Integrità DB compromessa: $result");
          }
        } catch (e) {
          debugPrint("   ⚠ Verifica integrità fallita: $e");
        }

      } finally {
        await testDb?.close();
      }

      // 4. DECISIONE RACCOMANDAZIONE
      if (risultati['problemi'].isEmpty) {
        risultati['raccomandazione'] = 'nessun_intervento';
        debugPrint("   ✅ Database OK, nessun intervento necessario");
      } else {
        // Priorità problemi
        if (risultati['problemi'].contains('db_vuoto_o_corrotto') ||
            risultati['problemi'].contains('struttura_spartiti_corretta') ||
            risultati['problemi'].contains('integrita_compromessa')) {
          risultati['raccomandazione'] = 'ricrea_completamente';
          debugPrint("   🔴 RACCOMANDAZIONE: Ricrea completamente");
        }
        else if (risultati['problemi'].contains('fts_non_funzionante') ||
            risultati['problemi'].contains('fts_corrotto') ||
            risultati['problemi'].contains('tabella_fts_mancante')) {
          risultati['raccomandazione'] = 'rigenera_solo_fts';
          debugPrint("   🟡 RACCOMANDAZIONE: Rigenera solo FTS");
        }
        else if (risultati['problemi'].contains('fts_desincronizzato')) {
          risultati['raccomandazione'] = 'risincronizza_fts';
          debugPrint("   🟡 RACCOMANDAZIONE: Risincronizza FTS");
        }
        else {
          risultati['raccomandazione'] = 'ripara_parziale';
          debugPrint("   🟢 RACCOMANDAZIONE: Riparazione parziale");
        }
      }

    } catch (e, s) {
      debugPrint("### ERRORE DIAGNOSTICA: $e ###");
      debugPrint("Stack: $s");
      risultati['problemi'].add('diagnostica_fallita');
      risultati['raccomandazione'] = 'ricrea_completamente';
    }

    debugPrint("   📝 Problemi identificati: ${risultati['problemi'].length}");
    for (final problema in risultati['problemi']) {
      debugPrint("     - $problema");
    }

    return risultati;
  }
}

/// ===================================================================
/// CREAZIONE INDICI FTS CON LOG DETTAGLIATO
/// ===================================================================
class FTSLogger {
  static final Map<String, dynamic> _log = {
    'timestamp': DateTime.now().toString(),
    'platform': Platform.operatingSystem,
    'actions': [],
    'statistics': {},
    'performance': {}
  };

  static void log(String action, {String? details, dynamic data}) {
    final entry = {
      'time': DateTime.now().toIso8601String(),
      'action': action,
      'details': details,
      'data': data
    };
    _log['actions'].add(entry);
    debugPrint("📝 FTS LOG: $action${details != null ? ' - $details' : ''}");
  }

  static void addStatistic(String key, dynamic value) {
    _log['statistics'][key] = value;
  }

  static void addPerformance(String key, Duration duration) {
    _log['performance'][key] = duration.inMilliseconds;
  }

  static Map<String, dynamic> getLog() => _log;

  static void resetLog() {
    _log.clear();
    _log['timestamp'] = DateTime.now().toString();
    _log['platform'] = Platform.operatingSystem;
    _log['actions'] = [];
    _log['statistics'] = {};
    _log['performance'] = {};
  }
}

Future<void> _creaIndiciFTSConLogDettagliato(Database db,
    {bool forzaturaCompleta = false}) async {

  final startTime = DateTime.now();
  FTSLogger.resetLog();
  FTSLogger.log("Inizio creazione FTS",
      details: forzaturaCompleta ? "Forzatura completa" : "Normale");

  try {
    FTSLogger.log("1. Prelievo statistiche database");

    // Statistiche iniziali
    final tablesBefore = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'"
    );
    FTSLogger.addStatistic('tabelle_iniziali', tablesBefore.length);

    // Conta record spartiti
    final countStart = await db.rawQuery("SELECT COUNT(*) as c FROM spartiti");
    final totalRecords = countStart.first['c'] as int? ?? 0;
    FTSLogger.addStatistic('record_spartiti_iniziali', totalRecords);
    FTSLogger.log("Record spartiti", details: "$totalRecords record trovati");

    // 1. Elimina eventuali FTS esistenti
    FTSLogger.log("2. Pulizia strutture FTS esistenti");

    final dropStart = DateTime.now();
    await db.execute("DROP TABLE IF EXISTS spartiti_fts");
    await db.execute("DROP TRIGGER IF EXISTS spartiti_ai_fts");
    await db.execute("DROP TRIGGER IF EXISTS spartiti_ad_fts");
    await db.execute("DROP TRIGGER IF EXISTS spartiti_au_fts");

    final dropTime = DateTime.now().difference(dropStart);
    FTSLogger.addPerformance('drop_structures_ms', dropTime);
    FTSLogger.log("Strutture eliminate",
        details: "Tempo: ${dropTime.inMilliseconds}ms");

    // 2. Crea FTS
    FTSLogger.log("3. Creazione nuova tabella FTS");

    final createStart = DateTime.now();
    if (Platform.isAndroid) {
      await db.execute('''
        CREATE VIRTUAL TABLE spartiti_fts 
        USING fts5(
          titolo,
          autore,
          strumento,
          volume,
          ArchivioProvenienza,
          tokenize='unicode61',
          content='spartiti',
          content_rowid='id_univoco_globale'
        )
      ''');
      FTSLogger.log("FTS Android creato", details: "tokenize=unicode61");
    } else {
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
      FTSLogger.log("FTS standard creato");
    }

    final createTime = DateTime.now().difference(createStart);
    FTSLogger.addPerformance('create_fts_ms', createTime);

    // 3. Crea trigger
    FTSLogger.log("4. Creazione trigger automatici");

    final triggerStart = DateTime.now();
    await db.execute('''
      CREATE TRIGGER spartiti_ai_fts AFTER INSERT ON spartiti 
      BEGIN
        INSERT INTO spartiti_fts(rowid, titolo, autore, strumento, volume, ArchivioProvenienza)
        VALUES (new.id_univoco_globale, 
                COALESCE(new.titolo, ''),
                COALESCE(new.autore, ''),
                COALESCE(new.strumento, ''),
                COALESCE(new.volume, ''),
                COALESCE(new.ArchivioProvenienza, ''));
      END
    ''');

    await db.execute('''
      CREATE TRIGGER spartiti_ad_fts AFTER DELETE ON spartiti 
      BEGIN
        INSERT INTO spartiti_fts(spartiti_fts, rowid, titolo, autore, strumento, volume, ArchivioProvenienza)
        VALUES('delete', old.id_univoco_globale, 
               COALESCE(old.titolo, ''),
               COALESCE(old.autore, ''),
               COALESCE(old.strumento, ''),
               COALESCE(old.volume, ''),
               COALESCE(old.ArchivioProvenienza, ''));
      END
    ''');

    await db.execute('''
      CREATE TRIGGER spartiti_au_fts AFTER UPDATE ON spartiti 
      BEGIN
        INSERT INTO spartiti_fts(spartiti_fts, rowid, titolo, autore, strumento, volume, ArchivioProvenienza)
        VALUES('delete', old.id_univoco_globale, 
               COALESCE(old.titolo, ''),
               COALESCE(old.autore, ''),
               COALESCE(old.strumento, ''),
               COALESCE(old.volume, ''),
               COALESCE(old.ArchivioProvenienza, ''));
        
        INSERT INTO spartiti_fts(rowid, titolo, autore, strumento, volume, ArchivioProvenienza)
        VALUES (new.id_univoco_globale, 
                COALESCE(new.titolo, ''),
                COALESCE(new.autore, ''),
                COALESCE(new.strumento, ''),
                COALESCE(new.volume, ''),
                COALESCE(new.ArchivioProvenienza, ''));
      END
    ''');

    final triggerTime = DateTime.now().difference(triggerStart);
    FTSLogger.addPerformance('create_triggers_ms', triggerTime);
    FTSLogger.log("Trigger creati",
        details: "3 trigger, tempo: ${triggerTime.inMilliseconds}ms");

    // 4. Popola FTS
    FTSLogger.log("5. Popolamento indici FTS");

    if (totalRecords > 0) {
      FTSLogger.log("Inizio popolamento", details: "$totalRecords record da indicizzare");

      final populateStart = DateTime.now();

      // Dividi in blocchi per grandi database
      if (totalRecords > 10000) {
        await _popolaFTSInBlocchi(db, totalRecords);
      } else {
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
      }

      final populateTime = DateTime.now().difference(populateStart);
      FTSLogger.addPerformance('populate_fts_ms', populateTime);
      FTSLogger.addStatistic('populazione_records_per_secondo',
          (totalRecords / (populateTime.inMilliseconds / 1000)).toStringAsFixed(1));

      FTSLogger.log("Popolamento completato",
          details: "Tempo: ${populateTime.inMilliseconds}ms");
    } else {
      FTSLogger.log("Nessun record da indicizzare");
    }

    // 5. Verifica finale
    FTSLogger.log("6. Verifica risultati");

    final verifyStart = DateTime.now();

    final countAfter = await db.rawQuery("SELECT COUNT(*) as c FROM spartiti_fts");
    final ftsRecords = countAfter.first['c'] as int? ?? 0;
    FTSLogger.addStatistic('record_fts_finali', ftsRecords);

    final tablesAfter = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'"
    );
    FTSLogger.addStatistic('tabelle_finali', tablesAfter.length);

    // Statistiche dettagliate
    final colonneFTS = await db.rawQuery("PRAGMA table_info(spartiti_fts)");
    FTSLogger.addStatistic('colonne_fts', colonneFTS.length);

    // Test funzionalità
    try {
      final testResults = await db.rawQuery(
          "SELECT COUNT(*) as c FROM spartiti_fts WHERE titolo MATCH 'test'"
      );
      FTSLogger.addStatistic('test_query_successo', true);
    } catch (e) {
      FTSLogger.addStatistic('test_query_successo', false);
    }

    final verifyTime = DateTime.now().difference(verifyStart);
    FTSLogger.addPerformance('verifica_ms', verifyTime);

    // Riepilogo
    final totalTime = DateTime.now().difference(startTime);
    FTSLogger.addStatistic('durata_totale_ms', totalTime.inMilliseconds);
    FTSLogger.addStatistic('efficienza_records_ms',
        totalRecords > 0 ? totalTime.inMilliseconds / totalRecords : 0);

    FTSLogger.log("✅ CREAZIONE FTS COMPLETATA",
        details: "Record: $totalRecords -> $ftsRecords indicizzati, Tempo totale: ${totalTime.inSeconds}s");

    // Stampa riepilogo console
    debugPrint("\n" + "="*50);
    debugPrint("📊 RIEPILOGO CREAZIONE FTS");
    debugPrint("="*50);
    debugPrint("Piattaforma: ${Platform.operatingSystem}");
    debugPrint("Tempo totale: ${totalTime.inSeconds}s");
    debugPrint("Record spartiti: $totalRecords");
    debugPrint("Record indicizzati FTS: $ftsRecords");
    debugPrint("Performance: ${(totalRecords / (totalTime.inMilliseconds / 1000)).toStringAsFixed(1)} record/secondo");

    if (totalRecords != ftsRecords) {
      debugPrint("⚠ ATTENZIONE: Discrepanza record!");
      debugPrint("   Differenza: ${(totalRecords - ftsRecords).abs()} record");
    } else {
      debugPrint("✅ Tutti i record sono stati indicizzati correttamente");
    }
    debugPrint("="*50 + "\n");

  } catch (e, s) {
    FTSLogger.log("❌ ERRORE creazione FTS", details: e.toString());
    debugPrint("### ERRORE creazione FTS: $e ###");
    debugPrint("Stack: $s");
    rethrow;
  }
}

Future<void> _popolaFTSInBlocchi(Database db, int totalRecords,
    {int chunkSize = 5000}) async {

  final chunks = (totalRecords / chunkSize).ceil();
  FTSLogger.log("Popolamento in blocchi",
      details: "$totalRecords record in $chunks blocchi da $chunkSize");

  for (int i = 0; i < chunks; i++) {
    final offset = i * chunkSize;
    final chunkStart = DateTime.now();

    await db.execute('''
      INSERT INTO spartiti_fts(rowid, titolo, autore, strumento, volume, ArchivioProvenienza)
      SELECT id_univoco_globale, 
             COALESCE(titolo, ''),
             COALESCE(autore, ''),
             COALESCE(strumento, ''),
             COALESCE(volume, ''),
             COALESCE(ArchivioProvenienza, '')
      FROM spartiti
      LIMIT $chunkSize OFFSET $offset
    ''');

    final chunkTime = DateTime.now().difference(chunkStart);
    final progress = ((offset + chunkSize) / totalRecords * 100).clamp(0, 100);

    FTSLogger.log("Blocco ${i+1}/$chunks completato",
        details: "Progresso: ${progress.toStringAsFixed(1)}%, Tempo: ${chunkTime.inMilliseconds}ms");

    // Yield per non bloccare l'UI
    if (i % 5 == 0) await Future.delayed(Duration(milliseconds: 10));
  }
}

/// ===================================================================
/// GESTIONE INTELLIGENTE PROBLEMI ANDROID
/// ===================================================================
Future<void> _gestisciDatabaseAndroidIntelligente(String dbPath) async {
  if (!Platform.isAndroid) return;

  debugPrint("\n" + "="*50);
  debugPrint("🤖 GESTIONE INTELLIGENTE DATABASE ANDROID");
  debugPrint("="*50);

  try {
    // 1. Diagnosi
    final diagnostica = await DiagnosticaAndroid.analizzaProblemiDatabase(dbPath);

    debugPrint("\n📋 RISULTATI DIAGNOSTICA:");
    debugPrint("Problemi identificati: ${diagnostica['problemi'].length}");
    debugPrint("Raccomandazione: ${diagnostica['raccomandazione']}");
    debugPrint("Statistiche: ${diagnostica['statistiche']}");

    // 2. Applica azione basata sulla diagnosi
    switch (diagnostica['raccomandazione']) {
      case 'ricrea_completamente':
        debugPrint("\n🔄 Azione: Ricrea completamente il database");
        await _ricreaDatabaseCompletamente(dbPath);
        break;

      case 'rigenera_solo_fts':
        debugPrint("\n🔄 Azione: Rigenera solo gli indici FTS");
        final db = await openDatabase(dbPath);
        await _creaIndiciFTSConLogDettagliato(db, forzaturaCompleta: true);
        await db.close();
        break;

      case 'risincronizza_fts':
        debugPrint("\n🔄 Azione: Risincronizza FTS");
        final db = await openDatabase(dbPath);
        await _risincronizzaFTS(db);
        await db.close();
        break;

      case 'ripara_parziale':
        debugPrint("\n🔧 Azione: Riparazione parziale");
        final db = await openDatabase(dbPath);
        await _riparaParziale(db, diagnostica['problemi']);
        await db.close();
        break;

      default:
        debugPrint("\n✅ Nessuna azione necessaria");
    }

  } catch (e, s) {
    debugPrint("### ERRORE gestione Android: $e ###");
    debugPrint("Stack: $s");
  }

  debugPrint("="*50 + "\n");
}

Future<void> _ricreaDatabaseCompletamente(String dbPath) async {
  debugPrint("🔨 Ricreazione completa database...");

  // Backup vecchio database se esiste
  final dbFile = File(dbPath);
  if (await dbFile.exists()) {
    final backupPath = dbPath + '.backup_' +
        DateTime.now().millisecondsSinceEpoch.toString();
    await dbFile.copy(backupPath);
    debugPrint("   Backup creato: $backupPath");

    await deleteDatabase(dbPath);
    await Future.delayed(Duration(milliseconds: 500));
  }

  // Crea nuovo database
  final db = await openDatabase(
    dbPath,
    version: 2,
    onCreate: (db, version) async {
      await _creaStrutturaDatabase(db);
      await _popolaDatabaseDaAssetConLog(db);
      await _creaIndiciFTSConLogDettagliato(db, forzaturaCompleta: true);
    },
  );

  await db.close();
  debugPrint("✅ Database ricreato completamente");
}

Future<void> _risincronizzaFTS(Database db) async {
  debugPrint("🔄 Risincronizzazione FTS...");

  // Disabilita trigger temporaneamente
  await db.execute("DROP TRIGGER IF EXISTS spartiti_ai_fts");
  await db.execute("DROP TRIGGER IF EXISTS spartiti_ad_fts");
  await db.execute("DROP TRIGGER IF EXISTS spartiti_au_fts");

  // Svuota FTS
  await db.execute("DELETE FROM spartiti_fts");

  // Ripopola
  final count = await db.rawQuery("SELECT COUNT(*) as c FROM spartiti");
  final total = count.first['c'] as int? ?? 0;

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

  // Ricrea trigger
  await db.execute('''
    CREATE TRIGGER spartiti_ai_fts AFTER INSERT ON spartiti 
    BEGIN
      INSERT INTO spartiti_fts(rowid, titolo, autore, strumento, volume, ArchivioProvenienza)
      VALUES (new.id_univoco_globale, 
              COALESCE(new.titolo, ''),
              COALESCE(new.autore, ''),
              COALESCE(new.strumento, ''),
              COALESCE(new.volume, ''),
              COALESCE(new.ArchivioProvenienza, ''));
    END
  ''');

  debugPrint("✅ FTS risincronizzato, $total record");
}

Future<void> _riparaParziale(Database db, List<dynamic> problemi) async {
  debugPrint("🔧 Riparazione parziale...");

  for (final problema in problemi) {
    switch (problema) {
      case 'trigger_fts_mancanti':
        debugPrint("   Ripristino trigger mancanti...");
        await _creaTriggerFTS(db);
        break;

      case 'colonne_mancanti':
        debugPrint("   Aggiunta colonne mancanti...");
        await _aggiungiColonneMancanti(db);
        break;

      default:
        debugPrint("   Problema '$problema' non gestito nella riparazione parziale");
    }
  }
}

// ... (mantieni le altre funzioni della versione originale)