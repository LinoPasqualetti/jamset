import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService {
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
    final percorsoDefault = await _getDefaultPdfPath();
    final ora = DateTime.now().toIso8601String();
    
    await db.insert('DatiSistremaApp', {
      'SistemaOperativo': Platform.operatingSystem,
      'PercorsoPdf': percorsoDefault,
      'Percorsodatabase': _databasePath,
      'id_catalogo_attivo': 1,
    });
    
    await db.insert('elenco_cataloghi', {
      'id': 1,
      'nome_catalogo': 'Catalogo Principale',
      'nome_file_db': _vecchioDbName,
      'descrizione': 'Catalogo predefinito importato da asset',
      'data_creazione': ora,
      'data_ultimo_aggiornamento': ora,
      'conteggio_brani': 0
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _verificaMigrazioneSchema(Database db) async {
    try {
      final columns = await db.rawQuery('PRAGMA table_info(elenco_cataloghi)');
      if (!columns.any((col) => col['name'] == 'data_creazione')) {
        await db.execute('ALTER TABLE elenco_cataloghi ADD COLUMN data_creazione TEXT');
      }
      if (!columns.any((col) => col['name'] == 'data_ultimo_aggiornamento')) {
        await db.execute('ALTER TABLE elenco_cataloghi ADD COLUMN data_ultimo_aggiornamento TEXT');
      }
      if (!columns.any((col) => col['name'] == 'conteggio_brani')) {
        await db.execute('ALTER TABLE elenco_cataloghi ADD COLUMN conteggio_brani INTEGER DEFAULT 0');
      }
    } catch (_) {}
  }

  Future<void> createCatalogoDatabase(String dbName) async {
    final dbPath = p.join(_databasePath, dbName);
    if (await databaseExists(dbPath)) return;

    final db = await openDatabase(dbPath, version: 1, onCreate: (db, v) async {
      await db.execute('''
        CREATE TABLE spartiti (
          id_univoco_globale INTEGER PRIMARY KEY AUTOINCREMENT,
          IdBra TEXT UNIQUE,
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
      await _creaIndiciFTS(db);
    });
    await db.close();
  }

  Future<void> _creaIndiciFTS(Database db) async {
    await db.execute("DROP TABLE IF EXISTS spartiti_fts");
    await db.execute("CREATE VIRTUAL TABLE spartiti_fts USING fts5 (titolo, autore, volume, ArchivioProvenienza, content = 'spartiti', content_rowid = 'id_univoco_globale')");
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS spartiti_ai AFTER INSERT ON spartiti BEGIN
        INSERT INTO spartiti_fts(rowid, titolo, autore, volume, ArchivioProvenienza)
        VALUES (new.id_univoco_globale, new.titolo, new.autore, new.volume, new.ArchivioProvenienza);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS spartiti_ad AFTER DELETE ON spartiti BEGIN
        INSERT INTO spartiti_fts(spartiti_fts, rowid, titolo, autore, volume, ArchivioProvenienza)
        VALUES('delete', old.id_univoco_globale, old.titolo, old.autore, old.volume, old.ArchivioProvenienza);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS spartiti_au AFTER UPDATE ON spartiti BEGIN
        INSERT INTO spartiti_fts(spartiti_fts, rowid, titolo, autore, volume, ArchivioProvenienza)
        VALUES('delete', old.id_univoco_globale, old.titolo, old.autore, old.volume, old.ArchivioProvenienza);
        INSERT INTO spartiti_fts(rowid, titolo, autore, volume, ArchivioProvenienza)
        VALUES (new.id_univoco_globale, new.titolo, new.autore, new.volume, new.ArchivioProvenienza);
      END
    ''');
  }

  /// Metodo pubblico per popolare un catalogo dai dati dell'asset master
  Future<int> populateCatalogFromMaster(String dbName) async {
    final targetPath = p.join(_databasePath, dbName);
    final db = await openDatabase(targetPath);
    try {
      final count = await _importaDatiDaAsset(db, _vecchioDbName);
      
      // Aggiorna il conteggio nel DB globale
      if (_dbGlobale != null) {
        await _dbGlobale!.update(
          'elenco_cataloghi', 
          {'conteggio_brani': count, 'data_ultimo_aggiornamento': DateTime.now().toIso8601String()},
          where: 'nome_file_db = ?',
          whereArgs: [dbName]
        );
      }
      return count;
    } finally {
      await db.close();
    }
  }

  Future<int> _importaDatiDaAsset(Database db, String assetName) async {
    final ByteData data = await rootBundle.load('assets/databases/$assetName');
    final tempPath = p.join((await getTemporaryDirectory()).path, "temp_master.db");
    await File(tempPath).writeAsBytes(data.buffer.asUint8List(), flush: true);

    Database? masterDb;
    int imported = 0;
    try {
      masterDb = await openReadOnlyDatabase(tempPath);
      final sourceTable = Platform.isWindows ? 'spartiti' : 'spartiti_andr';
      final dataToInsert = await masterDb.query(sourceTable);

      if (dataToInsert.isNotEmpty) {
        await db.transaction((txn) async {
          final batch = txn.batch();
          for (final row in dataToInsert) {
            final rowCopy = Map<String, dynamic>.from(row);
            rowCopy.remove('id_univoco_globale');
            batch.insert('spartiti', rowCopy, conflictAlgorithm: ConflictAlgorithm.replace);
          }
          await batch.commit(noResult: true);
        });
        imported = dataToInsert.length;
      }
    } finally {
      await masterDb?.close();
      await File(tempPath).delete();
    }
    return imported;
  }

  Future<void> synchronizeCatalogs() async {
    if (_dbGlobale == null) return;
    final cataloghi = await _dbGlobale!.query('elenco_cataloghi');
    for (final c in cataloghi) {
      final name = c['nome_file_db'] as String?;
      if (name != null && name.isNotEmpty) {
        final path = p.join(_databasePath, name);
        if (!await File(path).exists()) await createCatalogoDatabase(name);
      }
    }
  }

  Future<void> _loadConfigFromDb() async {
    if (_dbGlobale == null) return;
    final dati = await _dbGlobale!.query('DatiSistremaApp', limit: 1);
    if (dati.isEmpty) return;

    final riga = dati.first;
    _percorsoPdf = (riga['PercorsoPdf'] as String? ?? '').trim();
    if (_percorsoPdf.isEmpty) {
      _percorsoPdf = await _getDefaultPdfPath();
      await _dbGlobale!.update('DatiSistremaApp', {'PercorsoPdf': _percorsoPdf}, where: 'id = 1');
    }

    final idAttivo = riga['id_catalogo_attivo'] as int? ?? 1;
    final info = await _dbGlobale!.query('elenco_cataloghi', where: 'id = ?', whereArgs: [idAttivo], limit: 1);
    if (info.isNotEmpty) {
      _activeCatalogDbName = info.first['nome_file_db'] as String? ?? '';
      final path = p.join(_databasePath, _activeCatalogDbName);
      await _dbCatalogoAttivo?.close();
      _dbCatalogoAttivo = await openDatabase(path);
      await _verificaESincronizzaFTS(_dbCatalogoAttivo!);
    }
  }

  Future<void> _verificaESincronizzaFTS(Database db) async {
    try {
      final s = (await db.rawQuery("SELECT COUNT(*) as c FROM spartiti")).first['c'] as int? ?? 0;
      final f = (await db.rawQuery("SELECT COUNT(*) as c FROM spartiti_fts")).first['c'] as int? ?? 0;
      if (s != f) await db.execute("INSERT INTO spartiti_fts(spartiti_fts) VALUES('rebuild');");
    } catch (_) {
      await _creaIndiciFTS(db);
    }
  }

  Future<String> _getDefaultPdfPath() async {
    if (Platform.isAndroid) return '/storage/emulated/0/JamsetPDF/';
    if (Platform.isWindows) return r'C:\JamsetPDF\';
    return p.join((await getApplicationSupportDirectory()).path, 'JamsetPDF');
  }

  bool _isPathInvalidForCurrentPlatform(String? path) => path == null || path.isEmpty;

  Future<Map<String, dynamic>> getCurrentVolume() async {
    if (_dbGlobale == null) return {};
    final id = (await _dbGlobale!.query('DatiSistremaApp', limit: 1)).first['id_catalogo_attivo'] as int? ?? 1;
    final res = await _dbGlobale!.query('elenco_cataloghi', where: 'id = ?', whereArgs: [id], limit: 1);
    return res.isNotEmpty ? res.first : {};
  }

  Future<List<Map<String, dynamic>>> getAvailableVolumes() async {
    if (_dbGlobale == null) return [];
    return await _dbGlobale!.query('elenco_cataloghi', orderBy: 'nome_catalogo');
  }

  Future<bool> switchVolume(String dbFileName) async {
    if (_dbGlobale == null) return false;
    final res = await _dbGlobale!.query('elenco_cataloghi', where: 'nome_file_db = ?', whereArgs: [dbFileName], limit: 1);
    if (res.isEmpty) return false;
    await _dbGlobale!.update('DatiSistremaApp', {'id_catalogo_attivo': res.first['id']}, where: 'id = 1');
    await reloadConfig();
    return true;
  }

  Future<void> runDiagnostics() async {
     debugPrint("🩺 Diagnostica attiva");
  }
}
