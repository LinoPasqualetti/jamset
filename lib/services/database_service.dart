// lib/services/database_service.dart - CON LOGGING ESTESO
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
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
    await db.execute('''
      CREATE TABLE IF NOT EXISTS elenco_cataloghi (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome_catalogo TEXT,
        nome_file_db TEXT UNIQUE,
        descrizione TEXT,
        data_creazione TEXT,
        data_ultimo_aggiornamento TEXT,
        conteggio_brani INTEGER DEFAULT 0
      )
    ''');
  }

  Future<void> _popolaDatiGlobaliDefault(Database db) async {
    final ora = DateTime.now().toIso8601String();
    await db.insert('DatiSistremaApp', {
      'SistemaOperativo': Platform.isAndroid ? 'Android' : 'Windows',
      'PercorsoPdf': '/storage/emulated/0/JamsetPDF/',
      'Percorsodatabase': _databasePath,
      'id_catalogo_attivo': 1
    });

    await db.insert('elenco_cataloghi', {
      'nome_catalogo': 'Catalogo Principale',
      'nome_file_db': _vecchioDbName,
      'descrizione': 'Database iniziale',
      'data_creazione': ora,
      'data_ultimo_aggiornamento': ora,
      'conteggio_brani': 0
    });
  }

  Future<void> _verificaMigrazioneSchema(Database db) async {
    try {
      final resDati = await db.rawQuery("PRAGMA table_info('DatiSistremaApp')");
      final colDati = resDati.map((e) => e['name'] as String).toList();
      if (!colDati.contains('PercorsoPdf')) await db.execute('ALTER TABLE DatiSistremaApp ADD COLUMN PercorsoPdf TEXT');
      if (!colDati.contains('id_catalogo_attivo')) await db.execute('ALTER TABLE DatiSistremaApp ADD COLUMN id_catalogo_attivo INTEGER DEFAULT 1');

      final resCat = await db.rawQuery("PRAGMA table_info('elenco_cataloghi')");
      final colCat = resCat.map((e) => e['name'] as String).toList();
      if (!colCat.contains('data_creazione')) await db.execute('ALTER TABLE elenco_cataloghi ADD COLUMN data_creazione TEXT');
      if (!colCat.contains('data_ultimo_aggiornamento')) await db.execute('ALTER TABLE elenco_cataloghi ADD COLUMN data_ultimo_aggiornamento TEXT');
      if (!colCat.contains('conteggio_brani')) await db.execute('ALTER TABLE elenco_cataloghi ADD COLUMN conteggio_brani INTEGER DEFAULT 0');
    } catch (e) {
      debugPrint('⚠️ Errore migrazione: $e');
    }
  }

  Future<void> _loadConfigFromDb() async {
    if (_dbGlobale == null) return;
    try {
      final config = await _dbGlobale!.query('DatiSistremaApp', limit: 1);
      if (config.isNotEmpty) {
        _percorsoPdf = config.first['PercorsoPdf'] as String? ?? '/storage/emulated/0/JamsetPDF/';
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
          JOIN spartiti_fts f ON s.id_univoco_globale = f.rowid
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
      final res = await _dbGlobale!.query('elenco_cataloghi', where: 'nome_file_db = ?', whereArgs: [dbName], limit: 1);
      if (res.isNotEmpty) {
        await _dbGlobale!.update('DatiSistremaApp', {'id_catalogo_attivo': res.first['id']}, where: 'id = 1');
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
        id_univoco_globale INTEGER PRIMARY KEY AUTOINCREMENT,
        IdBra TEXT, 
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
        content_rowid='id_univoco_globale'
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
          VALUES (new.id_univoco_globale, new.titolo, new.autore, new.volume, new.ArchivioProvenienza);
        END
      ''');

      await db.execute('''
        CREATE TRIGGER spartiti_ad AFTER DELETE ON spartiti
        BEGIN
          INSERT INTO spartiti_fts(spartiti_fts, rowid, titolo, autore, volume, ArchivioProvenienza)
          VALUES('delete', old.id_univoco_globale, old.titolo, old.autore, old.volume, old.ArchivioProvenienza);
        END
      ''');

      await db.execute('''
        CREATE TRIGGER spartiti_au AFTER UPDATE ON spartiti
        BEGIN
          INSERT INTO spartiti_fts(spartiti_fts, rowid, titolo, autore, volume, ArchivioProvenienza)
          VALUES('delete', old.id_univoco_globale, old.titolo, old.autore, old.volume, old.ArchivioProvenienza);
          INSERT INTO spartiti_fts(rowid, titolo, autore, volume, ArchivioProvenienza)
          VALUES (new.id_univoco_globale, new.titolo, new.autore, new.volume, new.ArchivioProvenienza);
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
            'rowid': spartito['id_univoco_globale'],
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
        JOIN spartiti_fts f ON s.id_univoco_globale = f.rowid
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
          debugPrint('   ${i + 1}. ${result['titolo']} - ${result['autore']} (ID: ${result['id_univoco_globale']})');
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

  // ============================ METODI AGGIUNTI ============================

  Future<int> importFromCsv(String csvPath, String targetDbName) async {
    debugPrint('📥 Importazione CSV da $csvPath a $targetDbName');

    try {
      final dbPath = p.join(_databasePath, targetDbName);
      final db = await openDatabase(dbPath);

      final csvFile = File(csvPath);
      if (!await csvFile.exists()) {
        debugPrint('❌ File CSV non trovato');
        await db.close();
        return 0;
      }

      final lines = await csvFile.readAsLines();
      if (lines.isEmpty) {
        debugPrint('⚠️ File CSV vuoto');
        await db.close();
        return 0;
      }

      final headers = lines[0].split(',').map((h) => h.trim()).toList();
      int importedCount = 0;

      await db.transaction((txn) async {
        for (int i = 1; i < lines.length; i++) {
          final line = lines[i].trim();
          if (line.isEmpty) continue;

          final values = line.split(',').map((v) => v.trim()).toList();
          if (values.length < headers.length) continue;

          final record = <String, dynamic>{};
          for (int j = 0; j < headers.length; j++) {
            record[headers[j]] = values[j];
          }

          try {
            await txn.insert('spartiti', record);
            importedCount++;
          } catch (_) {}
        }
      });

      await db.close();

      debugPrint('✅ Importati $importedCount record da CSV');
      return importedCount;

    } catch (e) {
      debugPrint('❌ Errore importazione CSV: $e');
      return 0;
    }
  }

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
}