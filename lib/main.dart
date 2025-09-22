// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// ASSICURATI CHE QUESTO IMPORT SIA CORRETTO PER LA TUA NUOVA MAIN_SCREEN
import 'package:jamset/screens/main_screen.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

void main() {
  // Rilevamento piattaforma
  String platformType;
 // platform

  String osDetails = "";  if (kIsWeb) {
    platformType = "Web";
    osDetails = "Esecuzione in un browser web.";
    print("Tipo di Piattaforma: Platform");
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

  print("===== INFORMAZIONI PIATTAFORMA APP =====");
  print("Tipo di Piattaforma: $platformType");
  print(osDetails);
  print("========================================");

  // Esegui la tua app Flutter come al solito
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JamSet App', // O il titolo che preferisci
      theme: ThemeData(
        // Il tuo tema personalizzato, se ne hai uno
        primarySwatch: Colors.blueGrey, // Esempio
        // ... altre configurazioni del tema
      ),
      // LA MODIFICA CHIAVE È QUI:
      // Imposta MainScreen come la prima schermata che l'utente vede
      home: const MainScreen(),
    );
  }
}