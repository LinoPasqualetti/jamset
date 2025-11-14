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

// === VARIABILI GLOBALI PER I DATABASE (con nomi più chiari) ===
Database? dbVecchio;
Database? dbGlobale;
Database? dbCatalogoAttivo; // <-- SOSTITUISCE dbJazz
// =========================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  try {
    // Configurazione del lettore PDF per Windows
    if (Platform.isWindows) {
      const userSpecificViewerPath = r"C:\Program Files (x86)\Adobe\Acrobat 9.0\Acrobat\Acrobat.exe";
      const defaultViewerPath = r"C:\Program Files\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe";
      if (File(userSpecificViewerPath).existsSync()) {
        appSystemConfig['pdfViewerPath'] = userSpecificViewerPath;
      } else {
        appSystemConfig['pdfViewerPath'] = defaultViewerPath;
      }
    }

    // --- INIZIALIZZAZIONE OPENER (blocco mancante) ---
    if (!kIsWeb) {
      try {
        if (Platform.isAndroid) {
          OpenerPlatformInterface.instance = AndroidOpener();
        } else if (Platform.isWindows) {
          OpenerPlatformInterface.instance = WindowsOpener();
        }
      } catch (e) {
        if (kDebugMode) {
          print("Errore durante l'inizializzazione della piattaforma: $e");
        }
      }
    }
    // --------------------------------------------------

    if (kDebugMode) {
      // ... (stampa info piattaforma)
    }

    // --- APERTURA DEI DATABASE CON LOGICA DINAMICA ---
    final dbDir = await getDatabasesPath();

    // 1. Apertura VecchioDb.db (invariato)
    final dbPathVecchio = join(dbDir, "VecchioDb.db");
    if (!await File(dbPathVecchio).exists()) {
      await Directory(dirname(dbPathVecchio)).create(recursive: true);
      ByteData data = await rootBundle.load("assets/databases/VecchioDb.db");
      List<int> bytes = data.buffer.asUint8List();
      await File(dbPathVecchio).writeAsBytes(bytes, flush: true);
    }
    dbVecchio = await openDatabase(dbPathVecchio);
    if (kDebugMode) print("Database VecchioDb.db aperto con successo.");

    // 2. Apertura DBGlobale_seed.db (invariato)
    final dbPathGlobale = join(dbDir, "DBGlobale_seed.db");
    if (!await File(dbPathGlobale).exists()) {
      await Directory(dirname(dbPathGlobale)).create(recursive: true);
      ByteData data = await rootBundle.load("assets/databases/DBGlobale_seed.db");
      List<int> bytes = data.buffer.asUint8List();
      await File(dbPathGlobale).writeAsBytes(bytes, flush: true);
    }
    dbGlobale = await openDatabase(dbPathGlobale);
    if (kDebugMode) print("Database DBGlobale_seed.db aperto con successo.");

    // 3. APERTURA DINAMICA DEL CATALOGO ATTIVO
    if (dbGlobale == null) {
      throw Exception("Il database globale non è stato aperto. Impossibile determinare il catalogo attivo.");
    }
    
    final List<Map<String, dynamic>> results = await dbGlobale!.rawQuery(
        "select nome_file_db from elenco_cataloghi, datiSistremaApp where id=id_catalogo_attivo");

    if (results.isEmpty || results.first['nome_file_db'] == null) {
      throw Exception("Nessun catalogo attivo trovato nel database globale.");
    }

    final String catalogoDbName = results.first['nome_file_db'] as String;
    if (kDebugMode) print("Catalogo attivo da caricare: $catalogoDbName");

    final dbPathCatalogo = join(dbDir, catalogoDbName);
    if (!await File(dbPathCatalogo).exists()) {
      await Directory(dirname(dbPathCatalogo)).create(recursive: true);
      ByteData data = await rootBundle.load("assets/databases/$catalogoDbName");
      List<int> bytes = data.buffer.asUint8List();
      await File(dbPathCatalogo).writeAsBytes(bytes, flush: true);
    }
    dbCatalogoAttivo = await openDatabase(dbPathCatalogo);
    if (kDebugMode) print("Database catalogo '$catalogoDbName' aperto con successo.");
    // --------------------------------

    runApp(const MyApp());

  } catch (e) {
    if (kDebugMode) {
      print("ERRORE CRITICO DI INIZIALIZZAZIONE: $e");
    }
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
      theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey, primary: Colors.blueAccent, secondary: Colors.amber)),
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
