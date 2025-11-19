// lib/database/database_service.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/brano.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'jamset_database.db');

    // Incrementa la versione del database per attivare la migrazione se necessario
    return await openDatabase(
      path,
      version: 1, // Assicurati che sia 1 se non hai fatto modifiche prima.
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Crea la tabella 'brani' con tutte le colonne del tuo nuovo schema.
    await db.execute('''
      CREATE TABLE brani(
        idBra INTEGER PRIMARY KEY AUTOINCREMENT,
        tipoMulti TEXT,
        tipoDocu TEXT,
        titolo TEXT NOT NULL,
        autore TEXT,
        strum TEXT,
        archivioProvenienza TEXT,
        volume TEXT,
        numPag INTEGER,
        numOrig INTEGER,
        primoLink TEXT
      )
    ''');
  }
  // Metodo per importare i brani da un file CSV
  Future<void> importBraniFromCsv(String csvFilePath) async {
    try {
      final file = File(csvFilePath);
      if (!await file.exists()) {
        print('Il file CSV non esiste al percorso specificato.');
        return;
      }
      final input = file.openRead();
      final fields = await input
          .transform(const CsvToListConverter(fieldDelimiter: ',', eol: '\n'))
          .toList();

      if (fields.isEmpty) {
        print('File CSV vuoto o non valido.');
        return;
      }

      final dataRows = fields;
      int importedCount = 0;

      for (final row in dataRows) {
        if (row.length >= 11) {
          final brano = Brano(
            titolo: row[3].toString(),
            tipoMulti: row[1].toString(),
            tipoDocu: row[2].toString(),
            autore: row[4].toString(),
            strum: row[5].toString(),
            archivioProvenienza: row[6].toString(),
            volume: row[7].toString(),
            numPag: int.tryParse(row[8].toString()) ?? 0,
            numOrig: int.tryParse(row[9].toString()) ?? 0,
            primoLink: row[10].toString(),
          );
          await insertBrano(brano);
          importedCount++;
        }
      }
      print('$importedCount brani importati con successo!');
    } catch (e) {
      print('Errore durante l\'importazione da CSV: $e');
    }
  }
}
  // --- Metodi CRUD per Brano ---

  // Inserisce un nuovo Brano nel database.
  Future<int> insertBrano(Brano brano) async {
    final db = await database;
    return await db.insert(
      'brani',
      brano.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Recupera tutti i Brani dal database.
  Future<List<Brano>> getBrani() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('brani');
    return List.generate(maps.length, (i) {
      return Brano.fromMap(maps[i]);
    });
  }

  // Cerca i Brani per titolo o autore.
  Future<List<Brano>> searchBrani(String query) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'brani',
      where: 'titolo LIKE ? OR autore LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'titolo ASC',
    );
    return List.generate(maps.length, (i) {
      return Brano.fromMap(maps[i]);
    });
  }

  // Aggiorna un Brano esistente.
  Future<int> updateBrano(Brano brano) async {
    final db = await database;
    return await db.update(
      'brani',
      brano.toMap(),
      where: 'idBra = ?',
      whereArgs: [brano.idBra],
    );
  }

  // Elimina un Brano dal database.
  Future<int> deleteBrano(int id) async {
    final db = await database;
    return await db.delete(
      'brani',
      where: 'idBra = ?',
      whereArgs: [id],
    );
  }
}