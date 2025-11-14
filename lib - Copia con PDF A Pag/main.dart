// lib/main.dart
import 'package:flutter/material.dart';
import 'package:jamset/screens/main_screen.dart';
import 'dart:io' show File, Platform;
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:jamset/platform/opener_platform_interface.dart';
import 'package:jamset/platform/android_opener.dart';
import 'package:jamset/platform/windows_opener.dart';

// Chiave globale per accedere al Navigator
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Importa il tuo helper
Map<String, String> appSystemConfig = {};

void main() {
  // --- Configurazione del lettore PDF per Windows ---
  if (Platform.isWindows) {
    // 1. Percorso di override specifico dell'utente (il tuo "Acrobat 9 Pro")
    //    Modifica questa riga se sposti o cambi il tuo lettore PDF preferito.
    const userSpecificViewerPath = r"C:\Program Files (x86)\Adobe\Acrobat 9.0\Acrobat\Acrobat.exe";

    // 2. Percorso di default (il comune "Acrobat Reader DC" gratuito)
    const defaultViewerPath = r"C:\Program Files\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe";

    // 3. Logica di selezione: controlla se il file specificato dall'utente esiste.
    if (File(userSpecificViewerPath).existsSync()) {
      // Se esiste, usa il percorso dell'utente.
      appSystemConfig['pdfViewerPath'] = userSpecificViewerPath;
      if (kDebugMode) {
        print("Lettore PDF personalizzato trovato: $userSpecificViewerPath");
      }
    } else {
      // Altrimenti, usa il percorso di default.
      appSystemConfig['pdfViewerPath'] = defaultViewerPath;
      if (kDebugMode) {
        print("Lettore PDF personalizzato non trovato. Uso il default: $defaultViewerPath");
      }
    }
  }

  // Inizializzazione specifica della piattaforma
  if (kIsWeb) {
    // Se avessi un'implementazione web, la imposteresti qui
    // OpenerPlatformInterface.instance = WebOpener(); 
  } else {
    try {
      if (Platform.isAndroid) {
        OpenerPlatformInterface.instance = AndroidOpener();
      } else if (Platform.isWindows) {
        OpenerPlatformInterface.instance = WindowsOpener();
      }
      // Aggiungi altri 'else if' per altre piattaforme come iOS, Linux, MacOS se necessario
    } catch (e) {
      if (kDebugMode) {
        print("Errore durante l'inizializzazione della piattaforma: $e");
      }
    }
  }

  // Rilevamento piattaforma
  String platformType;
  // platform

  String osDetails = "";  if (kIsWeb) {
    platformType = "Web";
    osDetails = "Esecuzione in un browser web.";
  } else {
    platformType = "Nativa";
    try {
      if (Platform.isAndroid) {
        osDetails = "Sistema Operativo: Android";
      } else if (Platform.isIOS) {
        osDetails = "Sistema Operativo: iOS";
      } else if (Platform.isWindows) {
        osDetails = "Sistema Operativo: Windows";
      } else if (Platform.isLinux) {
        osDetails = "Sistema Operativo: Linux";
      } else if (Platform.isMacOS) {
        osDetails = "Sistema Operativo: macOS";
      } else {
        osDetails = "Sistema Operativo: Sconosciuto (Nativo)";
      }
    } catch (e) {
      osDetails = "Errore nel rilevare OS nativo: $e";
    }
  }

  if (kDebugMode) {
    print("===== INFORMAZIONI PIATTAFORMA APP =====");
    print("Tipo di Piattaforma: $platformType");
    print(osDetails);
    print("========================================");
  }

  // Esegui la tua app Flutter come al solito
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // Assegna la chiave globale al Navigator
      title: 'JamSet App', // O il titolo che preferisci
      theme: ThemeData(
        // Il tuo tema personalizzato, se ne hai uno
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueGrey, // Usa il tuo colore principale come "seme"

// Puoi anche sovrascrivere colori specifici se vuoi
          primary: Colors.blueAccent, // Il colore primario per elementi come bottoni, appbar, ecc.
          secondary: Colors.amber, // Un colore secondario (esempio)
// ... e molti altri colori come surface, background, error, etc.
        ),
      ),
      // LA MODIFICA CHIAVE È QUI:
      // Imposta MainScreen come la prima schermata che l'utente vede
      home: const MainScreen(),
    );
  }
}
