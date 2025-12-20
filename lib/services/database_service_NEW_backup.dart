import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

String gDatabasePath = '';
String gPercorsoPdf = '';
String gActiveCatalogDbName = '';

class DatabaseService with ChangeNotifier {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? dbGlobale;
  Database? dbCatalogoAttivo;
  String _activeCatalogDbName = '';

  // Proprietà pubbliche
  String get percorsoPdf => gPercorsoPdf;
  String get databasePath => gDatabasePath;
  String get activeCatalogDbName => _activeCatalogDbName;

  Future<void> initialize() async {
    debugPrint('🚀 INIZIALIZZAZIONE DATABASE SERVICE...');

    try {
      if (!kIsWeb) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      }

      final directory = await getApplicationDocumentsDirectory();
      gDatabasePath = directory.path;

      final dbPath = join(gDatabasePath, 'DBGlobale.db');
      debugPrint('📁 Percorso database: $dbPath');

      dbGlobale = await openDatabase(
        dbPath,
        version: 1,
        onCreate: _onCreateGlobale,
      );

      // Carica configurazioni
      await _loadConfig();

      // Sincronizza cataloghi
      await synchronizeCatalogs();

      // Carica catalogo attivo
      await _loadActiveCatalog();

      // Verifica VecchioDb.db
      final vecchioDbPath = join(gDatabasePath, 'VecchioDb.db');
      final file = File(vecchioDbPath);

      if (await file.exists()) {
        final fileSize = await file.length();
        debugPrint('✅ VecchioDb.db copiato correttamente');
        debugPrint('📏 Dimensione: $fileSize bytes');

        final db = await openDatabase(vecchioDbPath, readOnly: true);
        final tables = await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='spartiti'"
        );
        final countResult = await db.rawQuery('SELECT COUNT(*) as count FROM spartiti');
        final count = countResult.first['count'] as int? ?? 0;
        await db.close();

        debugPrint('📊 Tabelle spartiti esiste: ${tables.isNotEmpty}');
        debugPrint('🎵 Spartiti nel database: $count');
      } else {
        debugPrint('❌ ERRORE: VecchioDb.db non copiato!');
      }

      debugPrint('✅ DATABASE SERVICE INIZIALIZZATO CON SUCCESSO.');

    } catch (e) {
      debugPrint('❌ Errore inizializzazione: $e');
      rethrow;
    }
  }

  Future<void> _loadConfig() async {
    try {
      final config = await dbGlobale!.query('DatiSistremaApp', limit: 1);
      if (config.isNotEmpty) {
        gPercorsoPdf = config.first['percorso_pdf'] as String? ?? '';
        debugPrint('📁 Percorso PDF configurato: $gPercorsoPdf');
      }
    } catch (e) {
      debugPrint('⚠️ Errore caricamento configurazione: $e');
    }
  }

  Future<void> _loadActiveCatalog() async {
    try {
      final result = await dbGlobale!.query(
          'DatiSistremaApp',
          columns: ['id_catalogo_attivo'],
          limit: 1
      );

      if (result.isNotEmpty) {
        final idCatalogoAttivo = result.first['id_catalogo_attivo'] as int? ?? 1;

        final catalogo = await dbGlobale!.query(
            'elenco_cataloghi',
            where: 'id = ?',
            whereArgs: [idCatalogoAttivo]
        );

        if (catalogo.isNotEmpty) {
          final dbName = catalogo.first['nome_file_db'] as String?;
          if (dbName != null && dbName.isNotEmpty) {
            _activeCatalogDbName = dbName;
            gActiveCatalogDbName = dbName;

            final dbPath = join(gDatabasePath, dbName);
            dbCatalogoAttivo = await openDatabase(dbPath);

            debugPrint('🎯 Catalogo attivo caricato: $dbName');
          }
        }
      }
    } catch (e) {
      debugPrint('Errore nel caricamento catalogo attivo: $e');
    }
  }

  Future<void> reloadConfig() async {
    await _loadConfig();
    await _loadActiveCatalog();
    notifyListeners();
  }

  // Metodo per eseguire diagnostica
  Future<void> runDiagnostics() async {
    debugPrint('\n🩺 DIAGNOSTICA INIZIO');

    try {
      // Verifica database globale
      if (dbGlobale == null) {
        debugPrint('   ❌ Database globale NON inizializzato');
      } else {
        debugPrint('   ✅ Database globale OK');

        // Conta cataloghi
        final cataloghi = await dbGlobale!.query('elenco_cataloghi');
        debugPrint('   📊 Cataloghi presenti: ${cataloghi.length}');

        for (final catalogo in cataloghi) {
          debugPrint('      - ${catalogo['nome_catalogo']} (${catalogo['nome_file_db']}) - Brani: ${catalogo['conteggio_brani']}');
        }

        // Catalogo attivo
        final active = await getCurrentVolume();
        debugPrint('   🎯 Catalogo attivo: ${active['nome_catalogo']} (${active['nome_file_db']})');

        // Verifica catalogo attivo
        if (dbCatalogoAttivo != null) {
          final tables = await dbCatalogoAttivo!.rawQuery(
              "SELECT name FROM sqlite_master WHERE type='table'"
          );
          debugPrint('   📊 Tabelle nel catalogo attivo (${tables.length}):');

          for (final table in tables) {
            debugPrint('      - ${table['name']}');
          }

          // Conta spartiti
          final countResult = await dbCatalogoAttivo!.rawQuery(
              'SELECT COUNT(*) as count FROM spartiti'
          );
          final count = countResult.first['count'] as int? ?? 0;
          debugPrint('   📈 Spartiti nel catalogo: $count');

          // Conta FTS
          final ftsCount = await dbCatalogoAttivo!.rawQuery(
              'SELECT COUNT(*) as count FROM spartiti_fts'
          );
          final fts = ftsCount.first['count'] as int? ?? 0;
          debugPrint('   🔍 Record nell\'indice FTS: $fts');
        }
      }
    } catch (e) {
      debugPrint('   ❌ Errore diagnostica: $e');
    }

    debugPrint('🩺 DIAGNOSTICA FINE\n');
  }

  Future<Map<String, dynamic>> getCurrentVolume() async {
    if (dbGlobale == null) return {};

    try {
      final result = await dbGlobale!.query(
          'DatiSistremaApp',
          columns: ['id_catalogo_attivo'],
          limit: 1
      );

      if (result.isNotEmpty) {
        final idCatalogoAttivo = result.first['id_catalogo_attivo'] as int? ?? 1;

        final catalogo = await dbGlobale!.query(
            'elenco_cataloghi',
            where: 'id = ?',
            whereArgs: [idCatalogoAttivo]
        );

        if (catalogo.isNotEmpty) {
          return catalogo.first;
        }
      }
    } catch (e) {
      debugPrint('Errore getCurrentVolume: $e');
    }

    return {};
  }

  Future<List<Map<String, dynamic>>> getAvailableVolumes() async {
    if (dbGlobale == null) return [];
    return await dbGlobale!.query('elenco_cataloghi', orderBy: 'nome_catalogo');
  }

  Future<bool> switchVolume(String dbName) async {
    try {
      // Trova l'ID del catalogo con quel nome file
      final catalogo = await dbGlobale!.query(
          'elenco_cataloghi',
          where: 'nome_file_db = ?',
          whereArgs: [dbName],
          limit: 1
      );

      if (catalogo.isNotEmpty) {
        final id = catalogo.first['id'] as int;

        // Aggiorna il catalogo attivo
        await dbGlobale!.update(
            'DatiSistremaApp',
            {'id_catalogo_attivo': id},
            where: 'id = ?',
            whereArgs: [1]
        );

        // Ricarica il catalogo attivo
        await reloadConfig();

        return true;
      }
    } catch (e) {
      debugPrint('Errore switchVolume: $e');
    }

    return false;
  }

  // Metodo per importare dati da CSV (placeholder)
  Future<int> importFromCsv(String csvPath, String targetDbName) async {
    debugPrint('📥 Importazione CSV da $csvPath a $targetDbName');

    // Questo è un placeholder - implementa la logica di importazione CSV
    // Leggi il file CSV e importa i dati nel database

    // Per ora restituisce 0
    return 0;
  }

  // Metodo per popolare un catalogo dal master (placeholder)
  Future<int> populateCatalogFromMaster(String targetDbName) async {
    debugPrint('📚 Popolazione catalogo $targetDbName da master');

    try {
      // Apri il database target
      final targetPath = join(gDatabasePath, targetDbName);
      final targetDb = await openDatabase(targetPath);

      // Apri il database master (VecchioDb.db)
      final masterPath = join(gDatabasePath, 'VecchioDb.db');
      final masterDb = await openDatabase(masterPath, readOnly: true);

      // Copia i dati (esempio)
      final spartiti = await masterDb.query('spartiti', limit: 100); // Limite per test

      int count = 0;
      for (final spartito in spartiti) {
        await targetDb.insert('spartiti', spartito, conflictAlgorithm: ConflictAlgorithm.replace);
        count++;
      }

      await targetDb.close();
      await masterDb.close();

      debugPrint('✅ Importati $count spartiti');
      return count;
    } catch (e) {
      debugPrint('❌ Errore popolazione catalogo: $e');
      return 0;
    }
  }

  // Metodi per la sincronizzazione (già presenti)
  Future<void> synchronizeCatalogs() async {
    debugPrint('🔄 Sincronizzazione cataloghi...');

    if (dbGlobale == null) return;

    try {
      final cataloghi = await dbGlobale!.query('elenco_cataloghi');
      debugPrint('   📋 Cataloghi trovati: ${cataloghi.length}');

      for (final catalogo in cataloghi) {
        final dbName = catalogo['nome_file_db'] as String?;
        final catalogoId = catalogo['id'] as int?;
        final nomeCatalogo = catalogo['nome_catalogo'] as String?;

        if (dbName != null && dbName.isNotEmpty) {
          final dbPath = join(gDatabasePath, dbName);
          final file = File(dbPath);

          if (!await file.exists()) {
            debugPrint('   📁 Database non trovato: $nomeCatalogo ($dbName)');

            try {
              if (await _assetExists('assets/databases/$dbName')) {
                debugPrint('   📦 Copia database dall\'asset: $dbName');
                await _copyAssetDatabase(dbName);

                await _updateBraniCount(catalogoId!, dbPath);

                debugPrint('   ✅ Database copiato dall\'asset: $nomeCatalogo');
              } else {
                debugPrint('   🆕 Creazione nuovo database: $dbName');
                await createCatalogoDatabase(dbName);

                await dbGlobale!.update(
                    'elenco_cataloghi',
                    {'conteggio_brani': 0},
                    where: 'id = ?',
                    whereArgs: [catalogoId]
                );

                debugPrint('   ✅ Nuovo database creato: $nomeCatalogo');
              }
            } catch (e) {
              debugPrint('   ❌ Errore gestione database $dbName: $e');
              await createCatalogoDatabase(dbName);
            }
          } else {
            debugPrint('   ✓ Database esiste già: $dbName');

            try {
              await _updateBraniCount(catalogoId!, dbPath);
            } catch (e) {
              debugPrint('   ⚠️ Errore aggiornamento conteggio brani: $e');
            }
          }
        }
      }

      debugPrint('   ✅ Sincronizzazione completata');
    } catch (e) {
      debugPrint('   ❌ Errore nella sincronizzazione: $e');
    }
  }

  Future<bool> _assetExists(String assetPath) async {
    try {
      await rootBundle.load(assetPath);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _copyAssetDatabase(String dbName) async {
    try {
      debugPrint('   📦 Copia database dall\'asset: $dbName');

      final dbPath = join(gDatabasePath, dbName);

      final ByteData data = await rootBundle.load('assets/databases/$dbName');
      final List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

      final directory = Directory(gDatabasePath);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      await File(dbPath).writeAsBytes(bytes, flush: true);

      debugPrint('   ✅ Database copiato con successo');
      debugPrint('   📍 Percorso: $dbPath');
      debugPrint('   📏 Dimensione: ${bytes.length} bytes');

    } catch (e) {
      debugPrint('   ❌ Errore nella copia del database: $e');
      rethrow;
    }
  }

  Future<void> _updateBraniCount(int catalogoId, String dbPath) async {
    try {
      final db = await openDatabase(dbPath, readOnly: true);

      final result = await db.rawQuery('SELECT COUNT(*) as count FROM spartiti');
      final count = result.first['count'] as int? ?? 0;

      await db.close();

      if (dbGlobale != null) {
        await dbGlobale!.update(
            'elenco_cataloghi',
            {'conteggio_brani': count},
            where: 'id = ?',
            whereArgs: [catalogoId]
        );
      }

      debugPrint('   📊 Brani nel catalogo: $count');
    } catch (e) {
      debugPrint('   ⚠️ Errore nel conteggio brani: $e');
      if (dbGlobale != null) {
        await dbGlobale!.update(
            'elenco_cataloghi',
            {'conteggio_brani': 0},
            where: 'id = ?',
            whereArgs: [catalogoId]
        );
      }
    }
  }

  Future<void> createCatalogoDatabase(String dbName) async {
    debugPrint('📁 Creazione database catalogo: $dbName');
    final dbPath = join(gDatabasePath, dbName);

    try {
      final db = await openDatabase(dbPath, version: 1, onCreate: _onCreateCatalogo);
      await db.close();
      debugPrint('✅ Database catalogo creato con successo: $dbName');
    } catch (e) {
      debugPrint('❌ Errore nella creazione database $dbName: $e');
      rethrow;
    }
  }

  Future<void> _onCreateGlobale(Database db, int version) async {
    debugPrint('🏗️ Creazione schema database globale...');

    await db.execute('''
      CREATE TABLE DatiSistremaApp (
        id INTEGER PRIMARY KEY,
        app_version TEXT,
        data_installazione TEXT,
        ultimo_avvio TEXT,
        id_catalogo_attivo INTEGER DEFAULT 1,
        percorso_pdf TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE elenco_cataloghi (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome_catalogo TEXT NOT NULL,
        descrizione TEXT,
        nome_file_db TEXT NOT NULL,
        data_creazione TEXT,
        data_ultimo_aggiornamento TEXT,
        conteggio_brani INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      INSERT INTO DatiSistremaApp (
        id, app_version, data_installazione, ultimo_avvio, id_catalogo_attivo, percorso_pdf
      ) VALUES (
        1, '1.0.0', '${DateTime.now().toIso8601String()}', 
        '${DateTime.now().toIso8601String()}', 1, ''
      )
    ''');

    await db.execute('''
      INSERT INTO elenco_cataloghi (
        nome_catalogo, descrizione, nome_file_db, data_creazione, 
        data_ultimo_aggiornamento, conteggio_brani
      ) VALUES (
        'Catalogo Principale', 'Database iniziale con spartiti di esempio', 
        'VecchioDb.db', '${DateTime.now().toIso8601String()}',
        '${DateTime.now().toIso8601String()}', 0
      )
    ''');

    debugPrint('✅ Schema globale creato');
  }

  Future<void> _onCreateCatalogo(Database db, int version) async {
    debugPrint('📁 Creazione struttura database catalogo...');

    try {
      await _creaTabellaSpartiti(db);
      debugPrint('   ✅ Tabella "spartiti" creata');

      await _creaTabellaFTS(db);
      debugPrint('   ✅ Tabella FTS "spartiti_fts" creata');

      await _creaTriggerFTS(db);
      debugPrint('   ✅ Trigger FTS creati');

      await _creaIndici(db);
      debugPrint('   ✅ Indici creati');

      debugPrint('🎉 Database catalogo creato con successo!');
    } catch (e) {
      debugPrint('❌ Errore nella creazione del database catalogo: $e');
      rethrow;
    }
  }

  Future<void> _creaTabellaSpartiti(Database db) async {
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
  }

  Future<void> _creaTabellaFTS(Database db) async {
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
  }

  Future<void> _creaTriggerFTS(Database db) async {
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
  }

  Future<void> _creaIndici(Database db) async {
    await db.execute('CREATE INDEX IF NOT EXISTS idx_spartiti_titolo ON spartiti(titolo)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_spartiti_autore ON spartiti(autore)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_spartiti_IdBra ON spartiti(IdBra)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_spartiti_volume ON spartiti(volume)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_spartiti_strumento ON spartiti(strumento)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_spartiti_archivio ON spartiti(ArchivioProvenienza)');
  }

  Future<int> getConteggioSpartiti(int catalogoId) async {
    if (dbGlobale == null) return 0;

    try {
      final catalogo = await dbGlobale!.query(
          'elenco_cataloghi',
          where: 'id = ?',
          whereArgs: [catalogoId]
      );

      if (catalogo.isNotEmpty) {
        final dbName = catalogo.first['nome_file_db'] as String?;
        if (dbName != null && dbName.isNotEmpty) {
          final dbPath = join(gDatabasePath, dbName);
          final db = await openDatabase(dbPath, readOnly: true);

          final result = await db.rawQuery('SELECT COUNT(*) as count FROM spartiti');
          final count = result.first['count'] as int? ?? 0;

          await db.close();
          return count;
        }
      }
    } catch (e) {
      debugPrint('Errore conteggio spartiti: $e');
    }

    return 0;
  }

  Future<void> updateConteggioBrani(int catalogoId, int conteggio) async {
    if (dbGlobale == null) return;

    await dbGlobale!.update(
        'elenco_cataloghi',
        {'conteggio_brani': conteggio, 'data_ultimo_aggiornamento': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [catalogoId]
    );
  }

  Future<void> close() async {
    if (dbCatalogoAttivo != null) {
      await dbCatalogoAttivo!.close();
    }
    if (dbGlobale != null) {
      await dbGlobale!.close();
    }
  }
}