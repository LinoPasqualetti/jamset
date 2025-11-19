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
// =======================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

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

    final dbDir = await getDatabasesPath();

    // 1. Apertura VecchioDb.db
    final dbPathVecchio = join(dbDir, "VecchioDb.db");
    if (!await File(dbPathVecchio).exists()) {
      await Directory(dirname(dbPathVecchio)).create(recursive: true);
      ByteData data = await rootBundle.load("assets/databases/VecchioDb.db");
      List<int> bytes = data.buffer.asUint8List();
      await File(dbPathVecchio).writeAsBytes(bytes, flush: true);
    }
    dbVecchio = await openDatabase(dbPathVecchio);
    if (kDebugMode) print("Database VecchioDb.db aperto.");

    // --- SANIFICAZIONE di VecchioDb.db ---
    if (dbVecchio != null) {
      final tables = await dbVecchio!.query('sqlite_master', where: 'type = ? AND name = ?', whereArgs: ['table', 'spartiti_andr']);
      if (tables.isNotEmpty) {
        if (kDebugMode) print("Trovata tabella 'spartiti_andr'. Avvio sanificazione...");
        await dbVecchio!.transaction((txn) async {
          if (Platform.isWindows) {
            await txn.execute('DROP TABLE spartiti_andr;');
          } else {
            await txn.execute('DROP TABLE IF EXISTS spartiti;');
            await txn.execute('ALTER TABLE spartiti_andr RENAME TO spartiti;');
          }
        });
        if (kDebugMode) print("Sanificazione completata.");
      }
    }
    // --- FINE SANIFICAZIONE ---

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
    if (kDebugMode) print("Database catalogo '$gActiveCatalogDbName' aperto.");

    runApp(const MyApp());

  } catch (e) {
    if (kDebugMode) print("ERRORE CRITICO: $e");
    runApp(ErrorApp(error: e.toString()));
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
