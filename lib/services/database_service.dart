// lib/services/database_service.dart - VERSIONE FINALE CON SCHEMA CORRETTO
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService with ChangeNotifier {
  static DatabaseService? _instance;
  Database? _dbGlobale;
  Database? _dbCatalogoAttivo;

  static const String _dbGlobaleName = 'DBGlobale.db';
  static const String _vecchioDbName = 'VecchioDb.db';

  String _percorsoPdf = '';
  String _databasePath = '';
  String _activeCatalogDbName = '';

  factory DatabaseService() => _instance ??= DatabaseService._internal();
  DatabaseService._internal();

  Database? get dbGlobale => _dbGlobale;
  Database? get dbCatalogoAttivo => _dbCatalogoAttivo;
  String get percorsoPdf => _percorsoPdf;
  String get databasePath => _databasePath;
  String get activeCatalogDbName => _activeCatalogDbName;

  Future<void> initialize() async {
    final supportDir = await getApplicationSupportDirectory();
    _databasePath = supportDir.path;
    await Directory(_databasePath).create(recursive: true);
    final path = p.join(_databasePath, _dbGlobaleName);

    _dbGlobale = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await _creaSchemaDbGlobale(db);
        await _popolaDatiGlobaliDefault(db);
      },
      onOpen: (db) async {
        await _verificaMigrazioneSchema(db);
      },
    );

    await synchronizeCatalogs();
    await _loadConfigFromDb();

    await runDiagnostics();
  }

  Future<void> reloadConfig() async {
    await _loadConfigFromDb();
    notifyListeners();
  }

  Future<void> _creaSchemaDbGlobale(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS DatiSistremaApp (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        SistemaOperativo TEXT,
        PercorsoPdf TEXT,
        Percorsodatabase TEXT,
        id_catalogo_attivo INTEGER DEFAULT 1
      )
    ''');

    // 🔥 SCHEMA CORRETTO BASATO SULLA STRUTTURA FORNITA
    await db.execute('''
      CREATE TABLE IF NOT EXISTS elenco_cataloghi (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome_catalogo TEXT NOT NULL UNIQUE,
        nome_file_db TEXT NOT NULL UNIQUE,
        FilesPath TEXT,
        AppPath TEXT,
        descrizione TEXT,
        data_creazione TEXT DEFAULT (STRFTIME('%Y-%m-%d %H:%M:%S', 'NOW', 'localtime')),
        data_ultimo_aggiornamento TEXT,
        conteggio_brani INTEGER DEFAULT 0,
        icona_catalogo TEXT
      )
    ''');
  }

  Future<void> _popolaDatiGlobaliDefault(Database db) async {
    final ora = DateTime.now().toIso8601String();

    String defaultPath = Platform.isAndroid
        ? '/storage/emulated/0/'
        : r'C:\';

    // Inserisci configurazione sistema
    await db.insert('DatiSistremaApp', {
      'SistemaOperativo': Platform.isAndroid ? 'Android' : 'Windows',
      'PercorsoPdf': defaultPath,
      'Percorsodatabase': _databasePath,
      'id_catalogo_attivo': 1
    });

    // 🔥 INSERISCI CORRETTAMENTE IL CATALOGO PRINCIPALE
    await db.insert('elenco_cataloghi', {
      'nome_catalogo': 'Catalogo Principale',
      'nome_file_db': _vecchioDbName,
      'FilesPath': defaultPath,
      'AppPath': _databasePath,
      'descrizione': 'Database iniziale',
      'data_creazione': ora,
      'data_ultimo_aggiornamento': ora,
      'conteggio_brani': 0,
      'icona_catalogo': 'default'
    });
  }

  Future<void> _verificaMigrazioneSchema(Database db) async {
    try {
      // Verifica DatiSistremaApp
      final resDati = await db.rawQuery("PRAGMA table_info('DatiSistremaApp')");
      final colDati = resDati.map((e) => e['name'] as String).toList();
      if (!colDati.contains('PercorsoPdf')) await db.execute('ALTER TABLE DatiSistremaApp ADD COLUMN PercorsoPdf TEXT');
      if (!colDati.contains('id_catalogo_attivo')) await db.execute('ALTER TABLE DatiSistremaApp ADD COLUMN id_catalogo_attivo INTEGER DEFAULT 1');

      // Verifica elenco_cataloghi - AGGIORNAMENTO PER SCHEMA CORRETTO
      final resCat = await db.rawQuery("PRAGMA table_info('elenco_cataloghi')");
      final colCat = resCat.map((e) => e['name'] as String).toList();

      // Aggiungi colonne mancanti secondo lo schema fornito
      if (!colCat.contains('nome_file_db')) await db.execute('ALTER TABLE elenco_cataloghi ADD COLUMN nome_file_db TEXT NOT NULL UNIQUE');
      if (!colCat.contains('FilesPath')) await db.execute('ALTER TABLE elenco_cataloghi ADD COLUMN FilesPath TEXT');
      if (!colCat.contains('AppPath')) await db.execute('ALTER TABLE elenco_cataloghi ADD COLUMN AppPath TEXT');
      if (!colCat.contains('descrizione')) await db.execute('ALTER TABLE elenco_cataloghi ADD COLUMN descrizione TEXT');
      if (!colCat.contains('data_creazione')) await db.execute('ALTER TABLE elenco_cataloghi ADD COLUMN data_creazione TEXT');
      if (!colCat.contains('data_ultimo_aggiornamento')) await db.execute('ALTER TABLE elenco_cataloghi ADD COLUMN data_ultimo_aggiornamento TEXT');
      if (!colCat.contains('conteggio_brani')) await db.execute('ALTER TABLE elenco_cataloghi ADD COLUMN conteggio_brani INTEGER DEFAULT 0');
      if (!colCat.contains('icona_catalogo')) await db.execute('ALTER TABLE elenco_cataloghi ADD COLUMN icona_catalogo TEXT');

      // Se manca UNIQUE constraint su nome_catalogo
      if (colCat.contains('nome_catalogo')) {
        try {
          await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_nome_catalogo_unique ON elenco_cataloghi(nome_catalogo)');
          await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_nome_file_db_unique ON elenco_cataloghi(nome_file_db)');
        } catch (_) {}
      }

    } catch (e) {
      debugPrint('⚠️ Errore migrazione: $e');
    }
  }

  Future<void> _loadConfigFromDb() async {
    if (_dbGlobale == null) return;
    try {
      final config = await _dbGlobale!.query('DatiSistremaApp', limit: 1);

      // Default di emergenza basato su piattaforma
      String fallbackPath = Platform.isAndroid
          ? '/storage/emulated/0/'
          : r'C:\';

      if (config.isNotEmpty) {
        _percorsoPdf = config.first['PercorsoPdf'] as String? ?? fallbackPath;
      } else {
        _percorsoPdf = fallbackPath;
      }

      final catalogoAttivo = await getCurrentVolume();
      if (catalogoAttivo.isNotEmpty) {
        _activeCatalogDbName = catalogoAttivo['nome_file_db'] as String? ?? _vecchioDbName;
        await _caricaCatalogoAttivo();
      }
    } catch (e) {
      debugPrint('Errore caricamento configurazione: $e');
    }
  }

  Future<void> _caricaCatalogoAttivo() async {
    try {
      if (_dbCatalogoAttivo != null) {
        await _dbCatalogoAttivo!.close();
        _dbCatalogoAttivo = null;
      }

      if (_activeCatalogDbName.isNotEmpty) {
        final dbPath = p.join(_databasePath, _activeCatalogDbName);
        debugPrint('📂 Tentativo di aprire database: $dbPath');

        _dbCatalogoAttivo = await openDatabase(dbPath);
        debugPrint('🎯 Catalogo attivo caricato: $_activeCatalogDbName');

        // Esegui diagnostica immediata
        await _diagnosticaImmediataDatabase();
      }
    } catch (e) {
      debugPrint('❌ Errore caricamento catalogo: $e');
    }
  }

  Future<void> _diagnosticaImmediataDatabase() async {
    if (_dbCatalogoAttivo == null) return;

    try {
      debugPrint('\n🔍 DIAGNOSTICA IMMEDIATA DATABASE');
      debugPrint('==================================');

      // 1. Verifica tabelle esistenti
      final tables = await _dbCatalogoAttivo!.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"
      );

      debugPrint('📋 Tabelle nel database:');
      for (final table in tables) {
        debugPrint('   - ${table['name']}');
      }

      // 2. Conta record nelle tabelle principali
      final countSpartiti = await _dbCatalogoAttivo!.rawQuery('SELECT COUNT(*) as count FROM spartiti');
      final countFTS = await _dbCatalogoAttivo!.rawQuery('SELECT COUNT(*) as count FROM spartiti_fts');

      final numSpartiti = countSpartiti.first['count'] as int? ?? 0;
      final numFTS = countFTS.first['count'] as int? ?? 0;

      debugPrint('📊 Conteggio record:');
      debugPrint('   - spartiti: $numSpartiti');
      debugPrint('   - spartiti_fts: $numFTS');

      // 3. Verifica struttura tabella spartiti
      if (numSpartiti > 0) {
        final primaRiga = await _dbCatalogoAttivo!.rawQuery('SELECT * FROM spartiti LIMIT 1');
        if (primaRiga.isNotEmpty) {
          debugPrint('📄 Struttura prima riga spartiti:');
          primaRiga.first.forEach((key, value) {
            debugPrint('   - $key: $value (${value.runtimeType})');
          });
        }
      }

      // 4. Test ricerca semplice
      debugPrint('\n🧪 TEST RICERCA BASE:');
      final testResults = await _dbCatalogoAttivo!.rawQuery('''
        SELECT titolo, autore FROM spartiti 
        WHERE titolo LIKE '%test%' OR autore LIKE '%test%' 
        LIMIT 5
      ''');

      debugPrint('   Risultati ricerca "test": ${testResults.length}');
      if (testResults.isNotEmpty) {
        for (int i = 0; i < testResults.length; i++) {
          debugPrint('   ${i + 1}. ${testResults[i]['titolo']} - ${testResults[i]['autore']}');
        }
      }

      // 5. Test ricerca FTS
      debugPrint('\n🧪 TEST RICERCA FTS:');
      try {
        final testFTS = await _dbCatalogoAttivo!.rawQuery('''
          SELECT s.titolo, s.autore 
          FROM spartiti s
          JOIN spartiti_fts f ON s.IdBra = f.rowid
          WHERE spartiti_fts MATCH 'test'
          LIMIT 5
        ''');

        debugPrint('   Risultati FTS "test": ${testFTS.length}');
        if (testFTS.isNotEmpty) {
          for (int i = 0; i < testFTS.length; i++) {
            debugPrint('   ${i + 1}. ${testFTS[i]['titolo']} - ${testFTS[i]['autore']}');
          }
        } else {
          debugPrint('   ⚠️ Nessun risultato FTS');
        }
      } catch (e) {
        debugPrint('   ❌ Errore ricerca FTS: $e');
      }

      debugPrint('✅ Diagnostica completata\n');

    } catch (e) {
      debugPrint('❌ Errore diagnostica database: $e');
    }
  }

  Future<Map<String, dynamic>> getCurrentVolume() async {
    if (_dbGlobale == null) return {};
    try {
      final res = await _dbGlobale!.query('DatiSistremaApp', limit: 1);
      if (res.isNotEmpty) {
        final id = res.first['id_catalogo_attivo'] as int? ?? 1;
        final cat = await _dbGlobale!.query('elenco_cataloghi', where: 'id = ?', whereArgs: [id]);
        return cat.isNotEmpty ? cat.first : {};
      }
    } catch (_) {}
    return {};
  }

  Future<List<Map<String, dynamic>>> getAvailableVolumes() async {
    if (_dbGlobale == null) return [];
    return await _dbGlobale!.query('elenco_cataloghi', orderBy: 'nome_catalogo');
  }

  Future<bool> switchVolume(String dbName) async {
    try {
      // 🔥 AGGIORNATO: usa nome_file_db invece di nome_file_dbCatalogoAttivo
      final res = await _dbGlobale!.query('elenco_cataloghi',
          where: 'nome_file_db = ?',
          whereArgs: [dbName],
          limit: 1
      );

      if (res.isNotEmpty) {
        await _dbGlobale!.update('DatiSistremaApp',
            {'id_catalogo_attivo': res.first['id']},
            where: 'id = 1'
        );
        _activeCatalogDbName = dbName;
        await _caricaCatalogoAttivo();
        notifyListeners();
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> synchronizeCatalogs() async {
    if (_dbGlobale == null) return;

    debugPrint('🔄 Sincronizzazione cataloghi...');

    try {
      final cataloghi = await _dbGlobale!.query('elenco_cataloghi');
      debugPrint('📋 Cataloghi nel DB globale: ${cataloghi.length}');

      for (final catalogo in cataloghi) {
        final dbName = catalogo['nome_file_db'] as String?;
        final nomeCatalogo = catalogo['nome_catalogo'] as String? ?? 'Sconosciuto';

        if (dbName != null && dbName.isNotEmpty) {
          final dbPath = p.join(_databasePath, dbName);

          if (!await File(dbPath).exists()) {
            debugPrint('📁 Database non trovato: $nomeCatalogo ($dbName)');

            if (dbName == _vecchioDbName) {
              await _creaSchemaECopiaDatiConTrigger(dbName);
            } else {
              await createCatalogoDatabase(dbName);
            }
          } else {
            debugPrint('✅ Database esiste: $nomeCatalogo');
          }
        }
      }

      debugPrint('✅ Sincronizzazione cataloghi completata');

    } catch (e) {
      debugPrint('❌ Errore sincronizzazione cataloghi: $e');
    }
  }

  Future<void> _creaSchemaECopiaDatiConTrigger(String dbName) async {
    final dbPath = p.join(_databasePath, dbName);

    try {
      debugPrint('\n🚀 CREAZIONE DATABASE CON TRIGGER ATTIVI');
      debugPrint('=========================================');

      // 1. Crea schema con trigger FTS
      debugPrint('1️⃣  Creazione schema con trigger FTS...');
      await createCatalogoDatabase(dbName);

      // 2. Apri database (con trigger già attivi)
      final db = await openDatabase(dbPath);

      // 3. Copia dati dall'asset
      debugPrint('2️⃣  Copia dati con indicizzazione automatica...');
      await _copiaDatiDaAssetConIndicizzazioneAutomatica(db, dbName);

      await db.close();

      debugPrint('✅ Database creato con successo');

    } catch (e) {
      debugPrint('❌ Errore creazione database: $e');
      await createCatalogoDatabase(dbName);
    }
  }

  Future<void> _copiaDatiDaAssetConIndicizzazioneAutomatica(Database db, String dbName) async {
    try {
      debugPrint('📥 Caricamento asset...');

      final ByteData data = await rootBundle.load('assets/databases/$dbName');
      final tempDir = await getTemporaryDirectory();
      final tempPath = p.join(tempDir.path, 'temp_$dbName');
      await File(tempPath).writeAsBytes(data.buffer.asUint8List());

      final tempDb = await openDatabase(tempPath, readOnly: true);

      final spartiti = await tempDb.rawQuery('SELECT * FROM spartiti');
      final total = spartiti.length;

      debugPrint('📊 Record da copiare: $total');

      if (total == 0) {
        debugPrint('ℹ️ Asset vuoto');
        await tempDb.close();
        await File(tempPath).delete();
        return;
      }

      debugPrint('🔄 Copia dati con indicizzazione automatica...');

      int copiedCount = 0;
      const batchSize = 1000;

      for (int i = 0; i < total; i += batchSize) {
        final end = (i + batchSize) < total ? (i + batchSize) : total;

        await db.transaction((txn) async {
          for (int j = i; j < end; j++) {
            final spartito = Map<String, dynamic>.from(spartiti[j]);

            try {
              await txn.insert('spartiti', spartito);
              copiedCount++;
            } catch (e) {
              debugPrint('⚠️ Errore record $j: $e');
            }
          }
        });

        if (copiedCount % 5000 == 0) {
          debugPrint('   📦 Copiati $copiedCount/$total record');
        }
      }

      // Verifica
      final countSpartiti = await db.rawQuery('SELECT COUNT(*) as count FROM spartiti');
      final countFTS = await db.rawQuery('SELECT COUNT(*) as count FROM spartiti_fts');

      final numSpartiti = countSpartiti.first['count'] as int? ?? 0;
      final numFTS = countFTS.first['count'] as int? ?? 0;

      debugPrint('✅ Copia completata: $copiedCount record');
      debugPrint('🔍 Verifica: $numSpartiti in spartiti, $numFTS in FTS');

      if (copiedCount != numFTS) {
        debugPrint('⚠️  Discrepanza! Trigger FTS potrebbero non funzionare');
      }

      await tempDb.close();
      await File(tempPath).delete();

    } catch (e) {
      debugPrint('❌ Errore copia dati: $e');
      rethrow;
    }
  }

  Future<void> createCatalogoDatabase(String dbName) async {
    final dbPath = p.join(_databasePath, dbName);
    final db = await openDatabase(dbPath, version: 1, onCreate: _creaSchemaCatalogoCompleto);
    await db.close();
    debugPrint('✅ Database catalogo creato: $dbName');
  }

  Future<void> _creaSchemaCatalogoCompleto(Database db, int version) async {
    debugPrint('🏗️ Creazione schema catalogo COMPLETO...');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS spartiti (
        IdBra INTEGER PRIMARY KEY AUTOINCREMENT,
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

    await db.execute('''
      CREATE VIRTUAL TABLE IF NOT EXISTS spartiti_fts USING fts5(
        titolo,
        autore,
        volume,
        ArchivioProvenienza,
        content='spartiti',
        content_rowid='IdBra'
      )
    ''');

    await _creaTriggerFTS(db);

    await db.execute('CREATE INDEX IF NOT EXISTS idx_spartiti_titolo ON spartiti(titolo)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_spartiti_autore ON spartiti(autore)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_spartiti_volume ON spartiti(volume)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_spartiti_archivio ON spartiti(ArchivioProvenienza)');

    debugPrint('✅ Schema catalogo completo creato');
  }

  Future<void> _creaTriggerFTS(Database db) async {
    try {
      await db.execute('DROP TRIGGER IF EXISTS spartiti_ai');
      await db.execute('DROP TRIGGER IF EXISTS spartiti_au');
      await db.execute('DROP TRIGGER IF EXISTS spartiti_ad');

      await db.execute('''
        CREATE TRIGGER spartiti_ai AFTER INSERT ON spartiti
        BEGIN
          INSERT INTO spartiti_fts(rowid, titolo, autore, volume, ArchivioProvenienza)
          VALUES (new.IdBra, new.titolo, new.autore, new.volume, new.ArchivioProvenienza);
        END
      ''');

      await db.execute('''
        CREATE TRIGGER spartiti_ad AFTER DELETE ON spartiti
        BEGIN
          INSERT INTO spartiti_fts(spartiti_fts, rowid, titolo, autore, volume, ArchivioProvenienza)
          VALUES('delete', old.IdBra, old.titolo, old.autore, old.volume, old.ArchivioProvenienza);
        END
      ''');

      await db.execute('''
        CREATE TRIGGER spartiti_au AFTER UPDATE ON spartiti
        BEGIN
          INSERT INTO spartiti_fts(spartiti_fts, rowid, titolo, autore, volume, ArchivioProvenienza)
          VALUES('delete', old.IdBra, old.titolo, old.autore, old.volume, old.ArchivioProvenienza);
          INSERT INTO spartiti_fts(rowid, titolo, autore, volume, ArchivioProvenienza)
          VALUES (new.IdBra, new.titolo, new.autore, new.volume, new.ArchivioProvenienza);
        END
      ''');

      debugPrint('✅ Trigger FTS creati');
    } catch (e) {
      debugPrint('❌ Errore creazione trigger FTS: $e');
    }
  }

  Future<void> risincronizzaFTSCompleta({Function(double)? onProgress}) async {
    if (_activeCatalogDbName.isEmpty) {
      debugPrint('❌ Nessun catalogo attivo');
      return;
    }

    try {
      debugPrint('\n🎯 REINDICIZZAZIONE FTS MANUALE');
      debugPrint('===============================');

      final dbPath = p.join(_databasePath, _activeCatalogDbName);
      final db = await openDatabase(dbPath);

      // Disabilita trigger
      await db.execute('DROP TRIGGER IF EXISTS spartiti_ai');
      await db.execute('DROP TRIGGER IF EXISTS spartiti_au');
      await db.execute('DROP TRIGGER IF EXISTS spartiti_ad');

      // Pulisci FTS
      await db.execute('DELETE FROM spartiti_fts');

      // Ricopia tutti i dati
      final spartiti = await db.rawQuery('SELECT * FROM spartiti');
      final total = spartiti.length;

      debugPrint('🔄 Ricopiando $total record...');

      int reindexed = 0;
      await db.transaction((txn) async {
        for (final spartito in spartiti) {
          await txn.insert('spartiti_fts', {
            'rowid': spartito['IdBra'],
            'titolo': spartito['titolo'] ?? '',
            'autore': spartito['autore'] ?? '',
            'volume': spartito['volume'] ?? '',
            'ArchivioProvenienza': spartito['ArchivioProvenienza'] ?? ''
          });
          reindexed++;

          if (onProgress != null && total > 0) {
            onProgress(reindexed / total);
          }

          if (reindexed % 1000 == 0) {
            debugPrint('   📦 Reindicizzati $reindexed/$total record...');
          }
        }
      });

      // Riattiva trigger
      await _creaTriggerFTS(db);

      await db.close();

      debugPrint('✅ Reindicizzazione completata: $reindexed record');

      notifyListeners();

    } catch (e) {
      debugPrint('❌ Errore reindicizzazione: $e');
    }
  }

  // ============================ METODI DI RICERCA CON LOGGING ============================

  Future<List<Map<String, dynamic>>> searchFTS(String query) async {
    if (_dbCatalogoAttivo == null) {
      debugPrint('❌ Database catalogo non caricato');
      return [];
    }

    if (query.isEmpty) {
      debugPrint('⚠️ Query vuota');
      return [];
    }

    try {
      debugPrint('\n🔍🔍🔍 RICERCA FTS INIZIATA 🔍🔍🔍');
      debugPrint('Query: "$query"');
      debugPrint('Database attivo: $_activeCatalogDbName');

      // PRIMA: verifica stato database
      final countSpartiti = await _dbCatalogoAttivo!.rawQuery('SELECT COUNT(*) as count FROM spartiti');
      final countFTS = await _dbCatalogoAttivo!.rawQuery('SELECT COUNT(*) as count FROM spartiti_fts');

      final numSpartiti = countSpartiti.first['count'] as int? ?? 0;
      final numFTS = countFTS.first['count'] as int? ?? 0;

      debugPrint('📊 Stato database:');
      debugPrint('   - Record in spartiti: $numSpartiti');
      debugPrint('   - Record in spartiti_fts: $numFTS');

      if (numSpartiti == 0) {
        debugPrint('⚠️ Database spartiti vuoto!');
        return [];
      }

      if (numFTS == 0) {
        debugPrint('⚠️ Tabella FTS vuota! Ricerca non funzionerà.');
        debugPrint('💡 Usare il bottone "Reindicizza FTS"');
        return await _searchFallback(query);
      }

      // COSTRUISCI QUERY FTS
      final ftsQuery = '''
        SELECT s.* 
        FROM spartiti s
        JOIN spartiti_fts f ON s.IdBra = f.rowid
        WHERE spartiti_fts MATCH ?
        ORDER BY rank
        LIMIT 100
      ''';

      debugPrint('📝 Query FTS eseguita:');
      debugPrint('   SQL: $ftsQuery');
      debugPrint('   Parametri: ["$query"]');

      final stopwatch = Stopwatch()..start();
      final results = await _dbCatalogoAttivo!.rawQuery(ftsQuery, [query]);
      stopwatch.stop();

      debugPrint('⏱️  Tempo esecuzione: ${stopwatch.elapsedMilliseconds}ms');
      debugPrint('📊 Risultati trovati: ${results.length}');

      if (results.isNotEmpty) {
        debugPrint('🎯 PRIMI 5 RISULTATI:');
        for (int i = 0; i < results.length && i < 5; i++) {
          final result = results[i];
          debugPrint('   ${i + 1}. ${result['titolo']} - ${result['autore']} (ID: ${result['IdBra']})');
        }
      } else {
        debugPrint('😞 Nessun risultato trovato');

        // Test query alternativa
        debugPrint('\n🧪 TEST QUERY ALTERNATIVA (senza JOIN):');
        try {
          final testQuery = '''
            SELECT rowid, titolo, autore 
            FROM spartiti_fts 
            WHERE spartiti_fts MATCH ?
            LIMIT 10
          ''';

          final testResults = await _dbCatalogoAttivo!.rawQuery(testQuery, [query]);
          debugPrint('   Risultati diretti FTS: ${testResults.length}');

          if (testResults.isNotEmpty) {
            debugPrint('   💡 FTS funziona ma il JOIN potrebbe avere problemi');
          }
        } catch (e) {
          debugPrint('   ❌ Errore query alternativa: $e');
        }
      }

      debugPrint('🔍🔍🔍 RICERCA FTS COMPLETATA 🔍🔍🔍\n');

      return results;

    } catch (e, stackTrace) {
      debugPrint('❌❌❌ ERRORE RICERCA FTS ❌❌❌');
      debugPrint('Errore: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('Tentativo ricerca fallback...');

      return await _searchFallback(query);
    }
  }

  Future<List<Map<String, dynamic>>> _searchFallback(String query) async {
    debugPrint('\n🔄 ATTIVAZIONE RICERCA FALLBACK');

    if (_dbCatalogoAttivo == null) {
      debugPrint('❌ Database non disponibile per fallback');
      return [];
    }

    try {
      final searchTerm = '%$query%';
      final fallbackQuery = '''
        SELECT * FROM spartiti 
        WHERE titolo LIKE ? OR autore LIKE ? OR volume LIKE ? OR ArchivioProvenienza LIKE ?
        LIMIT 100
      ''';

      debugPrint('📝 Query fallback:');
      debugPrint('   SQL: $fallbackQuery');
      debugPrint('   Parametri: ["$searchTerm", "$searchTerm", "$searchTerm", "$searchTerm"]');

      final stopwatch = Stopwatch()..start();
      final results = await _dbCatalogoAttivo!.rawQuery(
          fallbackQuery,
          [searchTerm, searchTerm, searchTerm, searchTerm]
      );
      stopwatch.stop();

      debugPrint('⏱️  Tempo fallback: ${stopwatch.elapsedMilliseconds}ms');
      debugPrint('📊 Risultati fallback: ${results.length}');

      if (results.isNotEmpty) {
        debugPrint('🎯 PRIMI 3 RISULTATI FALLBACK:');
        for (int i = 0; i < results.length && i < 3; i++) {
          final result = results[i];
          debugPrint('   ${i + 1}. ${result['titolo']} - ${result['autore']}');
        }
      }

      debugPrint('🔄 RICERCA FALLBACK COMPLETATA\n');

      return results;
    } catch (e) {
      debugPrint('❌ Errore ricerca fallback: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getFTSStatus() async {
    if (_dbCatalogoAttivo == null) {
      return {'status': 'error', 'message': 'Database non caricato'};
    }

    try {
      final countSpartiti = await _dbCatalogoAttivo!.rawQuery('SELECT COUNT(*) as count FROM spartiti');
      final countFTS = await _dbCatalogoAttivo!.rawQuery('SELECT COUNT(*) as count FROM spartiti_fts');

      final numSpartiti = countSpartiti.first['count'] as int? ?? 0;
      final numFTS = countFTS.first['count'] as int? ?? 0;

      return {
        'status': 'ok',
        'spartiti_count': numSpartiti,
        'fts_count': numFTS,
        'synced': numSpartiti == numFTS,
        'difference': (numSpartiti - numFTS).abs(),
        'needs_reindex': numSpartiti != numFTS,
        'message': numSpartiti == numFTS
            ? '✅ FTS sincronizzata ($numSpartiti record)'
            : '⚠️ FTS non sincronizzata: $numSpartiti spartiti vs $numFTS in FTS'
      };
    } catch (e) {
      return {'status': 'error', 'message': 'Errore verifica FTS: $e'};
    }
  }

  // ============================ METODI DI IMPORT CSV ============================

  Future<int> importFromCsv(String csvPath, String targetDbName) async {
    debugPrint('\n📥📥📥 INIZIO IMPORT CSV 📥📥📥');
    debugPrint('Percorso CSV: $csvPath');
    debugPrint('Database destinazione: $targetDbName');

    // ⚠️ PROTEZIONE: Impedisci import su VecchioDb.db
    if (targetDbName == _vecchioDbName) {
      throw Exception('Importazione su VecchioDb.db non permessa. Crea un nuovo catalogo.');
    }

    try {
      final dbPath = p.join(_databasePath, targetDbName);
      final db = await openDatabase(dbPath);

      // Verifica schema
      await _verifyTableStructure(db);

      final csvFile = File(csvPath);
      if (!await csvFile.exists()) {
        debugPrint('❌ File CSV non trovato');
        await db.close();
        return 0;
      }

      // Leggi file
      String csvContent;
      try {
        csvContent = await csvFile.readAsString(encoding: utf8);
      } catch (_) {
        csvContent = await csvFile.readAsString(encoding: latin1);
      }

      // Rimuovi BOM se presente
      if (csvContent.startsWith('\uFEFF')) {
        csvContent = csvContent.substring(1);
      }

      // Processa righe
      List<String> lines = csvContent
          .replaceAll('\r\n', '\n')
          .replaceAll('\r', '\n')
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .toList();

      if (lines.isEmpty) {
        debugPrint('⚠️ File CSV vuoto');
        await db.close();
        return 0;
      }

      debugPrint('📄 Righe CSV trovate: ${lines.length}');

      // DETERMINA separatore
      final firstLine = lines[0];
      final separator = firstLine.contains(';') ? ';' : ',';
      debugPrint('🔤 Separatore rilevato: "$separator"');

      // Processa intestazioni
      List<String> headers = _parseCsvLine(firstLine, separator);
      headers = headers.map((h) => h.trim().replaceAll('"', '')).toList();

      debugPrint('📋 Colonne CSV (${headers.length}):');
      for (int i = 0; i < headers.length; i++) {
        debugPrint('   $i. "${headers[i]}"');
      }

      // Mappa delle colonne OBBLIGATORIE
      final requiredFields = {
        'titolo': ['titolo', 'Titolo', 'TITOLO', 'Title', 'Nome'],
        'volume': ['volume', 'Volume', 'VOLUME', 'Tomo'],
        'NumPag': ['NumPag', 'Pagine', 'Pages', 'NumeroPagine', 'numpag'],
        'PercResto': ['PercResto', 'Percorso', 'percorso', 'Path', 'PATH', 'File', 'NomeFile']
      };

      // Trova indici delle colonne obbligatorie
      final columnIndices = <String, int>{};
      for (final entry in requiredFields.entries) {
        final dbColumn = entry.key;
        final possibleNames = entry.value;

        int? foundIndex;
        for (int i = 0; i < headers.length; i++) {
          if (possibleNames.contains(headers[i])) {
            foundIndex = i;
            break;
          }
        }

        if (foundIndex != null) {
          columnIndices[dbColumn] = foundIndex;
          debugPrint('✅ "${dbColumn}" trovato alla colonna ${foundIndex} (${headers[foundIndex]})');
        } else {
          debugPrint('❌ "${dbColumn}" NON TROVATO! Nomi cercati: $possibleNames');
        }
      }

      // Verifica che tutte le colonne obbligatorie siano presenti
      if (columnIndices.length < requiredFields.length) {
        debugPrint('⚠️ Mancano alcune colonne obbligatorie. Verrà usato un valore di default.');
      }

      // Mappa delle colonne OPZIONALI
      final optionalFields = {
        'IdBra': ['IdBra', 'ID', 'id', 'Codice'],
        'autore': ['autore', 'Autore', 'AUTORE', 'Author', 'Compositore'],
        'strumento': ['strumento', 'Strumento', 'Instrument'],
        'PercRadice': ['PercRadice', 'PercorsoRadice', 'RootPath'],
        'PrimoLink': ['PrimoLink', 'Link', 'URL'],
        'TipoMulti': ['TipoMulti', 'TipoMultipla'],
        'TipoDocu': ['TipoDocu', 'Tipo', 'TipoDocumento'],
        'ArchivioProvenienza': ['ArchivioProvenienza', 'Archivio', 'archivio', 'Provenienza', 'Source'],
        'NumOrig': ['NumOrig', 'Originali', 'NumOriginali'],
        'IdVolume': ['IdVolume', 'IDVolume'],
        'IdAutore': ['IdAutore', 'IDAutore']
      };

      final optionalIndices = <String, int>{};
      for (final entry in optionalFields.entries) {
        final dbColumn = entry.key;
        final possibleNames = entry.value;

        for (int i = 0; i < headers.length; i++) {
          if (possibleNames.contains(headers[i])) {
            optionalIndices[dbColumn] = i;
            debugPrint('   "${dbColumn}" trovato alla colonna $i (${headers[i]})');
            break;
          }
        }
      }

      // Disabilita trigger per performance
      await _disableTriggers(db);
      await db.execute('DELETE FROM spartiti_fts');

      int importedCount = 0;
      int errorCount = 0;
      const int batchSize = 500;
      var batch = db.batch();

      debugPrint('\n🔄 Inizio importazione...');

      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        try {
          // Parsa la riga
          List<String> values = _parseCsvLine(line, separator);
          values = values.map((v) => v.trim().replaceAll('"', '')).toList();

          // Salta se non ha abbastanza valori
          if (values.length < headers.length) {
            if (errorCount < 5) {
              debugPrint('⚠️ Riga $i: Troppo pochi valori (${values.length} vs ${headers.length})');
            }
            errorCount++;
            continue;
          }

          // Crea record con valori di default
          final record = <String, dynamic>{
            'titolo': 'Senza titolo',
            'volume': 'Senza volume',
            'NumPag': 0,
            'PercResto': ''
          };

          // Imposta valori OBBLIGATORI
          if (columnIndices.containsKey('titolo') &&
              columnIndices['titolo']! < values.length &&
              values[columnIndices['titolo']!].isNotEmpty) {
            record['titolo'] = values[columnIndices['titolo']!];
          }

          if (columnIndices.containsKey('volume') &&
              columnIndices['volume']! < values.length &&
              values[columnIndices['volume']!].isNotEmpty) {
            record['volume'] = values[columnIndices['volume']!];
          }

          if (columnIndices.containsKey('NumPag') &&
              columnIndices['NumPag']! < values.length &&
              values[columnIndices['NumPag']!].isNotEmpty) {
            final numpagStr = values[columnIndices['NumPag']!];
            record['NumPag'] = int.tryParse(numpagStr) ?? 0;
          }

          if (columnIndices.containsKey('PercResto') &&
              columnIndices['PercResto']! < values.length) {
            record['PercResto'] = values[columnIndices['PercResto']!];
          }

          // Imposta valori OPZIONALI
          for (final entry in optionalIndices.entries) {
            final dbColumn = entry.key;
            final colIndex = entry.value;

            if (colIndex < values.length && values[colIndex].isNotEmpty) {
              if (dbColumn == 'NumOrig') {
                record[dbColumn] = int.tryParse(values[colIndex]) ?? 0;
              } else {
                record[dbColumn] = values[colIndex];
              }
            }
          }

          // Aggiungi al batch
          batch.insert('spartiti', record, conflictAlgorithm: ConflictAlgorithm.replace);
          importedCount++;

          // Commit batch ogni batchSize record
          if (importedCount % batchSize == 0) {
            debugPrint('📦 Commit batch di $batchSize record...');
            await batch.commit(noResult: true);
            // Reset batch
            batch = db.batch();
          }

          // Log progresso ogni 1000 record
          if (importedCount % 1000 == 0) {
            debugPrint('   Importati $importedCount record...');
          }

        } catch (e) {
          errorCount++;
          if (errorCount <= 10) {
            debugPrint('❌ Errore riga $i: ${e.toString().split('\n').first}');
          }
          continue;
        }
      }

      // Commit batch finale
      debugPrint('📦 Commit batch finale...');
      await batch.commit(noResult: true);

      // Riattiva trigger e ricostruisci FTS
      await _enableTriggers(db);
      await _rebuildFTS(db);

      // Statistiche finali
      final countAfter = await db.rawQuery('SELECT COUNT(*) as count FROM spartiti');
      final recordsAfter = countAfter.first['count'] as int? ?? 0;

      await db.close();

      debugPrint('\n✅✅✅ IMPORT CSV COMPLETATO ✅✅✅');
      debugPrint('📊 Statistiche:');
      debugPrint('   - Righe CSV: ${lines.length - 1}');
      debugPrint('   - Record importati: $importedCount');
      debugPrint('   - Record nel database: $recordsAfter');
      debugPrint('   - Errori: $errorCount');
      debugPrint('   - Successo: ${lines.length > 1 ? (importedCount / (lines.length - 1) * 100).toStringAsFixed(1) : 0}%');

      // Aggiorna conteggio nel catalogo
      await _updateCatalogCount(targetDbName, recordsAfter);

      return importedCount;

    } catch (e, stackTrace) {
      debugPrint('❌❌❌ ERRORE IMPORT CSV ❌❌❌');
      debugPrint('Errore: $e');
      debugPrint('Stack trace: $stackTrace');
      return 0;
    }
  }

  // ============================ METODI ESPORTAZIONE ============================

  String _escapeCsvField(String field) {
    if (field.isEmpty) {
      return '';
    }

    // Trim il campo
    field = field.trim();

    // Se contiene punto e virgola, virgolette o a capo, metti tra virgolette
    if (field.contains(';') ||
        field.contains('"') ||
        field.contains('\n') ||
        field.contains('\r') ||
        field.contains(',') ||
        field.startsWith(' ') ||
        field.endsWith(' ')) {

      // Sostituisci le virgolette doppie con doppie virgolette
      field = field.replaceAll('"', '""');
      return '"$field"';
    }

    return field;
  }

  void _writeCsvRow(IOSink sink, List<String> fields) {
    final escapedFields = fields.map(_escapeCsvField).toList();
    sink.write(escapedFields.join(';'));
    sink.write('\n');
  }

  // 1. ESPORTAZIONE CATALOGO COMPLETO
  Future<String?> exportFullCatalogToCsv() async {
    try {
      if (_dbCatalogoAttivo == null) {
        print('❌ Database catalogo non caricato');
        return null;
      }

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'catalogo_completo_$timestamp.csv';
      final filePath = p.join(tempDir.path, fileName);

      final file = File(filePath);
      final sink = file.openWrite(encoding: latin1);

      // HEADER con nomi colonne CORRETTI
      final headers = [
        'IdBra', 'TipoMulti', 'TipoDocu', 'titolo', 'autore',
        'strumento', 'ArchivioProvenienza', 'volume', 'NumPag',
        'NumOrig', 'PrimoLink', 'IdVolume', 'PercRadice', 'PercResto'
      ];

      // Scrivi header
      _writeCsvRow(sink, headers);

      // Query tutti i record
      final results = await _dbCatalogoAttivo!.rawQuery('''
      SELECT * FROM spartiti 
      ORDER BY LOWER(titolo), LOWER(autore), LOWER(volume), LOWER(strumento)
    ''');

      int count = 0;
      for (final row in results) {
        final csvRow = headers.map((header) {
          final value = row[header]?.toString() ?? '';
          return value;
        }).toList();

        _writeCsvRow(sink, csvRow);
        count++;

        // Progress ogni 100 record
        if (count % 100 == 0) {
          print('📊 Esportati $count record...');
        }
      }

      await sink.flush();
      await sink.close();

      print('✅ CSV esportato: $count record in $filePath');
      return filePath;
    } catch (e) {
      print('❌ Errore esportazione catalogo completo: $e');
      return null;
    }
  }

  // 2. ESPORTAZIONE PER VOLUME
  Future<String?> exportVolumeToCsv(String volume) async {
    try {
      if (_dbCatalogoAttivo == null) {
        print('❌ Database catalogo non caricato');
        return null;
      }

      final tempDir = await getTemporaryDirectory();
      final safeName = _sanitizeFileName(volume);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'volume_${safeName}_$timestamp.csv';
      final filePath = p.join(tempDir.path, fileName);

      final file = File(filePath);
      final sink = file.openWrite(encoding: latin1);

      // HEADER
      final headers = [
        'IdBra', 'TipoMulti', 'TipoDocu', 'titolo', 'autore',
        'strumento', 'ArchivioProvenienza', 'volume', 'NumPag',
        'NumOrig', 'PrimoLink', 'IdVolume', 'PercRadice', 'PercResto'
      ];

      _writeCsvRow(sink, headers);

      // Query con parametro
      final results = await _dbCatalogoAttivo!.rawQuery('''
      SELECT * FROM spartiti 
      WHERE volume LIKE ? 
      ORDER BY LOWER(titolo), LOWER(autore), LOWER(strumento)
    ''', ['%$volume%']);

      int count = 0;
      for (final row in results) {
        final csvRow = headers.map((header) {
          return row[header]?.toString() ?? '';
        }).toList();

        _writeCsvRow(sink, csvRow);
        count++;
      }

      await sink.flush();
      await sink.close();

      print('✅ CSV volume "$volume" esportato: $count record');
      return filePath;
    } catch (e) {
      print('❌ Errore esportazione volume "$volume": $e');
      return null;
    }
  }

  // 3. ESPORTAZIONE PER ARCHIVIO
  Future<String?> exportArchiveToCsv(String archivio) async {
    try {
      if (_dbCatalogoAttivo == null) {
        print('❌ Database catalogo non caricato');
        return null;
      }

      final tempDir = await getTemporaryDirectory();
      final safeName = _sanitizeFileName(archivio);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'archivio_${safeName}_$timestamp.csv';
      final filePath = p.join(tempDir.path, fileName);

      final file = File(filePath);
      final sink = file.openWrite(encoding: latin1);

      final headers = [
        'IdBra', 'TipoMulti', 'TipoDocu', 'titolo', 'autore',
        'strumento', 'ArchivioProvenienza', 'volume', 'NumPag',
        'NumOrig', 'PrimoLink', 'IdVolume', 'PercRadice', 'PercResto'
      ];

      _writeCsvRow(sink, headers);

      final results = await _dbCatalogoAttivo!.rawQuery('''
      SELECT * FROM spartiti 
      WHERE ArchivioProvenienza LIKE ? 
      ORDER BY LOWER(titolo), LOWER(volume), LOWER(strumento)
    ''', ['%$archivio%']);

      int count = 0;
      for (final row in results) {
        final csvRow = headers.map((header) {
          return row[header]?.toString() ?? '';
        }).toList();

        _writeCsvRow(sink, csvRow);
        count++;
      }

      await sink.flush();
      await sink.close();

      print('✅ CSV archivio "$archivio" esportato: $count record');
      return filePath;
    } catch (e) {
      print('❌ Errore esportazione archivio "$archivio": $e');
      return null;
    }
  }

  // 4. ESPORTAZIONE PER AUTORE
  Future<String?> exportAuthorToCsv(String autore) async {
    try {
      if (_dbCatalogoAttivo == null) {
        print('❌ Database catalogo non caricato');
        return null;
      }

      final tempDir = await getTemporaryDirectory();
      final safeName = _sanitizeFileName(autore);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'autore_${safeName}_$timestamp.csv';
      final filePath = p.join(tempDir.path, fileName);

      final file = File(filePath);
      final sink = file.openWrite(encoding: latin1);

      final headers = [
        'IdBra', 'TipoMulti', 'TipoDocu', 'titolo', 'autore',
        'strumento', 'ArchivioProvenienza', 'volume', 'NumPag',
        'NumOrig', 'PrimoLink', 'IdVolume', 'PercRadice', 'PercResto'
      ];

      _writeCsvRow(sink, headers);

      final results = await _dbCatalogoAttivo!.rawQuery('''
      SELECT * FROM spartiti 
      WHERE autore LIKE ? 
      ORDER BY LOWER(titolo), LOWER(volume), LOWER(strumento)
    ''', ['%$autore%']);

      int count = 0;
      for (final row in results) {
        final csvRow = headers.map((header) {
          return row[header]?.toString() ?? '';
        }).toList();

        _writeCsvRow(sink, csvRow);
        count++;
      }

      await sink.flush();
      await sink.close();

      print('✅ CSV autore "$autore" esportato: $count record');
      return filePath;
    } catch (e) {
      print('❌ Errore esportazione autore "$autore": $e');
      return null;
    }
  }

  // 5. ESPORTAZIONE PER STRUMENTO
  Future<String?> exportInstrumentToCsv(String strumento) async {
    try {
      if (_dbCatalogoAttivo == null) {
        print('❌ Database catalogo non caricato');
        return null;
      }

      final tempDir = await getTemporaryDirectory();
      final safeName = _sanitizeFileName(strumento);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'strumento_${safeName}_$timestamp.csv';
      final filePath = p.join(tempDir.path, fileName);

      final file = File(filePath);
      final sink = file.openWrite(encoding: latin1);

      final headers = [
        'IdBra', 'TipoMulti', 'TipoDocu', 'titolo', 'autore',
        'strumento', 'ArchivioProvenienza', 'volume', 'NumPag',
        'NumOrig', 'PrimoLink', 'IdVolume', 'PercRadice', 'PercResto'
      ];

      _writeCsvRow(sink, headers);

      final results = await _dbCatalogoAttivo!.rawQuery('''
      SELECT * FROM spartiti 
      WHERE strumento LIKE ? 
      ORDER BY LOWER(titolo), LOWER(autore), LOWER(volume)
    ''', ['%$strumento%']);

      int count = 0;
      for (final row in results) {
        final csvRow = headers.map((header) {
          return row[header]?.toString() ?? '';
        }).toList();

        _writeCsvRow(sink, csvRow);
        count++;
      }

      await sink.flush();
      await sink.close();

      print('✅ CSV strumento "$strumento" esportato: $count record');
      return filePath;
    } catch (e) {
      print('❌ Errore esportazione strumento "$strumento": $e');
      return null;
    }
  }

  // 6. ESPORTAZIONE PER ID VOLUME
  Future<String?> exportByVolumeId(String idVolume) async {
    try {
      if (_dbCatalogoAttivo == null) {
        print('❌ Database catalogo non caricato');
        return null;
      }

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'id_volume_${idVolume}_$timestamp.csv';
      final filePath = p.join(tempDir.path, fileName);

      final file = File(filePath);
      final sink = file.openWrite(encoding: latin1);

      final headers = [
        'IdBra', 'TipoMulti', 'TipoDocu', 'titolo', 'autore',
        'strumento', 'ArchivioProvenienza', 'volume', 'NumPag',
        'NumOrig', 'PrimoLink', 'IdVolume', 'PercRadice', 'PercResto'
      ];

      _writeCsvRow(sink, headers);

      final results = await _dbCatalogoAttivo!.rawQuery('''
      SELECT * FROM spartiti 
      WHERE IdVolume = ? 
      ORDER BY LOWER(titolo), LOWER(autore), LOWER(strumento)
    ''', [idVolume]);

      int count = 0;
      for (final row in results) {
        final csvRow = headers.map((header) {
          return row[header]?.toString() ?? '';
        }).toList();

        _writeCsvRow(sink, csvRow);
        count++;
      }

      await sink.flush();
      await sink.close();

      print('✅ CSV ID volume "$idVolume" esportato: $count record');
      return filePath;
    } catch (e) {
      print('❌ Errore esportazione ID volume "$idVolume": $e');
      return null;
    }
  }

  // 7. ESPORTAZIONE SOLO RECORD VOLUME
  Future<String?> exportVolumeRecordsToCsv() async {
    try {
      if (_dbCatalogoAttivo == null) {
        print('❌ Database catalogo non caricato');
        return null;
      }

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'solo_record_volume_$timestamp.csv';
      final filePath = p.join(tempDir.path, fileName);

      final file = File(filePath);
      final sink = file.openWrite(encoding: latin1);

      final headers = [
        'IdBra', 'TipoMulti', 'TipoDocu', 'titolo', 'autore',
        'strumento', 'ArchivioProvenienza', 'volume', 'NumPag',
        'NumOrig', 'PrimoLink', 'IdVolume', 'PercRadice', 'PercResto'
      ];

      _writeCsvRow(sink, headers);

      final results = await _dbCatalogoAttivo!.rawQuery('''
      SELECT * FROM spartiti 
      WHERE TipoDocu = 'volume' 
      ORDER BY LOWER(volume), LOWER(titolo)
    ''');

      int count = 0;
      for (final row in results) {
        final csvRow = headers.map((header) {
          return row[header]?.toString() ?? '';
        }).toList();

        _writeCsvRow(sink, csvRow);
        count++;
      }

      await sink.flush();
      await sink.close();

      print('✅ CSV solo record volume esportato: $count record');
      return filePath;
    } catch (e) {
      print('❌ Errore esportazione solo record volume: $e');
      return null;
    }
  }

  // 8. ESPORTAZIONE SOLO RECORD BRANI
  Future<String?> exportPieceRecordsToCsv() async {
    try {
      if (_dbCatalogoAttivo == null) {
        print('❌ Database catalogo non caricato');
        return null;
      }

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'solo_record_brani_$timestamp.csv';
      final filePath = p.join(tempDir.path, fileName);

      final file = File(filePath);
      final sink = file.openWrite(encoding: latin1);

      final headers = [
        'IdBra', 'TipoMulti', 'TipoDocu', 'titolo', 'autore',
        'strumento', 'ArchivioProvenienza', 'volume', 'NumPag',
        'NumOrig', 'PrimoLink', 'IdVolume', 'PercRadice', 'PercResto'
      ];

      _writeCsvRow(sink, headers);

      final results = await _dbCatalogoAttivo!.rawQuery('''
      SELECT * FROM spartiti 
      WHERE TipoDocu = 'brano' 
      ORDER BY LOWER(titolo), LOWER(autore), LOWER(strumento)
    ''');

      int count = 0;
      for (final row in results) {
        final csvRow = headers.map((header) {
          return row[header]?.toString() ?? '';
        }).toList();

        _writeCsvRow(sink, csvRow);
        count++;
      }

      await sink.flush();
      await sink.close();

      print('✅ CSV solo record brani esportato: $count record');
      return filePath;
    } catch (e) {
      print('❌ Errore esportazione solo record brani: $e');
      return null;
    }
  }

  // 9. ESPORTAZIONE STATISTICHE
  Future<String?> exportCatalogStatsToCsv() async {
    try {
      if (_dbCatalogoAttivo == null) {
        print('❌ Database catalogo non caricato');
        return null;
      }

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'statistiche_catalogo_$timestamp.csv';
      final filePath = p.join(tempDir.path, fileName);

      final file = File(filePath);
      final sink = file.openWrite(encoding: latin1);

      // Scrivi statistiche di base
      _writeCsvRow(sink, ['Statistica', 'Valore']);
      _writeCsvRow(sink, ['Data generazione', DateTime.now().toString()]);
      _writeCsvRow(sink, ['Catalogo', _activeCatalogDbName]);

      // Conta totale record
      final totalResult = await _dbCatalogoAttivo!.rawQuery('SELECT COUNT(*) as count FROM spartiti');
      final totalCount = totalResult.first['count'] as int;
      _writeCsvRow(sink, ['Record totali', totalCount.toString()]);

      // Conta record per tipo
      final volumeResult = await _dbCatalogoAttivo!.rawQuery('SELECT COUNT(*) as count FROM spartiti WHERE TipoDocu = "volume"');
      final volumeCount = volumeResult.first['count'] as int;
      _writeCsvRow(sink, ['Record volume', volumeCount.toString()]);

      final braniResult = await _dbCatalogoAttivo!.rawQuery('SELECT COUNT(*) as count FROM spartiti WHERE TipoDocu = "brano"');
      final braniCount = braniResult.first['count'] as int;
      _writeCsvRow(sink, ['Record brani', braniCount.toString()]);

      // Statistiche volumi distinti
      final volumiResult = await _dbCatalogoAttivo!.rawQuery('SELECT COUNT(DISTINCT volume) as count FROM spartiti WHERE volume IS NOT NULL AND volume != ""');
      final volumiCount = volumiResult.first['count'] as int;
      _writeCsvRow(sink, ['Volumi distinti', volumiCount.toString()]);

      // Statistiche autori distinti
      final autoriResult = await _dbCatalogoAttivo!.rawQuery('SELECT COUNT(DISTINCT autore) as count FROM spartiti WHERE autore IS NOT NULL AND autore != ""');
      final autoriCount = autoriResult.first['count'] as int;
      _writeCsvRow(sink, ['Autori distinti', autoriCount.toString()]);

      await sink.flush();
      await sink.close();

      print('✅ Statistiche CSV esportate');
      return filePath;
    } catch (e) {
      print('❌ Errore esportazione statistiche: $e');
      return null;
    }
  }

  // ============================ METODI HELPER ============================

  Future<void> _verifyTableStructure(Database db) async {
    try {
      final tableInfo = await db.rawQuery("PRAGMA table_info('spartiti')");
      debugPrint('🏗️ Struttura tabella spartiti:');
      for (final column in tableInfo) {
        debugPrint('   ${column['name']} (${column['type']})');
      }
    } catch (e) {
      debugPrint('⚠️ Errore verifica struttura: $e');
    }
  }

  List<String> _parseCsvLine(String line, String separator) {
    final result = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];

      if (char == '"') {
        if (i + 1 < line.length && line[i + 1] == '"') {
          // Doppie virgolette (escape)
          buffer.write('"');
          i++;
        } else {
          // Virgoletta singola
          inQuotes = !inQuotes;
        }
      } else if (char == separator && !inQuotes) {
        result.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }

    // Aggiungi ultimo campo
    result.add(buffer.toString());
    return result;
  }

  Future<void> _disableTriggers(Database db) async {
    try {
      await db.execute('DROP TRIGGER IF EXISTS spartiti_ai');
      await db.execute('DROP TRIGGER IF EXISTS spartiti_au');
      await db.execute('DROP TRIGGER IF EXISTS spartiti_ad');
      debugPrint('🔧 Trigger disabilitati');
    } catch (e) {
      debugPrint('⚠️ Errore disabilitazione trigger: $e');
    }
  }

  Future<void> _enableTriggers(Database db) async {
    try {
      await _creaTriggerFTS(db);
      debugPrint('🔧 Trigger riattivati');
    } catch (e) {
      debugPrint('⚠️ Errore abilitazione trigger: $e');
    }
  }

  Future<void> _rebuildFTS(Database db) async {
    try {
      debugPrint('🔄 Ricostruzione indice FTS...');
      await db.execute('DELETE FROM spartiti_fts');

      // Inserisci tutti i record da spartiti a spartiti_fts
      final count = await db.rawQuery('SELECT COUNT(*) as count FROM spartiti');
      final total = count.first['count'] as int? ?? 0;

      debugPrint('   Ricostruendo $total record...');

      await db.rawQuery('''
        INSERT INTO spartiti_fts(rowid, titolo, autore, volume, ArchivioProvenienza)
        SELECT IdBra, titolo, autore, volume, ArchivioProvenienza 
        FROM spartiti
      ''');

      debugPrint('✅ Indice FTS ricostruito ($total record)');
    } catch (e) {
      debugPrint('❌ Errore ricostruzione FTS: $e');
      // Tentativo alternativo
      try {
        await db.execute('INSERT INTO spartiti_fts(spartiti_fts) VALUES(\'rebuild\')');
        debugPrint('✅ Indice FTS ricostruito con comando REBUILD');
      } catch (e2) {
        debugPrint('❌ Anche il REBUILD ha fallito: $e2');
      }
    }
  }

  Future<void> _updateCatalogCount(String dbName, int count) async {
    try {
      if (_dbGlobale != null) {
        await _dbGlobale!.update(
            'elenco_cataloghi',
            {
              'conteggio_brani': count,
              'data_ultimo_aggiornamento': DateTime.now().toIso8601String()
            },
            where: 'nome_file_db = ?',
            whereArgs: [dbName]
        );
        debugPrint('📊 Conteggio catalogo aggiornato: $count brani');
      }
    } catch (e) {
      debugPrint('⚠️ Errore aggiornamento conteggio catalogo: $e');
    }
  }

  // METODO PER SANITIZZARE NOMI FILE
  String _sanitizeFileName(String name) {
    return name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
  }

  // METODI PER OTTENERE VALORI DISTINTI
  Future<List<String>> getDistinctVolumes() async {
    if (_dbCatalogoAttivo == null) return [];

    final results = await _dbCatalogoAttivo!.rawQuery(
        "SELECT DISTINCT volume FROM spartiti WHERE tipodocu = 'V' AND IdBra = IdVolume AND volume IS NOT NULL AND volume != '' ORDER BY volume"
    );
    return results.map((r) => r['volume'].toString()).toList();
  }

  Future<List<String>> getDistinctArchivi() async {
    if (_dbCatalogoAttivo == null) return [];

    final results = await _dbCatalogoAttivo!.rawQuery(
        "SELECT DISTINCT ArchivioProvenienza FROM spartiti WHERE ArchivioProvenienza IS NOT NULL AND ArchivioProvenienza != '' ORDER BY ArchivioProvenienza"
    );
    return results.map((r) => r['ArchivioProvenienza'].toString()).toList();
  }

  Future<List<String>> getDistinctAutori() async {
    if (_dbCatalogoAttivo == null) return [];

    final results = await _dbCatalogoAttivo!.rawQuery(
        "SELECT DISTINCT autore FROM spartiti WHERE autore IS NOT NULL AND autore != '' ORDER BY autore"
    );
    return results.map((r) => r['autore'].toString()).toList();
  }

  Future<List<String>> getDistinctStrumenti() async {
    if (_dbCatalogoAttivo == null) return [];

    final results = await _dbCatalogoAttivo!.rawQuery(
        "SELECT DISTINCT strumento FROM spartiti WHERE strumento IS NOT NULL AND strumento != '' ORDER BY strumento"
    );
    return results.map((r) => r['strumento'].toString()).toList();
  }

  Future<List<Map<String, dynamic>>> getVolumiWithIds() async {
    if (_dbCatalogoAttivo == null) return [];

    return await _dbCatalogoAttivo!.rawQuery(
        "SELECT DISTINCT IdVolume, volume FROM spartiti WHERE tipodocu = 'V' AND IdBra = IdVolume ORDER BY volume"
    );
  }

  // Verifica se il database è caricato
  bool get isDatabaseLoaded => _dbCatalogoAttivo != null;

  // METODI DIAGNOSTICI
  Future<int> populateCatalogFromMaster(String targetDbName) async {
    debugPrint('📚 Popolazione catalogo $targetDbName da master');

    try {
      final masterPath = p.join(_databasePath, _vecchioDbName);
      final targetPath = p.join(_databasePath, targetDbName);

      if (!await File(masterPath).exists()) {
        debugPrint('❌ Database master non trovato');
        return 0;
      }

      final masterDb = await openDatabase(masterPath, readOnly: true);
      final targetDb = await openDatabase(targetPath);

      final records = await masterDb.rawQuery('SELECT * FROM spartiti');
      int copiedCount = 0;

      await targetDb.transaction((txn) async {
        for (final record in records) {
          try {
            await txn.insert('spartiti', record);
            copiedCount++;
          } catch (_) {}
        }
      });

      await masterDb.close();
      await targetDb.close();

      debugPrint('✅ Copiati $copiedCount record dal master');
      return copiedCount;

    } catch (e) {
      debugPrint('❌ Errore popolazione da master: $e');
      return 0;
    }
  }

  Future<void> runDiagnostics() async {
    debugPrint('\n🔍 DIAGNOSTICA DATABASE SERVICE 🔍');
    debugPrint('====================================\n');

    try {
      debugPrint('📁 Percorso database: $_databasePath');
      debugPrint('🎯 Catalogo attivo: $_activeCatalogDbName');

      if (_dbGlobale != null) {
        final cataloghi = await getAvailableVolumes();
        debugPrint('📊 Cataloghi disponibili: ${cataloghi.length}');

        for (final cat in cataloghi) {
          debugPrint('  - ${cat['nome_catalogo']} (${cat['nome_file_db']}): ${cat['conteggio_brani']} brani');
        }
      }

      if (_dbCatalogoAttivo != null) {
        final ftsStatus = await getFTSStatus();
        debugPrint('\n🔍 STATO FTS:');
        debugPrint('  - Spartiti: ${ftsStatus['spartiti_count']}');
        debugPrint('  - FTS: ${ftsStatus['fts_count']}');
        debugPrint('  - Sincronizzato: ${ftsStatus['synced']}');
        debugPrint('  - Messaggio: ${ftsStatus['message']}');

        // Test ricerca rapido
        debugPrint('\n🧪 TEST RICERCA RAPIDO "a":');
        final testResults = await searchFTS('a');
        debugPrint('  - Risultati: ${testResults.length}');
      }

      debugPrint('\n✅ Diagnostica completata\n');
    } catch (e) {
      debugPrint('❌ Errore diagnostica: $e\n');
    }
  }

  Future<void> testSmallImport(String csvPath, String targetDbName, int maxRows) async {
    debugPrint('\n🧪 TEST IMPORT PICCOLO (max $maxRows righe)');

    final tempDbName = 'test_${DateTime.now().millisecondsSinceEpoch}.db';
    await createCatalogoDatabase(tempDbName);

    final result = await importFromCsv(csvPath, tempDbName);

    debugPrint('🧪 Test completato: $result record importati');

    // Pulisci
    final tempPath = p.join(_databasePath, tempDbName);
    try {
      await File(tempPath).delete();
    } catch (_) {}
  }

  Future<void> cleanupOldCsvFiles({int maxAgeHours = 24}) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final now = DateTime.now();
      final cutoff = now.subtract(Duration(hours: maxAgeHours));

      final csvFiles = Directory(tempDir.path)
          .listSync()
          .where((file) =>
      file is File &&
          file.path.toLowerCase().endsWith('.csv') &&
          file.path.toLowerCase().contains('spartiti_export_'))
          .cast<File>()
          .toList();

      int deletedCount = 0;

      for (final file in csvFiles) {
        final stat = file.statSync();
        final modified = stat.modified;

        if (modified.isBefore(cutoff)) {
          await file.delete();
          deletedCount++;
        }
      }

      if (deletedCount > 0) {
        debugPrint('🧹 Puliti $deletedCount file CSV vecchi (> $maxAgeHours ore)');
      }

    } catch (e) {
      debugPrint('⚠️ Errore pulizia file CSV: $e');
    }
  }

  Future<void> close() async {
    try {
      if (_dbCatalogoAttivo != null) {
        await _dbCatalogoAttivo!.close();
        _dbCatalogoAttivo = null;
      }
      if (_dbGlobale != null) {
        await _dbGlobale!.close();
        _dbGlobale = null;
      }
    } catch (_) {}
  }

  // ============================ NUOVI METODI PER GESTIONE CATALOGHI ============================

  Future<bool> createNewCatalog(String nomeCatalogo, String nomeFileDb, String descrizione) async {
    try {
      if (_dbGlobale == null) return false;

      final ora = DateTime.now().toIso8601String();

      // Inserisci nuovo catalogo
      final id = await _dbGlobale!.insert('elenco_cataloghi', {
        'nome_catalogo': nomeCatalogo,
        'nome_file_db': nomeFileDb,
        'descrizione': descrizione,
        'data_creazione': ora,
        'data_ultimo_aggiornamento': ora,
        'conteggio_brani': 0,
        'icona_catalogo': 'default'
      });

      if (id > 0) {
        // Crea il database fisico
        await createCatalogoDatabase(nomeFileDb);
        debugPrint('✅ Catalogo creato: $nomeCatalogo ($nomeFileDb)');
        return true;
      }
    } catch (e) {
      debugPrint('❌ Errore creazione catalogo: $e');
    }
    return false;
  }

  Future<bool> deleteCatalog(String dbName) async {
    try {
      if (_dbGlobale == null) return false;

      // Non permettere di eliminare il catalogo attivo
      if (dbName == _activeCatalogDbName) {
        debugPrint('⚠️ Non puoi eliminare il catalogo attivo');
        return false;
      }

      // Elimina dalla tabella
      final result = await _dbGlobale!.delete(
          'elenco_cataloghi',
          where: 'nome_file_db = ?',
          whereArgs: [dbName]
      );

      if (result > 0) {
        // Elimina file fisico
        final dbPath = p.join(_databasePath, dbName);
        try {
          await File(dbPath).delete();
          debugPrint('🗑️ Catalogo eliminato: $dbName');
        } catch (_) {}
        return true;
      }
    } catch (e) {
      debugPrint('❌ Errore eliminazione catalogo: $e');
    }
    return false;
  }

  Future<void> updateCatalogInfo(int id, Map<String, dynamic> updates) async {
    try {
      if (_dbGlobale != null) {
        updates['data_ultimo_aggiornamento'] = DateTime.now().toIso8601String();
        await _dbGlobale!.update(
            'elenco_cataloghi',
            updates,
            where: 'id = ?',
            whereArgs: [id]
        );
        debugPrint('📝 Catalogo aggiornato: ID $id');
      }
    } catch (e) {
      debugPrint('❌ Errore aggiornamento catalogo: $e');
    }
  }

  Future<int> getRecordCount(String dbName) async {
    try {
      final dbPath = p.join(_databasePath, dbName);
      if (await File(dbPath).exists()) {
        final db = await openDatabase(dbPath, readOnly: true);
        final result = await db.rawQuery('SELECT COUNT(*) as count FROM spartiti');
        final count = result.first['count'] as int? ?? 0;
        await db.close();
        return count;
      }
    } catch (e) {
      debugPrint('❌ Errore conteggio record: $e');
    }
    return 0;
  }
}