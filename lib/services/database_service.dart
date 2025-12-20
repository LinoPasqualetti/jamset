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
    await db.insert('DatiSistremaApp', {
      'SistemaOperativo': Platform.isAndroid ? 'Android' : 'Windows',
      'PercorsoPdf': '/storage/emulated/0/JamsetPDF/',
      'Percorsodatabase': _databasePath,
      'id_catalogo_attivo': 1
    });

    await db.insert('elenco_cataloghi', {
      'nome_catalogo': 'Catalogo Principale',
      'nome_file_db': _vecchioDbName,
      'descrizione': 'Database iniziale con spartiti di esempio',
      'data_creazione': DateTime.now().toIso8601String(),
      'data_ultimo_aggiornamento': DateTime.now().toIso8601String(),
      'conteggio_brani': 0
    });
  }

  Future<void> _verificaMigrazioneSchema(Database db) async {
    try {
      final result = await db.rawQuery(
          "PRAGMA table_info('DatiSistremaApp')"
      );

      final columns = result.map((e) => e['name'] as String).toList();

      if (!columns.contains('PercorsoPdf')) {
        await db.execute('ALTER TABLE DatiSistremaApp ADD COLUMN PercorsoPdf TEXT');
      }

      if (!columns.contains('id_catalogo_attivo')) {
        await db.execute('ALTER TABLE DatiSistremaApp ADD COLUMN id_catalogo_attivo INTEGER DEFAULT 1');
      }
    } catch (e) {
      debugPrint('Errore verifica schema: $e');
    }
  }

  Future<void> _loadConfigFromDb() async {
    if (_dbGlobale == null) return;

    try {
      final config = await _dbGlobale!.query('DatiSistremaApp', limit: 1);
      if (config.isNotEmpty) {
        _percorsoPdf = config.first['PercorsoPdf'] as String? ?? '/storage/emulated/0/JamsetPDF/';
        debugPrint('📁 Percorso PDF configurato: $_percorsoPdf');
      }

      final catalogoAttivo = await _getCurrentVolume();
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
      final catalogoAttivo = await _getCurrentVolume();
      if (catalogoAttivo.isNotEmpty) {
        final dbName = catalogoAttivo['nome_file_db'] as String?;
        if (dbName != null && dbName.isNotEmpty) {
          final dbPath = p.join(_databasePath, dbName);
          _dbCatalogoAttivo = await openDatabase(dbPath);
          _activeCatalogDbName = dbName;
          debugPrint('🎯 Catalogo attivo caricato: $dbName');
        }
      }
    } catch (e) {
      debugPrint('Errore caricamento catalogo attivo: $e');
    }
  }

  Future<Map<String, dynamic>> _getCurrentVolume() async {
    if (_dbGlobale == null) return {};

    try {
      final result = await _dbGlobale!.query(
          'DatiSistremaApp',
          columns: ['id_catalogo_attivo'],
          limit: 1
      );

      if (result.isNotEmpty) {
        final idCatalogoAttivo = result.first['id_catalogo_attivo'] as int? ?? 1;

        final catalogo = await _dbGlobale!.query(
            'elenco_cataloghi',
            where: 'id = ?',
            whereArgs: [idCatalogoAttivo]
        );

        if (catalogo.isNotEmpty) {
          return catalogo.first;
        }
      }
    } catch (e) {
      debugPrint('Errore _getCurrentVolume: $e');
    }

    return {};
  }

  Future<List<Map<String, dynamic>>> getAvailableVolumes() async {
    if (_dbGlobale == null) return [];
    return await _dbGlobale!.query('elenco_cataloghi', orderBy: 'nome_catalogo');
  }

  Future<Map<String, dynamic>> getCurrentVolume() async {
    return await _getCurrentVolume();
  }

  Future<bool> switchVolume(String dbName) async {
    try {
      final catalogo = await _dbGlobale!.query(
          'elenco_cataloghi',
          where: 'nome_file_db = ?',
          whereArgs: [dbName],
          limit: 1
      );

      if (catalogo.isNotEmpty) {
        final id = catalogo.first['id'] as int;

        await _dbGlobale!.update(
            'DatiSistremaApp',
            {'id_catalogo_attivo': id},
            where: 'id = ?',
            whereArgs: [1]
        );

        await reloadConfig();
        return true;
      }
    } catch (e) {
      debugPrint('Errore switchVolume: $e');
    }

    return false;
  }

  // ==================== LOGICA SINCRONIZZAZIONE CORRETTA ====================

  Future<void> synchronizeCatalogs() async {
    debugPrint('🔄 Sincronizzazione cataloghi...');

    if (_dbGlobale == null) return;

    try {
      final cataloghi = await _dbGlobale!.query('elenco_cataloghi');
      debugPrint('   📋 Cataloghi trovati: ${cataloghi.length}');

      for (final catalogo in cataloghi) {
        final dbName = catalogo['nome_file_db'] as String?;
        final catalogoId = catalogo['id'] as int?;
        final nomeCatalogo = catalogo['nome_catalogo'] as String?;

        if (dbName != null && dbName.isNotEmpty) {
          final dbPath = p.join(_databasePath, dbName);
          final file = File(dbPath);

          if (!await file.exists()) {
            debugPrint('   📁 Database non trovato: $nomeCatalogo ($dbName)');

            // SE IL DATABASE NON ESISTE
            if (dbName == _vecchioDbName) {
              // Per il catalogo principale: crea con trigger e copia dati
              await _creaDatabaseConTriggerECopiaDati(dbName);
            } else {
              // Per altri cataloghi: crea vuoto
              await createCatalogoDatabase(dbName);
            }
          } else {
            debugPrint('   ✓ Database esiste già: $dbName');

            // SE IL DATABASE ESISTE GIÀ
            // 1. Verifica e risincronizza FTS se necessario
            await _verificaERisincronizzaFTSSeNecessario(dbPath);

            // 2. Aggiorna conteggio brani
            await _updateBraniCount(catalogoId!, dbPath);
          }
        }
      }

      debugPrint('   ✅ Sincronizzazione completata');
    } catch (e) {
      debugPrint('   ❌ Errore nella sincronizzazione: $e');
    }
  }

  Future<void> _creaDatabaseConTriggerECopiaDati(String dbName) async {
    try {
      debugPrint('   🏗️  Creazione database con trigger attivi...');

      // 1. PRIMA crea database VUOTO con schema e trigger FTS
      await createCatalogoDatabase(dbName);

      // 2. POI copia SOLO i dati dalla tabella 'spartiti' dell'asset
      await _copiaSoloDatiSpartitiDaAsset(dbName);

      debugPrint('   ✅ Database creato, trigger attivi e dati copiati');
    } catch (e) {
      debugPrint('   ❌ Errore creazione database: $e');
      // Fallback: crea database vuoto
      await createCatalogoDatabase(dbName);
    }
  }

  Future<void> _copiaSoloDatiSpartitiDaAsset(String dbName) async {
    try {
      debugPrint('   📥 Copia dati dalla tabella spartiti dell\'asset...');

      // Carica l'asset
      final ByteData data = await rootBundle.load('assets/databases/$dbName');
      final tempPath = p.join(_databasePath, 'temp_$dbName');
      await File(tempPath).writeAsBytes(data.buffer.asUint8List());

      // Apri database temporaneo (asset) e target
      final tempDb = await openDatabase(tempPath, readOnly: true);
      final targetDbPath = p.join(_databasePath, dbName);
      final targetDb = await openDatabase(targetDbPath);

      // Leggi dati dall'asset
      final spartiti = await tempDb.rawQuery('SELECT * FROM spartiti');
      debugPrint('   📊 Record da copiare: ${spartiti.length}');

      if (spartiti.isEmpty) {
        debugPrint('   ⚠️  Nessun dato da copiare');
        return;
      }

      // Inserisci dati (i trigger FTS indicizzeranno automaticamente)
      int count = 0;
      for (final spartito in spartiti) {
        await targetDb.insert('spartiti', spartito);
        count++;

        if (count % 1000 == 0) {
          debugPrint('   📦 Copiati $count record...');
        }
      }

      // Pulisci
      await tempDb.close();
      await targetDb.close();
      await File(tempPath).delete();

      debugPrint('   ✅ $count record copiati e indicizzati automaticamente dai trigger');

    } catch (e) {
      debugPrint('   ❌ Errore copia dati: $e');
      // Se non può copiare, almeno avremo un database vuoto con trigger
    }
  }

  Future<void> _verificaERisincronizzaFTSSeNecessario(String dbPath) async {
    try {
      final db = await openDatabase(dbPath);

      // Conta record in spartiti vs spartiti_fts
      final countSpartiti = await db.rawQuery(
          'SELECT COUNT(*) as count FROM spartiti'
      );
      final countFTS = await db.rawQuery(
          'SELECT COUNT(*) as count FROM spartiti_fts'
      );

      final numSpartiti = countSpartiti.first['count'] as int? ?? 0;
      final numFTS = countFTS.first['count'] as int? ?? 0;

      await db.close();

      if (numSpartiti == numFTS) {
        debugPrint('   ✅ FTS sincronizzata ($numSpartiti record)');
      } else {
        debugPrint('   ⚠️  FTS non sincronizzata: $numSpartiti spartiti vs $numFTS in FTS');
        debugPrint('   🔄 Risincronizzazione necessaria...');

        // Risincronizza
        await _risincronizzaFTS(dbPath);
      }
    } catch (e) {
      debugPrint('   ❌ Errore verifica FTS: $e');
    }
  }

  Future<void> _risincronizzaFTS(String dbPath) async {
    try {
      final db = await openDatabase(dbPath);

      debugPrint('   🧹 Pulizia tabella FTS...');
      await db.execute('DELETE FROM spartiti_fts');

      debugPrint('   📥 Ricostruzione indice FTS...');
      final spartiti = await db.rawQuery(
          'SELECT id_univoco_globale, titolo, autore, volume, ArchivioProvenienza FROM spartiti'
      );

      int count = 0;
      for (final spartito in spartiti) {
        await db.insert('spartiti_fts', {
          'rowid': spartito['id_univoco_globale'],
          'titolo': spartito['titolo'] ?? '',
          'autore': spartito['autore'] ?? '',
          'volume': spartito['volume'] ?? '',
          'ArchivioProvenienza': spartito['ArchivioProvenienza'] ?? ''
        });
        count++;
      }

      await db.close();
      debugPrint('   ✅ $count record risincronizzati in FTS');
    } catch (e) {
      debugPrint('   ❌ Errore risincronizzazione FTS: $e');
    }
  }

  Future<void> _updateBraniCount(int catalogoId, String dbPath) async {
    try {
      final db = await openDatabase(dbPath, readOnly: true);

      final result = await db.rawQuery('SELECT COUNT(*) as count FROM spartiti');
      final count = result.first['count'] as int? ?? 0;

      await db.close();

      if (_dbGlobale != null) {
        await _dbGlobale!.update(
            'elenco_cataloghi',
            {'conteggio_brani': count},
            where: 'id = ?',
            whereArgs: [catalogoId]
        );
      }

      debugPrint('   📊 Brani nel catalogo: $count');
    } catch (e) {
      debugPrint('   ⚠️  Errore conteggio brani: $e');
    }
  }

  Future<void> createCatalogoDatabase(String dbName) async {
    debugPrint('📁 Creazione database catalogo: $dbName');
    final dbPath = p.join(_databasePath, dbName);

    try {
      final db = await openDatabase(dbPath, version: 1, onCreate: _creaSchemaCatalogo);
      await db.close();
      debugPrint('✅ Database catalogo creato con successo: $dbName');
    } catch (e) {
      debugPrint('❌ Errore creazione database $dbName: $e');
      rethrow;
    }
  }

  Future<void> _creaSchemaCatalogo(Database db, int version) async {
    debugPrint('   🏗️  Creazione schema catalogo con trigger FTS...');

    // Tabella principale spartiti
    await db.execute('''
      CREATE TABLE spartiti (
        id_univoco_globale INTEGER UNIQUE,
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
        IdAutore TEXT,
        PRIMARY KEY (id_univoco_globale AUTOINCREMENT)
      )
    ''');

    // Tabella FTS per ricerca full-text
    await db.execute('''
      CREATE VIRTUAL TABLE spartiti_fts USING fts5 (
        titolo,
        autore,
        volume,
        ArchivioProvenienza,
        content = 'spartiti',
        content_rowid = 'id_univoco_globale'
      )
    ''');

    // TRIGGER per mantenere sincronizzata la FTS
    await db.execute('''
      CREATE TRIGGER spartiti_ai AFTER INSERT ON spartiti BEGIN
        INSERT INTO spartiti_fts(rowid, titolo, autore, volume, ArchivioProvenienza)
        VALUES (new.id_univoco_globale, new.titolo, new.autore, new.volume, new.ArchivioProvenienza);
      END
    ''');

    await db.execute('''
      CREATE TRIGGER spartiti_ad AFTER DELETE ON spartiti BEGIN
        INSERT INTO spartiti_fts(spartiti_fts, rowid, titolo, autore, volume, ArchivioProvenienza)
        VALUES('delete', old.id_univoco_globale, old.titolo, old.autore, old.volume, old.ArchivioProvenienza);
      END
    ''');

    await db.execute('''
      CREATE TRIGGER spartiti_au AFTER UPDATE ON spartiti BEGIN
        INSERT INTO spartiti_fts(spartiti_fts, rowid, titolo, autore, volume, ArchivioProvenienza)
        VALUES('delete', old.id_univoco_globale, old.titolo, old.autore, old.volume, old.ArchivioProvenienza);
        INSERT INTO spartiti_fts(rowid, titolo, autore, volume, ArchivioProvenienza)
        VALUES (new.id_univoco_globale, new.titolo, new.autore, new.volume, new.ArchivioProvenienza);
      END
    ''');

    // Indici per performance
    await db.execute('CREATE INDEX IF NOT EXISTS idx_spartiti_titolo ON spartiti(titolo)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_spartiti_autore ON spartiti(autore)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_spartiti_IdBra ON spartiti(IdBra)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_spartiti_volume ON spartiti(volume)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_spartiti_strumento ON spartiti(strumento)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_spartiti_archivio ON spartiti(ArchivioProvenienza)');

    debugPrint('   ✅ Schema catalogo e trigger FTS creati');
  }

  // Metodi placeholder per compatibilità
  Future<int> importFromCsv(String csvPath, String targetDbName) async {
    debugPrint('📥 Importazione CSV da $csvPath a $targetDbName');
    return 0;
  }

  Future<int> populateCatalogFromMaster(String targetDbName) async {
    debugPrint('📚 Popolazione catalogo $targetDbName da master');
    return 0;
  }

  Future<void> risincronizzaFTSCompleta() async {
    if (_dbCatalogoAttivo == null) return;

    debugPrint('\n🔄 RISINCRONIZZAZIONE COMPLETA FTS...');

    try {
      final dbPath = p.join(_databasePath, _activeCatalogDbName);
      await _risincronizzaFTS(dbPath);
      debugPrint('🎉 Risincronizzazione completata');
    } catch (e) {
      debugPrint('❌ Errore risincronizzazione FTS: $e');
    }
  }

  Future<void> runDiagnostics() async {
    debugPrint('\n🩺 DIAGNOSTICA INIZIO');

    try {
      if (_dbGlobale == null) {
        debugPrint('   ❌ Database globale NON inizializzato');
      } else {
        debugPrint('   ✅ Database globale OK');

        final cataloghi = await getAvailableVolumes();
        debugPrint('   📊 Cataloghi presenti: ${cataloghi.length}');

        for (final catalogo in cataloghi) {
          debugPrint('      - ${catalogo['nome_catalogo']} (${catalogo['nome_file_db']}) - Brani: ${catalogo['conteggio_brani']}');
        }

        final active = await getCurrentVolume();
        debugPrint('   🎯 Catalogo attivo: ${active['nome_catalogo']} (${active['nome_file_db']})');

        if (dbCatalogoAttivo != null) {
          final tables = await dbCatalogoAttivo!.rawQuery(
              "SELECT name FROM sqlite_master WHERE type='table'"
          );
          debugPrint('   📊 Tabelle nel catalogo attivo (${tables.length}):');

          for (final table in tables.take(5)) {
            debugPrint('      - ${table['name']}');
          }
          if (tables.length > 5) {
            debugPrint('      ... e altre ${tables.length - 5} tabelle');
          }

          final countResult = await dbCatalogoAttivo!.rawQuery(
              'SELECT COUNT(*) as count FROM spartiti'
          );
          final count = countResult.first['count'] as int? ?? 0;
          debugPrint('   📈 Spartiti nel catalogo: $count');

          // Diagnostica FTS
          debugPrint('   🔍 DIAGNOSTICA TABELLA FTS:');
          final countSpartiti = await dbCatalogoAttivo!.rawQuery(
              'SELECT COUNT(*) as count FROM spartiti'
          );
          final countFTS = await dbCatalogoAttivo!.rawQuery(
              'SELECT COUNT(*) as count FROM spartiti_fts'
          );

          final numSpartiti = countSpartiti.first['count'] as int? ?? 0;
          final numFTS = countFTS.first['count'] as int? ?? 0;

          debugPrint('      📊 Record in "spartiti": $numSpartiti');
          debugPrint('      📊 Record in "spartiti_fts": $numFTS');

          if (numSpartiti == numFTS) {
            debugPrint('      ✅ Tabelle sincronizzate');
          } else {
            debugPrint('      ⚠️  DISCREPANZA: ${numSpartiti - numFTS} record non sincronizzati');
          }
        }
      }
    } catch (e) {
      debugPrint('   ❌ Errore diagnostica: $e');
    }

    debugPrint('🩺 DIAGNOSTICA FINE\n');
  }

  Future<void> close() async {
    if (_dbCatalogoAttivo != null) {
      await _dbCatalogoAttivo!.close();
    }
    if (_dbGlobale != null) {
      await _dbGlobale!.close();
    }
  }
}