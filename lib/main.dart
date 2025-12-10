// lib/main.dart - VERSIONE CON DIAGNOSTICA INTEGRATA (CORRETTA)
import 'package:flutter/material.dart';
import 'package:jamsetgemini/screens/main_screen.dart';
import 'dart:io' show Directory, File, Platform;
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart'; // Aggiunto per SystemNavigator
import 'dart:io'; // Aggiunto per exit e FileMode

// --- IMPORT PER DATABASE ---
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';
// ---------------------------

import 'package:jamsetgemini/database/inizializza_i_db_della_app.dart';
import 'package:jamsetgemini/platform/opener_platform_interface.dart';
import 'package:jamsetgemini/platform/android_opener.dart';
import 'package:jamsetgemini/platform/windows_opener.dart';

// Import nuova diagnostica
import 'package:jamsetgemini/utils/database_diagnostica.dart';

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

/// Configura logging avanzato
void _setupAdvancedLogging() {
  if (kDebugMode) {
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null && message.isNotEmpty) {
        final timestamp = DateTime.now().toString().substring(11, 23);
        print("[$timestamp] $message");

        // Salva anche in file su Windows per debug
        if (Platform.isWindows) {
          try {
            final logFile = File('jamset_debug_log.txt');
            final sink = logFile.openWrite(mode: FileMode.append);
            sink.writeln("[$timestamp] $message");
            sink.close();
          } catch (e) {
            // Ignora errori di scrittura file
          }
        }
      }
    };
  }
}

/// Richiedi permessi Android
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

/// Inizializzazione database avanzata con diagnostica
Future<void> _inizializzaDatabaseConDiagnostica() async {
  debugPrint("\n" + "="*80);
  debugPrint("🚀 INIZIALIZZAZIONE DATABASE JAMSETGEMINI");
  debugPrint("="*80);
  debugPrint("Data: ${DateTime.now()}");
  debugPrint("Piattaforma: ${Platform.operatingSystem}");
  debugPrint("Versione OS: ${Platform.version}");
  debugPrint("Modalità debug: $kDebugMode");

  try {
    // 1. Inizializzazione standard
    await inizializzaIDbDellaApp();

    debugPrint("\n✅ INIZIALIZZAZIONE DATABASE COMPLETATA");

    // 2. Diagnostica database globale
    if (dbGlobale != null) {
      debugPrint("\n📊 DATABASE GLOBALE INIZIALIZZATO:");
      debugPrint("   Path: ${dbGlobale!.path}");
      debugPrint("   Connesso: ${dbGlobale!.isOpen}");

      // Test rapido
      try {
        final test = await dbGlobale!.rawQuery("SELECT COUNT(*) as c FROM sqlite_master");
        debugPrint("   Oggetti nel database: ${test.first['c']}");
      } catch (e) {
        debugPrint("   ⚠️ Errore test database globale: $e");
      }
    } else {
      debugPrint("❌ Database globale non inizializzato!");
    }

    // 3. Diagnostica database catalogo attivo
    if (dbCatalogoAttivo != null) {
      debugPrint("\n📁 CATALOGO ATTIVO:");
      debugPrint("   Nome: $gActiveCatalogDbName");
      debugPrint("   Path: ${dbCatalogoAttivo!.path}");
      debugPrint("   Connesso: ${dbCatalogoAttivo!.isOpen}");

      // Esegui diagnostica completa sul catalogo attivo
      await DatabaseDiagnostica.eseguiDiagnosticaCompleta(dbCatalogoAttivo);

    } else {
      debugPrint("❌ Catalogo attivo non inizializzato!");

      // Fallback a VecchioDb se disponibile
      if (dbVecchio != null) {
        debugPrint("\n🔄 Fallback a VecchioDb per diagnostica...");
        await DatabaseDiagnostica.eseguiDiagnosticaCompleta(dbVecchio);
      }
    }

    // 4. Verifica percorso PDF
    debugPrint("\n📂 PERCORSI CONFIGURATI:");
    debugPrint("   Percorso PDF: $gPercorsoPdf");
    debugPrint("   Percorso Database: $gDatabasePath");

    if (Platform.isAndroid && gPercorsoPdf.isNotEmpty) {
      final dir = Directory(gPercorsoPdf);
      final exists = await dir.exists();
      debugPrint("   Directory PDF esiste: $exists");

      if (!exists) {
        debugPrint("   ⚠️ ATTENZIONE: Directory PDF non trovata!");
        debugPrint("   Tentativo di creazione...");
        try {
          await dir.create(recursive: true);
          debugPrint("   ✅ Directory PDF creata");
        } catch (e) {
          debugPrint("   ❌ Impossibile creare directory: $e");
        }
      }
    }

    debugPrint("\n" + "="*80);
    debugPrint("🎯 INIZIALIZZAZIONE COMPLETATA CON SUCCESSO");
    debugPrint("="*80);

  } catch (e, s) {
    debugPrint("\n❌ ERRORE DURANTE INIZIALIZZAZIONE DATABASE:");
    debugPrint("   Messaggio: $e");
    debugPrint("   Stack trace: $s");

    // Rilancia l'errore per gestione a livello superiore
    rethrow;
  }
}

/// Test automatico ricerca all'avvio
Future<void> _testRicercaAutomatica() async {
  if (dbCatalogoAttivo == null) {
    debugPrint("⚠️ Test ricerca saltato: catalogo non inizializzato");
    return;
  }

  debugPrint("\n🧪 TEST RICERCA AUTOMATICA ALL'AVVIO:");

  try {
    // Test query semplice
    final testQuery = "SELECT COUNT(*) as c FROM spartiti_fts WHERE spartiti_fts MATCH 'test'";
    final result = await dbCatalogoAttivo!.rawQuery(testQuery);
    final count = result.first['c'] as int? ?? 0;

    debugPrint("   Query test FTS: $count risultati");

    // Test ricerca specifica
    if (count > 0) {
      debugPrint("   🔍 Test ricerca 'girl ipanema':");

      final testSearch = await dbCatalogoAttivo!.rawQuery(
          "SELECT COUNT(*) as c FROM spartiti_fts WHERE spartiti_fts MATCH ?",
          ['girl ipanema']
      );

      final searchCount = testSearch.first['c'] as int? ?? 0;
      debugPrint("   Risultati: $searchCount");

      if (searchCount == 0) {
        debugPrint("   ⚠️ Nessun risultato per 'girl ipanema'");
        debugPrint("   Verifica se l'indice FTS è popolato correttamente");
      }
    }

  } catch (e) {
    debugPrint("   ❌ Test ricerca fallito: $e");
  }
}

/// Main con gestione errori avanzata
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configura logging avanzato
  _setupAdvancedLogging();

  // Richiedi permessi (Android)
  await _requestPermissions();

  // Setup directory per non-web
  if (!kIsWeb) {
    Directory.current = (await getApplicationDocumentsDirectory()).path;
  }

  // Inizializza SQLite per diverse piattaforme
  if (Platform.isAndroid) {
    await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
  }
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS || Platform.isAndroid) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  try {
    // Configura opener platform-specific
    if (!kIsWeb) {
      try {
        if (Platform.isAndroid) {
          OpenerPlatformInterface.instance = AndroidOpener();
          debugPrint("✅ AndroidOpener configurato");
        } else if (Platform.isWindows) {
          OpenerPlatformInterface.instance = WindowsOpener();
          debugPrint("✅ WindowsOpener configurato");

          // --- LOGICA PERCORSO PDF WINDOWS RIPRISTINATA ---
          const userSpecificViewerPath = r"C:\Program Files (x86)\Adobe\Acrobat 9.0\Acrobat\Acrobat.exe";
          const defaultViewerPath = r"C:\Program Files\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe";

          if (File(userSpecificViewerPath).existsSync()) {
            appSystemConfig['pdfViewerPath'] = userSpecificViewerPath;
            debugPrint("📄 Lettore PDF trovato: $userSpecificViewerPath");
          } else if (File(defaultViewerPath).existsSync()) {
            appSystemConfig['pdfViewerPath'] = defaultViewerPath;
            debugPrint("📄 Lettore PDF trovato: $defaultViewerPath");
          } else {
            debugPrint("⚠️ Nessun lettore PDF Adobe trovato nei percorsi predefiniti");
            debugPrint("   L'app userà il visualizzatore di sistema");
          }
          // --------------------------------------------------
        }
      } catch (e) {
        debugPrint("⚠️ Errore inizializzazione piattaforma: $e");
      }
    }

    // Inizializzazione database con diagnostica
    await _inizializzaDatabaseConDiagnostica();

    // Test automatico ricerca
    await _testRicercaAutomatica();

    if (kDebugMode) {
      debugPrint("\n=== RIEPILOGO INIZIALIZZAZIONE ===");
      debugPrint("Percorso PDF: $gPercorsoPdf");
      debugPrint("Database path: $gDatabasePath");
      debugPrint("Catalogo attivo: $gActiveCatalogDbName");
      debugPrint("===============================\n");
    }

    // Avvia l'app
    runApp(const MyApp());

  } catch (e, stackTrace) {
    debugPrint("\n" + "="*80);
    debugPrint("❌ ERRORE CRITICO DURANTE L'INIZIALIZZAZIONE");
    debugPrint("="*80);
    debugPrint("Errore: $e");
    debugPrint("Stack trace: $stackTrace");

    // Log dettagliato in file su Windows
    if (Platform.isWindows) {
      try {
        final errorLog = File('jamset_error_log.txt');
        final sink = errorLog.openWrite(mode: FileMode.append);
        sink.writeln("="*60);
        sink.writeln("ERRORE ${DateTime.now()}");
        sink.writeln("="*60);
        sink.writeln("Messaggio: $e");
        sink.writeln("Stack trace: $stackTrace");
        sink.writeln("");
        sink.close();
      } catch (fileError) {
        debugPrint("⚠️ Impossibile scrivere log errore: $fileError");
      }
    }

    // Avvia app di errore
    runApp(ErrorApp(
      error: "Errore inizializzazione: ${e.toString()}",
      stackTrace: stackTrace.toString(),
    ));
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
  final String stackTrace;

  const ErrorApp({
    super.key,
    required this.error,
    this.stackTrace = ''
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFFFFF0F0),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
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
                    'L\'app non può essere avviata a causa di un problema con il database.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 20),

                  // Dettaglio errore
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Dettaglio errore:',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          error,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Stack trace (espandibile)
                  if (stackTrace.isNotEmpty)
                    ExpansionTile(
                      title: const Text(
                        'Dettagli tecnici',
                        style: TextStyle(color: Colors.blue),
                      ),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(4),
                          ),
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

                  const SizedBox(height: 30),

                  // Pulsanti azione
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          // Tentativo di riavvio
                          main();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text("Riprova"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: () {
                          // Esci dall'app
                          if (Platform.isAndroid) {
                            SystemNavigator.pop();
                          } else {
                            exit(0);
                          }
                        },
                        icon: const Icon(Icons.exit_to_app),
                        label: const Text("Esci"),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Informazioni piattaforma
                  Text(
                    'Piattaforma: ${Platform.operatingSystem} • ${DateTime.now()}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}