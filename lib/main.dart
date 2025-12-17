// lib/main.dart - VERSIONE FINALE CON DATABASESERVICE
import 'package:flutter/material.dart';
import 'package:jamsetgemini/screens/main_screen.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

// Import del nuovo DatabaseService
import 'package:jamsetgemini/services/database_service.dart';

import 'package:jamsetgemini/platform/opener_platform_interface.dart';
import 'package:jamsetgemini/platform/android_opener.dart';
import 'package:jamsetgemini/platform/windows_opener.dart';

// Chiave globale per accedere al Navigator
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Mappa di configurazione (es. per percorso PDF su Windows)
Map<String, String> appSystemConfig = {};

// ===================================================================
// VARIABILI GLOBALI (da ridurre progressivamente)
// ===================================================================
String gPercorsoPdf = '';
String gDatabasePath = '';
String gActiveCatalogDbName = '';

// Unica istanza del servizio database
DatabaseService databaseService = DatabaseService();
// ===================================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Configura il logging (opzionale, ma utile)
  _setupAdvancedLogging();

  // 2. Richiedi permessi (se su Android)
  if (!kIsWeb && Platform.isAndroid) {
    await _requestPermissions();
  }

  // 3. Setup directory per piattaforme non-web
  if (!kIsWeb) {
    Directory.current = (await getApplicationDocumentsDirectory()).path;
  }

  // 4. Inizializza SQLite per FFI (Windows, Linux, macOS, Android)
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS || Platform.isAndroid) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  try {
    // 5. Configura componenti specifici per la piattaforma
    _setupPlatformSpecifics();

    // 6. INIZIALIZZA IL DATABASE TRAMITE IL NUOVO SERVICE
    debugPrint("\n🚀 INIZIALIZZAZIONE DATABASE SERVICE...");
    await databaseService.initialize();
    debugPrint("✅ DATABASE SERVICE INIZIALIZZATO CON SUCCESSO.");

    // 7. Sincronizza le variabili globali con i dati dal Service
    gPercorsoPdf = databaseService.percorsoPdf;
    gDatabasePath = databaseService.databasePath;
    final currentVolume = await databaseService.getCurrentVolume();
    gActiveCatalogDbName = currentVolume['nome_file_db'] as String? ?? '';

    // 8. Esegui diagnostica (opzionale)
    if (kDebugMode) {
      await databaseService.runDiagnostics();
    }

    debugPrint("\n=== RIEPILOGO AVVIO ===");
    debugPrint("Percorso PDF: $gPercorsoPdf");
    debugPrint("Catalogo Attivo: $gActiveCatalogDbName");
    debugPrint("========================\n");

    // 9. Avvia l'app
    runApp(const MyApp());

  } catch (e, stackTrace) {
    // Gestione errore critico
    _handleInitializationError(e, stackTrace);
  }
}

/// ===================================================================
/// FUNZIONI DI SUPPORTO AL MAIN
/// ===================================================================

void _setupPlatformSpecifics() {
  if (kIsWeb) return;

  try {
    if (Platform.isAndroid) {
      OpenerPlatformInterface.instance = AndroidOpener();
      debugPrint("✅ AndroidOpener configurato");
    } else if (Platform.isWindows) {
      OpenerPlatformInterface.instance = WindowsOpener();
      debugPrint("✅ WindowsOpener configurato");
      _findWindowsPdfViewer();
    }
  } catch (e) {
    debugPrint("⚠️ Errore inizializzazione piattaforma: $e");
  }
}

void _findWindowsPdfViewer() {
  const userSpecificViewerPath = r"C:\Program Files (x86)\Adobe\Acrobat 9.0\Acrobat\Acrobat.exe";
  const defaultViewerPath = r"C:\Program Files\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe";

  if (File(userSpecificViewerPath).existsSync()) {
    appSystemConfig['pdfViewerPath'] = userSpecificViewerPath;
    debugPrint("📄 Lettore PDF trovato: $userSpecificViewerPath");
  } else if (File(defaultViewerPath).existsSync()) {
    appSystemConfig['pdfViewerPath'] = defaultViewerPath;
    debugPrint("📄 Lettore PDF trovato: $defaultViewerPath");
  } else {
    debugPrint("⚠️ Nessun lettore PDF Adobe trovato");
  }
}

Future<void> _requestPermissions() async {
  if (Platform.isAndroid) {
    final deviceInfo = await DeviceInfoPlugin().androidInfo;
    if (deviceInfo.version.sdkInt >= 30) { // Android 11+
      var status = await Permission.manageExternalStorage.status;
      if (!status.isGranted) {
        await Permission.manageExternalStorage.request();
      }
    } else {
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        await Permission.storage.request();
      }
    }
  }
}

void _setupAdvancedLogging() {
  if (kDebugMode) {
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null && message.isNotEmpty) {
        final timestamp = DateTime.now().toString().substring(11, 23);
        print("[$timestamp] $message");
      }
    };
  }
}

void _handleInitializationError(dynamic e, StackTrace stackTrace) {
  debugPrint("\n" + "="*80);
  debugPrint("❌ ERRORE CRITICO DURANTE L'INIZIALIZZAZIONE");
  debugPrint("="*80);
  debugPrint("Errore: $e");
  debugPrint("Stack trace: $stackTrace");

  runApp(ErrorApp(
    error: e.toString(),
    stackTrace: stackTrace.toString(),
  ));
}

/// ===================================================================
/// WIDGET PRINCIPALI (MyApp, ErrorApp)
/// ===================================================================

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Jamset Gemini',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

class ErrorApp extends StatelessWidget {
  final String error;
  final String stackTrace;

  const ErrorApp({super.key, required this.error, this.stackTrace = ''});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.red[50],
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 60),
                const SizedBox(height: 20),
                const Text(
                  'Errore Critico all\'Avvio',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  'L\'app non può essere avviata a causa di un problema irreversibile.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    error,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
                if (stackTrace.isNotEmpty)
                  ExpansionTile(
                    title: const Text('Dettagli tecnici (stack trace)'),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        color: Colors.black,
                        child: SelectableText(
                          stackTrace,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontFamily: 'monospace',
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
