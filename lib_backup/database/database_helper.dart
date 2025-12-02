import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  // Nome del file del database
  static const _dbName = 'jamset_database.db';
  // Versione del database (incrementa se cambi lo schema)
  static const _dbVersion = 1;

  // Nome della tabella dei dati di sistema
  static const tableAppSystemData = 'AppSystemData';

  // Colonne per AppSystemData (esempio)
  static const colId = '_id'; // Chiave primaria standard
  static const colKey = 'dataKey'; // Es. 'lastSyncDate', 'basePdfPathWindows'
  static const colValue = 'dataValue'; // Es. '2023-10-27', 'C:\JamsetPDF'

  // Singleton instance
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  // Riferimento al database (una sola istanza per tutta l'app)
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Inizializza il database (apre o crea se non esiste)
  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = p.join(documentsDirectory.path, _dbName);
    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      // onUpgrade: _onUpgrade, // Aggiungi se avrai versioni future
    );
  }

  // SQL per creare le tabelle
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableAppSystemData (
        $colId INTEGER PRIMARY KEY AUTOINCREMENT,
        $colKey TEXT NOT NULL UNIQUE, 
        $colValue TEXT
      )
    ''');
    // Inserisci qui i dati di sistema iniziali (seed)
    await _seedAppSystemData(db);
  }

  // Funzione per popolare i dati di sistema iniziali
  Future<void> _seedAppSystemData(Database db) async {
    // Esempi di dati di sistema che potresti voler memorizzare
    // Questi sono solo esempi, adattali alle tue necessità!
    Map<String, String> defaultSystemData = {
      'basePdfPathWindows': r'C:\JamsetPDF\', // Raw string per i backslash
      'basePdfPathAndroid': '/storage/emulated/0/JamsetPDF/', // Esempio, considera Scoped Storage
      'basePdfPathLinux': '/home/user/JamsetPDF/', // Esempio
      'appName': 'JamSet Visualizzatore Spartiti',
      'lastCsvImportPath': '', // Percorso dell'ultimo CSV importato
      // Aggiungi altre chiavi di configurazione che ti servono
    };

    for (var entry in defaultSystemData.entries) {
      // Inserisci solo se la chiave non esiste già (per evitare duplicati in futuri onCreate se qualcosa va storto)
      // Anche se UNIQUE su colKey dovrebbe già prevenire questo a livello DB
      await db.insert(
        tableAppSystemData,
        {colKey: entry.key, colValue: entry.value},
        conflictAlgorithm: ConflictAlgorithm.ignore, // Ignora se la chiave (colKey) esiste già
      );
    }
    print("DatabaseHelper: Dati di sistema iniziali popolati.");
  }

  // --- Metodi CRUD per AppSystemData ---

  // Inserisci un dato di sistema (o aggiorna se la chiave esiste)
  Future<int> upsertSystemData(String key, String value) async {
    Database db = await instance.database;
    return await db.insert(
      tableAppSystemData,
      {colKey: key, colValue: value},
      conflictAlgorithm: ConflictAlgorithm.replace, // Sostituisce se colKey esiste
    );
  }

  // Leggi un valore specifico per chiave
  Future<String?> getSystemData(String key) async {
    Database db = await instance.database;
    List<Map<String, dynamic>> maps = await db.query(
      tableAppSystemData,
      columns: [colValue],
      where: '$colKey = ?',
      whereArgs: [key],
    );
    if (maps.isNotEmpty) {
      return maps.first[colValue] as String?;
    }
    return null;
  }

  // Leggi tutti i dati di sistema come una mappa
  Future<Map<String, String>> getAllSystemData() async {
    Database db = await instance.database;
    List<Map<String, dynamic>> maps = await db.query(tableAppSystemData);
    Map<String, String> systemData = {};
    for (var map in maps) {
      systemData[map[colKey] as String] = map[colValue] as String? ?? '';
    }
    return systemData;
  }

// Altri metodi (update, delete) se necessari...
}

