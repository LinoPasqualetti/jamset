// lib/main.dart (per Jamset)

import 'package:flutter/material.dart';
import 'dart:io' show File, Platform;
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;

// === IMPORT AGGIUNTI PER IL GUARDIANO ===
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'inizializza_i_db_della_app.dart'; // Il nostro motore!
// ========================================

// === LOGICA ORIGINALE DI JAMSET (PRESERVATA) ===
import 'package:jamset/platform/opener_platform_interface.dart';
import 'package:jamset/platform/android_opener.dart';
import 'package:jamset/platform/windows_opener.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
Map<String, String> appSystemConfig = {};
// ===========================================

// === VARIABILI GLOBALI PER I DATABASE ===
// Queste variabili verranno popolate dal Guardiano e saranno
// disponibili in tutta l'app Jamset.
Database? gDbGlobale;
Database? gDatabase; 
String gActiveCatalogDbName = ''; 
String gDbGlobalePath = '';
String gVecchioDbPath = '';
const String gSpartitiTableName = 'spartiti';
String gPercorsoPdf = '';
// ========================================


Future<void> main() async {
  // --- Blocco 1: Inizializzazione di base ---
  WidgetsFlutterBinding.ensureInitialized();

  // Inizializzazione della factory del DB per la piattaforma corrente
  if (kIsWeb) {
    // databaseFactory = databaseFactoryFfiWeb;
  } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // --- Blocco 2: Logica specifica di Jamset (preservata) ---
  if (Platform.isWindows) {
    const userSpecificViewerPath = r"C:\Program Files (x86)\Adobe\Acrobat 9.0\Acrobat\Acrobat.exe";
    const defaultViewerPath = r"C:\Program Files\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe";
    if (File(userSpecificViewerPath).existsSync()) {
      appSystemConfig['pdfViewerPath'] = userSpecificViewerPath;
    } else {
      appSystemConfig['pdfViewerPath'] = defaultViewerPath;
    }
  }

  // Inizializzazione Opener (preservata)
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
  
  // Esegui l'app Jamset
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'JamSet App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
      ),
      home: const MainScreen(),
    );
  }
}

// === MainScreen TRASFORMATA PER CHIAMARE IL GUARDIANO ===
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  bool _isInitializing = true;
  String? _initError;

  @override
  void initState() {
    super.initState();
    // Avvia il motore del Guardiano!
    inizializzaIDbDellaApp().catchError((e) {
      if(mounted) setState(() => _initError = e.toString());
    }).whenComplete(() {
      if(mounted) setState(() => _isInitializing = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    // 1. Se il Guardiano sta lavorando, mostra un caricamento
    if (_isInitializing) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Avvio di Jamset in corso...'),
            ],
          ),
        ),
      );
    }

    // 2. Se il Guardiano ha fallito, mostra un errore bloccante
    if (_initError != null) {
      return Scaffold(
        backgroundColor: Colors.red.shade50,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 50),
                const SizedBox(height: 16),
                const Text(
                  'Errore critico di inizializzazione', 
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                ),
                const SizedBox(height: 8),
                SelectableText(
                  'Impossibile avviare l\'applicazione. Dettagli:\n$_initError',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 3. Altrimenti, l'inizializzazione è riuscita!
    //    Mostra la VERA interfaccia utente di Jamset.
    //    Da qui in poi, puoi usare gDatabase e gDbGlobale in sicurezza.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jamset'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: const Center(
          child: Text(
            'Database Inizializzati Correttamente!',
            style: TextStyle(fontSize: 22, color: Colors.green),
        )
      ),
      // SOSTITUISCI IL BODY QUI SOPRA CON LA TUA VERA UI
      // es. la tua Home, la tua lista di brani, etc.
    );
  }
}