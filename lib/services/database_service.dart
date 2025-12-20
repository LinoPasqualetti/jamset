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
    _databasePath = supportDir.path; // CORREZIONE: Usa direttamente la cartella di supporto
    await Directory(_databasePath).create(recursive: true);
    final path = p.join(_databasePath, _dbGlobaleName);

    _dbGlobale = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        debugPrint("🔧 Creazione DB Globale da zero (onCreate)...");
        await _creaSchemaDbGlobale(db);
        await _popolaDatiGlobaliDefault(db);
      },
      onOpen: (db) async {
        await _verificaMigrazioneSchema(db);
      },
    );

    await _loadConfigFromDb();
    debugPrint("✅ Inizializzazione DatabaseService completata.");
  }

  Future<void> reloadConfig() async {
    debugPrint("🔄 Ricaricamento configurazione dal database...");
    await _loadConfigFromDb();
    debugPrint("✅ Ricaricamento completato.");
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
        descrizione TEXT
      )
    ''');
  }

  Future<void> _popolaDatiGlobaliDefault(Database db) async {
    final percorsoDefault = await _getDefaultPdfPath();
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
      'descrizione': 'Catalogo predefinito da importare'
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    debugPrint("✅ DB Globale popolato con valori di sistema e catalogo di bootstrap.");
  }

  Future<void> _verificaMigrazioneSchema(Database db) async {
    try {
      final columns = await db.rawQuery('PRAGMA table_info(DatiSistremaApp)');
      if (!columns.any((col) => col['name'] == 'PercorsoPdf')) {
        await db.execute('ALTER TABLE DatiSistremaApp ADD COLUMN PercorsoPdf TEXT');
      }
      final catalogColumns = await db.rawQuery('PRAGMA table_info(elenco_cataloghi)');
      if (!catalogColumns.any((col) => col['name'] == 'nome_catalogo')) {
        await db.execute('ALTER TABLE elenco_cataloghi ADD COLUMN nome_catalogo TEXT');
      }
    } catch (e) {
      debugPrint("Info: Controllo migrazione fallito. $e");
    }
  }

  Future<void> _loadConfigFromDb() async {
    if (_dbGlobale == null) return;
    
    final datiSistema = await _dbGlobale!.query('DatiSistremaApp', limit: 1);
    if (datiSistema.isEmpty) {
      await _popolaDatiGlobaliDefault(_dbGlobale!);
      await _loadConfigFromDb();
      return;
    }

    String? percorsoDalDb = datiSistema.first['PercorsoPdf'] as String?;
    if (_isPathInvalidForCurrentPlatform(percorsoDalDb)) {
      _percorsoPdf = await _getDefaultPdfPath();
      await _dbGlobale!.update('DatiSistremaApp', {'PercorsoPdf': _percorsoPdf}, where: 'id = ?', whereArgs: [datiSistema.first['id']]);
    } else {
      _percorsoPdf = percorsoDalDb!;
    }

    final idCatalogoAttivo = datiSistema.first['id_catalogo_attivo'] as int? ?? 1;
    final catalogoInfo = await _dbGlobale!.query('elenco_cataloghi', where: 'id = ?', whereArgs: [idCatalogoAttivo], limit: 1);
    
    if (catalogoInfo.isNotEmpty) {
      _activeCatalogDbName = catalogoInfo.first['nome_file_db'] as String? ?? '';
      await _loadCatalogoAttivo();
    } else {
      debugPrint("❌ Nessun catalogo attivo trovato in DB, provo a usare il primo disponibile...");
      await synchronizeCatalogs();
      final allCatalogs = await getAvailableVolumes();
      if (allCatalogs.isNotEmpty) {
        await switchVolume(allCatalogs.first['nome_file_db']);
      } else {
        debugPrint("❌ ERRORE FATALE: Nessun catalogo disponibile. L'app non può funzionare.");
      }
    }
  }

  Future<void> _loadCatalogoAttivo() async {
    if (_activeCatalogDbName.isEmpty) {
      debugPrint("⚠️ _loadCatalogoAttivo chiamato con nome vuoto. Impossibile procedere.");
      return;
    }
    
    final catalogoPath = p.join(_databasePath, _activeCatalogDbName);

    if (!await databaseExists(catalogoPath)) {
      debugPrint("‼️ Catalogo '$_activeCatalogDbName' non trovato. Lo creo e popolo da asset...");
      Database? newDb;
      try {
        newDb = await openDatabase(catalogoPath, version: 1);
        await _creaTabellaSpartiti(newDb);
        await _creaIndiciFTS(newDb);
        await _importaDatiDaAsset(newDb, _activeCatalogDbName);
        await _verificaESincronizzaFTS(newDb);
        _dbCatalogoAttivo = newDb;
        debugPrint("   ✅ Catalogo '$_activeCatalogDbName' creato e popolato con successo.");
      } catch (e, s) {
        debugPrint("   ❌ ERRORE CRITICO durante la creazione del catalogo: $e\n$s");
        await newDb?.close();
        try { await deleteDatabase(catalogoPath); } catch (_) {}
        _dbCatalogoAttivo = null;
        return;
      }
    } else {
      await _dbCatalogoAttivo?.close();
      _dbCatalogoAttivo = await openDatabase(catalogoPath);
      debugPrint("✅ Catalogo esistente caricato: $_activeCatalogDbName");
      await _verificaESincronizzaFTS(_dbCatalogoAttivo!);
    }
  }

  Future<void> _creaTabellaSpartiti(Database db) async {
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
  }

  Future<void> _creaIndiciFTS(Database db) async {
    await _eliminaFTSCompleto(db);
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS spartiti_ai_fts AFTER INSERT ON spartiti BEGIN
        INSERT INTO spartiti_fts(rowid, titolo, autore, volume, ArchivioProvenienza)
        VALUES (NEW.id_univoco_globale, NEW.titolo, NEW.autore, NEW.volume, NEW.ArchivioProvenienza);
      END;
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS spartiti_au_fts AFTER UPDATE ON spartiti BEGIN
        UPDATE spartiti_fts 
        SET titolo = NEW.titolo, autore = NEW.autore, volume = NEW.volume, ArchivioProvenienza = NEW.ArchivioProvenienza
        WHERE rowid = OLD.id_univoco_globale;
      END;
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS spartiti_ad_fts AFTER DELETE ON spartiti BEGIN
        DELETE FROM spartiti_fts WHERE rowid = OLD.id_univoco_globale;
      END;
    ''');
    await db.execute('''
      CREATE VIRTUAL TABLE spartiti_fts USING fts5(
        titolo, autore, volume, ArchivioProvenienza,
        content='spartiti', content_rowid='id_univoco_globale'
      )
    ''');
  }
  
  Future<int> _importaDatiDaAsset(Database db, String assetName) async {
    try {
      final ByteData data = await rootBundle.load('assets/databases/$assetName');
      final tempAssetDbPath = p.join((await getTemporaryDirectory()).path, "master_temp.db");
      await File(tempAssetDbPath).writeAsBytes(data.buffer.asUint8List(), flush: true);

      Database? masterDb;
      int recordImportati = 0;
      try {
        masterDb = await openReadOnlyDatabase(tempAssetDbPath);
        final sourceTable = Platform.isWindows ? 'spartiti' : 'spartiti_andr';
        final dataToInsert = await masterDb.query(sourceTable);

        if (dataToInsert.isEmpty) return 0;
        
        final chunkSize = 200;
        for (var i = 0; i < dataToInsert.length; i += chunkSize) {
          final end = (i + chunkSize < dataToInsert.length) ? i + chunkSize : dataToInsert.length;
          final chunk = dataToInsert.sublist(i, end);
          await db.transaction((txn) async {
            final batch = txn.batch();
            for (final row in chunk) {
              final rowCopy = Map<String, dynamic>.from(row);
              rowCopy.remove('id_univoco_globale');
              batch.insert('spartiti', rowCopy, conflictAlgorithm: ConflictAlgorithm.replace);
            }
            await batch.commit(noResult: true);
          });
          recordImportati += chunk.length;
        }
        return recordImportati;
      } finally {
        await masterDb?.close();
        try { await deleteDatabase(tempAssetDbPath); } catch (_) {}
      }
    } catch (e) {
      return 0;
    }
  }

  Future<void> rebuildActiveCatalogFtsIndex() async {
    if (_dbCatalogoAttivo == null) return;
    await _verificaESincronizzaFTS(_dbCatalogoAttivo!);
  }
  
  Future<void> _verificaESincronizzaFTS(Database db) async {
    try {
      final countSpartiti = (await db.rawQuery("SELECT COUNT(*) as c FROM spartiti")).first['c'] as int? ?? 0;
      final countFTS = (await db.rawQuery("SELECT COUNT(*) as c FROM spartiti_fts")).first['c'] as int? ?? 0;
      
      if (countSpartiti != countFTS) {
        await db.execute("INSERT INTO spartiti_fts(spartiti_fts) VALUES('rebuild');");
      }
    } catch (e) {
      try {
        await _creaIndiciFTS(db);
        await db.execute("INSERT INTO spartiti_fts(rowid, titolo, autore, volume, ArchivioProvenienza) SELECT id_univoco_globale, titolo, autore, volume, ArchivioProvenienza FROM spartiti");
      } catch (e2) {}
    }
  }

  Future<void> _eliminaFTSCompleto(Database db) async {
    await db.execute("DROP TRIGGER IF EXISTS spartiti_ai_fts");
    await db.execute("DROP TRIGGER IF EXISTS spartiti_au_fts");
    await db.execute("DROP TRIGGER IF EXISTS spartiti_ad_fts");
    await db.execute("DROP TABLE IF EXISTS spartiti_fts");
  }

  Future<String> _getDefaultPdfPath() async {
    if (Platform.isAndroid) return '/storage/emulated/0/JamsetPDF/';
    if (Platform.isWindows) return r'C:\JamsetPDF\';
    final supportDir = await getApplicationSupportDirectory();
    return p.join(supportDir.path, 'JamsetPDF');
  }

  bool _isPathInvalidForCurrentPlatform(String? path) {
    if (path == null || path.isEmpty) return true;
    if (Platform.isAndroid && (path.contains(r'\') || path.startsWith('C:'))) return true;
    if (Platform.isWindows && path.contains('/storage/')) return true;
    return false;
  }

  Future<Map<String, dynamic>> getCurrentVolume() async {
    if (_dbGlobale == null) return {};
    final id = (await _dbGlobale!.query('DatiSistremaApp', limit: 1)).first['id_catalogo_attivo'] as int? ?? 1;
    final result = await _dbGlobale!.query('elenco_cataloghi', where: 'id = ?', whereArgs: [id], limit: 1);
    return result.isNotEmpty ? result.first : {};
  }

  Future<List<Map<String, dynamic>>> getAvailableVolumes() async {
    if (_dbGlobale == null) return [];
    try {
      return await _dbGlobale!.query('elenco_cataloghi', orderBy: 'nome_catalogo');
    } catch (e) {
      return [];
    }
  }

  Future<bool> switchVolume(String dbFileName) async {
    if (_dbGlobale == null) return false;
    try {
      final catalogo = await _dbGlobale!.query('elenco_cataloghi', where: 'nome_file_db = ?', whereArgs: [dbFileName], limit: 1);
      if (catalogo.isEmpty) return false;
      await _dbGlobale!.update('DatiSistremaApp', {'id_catalogo_attivo': catalogo.first['id']}, where: 'id = 1');
      await reloadConfig();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> synchronizeCatalogs() async {
    if (_dbGlobale == null) return;
    debugPrint("🔄 Sincronizzazione elenco cataloghi...");

    final dir = Directory(_databasePath);
    if (!await dir.exists()) return;

    final files = await dir.list().toList();
    final dbFiles = files.where((f) => f.path.endsWith('.db') && p.basename(f.path) != _dbGlobaleName).map((f) => p.basename(f.path)).toList();

    final catalogInDb = await _dbGlobale!.query('elenco_cataloghi');
    final dbNamesInDb = catalogInDb.map((row) => row['nome_file_db'] as String).toSet();

    for (final fileName in dbFiles) {
      if (!dbNamesInDb.contains(fileName)) {
        await _dbGlobale!.insert('elenco_cataloghi', {
          'nome_catalogo': p.basenameWithoutExtension(fileName),
          'nome_file_db': fileName,
          'descrizione': 'Catalogo importato automaticamente'
        });
      }
    }

    for (final row in catalogInDb) {
      final dbName = row['nome_file_db'] as String;
      if (!dbFiles.contains(dbName)) {
        await _dbGlobale!.delete('elenco_cataloghi', where: 'nome_file_db = ?', whereArgs: [dbName]);
      }
    }
  }

  Future<void> runDiagnostics() async {
     debugPrint("🩺 Esecuzione diagnostica...");
  }
}
