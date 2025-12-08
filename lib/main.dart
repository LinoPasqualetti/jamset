// lib/main.dart - VERSIONE CON LOGICA PERCORSO WINDOWS RIPRISTINATA
import 'package:flutter/material.dart';
import 'package:jamsetgemini/screens/main_screen.dart';
import 'dart:io' show Directory, File, Platform;
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

// --- IMPORT PER DATABASE ---
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';
// ---------------------------

import 'package:jamsetgemini/database/inizializza_i_db_della_app.dart';
import 'package:jamsetgemini/platform/opener_platform_interface.dart';
import 'package:jamsetgemini/platform/android_opener.dart';
import 'package:jamsetgemini/platform/windows_opener.dart';

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


Future<void> _requestPermissions() async {
  if (kIsWeb || !Platform.isAndroid) {
    return; 
  }

  final deviceInfo = await DeviceInfoPlugin().androidInfo;
  
  if (deviceInfo.version.sdkInt >= 30) {
    var status = await Permission.manageExternalStorage.status;
    if (!status.isGranted) {
      await Permission.manageExternalStorage.request();
    }
  } 
  else {
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      await Permission.storage.request();
    }
  }
}


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _requestPermissions();

  if (!kIsWeb) {
    Directory.current = (await getApplicationDocumentsDirectory()).path;
  }

  if (Platform.isAndroid) {
    await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
  }
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS || Platform.isAndroid) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  try {
    if (!kIsWeb) {
      try {
        if (Platform.isAndroid) {
          OpenerPlatformInterface.instance = AndroidOpener();
        } else if (Platform.isWindows) {
          OpenerPlatformInterface.instance = WindowsOpener();

          // --- LOGICA PERCORSO PDF WINDOWS RIPRISTINATA ---
          const userSpecificViewerPath = r"C:\Program Files (x86)\Adobe\Acrobat 9.0\Acrobat\Acrobat.exe";
          const defaultViewerPath = r"C:\Program Files\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe";

          if (File(userSpecificViewerPath).existsSync()) {
            appSystemConfig['pdfViewerPath'] = userSpecificViewerPath;
          } else if (File(defaultViewerPath).existsSync()) {
            appSystemConfig['pdfViewerPath'] = defaultViewerPath;
          } else {
            if(kDebugMode) print("ATTENZIONE: Nessun lettore PDF Adobe trovato nei percorsi predefiniti.");
          }
          // --------------------------------------------------
        }
      } catch (e) {
        if (kDebugMode) print("Errore inizializzazione piattaforma: $e");
      }
    }

    await inizializzaIDbDellaApp();

    if (kDebugMode) {
      print("=== INIZIALIZZAZIONE COMPLETATA ===");
      print("Percorso PDF corretto: $gPercorsoPdf");
    }

    runApp(const MyApp());

  } catch (e, stackTrace) {
    if (kDebugMode) {
      print("### ERRORE CRITICO DURANTE L'INIZIALIZZAZIONE: $e ###");
      print("Stack trace: $stackTrace");
    }
    runApp(ErrorApp(error: "Errore inizializzazione: ${e.toString()}"));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'JamsetGemini App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blueGrey,
            primary: Colors.blueAccent,
            secondary: Colors.amber
        ),
        useMaterial3: true,
      ),
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 60),
                const SizedBox(height: 20),
                const Text(
                    'Errore Critico all\'Avvio',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)
                ),
                const SizedBox(height: 10),
                SelectableText(
                  error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}