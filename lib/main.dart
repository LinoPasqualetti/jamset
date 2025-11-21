// lib/main.dart
import 'package:flutter/material.dart';
import 'package:jamset/screens/main_screen.dart';
import 'dart:io' show Directory, File, Platform;
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;

// --- IMPORT PER DATABASE ---
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/services.dart' show ByteData, rootBundle;
// ---------------------------

import 'package:jamset/platform/opener_platform_interface.dart';
import 'package:jamset/platform/android_opener.dart';
import 'package:jamset/platform/windows_opener.dart';

// Chiave globale per accedere al Navigator
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Map<String, String> appSystemConfig = {};

// === VARIABILI GLOBALI ===
Database? dbVecchio;
Database? dbGlobale;
Database? dbCatalogoAttivo;
String gActiveCatalogDbName = '';
String gPercorsoPdf = ''; 
String gDatabasePath = ''; // <-- VARIABILE AGGIUNTA
// =======================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- Inizializzazione Piattaforma-Specifica di SQLite ---
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    // Per il desktop, inizializziamo FFI e impostiamo la factory.
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  // Per Android e iOS, NON facciamo nulla qui. Il pacchetto `sqlite3_flutter_libs` 
  // si integra automaticamente con la configurazione di default di `sqflite`.

  try {
    if (Platform.isWindows) {
      const userSpecificViewerPath = r"C:\Program Files (x86)\Adobe\Acrobat 9.0\Acrobat\Acrobat.exe";
      const defaultViewerPath = r"C:\Program Files\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe";
      if (File(userSpecificViewerPath).existsSync()) {
        appSystemConfig['pdfViewerPath'] = userSpecificViewerPath;
      } else {
        appSystemConfig['pdfViewerPath'] = defaultViewerPath;
      }
    }

    if (!kIsWeb) {
      try {
        if (Platform.isAndroid) {
          OpenerPlatformInterface.instance = AndroidOpener();
        } else if (Platform.isWindows) {
          OpenerPlatformInterface.instance = WindowsOpener();
        }
      } catch (e) {
        if (kDebugMode) print("Errore inizializzazione piattaforma: $e");
      }
    }

    gDatabasePath = await getDatabasesPath(); // <-- VALORIZZAZIONE
    final dbDir = gDatabasePath;
    if (kDebugMode) print("--- PERCORSO DATABASE: $dbDir ---");

    // 1. Apertura VecchioDb.db
    final dbPathVecchio = join(dbDir, "VecchioDb.db");
    if (!await File(dbPathVecchio).exists()) {
      await Directory(dirname(dbPathVecchio)).create(recursive: true);
      ByteData data = await rootBundle.load("assets/databases/VecchioDb.db");
      List<int> bytes = data.buffer.asUint8List();
      await File(dbPathVecchio).writeAsBytes(bytes, flush: true);
    }
    dbVecchio = await openDatabase(dbPathVecchio);
    await _setupDatabase(dbVecchio!, "VecchioDb");
    if (kDebugMode) print("Database VecchioDb.db aperto e configurato.");

    // 2. Apertura DBGlobale_seed.db
    final dbPathGlobale = join(dbDir, "DBGlobale_seed.db");
    if (!await File(dbPathGlobale).exists()) {
      await Directory(dirname(dbPathGlobale)).create(recursive: true);
      ByteData data = await rootBundle.load("assets/databases/DBGlobale_seed.db");
      List<int> bytes = data.buffer.asUint8List();
      await File(dbPathGlobale).writeAsBytes(bytes, flush: true);
    }
    dbGlobale = await openDatabase(dbPathGlobale);
    if (kDebugMode) print("Database DBGlobale_seed.db aperto.");

    // --- LETTURA CONFIGURAZIONI GLOBALI ---
    if (dbGlobale == null) throw Exception("DB Globale non aperto.");

    final configData = await dbGlobale!.query('DatiSistremaApp', columns: ['PercorsoPdf'], limit: 1);
    if (configData.isNotEmpty) {
      gPercorsoPdf = configData.first['PercorsoPdf'] as String;
      if (kDebugMode) print("Percorso PDF globale: $gPercorsoPdf");
    }

    final catalogResults = await dbGlobale!.rawQuery("select nome_file_db from elenco_cataloghi, datiSistremaApp where id=id_catalogo_attivo");
    if (catalogResults.isEmpty || catalogResults.first['nome_file_db'] == null) {
      throw Exception("Nessun catalogo attivo trovato.");
    }
    gActiveCatalogDbName = catalogResults.first['nome_file_db'] as String;
    if (kDebugMode) print("Catalogo attivo: $gActiveCatalogDbName");

    // 3. APERTURA DINAMICA DEL CATALOGO ATTIVO
    final dbPathCatalogo = join(dbDir, gActiveCatalogDbName);
    if (!await File(dbPathCatalogo).exists()) {
      await Directory(dirname(dbPathCatalogo)).create(recursive: true);
      ByteData data = await rootBundle.load("assets/databases/$gActiveCatalogDbName");
      List<int> bytes = data.buffer.asUint8List();
      await File(dbPathCatalogo).writeAsBytes(bytes, flush: true);
    }
    dbCatalogoAttivo = await openDatabase(dbPathCatalogo);
    await _setupDatabase(dbCatalogoAttivo!, gActiveCatalogDbName);
    if (kDebugMode) print("Database catalogo '$gActiveCatalogDbName' aperto e configurato.");

    runApp(const MyApp());

  } catch (e) {
    if (kDebugMode) print("ERRORE CRITICO: $e");
    runApp(ErrorApp(error: e.toString()));
  }
}

// --- NUOVA LOGICA DI SETUP DEL DATABASE ---
Future<void> _setupDatabase(Database db, String dbName) async {
  await db.transaction((txn) async {
    // 1. Normalizzazione dei percorsi (solo su piattaforme non-Windows)
    if (!Platform.isWindows) {
      if (kDebugMode) print("[$dbName] Normalizzazione percorsi per piattaforma non-Windows...");
      await txn.rawUpdate("UPDATE spartiti SET percResto = REPLACE(percResto, '\\', '/')");
    }

    // 2. Verifica e creazione indice FTS5 (SOLO SU WINDOWS, per ora)
    if (Platform.isWindows) {
      final ftsTable = await txn.query('sqlite_master', where: 'type = ? AND name = ?', whereArgs: ['table', 'spartiti_fts']);
      if (ftsTable.isEmpty) {
        if (kDebugMode) print("[$dbName] Indice FTS non trovato. Creazione in corso...");

        // Crea la tabella virtuale
        await txn.execute('''
          CREATE VIRTUAL TABLE spartiti_fts USING fts5 (
            titolo, autore, volume, ArchivioProvenienza,
            content = \'spartiti\', content_rowid = \'IdBra\'
          );
        ''');

        // Popola l'indice
        await txn.execute('''
          INSERT INTO spartiti_fts(rowid, titolo, autore, volume, ArchivioProvenienza)
          SELECT IdBra, titolo, autore, volume, ArchivioProvenienza FROM spartiti;
        ''');

        // Crea i trigger
        await txn.execute('''
          CREATE TRIGGER spartiti_ai AFTER INSERT ON spartiti BEGIN
            INSERT INTO spartiti_fts(rowid, titolo, autore, volume, ArchivioProvenienza)
            VALUES (new.IdBra, new.titolo, new.autore, new.volume, new.ArchivioProvenienza);
          END;
        ''');
        await txn.execute('''
          CREATE TRIGGER spartiti_ad AFTER DELETE ON spartiti BEGIN
            INSERT INTO spartiti_fts(spartiti_fts, rowid, titolo, autore, volume, ArchivioProvenienza) 
            VALUES(\'delete\', old.IdBra, old.titolo, old.autore, old.volume, old.ArchivioProvenienza);
          END;
        ''');
        await txn.execute('''
          CREATE TRIGGER spartiti_au AFTER UPDATE ON spartiti BEGIN
            INSERT INTO spartiti_fts(spartiti_fts, rowid, titolo, autore, volume, ArchivioProvenienza) 
            VALUES(\'delete\', old.IdBra, old.titolo, old.autore, old.volume, old.ArchivioProvenienza);
            INSERT INTO spartiti_fts(rowid, titolo, autore, volume, ArchivioProvenienza)
            VALUES (new.IdBra, new.titolo, new.autore, new.volume, new.ArchivioProvenienza);
          END;
        ''');

        if (kDebugMode) print("[$dbName] Creazione indice FTS e triggers completata.");
      }
    }
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'JamSet App',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey, primary: Colors.blueAccent, secondary: Colors.amber)),
      home: const MainScreen(),
    );
  }
}

class ErrorApp extends StatelessWidget {
  final String error;
  const ErrorApp({super.key, required this.error});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
          backgroundColor: const Color(0xFFFFF0F0),
          body: Center(
            child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 60),
                  const SizedBox(height: 20),
                  const Text('Errore Critico all\'Avvio', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  SelectableText(error, textAlign: TextAlign.center),
                ])),
          )),
    );
  }
}
