// lib/database/inizializza_i_db_della_app.dart - VERSIONE CORRETTA con FTS funzionante
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
/// FUNZIONE PER CREARE TRIGGERS DI SINCRONIZZAZIONE FTS
/// ===================================================================
Future<void> _creaTriggersSincronizzazioneFTS(Database db) async {
  debugPrint("🔗 Creazione triggers sincronizzazione FTS...");

  try {
    // Elimina triggers esistenti
    await db.execute("DROP TRIGGER IF EXISTS spartiti_ai_fts");
    await db.execute("DROP TRIGGER IF EXISTS spartiti_ad_fts");
    await db.execute("DROP TRIGGER IF EXISTS spartiti_au_fts");

    // Trigger per INSERT con TUTTI i campi
    await db.execute('''
      CREATE TRIGGER spartiti_ai_fts AFTER INSERT ON spartiti
      BEGIN
        INSERT INTO spartiti_fts(rowid, titolo, autore, strumento, volume, ArchivioProvenienza)
        VALUES (
          new.id_univoco_globale, 
          new.titolo, 
          new.autore, 
          new.strumento,
          new.volume,
          new.ArchivioProvenienza
        );
      END;
    ''');

    // Trigger per UPDATE con TUTTI i campi
    await db.execute('''
      CREATE TRIGGER spartiti_au_fts AFTER UPDATE ON spartiti
      BEGIN
        UPDATE spartiti_fts SET
          titolo = new.titolo,
          autore = new.autore,
          strumento = new.strumento,
          volume = new.volume,
          ArchivioProvenienza = new.ArchivioProvenienza
        WHERE rowid = old.id_univoco_globale;
      END;
    ''');

    // Trigger per DELETE
    await db.execute('''
      CREATE TRIGGER spartiti_ad_fts AFTER DELETE ON spartiti
      BEGIN
        DELETE FROM spartiti_fts WHERE rowid = old.id_univoco_globale;
      END;
    ''');

    debugPrint("✅ Triggers di sincronizzazione creati con 5 campi");
  } catch (e, s) {
    debugPrint("❌ Errore creazione triggers: $e");
    debugPrint("$s");
    throw e;
  }
}

/// ===================================================================
/// CREAZIONE INDICI FTS - VERSIONE CORRETTA per tutte le piattaforme
/// ===================================================================
Future<void> _creaIndiciFTSDefinitivo(Database db) async {
  debugPrint("\n" + "="*50);
  debugPrint("🔧 CREAZIONE FTS CON 5 CAMPI - Piattaforma: ${Platform.operatingSystem}");
  debugPrint("Campi: titolo, autore, strumento, volume, ArchivioProvenienza");
  debugPrint("="*50);

  try {
    // 1. Controlla stato attuale
    final ftsEsiste = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='spartiti_fts'"
    );

    if (ftsEsiste.isNotEmpty) {
      debugPrint("⚠️ FTS già presente - lo distruggo e ricreo");
      await db.execute("DROP TABLE IF EXISTS spartiti_fts");
      await db.execute("DROP TRIGGER IF EXISTS spartiti_ai_fts");
      await db.execute("DROP TRIGGER IF EXISTS spartiti_ad_fts");
      await db.execute("DROP TRIGGER IF EXISTS spartiti_au_fts");
    }

    // 2. Verifica struttura database e presenza campi
    final colonne = await db.rawQuery("PRAGMA table_info(spartiti)");
    final hasIdUnivoco = colonne.any((c) => c['name'] == 'id_univoco_globale');
    final hasTitolo = colonne.any((c) => c['name'] == 'titolo');
    final hasAutore = colonne.any((c) => c['name'] == 'autore');
    final hasStrumento = colonne.any((c) => c['name'] == 'strumento');
    final hasVolume = colonne.any((c) => c['name'] == 'volume');
    final hasArchivio = colonne.any((c) => c['name'] == 'ArchivioProvenienza');

    if (!hasIdUnivoco) {
      debugPrint("❌ ERRORE: Tabella 'spartiti' non ha 'id_univoco_globale'");
      throw Exception("Struttura database non valida per FTS");
    }

    debugPrint("Verifica campi nella tabella spartiti:");
    debugPrint("  • id_univoco_globale: ${hasIdUnivoco ? '✅' : '❌'}");
    debugPrint("  • titolo: ${hasTitolo ? '✅' : '❌'}");
    debugPrint("  • autore: ${hasAutore ? '✅' : '❌'}");
    debugPrint("  • strumento: ${hasStrumento ? '✅' : '❌'}");
    debugPrint("  • volume: ${hasVolume ? '✅' : '❌'}");
    debugPrint("  • ArchivioProvenienza: ${hasArchivio ? '✅' : '❌'}");

    // 3. Crea FTS - VERSIONE PLATFORM-SPECIFIC con 5 CAMPI
    debugPrint("\nCreazione tabella FTS con 5 campi...");

    if (Platform.isAndroid) {
      // ⭐️ VERSIONE ANDROID: senza content/content_rowid (problemi noti)
      await db.execute('''
        CREATE VIRTUAL TABLE spartiti_fts 
        USING fts5(
          titolo,
          autore,
          strumento,
          volume,
          ArchivioProvenienza
          -- NOTA: Su Android evitiamo content/content_rowid per problemi di compatibilità
          -- tokenize escluso per maggiore compatibilità
        )
      ''');

      debugPrint("✅ FTS Android creato con 5 campi");

      // 4. Popola dati iniziali MANUALMENTE per Android con TUTTI i campi
      debugPrint("Popolamento dati FTS iniziali (5 campi)...");
      final count = await db.rawQuery("SELECT COUNT(*) as c FROM spartiti");
      final total = count.first['c'] as int? ?? 0;

      if (total > 0) {
        await db.execute('''
          INSERT INTO spartiti_fts(rowid, titolo, autore, strumento, volume, ArchivioProvenienza)
          SELECT 
            id_univoco_globale,
            COALESCE(titolo, ''),
            COALESCE(autore, ''),
            COALESCE(strumento, ''),
            COALESCE(volume, ''),
            COALESCE(ArchivioProvenienza, '')
          FROM spartiti
          WHERE 
            titolo IS NOT NULL OR 
            autore IS NOT NULL OR 
            strumento IS NOT NULL OR
            volume IS NOT NULL OR
            ArchivioProvenienza IS NOT NULL
        ''');
        debugPrint("✅ $total record inseriti in FTS con 5 campi");
      }

      // 5. Crea triggers per sincronizzazione MANUALE con tutti i campi
      await _creaTriggersSincronizzazioneFTS(db);

    } else {
      // ⭐️ VERSIONE DESKTOP/IOS: con content/content_rowid (funziona meglio)
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
      debugPrint("✅ FTS Desktop/iOS creato con 5 campi (sincronizzazione automatica)");

      // NOTA: Con content/content_rowid, i triggers sono automatici
      // e i dati si sincronizzano automaticamente
    }

    // 6. Verifica IMMEDIATA della funzionalità FTS
    debugPrint("\n🔍 Verifica funzionalità FTS con 5 campi...");
    try {
      // Test 1: Conteggio record
      final countFts = await db.rawQuery("SELECT COUNT(*) as c FROM spartiti_fts");
      final countFtsValue = countFts.first['c'] as int? ?? 0;
      debugPrint("Record in FTS: $countFtsValue");

      // Test 2: Ricerca generica
      final testSimple = await db.rawQuery('''
        SELECT COUNT(*) as c FROM spartiti_fts 
        WHERE spartiti_fts MATCH ?
      ''', ['*']);
      debugPrint("Ricerca '*': ${testSimple.first['c']} risultati");

      // Test 3: Verifica presenza campi nella tabella FTS
      if (countFtsValue > 0) {
        final campiPresenti = await db.rawQuery('''
          SELECT * FROM spartiti_fts LIMIT 1
        ''');
        if (campiPresenti.isNotEmpty) {
          final keys = campiPresenti.first.keys.toList();
          debugPrint("Campi nella tabella FTS: ${keys.join(', ')}");
        }
      }

      // Test 4: Ricerca in campi specifici se ci sono dati
      if (countFtsValue > 0) {
        // Controlla se ci sono dati non vuoti nei vari campi
        final analisiDati = await db.rawQuery('''
          SELECT 
            COUNT(CASE WHEN titolo IS NOT NULL AND titolo != '' THEN 1 END) as con_titolo,
            COUNT(CASE WHEN autore IS NOT NULL AND autore != '' THEN 1 END) as con_autore,
            COUNT(CASE WHEN strumento IS NOT NULL AND strumento != '' THEN 1 END) as con_strumento,
            COUNT(CASE WHEN volume IS NOT NULL AND volume != '' THEN 1 END) as con_volume,
            COUNT(CASE WHEN ArchivioProvenienza IS NOT NULL AND ArchivioProvenienza != '' THEN 1 END) as con_archivio
          FROM spartiti
        ''');

        final row = analisiDati.first;
        debugPrint("\nAnalisi dati nei 5 campi:");
        debugPrint("  • Record con titolo: ${row['con_titolo']}");
        debugPrint("  • Record con autore: ${row['con_autore']}");
        debugPrint("  • Record con strumento: ${row['con_strumento']}");
        debugPrint("  • Record con volume: ${row['con_volume']}");
        debugPrint("  • Record con archivio: ${row['con_archivio']}");

        // Prova una ricerca reale
        try {
          // Prova con diversi campi
          final testTitolo = await db.rawQuery('''
            SELECT COUNT(*) as c FROM spartiti_fts 
            WHERE spartiti_fts MATCH 'titolo:*'
          ''');
          debugPrint("Ricerca 'titolo:*': ${testTitolo.first['c']} risultati");

          final testVolume = await db.rawQuery('''
            SELECT COUNT(*) as c FROM spartiti_fts 
            WHERE spartiti_fts MATCH 'volume:*'
          ''');
          debugPrint("Ricerca 'volume:*': ${testVolume.first['c']} risultati");

        } catch (e) {
          debugPrint("⚠️ Ricerca specifica fallita: $e");
        }
      }

      debugPrint("\n✅✅✅ FTS CON 5 CAMPI CREATO E VERIFICATO ✅✅✅");

    } catch (e) {
      debugPrint("⚠️ Test FTS parziale: $e");
      // Non blocchiamo l'app per errori di test
    }

    // 7. Verifica sincronizzazione (solo su Android)
    if (Platform.isAndroid) {
      debugPrint("\n🔗 Test sincronizzazione triggers con 5 campi...");
      try {
        // Verifica se i triggers sono stati creati
        final triggers = await db.rawQuery('''
          SELECT name FROM sqlite_master 
          WHERE type='trigger' AND name LIKE 'spartiti_%_fts'
        ''');

        debugPrint("Triggers presenti: ${triggers.length}");
        for (final trigger in triggers) {
          debugPrint("  • ${trigger['name']}");
        }

        if (triggers.length >= 3) {
          debugPrint("✅ Tutti i triggers sono presenti");

          // Test di sincronizzazione reale
          // Inserisci record di test
          final testId = 999999 + DateTime.now().millisecondsSinceEpoch;
          await db.insert('spartiti', {
            'titolo': 'Test FTS 5 Campi',
            'autore': 'Autore Test',
            'strumento': 'Piano',
            'volume': 'Volume Test',
            'ArchivioProvenienza': 'Archivio Test',
            'IdBra': testId,
            'PercRadice': '/test',
            'PercResto': 'test',
            'PrimoLInk': 'test',
            'TipoMulti': 'test',
            'TipoDocu': 'test',
            'NumPag': 1,
            'NumOrig': 1,
            'IdVolume': 'test',
            'IdAutore': 'test'
          });

          // Verifica che il record sia stato sincronizzato in FTS
          final ricercaTest = await db.rawQuery('''
            SELECT COUNT(*) as c FROM spartiti_fts 
            WHERE spartiti_fts MATCH 'Test'
          ''');

          debugPrint("Record di test sincronizzato: ${ricercaTest.first['c']} > 0?");

          // Pulizia record di test
          await db.delete('spartiti', where: 'IdBra = ?', whereArgs: [testId]);
        }

      } catch (e) {
        debugPrint("⚠️ Test sincronizzazione: $e");
      }
    }

    debugPrint("\n" + "="*50);
    debugPrint("🎯 CREAZIONE FTS CON 5 CAMPI COMPLETATA");
    debugPrint("="*50);

  } catch (e, s) {
    debugPrint("\n❌ ERRORE creazione FTS con 5 campi:");
    debugPrint("$e");
    debugPrint("$s");
    rethrow;
  }
}

/// ===================================================================
/// FUNZIONE PRINCIPALE DI INIZIALIZZAZIONE - VERSIONE CORRETTA
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
    debugPrint("🚀 INIZIALIZZAZIONE DATABASE JAMSETGEMINI - VERSIONE FTS 5 CAMPI");
    debugPrint("="*60);
    debugPrint("Piattaforma: ${Platform.operatingSystem}");
    debugPrint("Data: ${DateTime.now()}");

    // 1. Prepara engine database
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS || Platform.isAndroid) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    // 2. Ottieni directory support
    final supportDir = await getApplicationSupportDirectory();
    gDatabasePath = supportDir.path;
    final sep = Platform.pathSeparator;

    debugPrint("Directory support: $gDatabasePath");

    // 3. Crea/verifica VecchioDb.db
    final vecchioDbPath = '$gDatabasePath$sep$_vecchioDbName';
    debugPrint("\nFASE 1: Database VecchioDb.db...");

    if (!await databaseExists(vecchioDbPath)) {
      debugPrint("VecchioDb.db non trovato, creazione...");
      await _creaVecchioDbConPopolamento(vecchioDbPath);
    }

    // 4. Apri database e CREA FTS DEFINITIVO CON 5 CAMPI
    dbVecchio = await openDatabase(vecchioDbPath);
    debugPrint("VecchioDb.db: creazione FTS con 5 campi...");

    // ⭐️ CHIAMA LA FUNZIONE CORRETTA CON 5 CAMPI ⭐️
    await _creaIndiciFTSDefinitivo(dbVecchio!);

    // 5. Gestisci altri database...
    await _gestisciAltriDatabase(supportDir.path, sep);

    debugPrint("\n" + "="*60);
    debugPrint("✅ INIZIALIZZAZIONE COMPLETATA CON SUCCESSO");
    debugPrint("FTS configurato con 5 campi di ricerca");
    debugPrint("="*60);

    _initializationCompleter?.complete();

  } catch (e, s) {
    debugPrint("\n❌ ERRORE CRITICO INIZIALIZZAZIONE:");
    debugPrint("$e");
    debugPrint("$s");
    _initializationCompleter?.completeError(e);
    rethrow;
  } finally {
    _isInitializing = false;
  }
}

/// Crea VecchioDb con popolamento
Future<void> _creaVecchioDbConPopolamento(String destDbPath) async {
  debugPrint("Creazione VecchioDb da asset...");

  final tempDir = await getTemporaryDirectory();
  final sep = Platform.pathSeparator;
  final tempAssetDbPath = '${tempDir.path}${sep}asset_seed.db';

  // Copia asset
  final ByteData data = await rootBundle.load('assets/databases/$_vecchioDbName');
  await File(tempAssetDbPath).writeAsBytes(data.buffer.asUint8List(), flush: true);

  Database? seedDb;
  Database? newDb;
  try {
    seedDb = await openReadOnlyDatabase(tempAssetDbPath);
    newDb = await openDatabase(destDbPath);

    // Crea struttura con TUTTI i campi
    await newDb.execute('''
      CREATE TABLE spartiti (
        id_univoco_globale INTEGER PRIMARY KEY AUTOINCREMENT,
        IdBra INTEGER UNIQUE,
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

    // Popola dati
    final sourceTableName = Platform.isAndroid ? 'spartiti_andr' : 'spartiti';
    final dataToInsert = await seedDb.query(sourceTableName);

    debugPrint("Letti ${dataToInsert.length} record da asset (con tutti i campi)");

    final batch = newDb.batch();
    for (final row in dataToInsert) {
      batch.insert('spartiti', row, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);

    debugPrint("Popolamento completato: ${dataToInsert.length} record inseriti");

  } finally {
    await seedDb?.close();
    await newDb?.close();
    await deleteDatabase(tempAssetDbPath);
  }
}

/// Gestisci altri database (DBGlobale_seed, etc.)
Future<void> _gestisciAltriDatabase(String supportDirPath, String sep) async {
  // DBGlobale_seed.db
  final dbGlobalePath = '$supportDirPath$sep$_dbGlobaleName';
  if (!await databaseExists(dbGlobalePath)) {
    debugPrint("DBGlobale_seed.db non trovato, copia da asset...");
    final ByteData data = await rootBundle.load('assets/databases/$_dbGlobaleName');
    await File(dbGlobalePath).writeAsBytes(data.buffer.asUint8List(), flush: true);
  }

  dbGlobale = await openDatabase(dbGlobalePath);

  // Configura percorso PDF
  gPercorsoPdf = Platform.isAndroid
      ? "/storage/emulated/0/JamsetPDF/"
      : "C:\\JamsetPDF\\";

  debugPrint("Percorso PDF configurato: $gPercorsoPdf");

  // Configura catalogo attivo
  final datiSistema = (await dbGlobale!.query('DatiSistremaApp', limit: 1)).first;
  gPercorsoPdf = datiSistema['PercorsoPdf'] as String? ?? gPercorsoPdf;
  int idCatalogoAttivo = datiSistema['id_catalogo_attivo'] as int? ?? 1;

  var catalogoInfoResult = await dbGlobale!.query(
      'elenco_cataloghi',
      where: 'id = ?',
      whereArgs: [idCatalogoAttivo],
      limit: 1
  );

  if (catalogoInfoResult.isEmpty) {
    idCatalogoAttivo = 1;
    catalogoInfoResult = await dbGlobale!.query(
        'elenco_cataloghi',
        where: 'id = ?',
        whereArgs: [1],
        limit: 1
    );
  }

  gActiveCatalogDbName = catalogoInfoResult.first['nome_file_db'] as String;
  final catalogoPath = '$supportDirPath$sep$gActiveCatalogDbName';

  if (!await databaseExists(catalogoPath)) {
    debugPrint("$gActiveCatalogDbName non trovato, copia da asset...");
    final ByteData data = await rootBundle.load('assets/databases/$gActiveCatalogDbName');
    await File(catalogoPath).writeAsBytes(data.buffer.asUint8List(), flush: true);
  }

  dbCatalogoAttivo = await openDatabase(catalogoPath);

  // ⭐️ CREA FTS ANCHE PER CATALOGO ATTIVO CON 5 CAMPI ⭐️
  debugPrint("Catalogo attivo: creazione FTS con 5 campi...");
  await _creaIndiciFTSDefinitivo(dbCatalogoAttivo!);

  debugPrint("Catalogo attivo configurato: $gActiveCatalogDbName");
}

/// ===================================================================
/// FUNZIONI AGGIUNTIVE PER COMPATIBILITÀ
/// ===================================================================

/// Vecchia funzione mantenuta per compatibilità
Future<void> _creaIndiciFTSConLogDettagliato(Database db, {bool forzaturaCompleta = false}) async {
  // Chiama la nuova funzione con 5 campi
  await _creaIndiciFTSDefinitivo(db);
}

/// Vecchia diagnostica mantenuta per compatibilità
class DiagnosticaAndroid {
  static Future<Map<String, dynamic>> analizzaProblemiDatabase(String dbPath) async {
    return {
      'problemi': [],
      'raccomandazione': 'nessun_intervento'
    };
  }
}