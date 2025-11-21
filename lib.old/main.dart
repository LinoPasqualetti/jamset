// lib/main.dart
import 'package:flutter/material.dart';
import 'package:jamset/screens/main_screen.dart';
import 'dart:io' show Directory, File, Platform;
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:permission_handler/permission_handler.dart'; 

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
String gDatabasePath = ''; 
// =======================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isAndroid) {
    var status = await Permission.manageExternalStorage.request();
    if (!status.isGranted) {
      runApp(const ErrorApp(error: 'Permesso di accesso a tutti i file negato. L\'app non può funzionare.'));
      return; 
    }
  }

  // --- Inizializzazione Piattaforma-Specifica di SQLite (STABILE) ---
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  try {
    if (Platform.isWindows) {
      // ... viewer ...
    }

    if (!kIsWeb) {
      // ... opener ...
    }

    gDatabasePath = await getDatabasesPath(); // Ripristinato a getDatabasesPath()
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

// --- Logica di setup STABILE ---
Future<void> _setupDatabase(Database db, String dbName) async {
  await db.transaction((txn) async {
    if (!Platform.isWindows) {
      if (kDebugMode) print("[$dbName] Normalizzazione percorsi per piattaforma non-Windows...");
      await txn.rawUpdate("UPDATE spartiti SET percResto = REPLACE(percResto, '\\', '/')");
    }

    if (Platform.isWindows) {
      final ftsTable = await txn.query('sqlite_master', where: 'type = ? AND name = ?', whereArgs: ['table', 'spartiti_fts']);
      if (ftsTable.isEmpty) {
        // ... codice creazione FTS ...
      }
    }
  });
}

// ... resto del file ...

class ErrorApp extends StatelessWidget {
  final String error;
  const ErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    bool isPermissionError = error.contains('negato');
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
                  const SizedBox(height: 20),
                  if (isPermissionError)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.settings),
                      label: const Text('Apri Impostazioni App'),
                      onPressed: () {
                        openAppSettings();
                      },
                    ),
                ])),
          )),
    );
  }
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
