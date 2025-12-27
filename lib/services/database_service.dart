// lib/services/database_service.dart - CON LOGGING ESTESO
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:math' as math; // Aggiunto per math.min
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

    // Rileva il percorso di default corretto per la piattaforma (taglio a C:\ e /storage/emulated/0/)
    String defaultPath = Platform.isAndroid
        ? '/storage/emulated/0/'
        : r'C:\';

    await db.insert('DatiSistremaApp', {
      'SistemaOperativo': Platform.isAndroid ? 'Android' : 'Windows',
      'PercorsoPdf': defaultPath,
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

      // Default di emergenza basato su piattaforma (taglio)
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
      const int batchSize = 500; // Ridotto per gestione migliore
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

  // ============================ METODI ESPORTAZIONE CSV COMPLETA (SENZA LIMITI) ============================
// Metodo per analizzare l'ordinamento (rinominato per evitare conflitti)
  void _analyzeExportSorting(List<Map<String, dynamic>> results) {
    if (results.isEmpty) return;

    debugPrint('\n🔍 ANALISI ORDINAMENTO ESPORTAZIONE:');

    String? currentVolume;
    int volumeRecordCount = 0;
    int mainVolumeCount = 0;
    int otherVolumeCount = 0;
    int pieceCount = 0;
    int totalVolumes = 0;
    List<int> currentVolumePages = [];
    bool hasVolumeMainRecord = false;

    for (final row in results) {
      final volumeName = row['volume']?.toString() ?? '(senza volume)';
      final tipoDocu = row['TipoDocu']?.toString() ?? '';
      final idBra = row['IdBra']?.toString() ?? '';
      final idVolume = row['IdVolume']?.toString() ?? '';
      final numPag = row['NumPag'] is int ? row['NumPag'] as int : 0;
      final titolo = row['titolo']?.toString() ?? 'Senza titolo';

      // Se cambia volume
      if (currentVolume != volumeName) {
        if (currentVolume != null) {
          totalVolumes++;
          debugPrint('   📚 Fine volume "$currentVolume": $volumeRecordCount record');
          if (currentVolumePages.isNotEmpty) {
            debugPrint('     🎵 Ordine pagine brani: ${currentVolumePages.join(', ')}');
            bool isOrdered = true;
            for (int i = 1; i < currentVolumePages.length; i++) {
              if (currentVolumePages[i] < currentVolumePages[i - 1]) {
                isOrdered = false;
                debugPrint('     ❌ ERRORE ORDINAMENTO: Pagina ${currentVolumePages[i]} < ${currentVolumePages[i-1]}');
              }
            }
            if (isOrdered) {
              debugPrint('     ✅ Pagine in ordine crescente');
            }
          }
          if (!hasVolumeMainRecord) {
            debugPrint('     ⚠️ ATTENZIONE: Nessun record volume principale trovato!');
          }
          currentVolumePages.clear();
          hasVolumeMainRecord = false;
        }

        currentVolume = volumeName;
        volumeRecordCount = 0;
        debugPrint('   ──────────────────────────────');
        debugPrint('   📖 NUOVO VOLUME: "$volumeName"');
      }

      volumeRecordCount++;

      if (tipoDocu == 'V') {
        // Verifica se è il record volume principale (IdBra = IdVolume)
        final isMainVolume = (idBra == idVolume);
        if (isMainVolume) {
          mainVolumeCount++;
          hasVolumeMainRecord = true;
          debugPrint('     🏷️  [PRIMO] Record volume principale: "$titolo" (ID: $idBra)');
        } else {
          otherVolumeCount++;
          debugPrint('     📋 Record volume secondario: "$titolo" (ID: $idBra)');
        }
      } else {
        pieceCount++;
        debugPrint('     🎵 Brano: "$titolo" (Pagina: $numPag)');
        currentVolumePages.add(numPag);
      }
    }

    if (currentVolume != null) {
      totalVolumes++;
      debugPrint('   📚 Fine volume "$currentVolume": $volumeRecordCount record');
      if (!hasVolumeMainRecord) {
        debugPrint('     ⚠️ ATTENZIONE: Nessun record volume principale trovato!');
      }
    }

    debugPrint('\n📊 RIEPILOGO ORDINAMENTO:');
    debugPrint('   • Volumi totali: $totalVolumes');
    debugPrint('   • Record volume principale: $mainVolumeCount');
    debugPrint('   • Altri record volume: $otherVolumeCount');
    debugPrint('   • Record brani: $pieceCount');
    debugPrint('   • Totale record: ${results.length}');

    // Verifica coerenza
    if (mainVolumeCount != totalVolumes) {
      debugPrint('   ⚠️ DISCREPANZA: $mainVolumeCount record principali vs $totalVolumes volumi');
    }
  }

// Metodo per costruire il contenuto CSV
  String _buildCsvContent(
      List<Map<String, dynamic>> results,
      bool includeHeaders,
      bool includeVolumeSeparators,
      ) {
    final headers = [
      'IdBra',
      'titolo',
      'autore',
      'strumento',
      'volume',
      'PercRadice',
      'PercResto',
      'Primolink',
      'TipoMulti',
      'TipoDocu',
      'ArchivioProvenienza',
      'NumPag',
      'NumOrig',
      'IdVolume',
      'IdAutore'
    ];

    final csvBuffer = StringBuffer();
    final dataStopwatch = Stopwatch()..start();

    // Header
    if (includeHeaders) {
      csvBuffer.write(headers.join(';'));
      csvBuffer.write('\n');
    }

    // Dati
    String? currentVolume;
    int totalVolumes = 0;

    for (final row in results) {
      final volumeName = row['volume']?.toString() ?? '';

      // Aggiungi riga vuota tra volumi se richiesto
      if (includeVolumeSeparators && currentVolume != null && currentVolume != volumeName) {
        csvBuffer.write('\n');
        totalVolumes++;
      }

      if (currentVolume != volumeName) {
        currentVolume = volumeName;
      }

      final List<String> rowValues = [];

      for (final header in headers) {
        var value = row[header];

        if (value == null) {
          rowValues.add('');
        } else {
          String stringValue = value.toString();

          // Gestisci caratteri speciali CSV
          if (stringValue.contains(';') ||
              stringValue.contains('"') ||
              stringValue.contains('\n') ||
              stringValue.contains('\r')) {
            stringValue = '"${stringValue.replaceAll('"', '""')}"';
          }

          rowValues.add(stringValue);
        }
      }

      csvBuffer.write(rowValues.join(';'));
      csvBuffer.write('\n');
    }

    if (currentVolume != null) {
      totalVolumes++;
    }

    dataStopwatch.stop();
    debugPrint('📊 CSV costruito: ${results.length} record, $totalVolumes volumi');
    debugPrint('⏱️  Tempo: ${dataStopwatch.elapsedMilliseconds}ms');

    return csvBuffer.toString();
  }

// Aggiorna anche i metodi specifici per includere il nuovo parametro
  Future<String> exportFullCatalogToCsv() async {
    debugPrint('\n📤 Esportazione CATALOGO COMPLETO');
    return await exportAllToCsv(
      includeHeaders: true,
      includeVolumeSeparators: false,
    );
  }

  Future<String> exportVolumeToCsv(String volumeName) async {
    debugPrint('\n📤 Esportazione per VOLUME: "$volumeName"');
    return await exportAllToCsv(
      whereClause: 'volume LIKE ?',
      whereArgs: ['%$volumeName%'],
      includeHeaders: true,
      includeVolumeSeparators: false,
    );
  }

  Future<String> exportArchiveToCsv(String archiveName) async {
    debugPrint('\n📤 Esportazione per ARCHIVIO: "$archiveName"');
    return await exportAllToCsv(
      whereClause: 'ArchivioProvenienza = ?',
      whereArgs: [archiveName],
      includeHeaders: true,
      includeVolumeSeparators: false,
    );
  }

  Future<String> exportAuthorToCsv(String authorName) async {
    debugPrint('\n📤 Esportazione per AUTORE: "$authorName"');
    return await exportAllToCsv(
      whereClause: 'autore LIKE ?',
      whereArgs: ['%$authorName%'],
      includeHeaders: true,
      includeVolumeSeparators: false,
    );
  }

  Future<String> exportInstrumentToCsv(String instrument) async {
    debugPrint('\n📤 Esportazione per STRUMENTO: "$instrument"');
    return await exportAllToCsv(
      whereClause: 'strumento LIKE ?',
      whereArgs: ['%$instrument%'],
      includeHeaders: true,
      includeVolumeSeparators: false,
    );
  }

  Future<String> exportVolumeRecordsToCsv() async {
    debugPrint('\n📤 Esportazione RECORD VOLUME (tipodocu = V)');
    return await exportAllToCsv(
      whereClause: 'tipodocu = ?',
      whereArgs: ['V'],
      includeHeaders: true,
      includeVolumeSeparators: false,
    );
  }

  Future<String> exportAllToCsv({
    String? whereClause,
    List<dynamic>? whereArgs,
    bool includeHeaders = true,
    bool includeVolumeSeparators = false,
  }) async {
    debugPrint('\n📤 ESPORTAZIONE TUTTI I RECORD');
    debugPrint('   Where: $whereClause');
    debugPrint('   Args: $whereArgs');
    debugPrint('   Headers: $includeHeaders');
    debugPrint('   Volume separators: $includeVolumeSeparators');

    if (_dbCatalogoAttivo == null) {
      throw Exception('Database catalogo non caricato');
    }

    try {
      // Costruisci query base
      String query = 'SELECT * FROM spartiti';

      if (whereClause != null && whereClause.isNotEmpty) {
        query += ' WHERE $whereClause';
      }

      // ORDINAMENTO SEMPLICE: volume, tipodocu DESC, NumPag
      query += ' ORDER BY volume, tipodocu DESC, NumPag';

      debugPrint('📝 Query esportazione:');
      debugPrint('   SQL: $query');
      if (whereArgs != null && whereArgs.isNotEmpty) {
        debugPrint('   Parametri: $whereArgs');
      }

      // Esegui query
      final queryStopwatch = Stopwatch()..start();
      final results = await _dbCatalogoAttivo!.rawQuery(query, whereArgs);
      queryStopwatch.stop();

      debugPrint('⏱️  Tempo query: ${queryStopwatch.elapsedMilliseconds}ms');
      debugPrint('📊 Record trovati: ${results.length}');

      if (results.isEmpty) {
        debugPrint('ℹ️ Nessun record da esportare');
        return '';
      }

      // DEBUG: stampa primi 20 record per verificare ordinamento
      debugPrint('\n🧪 VERIFICA ORDINAMENTO (primi 20 record):');
      for (int i = 0; i < math.min(20, results.length); i++) {
        final row = results[i];
        final volume = row['volume'] ?? '(no volume)';
        final tipodocu = row['tipodocu'] ?? '(NULL)';
        final numpag = row['NumPag'] ?? 0;
        final titolo = (row['titolo']?.toString() ?? 'Senza titolo').substring(0, math.min(30, row['titolo']?.toString().length ?? 0));

        debugPrint('${i + 1}. Vol: "$volume" | Tipo: "$tipodocu" | Pag: $numpag | Tit: "$titolo"');
      }

      // Costruisci CSV
      final csvContent = _buildCsvContent(
        results,
        includeHeaders,
        includeVolumeSeparators,
      );

      // Salva in file temporaneo
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final csvPath = p.join(tempDir.path, 'export_completo_$timestamp.csv');

      await File(csvPath).writeAsString(csvContent, flush: true);

      debugPrint('✅ Esportazione completata: ${results.length} record');
      debugPrint('💾 File salvato: $csvPath');

      return csvPath;

    } catch (e, stackTrace) {
      debugPrint('❌❌❌ ERRORE ESPORTAZIONE COMPLETA ❌❌❌');
      debugPrint('Errore: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }
  /// Esporta i record di tipo "Brano" (tipodocu != 'V') - TUTTI i record con ordinamento per volume
  Future<String> exportPieceRecordsToCsv() async {
    debugPrint('\n📤 Esportazione RECORD BRANO (tipodocu != V)');
    return await exportAllToCsv(
      whereClause: 'tipodocu != ? OR tipodocu IS NULL',
      whereArgs: ['V'],
      includeHeaders: true,
      includeVolumeSeparators: false,
    );
  }

  Future<String> exportByVolumeId(String idVolume) async {
    debugPrint('\n📤 Esportazione per ID VOLUME: "$idVolume"');
    return await exportAllToCsv(
      whereClause: 'IdVolume = ?',
      whereArgs: [idVolume],
      includeHeaders: true,
      includeVolumeSeparators: false,
    );
  }

  Future<String> exportWithFilters({
    String? volume,
    String? archive,
    String? author,
    String? instrument,
    String? tipoDocu,
  }) async {
    debugPrint('\n📤 Esportazione con FILTRI MULTIPLI');

    final conditions = <String>[];
    final args = <dynamic>[];

    if (volume != null && volume.isNotEmpty) {
      conditions.add('volume LIKE ?');
      args.add('%$volume%');
    }

    if (archive != null && archive.isNotEmpty) {
      conditions.add('ArchivioProvenienza = ?');
      args.add(archive);
    }

    if (author != null && author.isNotEmpty) {
      conditions.add('autore LIKE ?');
      args.add('%$author%');
    }

    if (instrument != null && instrument.isNotEmpty) {
      conditions.add('strumento LIKE ?');
      args.add('%$instrument%');
    }

    if (tipoDocu != null && tipoDocu.isNotEmpty) {
      conditions.add('tipodocu = ?');
      args.add(tipoDocu);
    }

    String whereClause = conditions.isNotEmpty ? conditions.join(' AND ') : '';

    return await exportAllToCsv(
      whereClause: whereClause.isNotEmpty ? whereClause : null,
      whereArgs: args.isNotEmpty ? args : null,
      includeHeaders: true,
      includeVolumeSeparators: false,
    );
  }
  // Metodo legacy per compatibilità


// Metodo helper per export con query specifica
  Future<String> _executeCsvExport(String query, {List<dynamic>? args}) async {
    if (_dbCatalogoAttivo == null) {
      throw Exception('Database catalogo non caricato');
    }

    final results = await _dbCatalogoAttivo!.rawQuery(query, args);

    if (results.isEmpty) {
      return '';
    }

    final headers = [
      'IdBra',
      'titolo',
      'autore',
      'strumento',
      'volume',
      'PercRadice',
      'PercResto',
      'Primolink',
      'TipoMulti',
      'TipoDocu',
      'ArchivioProvenienza',
      'NumPag',
      'NumOrig',
      'IdVolume',
      'IdAutore'
    ];

    final csvBuffer = StringBuffer();
    csvBuffer.write(headers.join(';'));
    csvBuffer.write('\n');

    for (final row in results) {
      final List<String> rowValues = [];

      for (final header in headers) {
        var value = row[header];
        String stringValue = value?.toString() ?? '';

        // Gestisci caratteri speciali CSV
        if (stringValue.contains(';') ||
            stringValue.contains('"') ||
            stringValue.contains('\n') ||
            stringValue.contains('\r')) {
          stringValue = '"${stringValue.replaceAll('"', '""')}"';
        }

        rowValues.add(stringValue);
      }

      csvBuffer.write(rowValues.join(';'));
      csvBuffer.write('\n');
    }

    final csvContent = csvBuffer.toString();

    // Salva in file temporaneo
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final csvPath = p.join(tempDir.path, 'spartiti_export_$timestamp.csv');

    await File(csvPath).writeAsString(csvContent, flush: true);

    return csvPath;
  }




  // ============================ METODI ESPORTAZIONE CON PAGINAZIONE (per compatibilità) ============================

  /// Metodo legacy per export con limite (mantenuto per compatibilità)
  Future<String> exportPaginatedToCsv(int page, int pageSize) async {
    debugPrint('\n📤 Esportazione PAGINATA - Pagina $page, Size $pageSize');
    final offset = (page - 1) * pageSize;

    String query = '''
      SELECT * FROM spartiti 
      ORDER BY IdBra 
      LIMIT $pageSize OFFSET $offset
    ''';

    return await _executeCsvExport(query);
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

  // ============================ NUOVI METODI PER ESPORTAZIONE ============================

  Future<String> _exportWithQuery(String query, {List<dynamic>? args}) async {
    if (_dbCatalogoAttivo == null) {
      throw Exception('Database catalogo non caricato');
    }

    final results = await _dbCatalogoAttivo!.rawQuery(query, args);

    if (results.isEmpty) {
      return '';
    }

    final headers = [
      'IdBra',
      'titolo',
      'autore',
      'strumento',
      'volume',
      'PercRadice',
      'PercResto',
      'PrimoLink',
      'TipoMulti',
      'TipoDocu',
      'ArchivioProvenienza',
      'NumPag',
      'NumOrig',
      'IdVolume',
      'IdAutore'
    ];

    final csvBuffer = StringBuffer();
    csvBuffer.write(headers.join(';'));
    csvBuffer.write('\n');

    for (final row in results) {
      final List<String> rowValues = [];

      for (final header in headers) {
        var value = row[header];
        String stringValue = value?.toString() ?? '';

        // Gestisci caratteri speciali CSV
        if (stringValue.contains(';') ||
            stringValue.contains('"') ||
            stringValue.contains('\n') ||
            stringValue.contains('\r')) {
          stringValue = '"${stringValue.replaceAll('"', '""')}"';
        }

        rowValues.add(stringValue);
      }

      csvBuffer.write(rowValues.join(';'));
      csvBuffer.write('\n');
    }

    final csvContent = csvBuffer.toString();

    // Salva in file temporaneo
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final csvPath = p.join(tempDir.path, 'spartiti_export_$timestamp.csv');

    await File(csvPath).writeAsString(csvContent, flush: true);

    return csvPath;
  }

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

  Future<void> _debugCsvStructure(String csvPath) async {
    debugPrint('\n🔍 ANALISI STRUTTURA CSV');

    final file = File(csvPath);
    final content = await file.readAsString(encoding: latin1);
    final lines = content.split('\n');

    debugPrint('📏 Totale righe: ${lines.length}');

    if (lines.isEmpty) return;

    // Analizza prima riga (intestazioni)
    final firstLine = lines[0];
    debugPrint('📋 Prima riga (intestazioni): $firstLine');

    // Conta separatori
    final commaCount = firstLine.split(',').length - 1;
    final semicolonCount = firstLine.split(';').length - 1;
    debugPrint('🔤 Separatori: $commaCount virgole, $semicolonCount punto e virgola');

    // Analizza qualche riga dati
    for (int i = 1; i < math.min(5, lines.length); i++) {
      if (lines[i].trim().isNotEmpty) {
        debugPrint('📝 Riga $i: ${lines[i].substring(0, math.min(100, lines[i].length))}...');
      }
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
// ============================ METODO ESPORTAZIONE STATISTICHE ============================

// ============================ METODO ESPORTAZIONE STATISTICHE (OTTIMIZZATO) ============================

  Future<String> exportCatalogStatsToCsv() async {
    debugPrint('\n📊 ESPORTAZIONE STATISTICHE CATALOGO');

    if (_dbCatalogoAttivo == null) {
      throw Exception('Database catalogo non caricato');
    }

    try {
      // Query per statistiche
      final statsQueries = [
        'SELECT COUNT(*) as totale FROM spartiti',
        'SELECT COUNT(DISTINCT volume) as volumi_distinti FROM spartiti',
        'SELECT COUNT(DISTINCT autore) as autori_distinti FROM spartiti',
        'SELECT COUNT(DISTINCT ArchivioProvenienza) as archivi_distinti FROM spartiti',
        'SELECT COUNT(*) as record_volume FROM spartiti WHERE tipodocu = "V"',
        'SELECT COUNT(*) as record_brano FROM spartiti WHERE tipodocu != "V" OR tipodocu IS NULL',
      ];

      final stats = <String, dynamic>{};

      for (final query in statsQueries) {
        final result = await _dbCatalogoAttivo!.rawQuery(query);
        if (result.isNotEmpty) {
          final key = result.first.keys.first;
          stats[key] = result.first[key];
        }
      }

      // Crea CSV delle statistiche
      final csvBuffer = StringBuffer();
      csvBuffer.write('Statistica;Valore\n');

      stats.forEach((key, value) {
        csvBuffer.write('$key;$value\n');
      });

      final csvContent = csvBuffer.toString();

      // Salva in file temporaneo
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final csvPath = p.join(tempDir.path, 'catalogo_stats_$timestamp.csv');

      await File(csvPath).writeAsString(csvContent, flush: true);

      debugPrint('📊 Statistiche esportate');
      debugPrint('💾 File: $csvPath');

      return csvPath;

    } catch (e) {
      debugPrint('❌ Errore esportazione statistiche: $e');
      rethrow;
    }
  }

  Future<String> _computeCatalogStats() async {
    try {
      debugPrint('🔍 Fase 1/5: Query statistiche base...');

      // Query per statistiche principali (solo quelle essenziali)
      final essentialQueries = [
        'SELECT COUNT(*) as totale FROM spartiti',
        'SELECT COUNT(DISTINCT volume) as volumi_distinti FROM spartiti',
        'SELECT COUNT(DISTINCT autore) as autori_distinti FROM spartiti',
      ];

      final stats = <String, dynamic>{};

      // Esegui solo le query essenziali
      for (final query in essentialQueries) {
        try {
          final result = await _dbCatalogoAttivo!.rawQuery(query);
          if (result.isNotEmpty) {
            final key = result.first.keys.first;
            stats[key] = result.first[key];
          }
          debugPrint('   ✅ Query completata: $query');
        } catch (e) {
          debugPrint('   ⚠️ Errore query $query: $e');
          stats[query.contains('totale') ? 'totale' :
          query.contains('volumi') ? 'volumi_distinti' :
          'autori_distinti'] = 0;
        }
      }

      debugPrint('🔍 Fase 2/5: Statistiche tipi documento...');

      // Statistiche sui tipi di documento (semplificate)
      List<Map<String, dynamic>> tipoDocuStats = [];
      try {
        tipoDocuStats = await _dbCatalogoAttivo!.rawQuery(
            'SELECT TipoDocu, COUNT(*) as count FROM spartiti WHERE TipoDocu IS NOT NULL GROUP BY TipoDocu ORDER BY TipoDocu LIMIT 10'
        );
        debugPrint('   ✅ Statistiche TipoDocu completate');
      } catch (e) {
        debugPrint('   ⚠️ Errore statistiche TipoDocu: $e');
      }

      debugPrint('🔍 Fase 3/5: Creazione CSV...');

      // Crea CSV delle statistiche (semplificato)
      final csvBuffer = StringBuffer();

      // Intestazioni
      csvBuffer.write('REPORT STATISTICHE CATALOGO MUSICALE\n');
      csvBuffer.write('====================================\n\n');

      csvBuffer.write('STATISTICHE GENERALI\n');
      csvBuffer.write('===================\n');
      csvBuffer.write('Statistica;Valore\n');

      // Statistiche generali
      csvBuffer.write('Record totali nel catalogo;${stats['totale'] ?? 0}\n');
      csvBuffer.write('Volumi distinti;${stats['volumi_distinti'] ?? 0}\n');
      csvBuffer.write('Autori distinti;${stats['autori_distinti'] ?? 0}\n');

      // Statistiche per TipoDocu
      if (tipoDocuStats.isNotEmpty) {
        csvBuffer.write('\nDISTRIBUZIONE PER TIPODOCU\n');
        csvBuffer.write('=========================\n');
        csvBuffer.write('TipoDocu;Conteggio\n');

        for (final stat in tipoDocuStats) {
          final tipo = stat['TipoDocu']?.toString() ?? 'NULL';
          final count = stat['count'] ?? 0;
          csvBuffer.write('$tipo;$count\n');
        }
      }

      // Aggiungi metadati
      csvBuffer.write('\nMETADATI\n');
      csvBuffer.write('========\n');
      csvBuffer.write('Campo;Valore\n');
      csvBuffer.write('Data generazione report;${DateTime.now().toLocal().toString()}\n');
      csvBuffer.write('Catalogo attivo;$_activeCatalogDbName\n');

      final csvContent = csvBuffer.toString();

      debugPrint('🔍 Fase 4/5: Salvataggio file...');

      // Salva in file temporaneo
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final csvPath = p.join(tempDir.path, 'statistiche_$timestamp.csv');

      await File(csvPath).writeAsString(csvContent, flush: true);

      debugPrint('🔍 Fase 5/5: Completamento...');
      debugPrint('📊 Statistiche esportate con successo');
      debugPrint('💾 File: $csvPath');
      debugPrint('📄 Record totali: ${stats['totale'] ?? 0}');

      return csvPath;

    } catch (e, stackTrace) {
      debugPrint('❌ ERRORE CALCOLO STATISTICHE');
      debugPrint('Errore: $e');
      debugPrint('Stack: $stackTrace');
      rethrow;
    }
  }

  Future<String> _createStatsFallbackFile(String errorMessage) async {
    debugPrint('🔄 Creazione file di fallback...');

    final csvBuffer = StringBuffer();
    csvBuffer.write('REPORT STATISTICHE CATALOGO - ERRORE\n');
    csvBuffer.write('===================================\n\n');
    csvBuffer.write('⚠️ Impossibile generare statistiche complete\n\n');
    csvBuffer.write('Informazioni disponibili:\n');
    csvBuffer.write('========================\n');
    csvBuffer.write('Messaggio errore;$errorMessage\n');
    csvBuffer.write('Data;${DateTime.now().toLocal().toString()}\n');
    csvBuffer.write('Catalogo;$_activeCatalogDbName\n');

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final csvPath = p.join(tempDir.path, 'statistiche_errore_$timestamp.csv');

    await File(csvPath).writeAsString(csvBuffer.toString(), flush: true);

    debugPrint('💾 File fallback creato: $csvPath');
    return csvPath;
  }


  // ============================ METODO PER ELIMINARE FILE CSV VECCHI ============================

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
}