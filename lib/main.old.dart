import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Se usata
import 'dart:io' show Platform; // Per rilevamento OS e percorsi
import 'package:flutter/foundation.dart' show kIsWeb; // Per rilevamento OS
import 'package:sqflite_common_ffi/sqflite_ffi.dart'; // Importa questo
import 'database/database_helper.dart';
import 'screens/main_screen.dart'; // O la tua schermata principale effettiva
// import 'screens/csv_viewer_screen.dart'; // Se diversa da MainScreen e la usi

Map<String, String> appSystemConfig = {};

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // --- INIZIALIZZAZIONE SQFLITE FFI PER DESKTOP ---
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    // Inizializza la factory per FFI
    sqfliteFfiInit();
    // Imposta la database factory globale per usare l'implementazione FFI
    databaseFactory = databaseFactoryFfi;
  }
  // --- FINE INIZIALIZZAZIONE SQFLITE FFI ---
  // --- Logica di Rilevamento Piattaforma (dal tuo vecchio main) ---
  String platformTypeForInfo;
  String osDetailsForInfo = "";
  if (kIsWeb) {
    platformTypeForInfo = "Web";
    osDetailsForInfo = "Esecuzione in un browser web.";
  } else {
    platformTypeForInfo = "Nativa";
    try {
      if (Platform.isAndroid) {
        osDetailsForInfo = "Sistema Operativo: Android";
      } else if (Platform.isIOS) {
        osDetailsForInfo = "Sistema Operativo: iOS";
      } else if (Platform.isWindows) {
        osDetailsForInfo = "Sistema Operativo: Windows";
      } else if (Platform.isLinux) {
        osDetailsForInfo = "Sistema Operativo: Linux";
      } else if (Platform.isMacOS) {
        osDetailsForInfo = "Sistema Operativo: macOS";
      } else {
        osDetailsForInfo = "Sistema Operativo: Sconosciuto (Nativo)";
      }
    } catch (e) {
      osDetailsForInfo = "Errore nel rilevare OS nativo: $e";
    }
  }
  print("===== INFORMAZIONI PIATTAFORMA APP (main.dart) =====");
  print("Tipo di Piattaforma: $platformTypeForInfo");
  print(osDetailsForInfo);
  print("===================================================");
  // --- Fine Logica Rilevamento Piattaforma ---


  try {
    await DatabaseHelper.instance.database;
    appSystemConfig = await DatabaseHelper.instance.getAllSystemData();

    print("--- Dati di Sistema Caricati in main() ---");
    appSystemConfig.forEach((key, value) {
      print("$key: $value");
    });
    print("---------------------------------------");

  } catch (e) {
    print("Errore durante l'inizializzazione del database o il caricamento dei dati di sistema: $e");
    // Considera di mostrare un errore all'utente o usare valori di fallback
    // In questo esempio, appSystemConfig potrebbe rimanere vuota o parziale
    // Potresti voler popolare appSystemConfig con valori di default hardcodati qui
    // se il caricamento dal DB fallisce, per garantire che l'app possa comunque partire.
    // Esempio di fallback (molto basico):
    if (appSystemConfig.isEmpty) {
      print("Caricamento da DB fallito. Uso valori di fallback per appSystemConfig.");
      appSystemConfig['appName'] = 'JamSet App (Fallback)';
      if (Platform.isWindows) {
        appSystemConfig['basePdfPath'] = r'C:\DefaultJamsetPDF\';
      } else if (Platform.isAndroid) {
        appSystemConfig['basePdfPath'] = '/storage/emulated/0/Documents/DefaultJamsetPDF/';
      }
      // ... altri fallback necessari
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    String appNameFromDb = appSystemConfig['appName'] ?? 'App Spartiti (Default)';

    // Potresti voler recuperare il percorso PDF corretto qui basandoti sulla piattaforma
    // e passarlo alla tua schermata home se necessario.
    // Esempio:
    // String currentPlatformPdfPath = "";
    // if (kIsWeb) {
    //   currentPlatformPdfPath = appSystemConfig['basePdfPathWeb'] ?? "/web/pdf/";
    // } else if (Platform.isWindows) {
    //   currentPlatformPdfPath = appSystemConfig['basePdfPathWindows'] ?? r"C:\JamsetPDF\";
    // } else if (Platform.isAndroid) {
    //   currentPlatformPdfPath = appSystemConfig['basePdfPathAndroid'] ?? "/storage/emulated/0/Download/JamsetPDF/";
    // } // etc.


    return MaterialApp(
      title: appNameFromDb,
      // title: 'JamSet App',
      theme: ThemeData(
        // Il tuo tema personalizzato dal vecchio main.dart
        primarySwatch: Colors.blueGrey,
        // ... altre tue configurazioni del tema
      ),
      home: const MainScreen(), // O la tua schermata home effettiva
      // Se MainScreen necessita di config:
      // home: MainScreen(config: appSystemConfig, defaultPdfPath: currentPlatformPdfPath),
    );
  }
}

