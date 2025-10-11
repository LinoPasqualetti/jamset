// file_path_validator.dart
import 'package:flutter/foundation.dart';

import 'dart:io';
import 'package:path/path.dart' as p;

// La classe FilePathResult non cambia
class FilePathResult {
  final bool exists;
  final String? fullPath;
  final String message;
  final bool isSuccess;

  FilePathResult({
    required this.exists,
    this.fullPath,
    required this.message,
    required this.isSuccess,
  });
}

class ValidaPercorso {
  static Future<FilePathResult> checkGenericFilePath({
    required String basePath,
    String? subPath,
    required String fileNameWithExtension,
    required String NumeroPagina, // Mantenuto per coerenza, anche se non usato qui
  }) async {
    // Gestione preliminare degli errori
    if (kIsWeb) {
      return FilePathResult(
        exists: false,
        message: "La verifica dei file non è supportata su web.",
        isSuccess: false,
      );
    }
    if (fileNameWithExtension.isEmpty) {
      return FilePathResult(
          exists: false,
          message: "Il nome del file non può essere vuoto.",
          isSuccess: false);
    }

    // --- LOGICA DI COSTRUZIONE SPECIFICA PER PIATTAFORMA ---

    String effectiveBasePath = basePath;
    String? effectiveSubPath = subPath;

    // 1. GESTIONE SPECIFICA PER MOBILE (Android/iOS)
    if (Platform.isAndroid || Platform.isIOS) {

      if (effectiveBasePath.contains(':')) {
        print("ATTENZIONE: Rilevato un basePath ('$effectiveBasePath') in stile Windows su piattaforma mobile.");
        int colonIndex = effectiveBasePath.indexOf(':');
        effectiveBasePath = effectiveBasePath.substring(colonIndex + 1);
        print("BasePath 'pulito' temporaneamente in: '$effectiveBasePath'");
      }

// === LA TUA NUOVA MODIFICA: APPLICA replaceAll ANCHE AL basePath ===
// Converte i separatori di Windows in separatori POSIX/Android
      effectiveBasePath = effectiveBasePath.replaceAll(r'\', '/');
// =================================================================

// --- FINE DELLA MODIFICA DI PULIZIA DEL basePath ---

      if (effectiveSubPath != null) {
// 1. Sostituisci tutti i backslash con slash
        effectiveSubPath = effectiveSubPath.replaceAll(r'\', '/');

// 2. Rimuovi lo slash iniziale, se presente
        if (effectiveSubPath.startsWith('/')) {
          effectiveSubPath = effectiveSubPath.substring(1);
        }

// 3. Rimuovi lo slash finale, se presente
        if (effectiveSubPath.endsWith('/')) {
          effectiveSubPath = effectiveSubPath.substring(0, effectiveSubPath.length - 1);
        }
      }
      if (kDebugMode) {
        print("Siamo su Mobile. Usiamo la basePath fornita: $effectiveBasePath");
      }
      print("SubPath pulito per mobile: $effectiveSubPath");

    } else if (Platform.isWindows) {
      // Su Windows non facciamo nessuna pulizia
      // if (effectiveSubPath.endsWith('/')) {
      if (effectiveSubPath != null) {
// 1. Sostituisci tutti i backslash con slash
        effectiveSubPath = effectiveSubPath.replaceAll(r'\', '/');

// 2. Rimuovi lo slash iniziale, se presente
        if (effectiveSubPath.startsWith('/')) {
          effectiveSubPath = effectiveSubPath.substring(1);
        }

// 3. Rimuovi lo slash finale, se presente
        if (effectiveSubPath.endsWith('/')) {
          effectiveSubPath = effectiveSubPath.substring(0, effectiveSubPath.length - 1);
        }
      }
      if (kDebugMode) {
        print("Siamo su Mobile. Usiamo la basePath fornita: $effectiveBasePath");
      }
      print("SubPath pulito per mobile: $effectiveSubPath");
      //  effectiveSubPath = effectiveSubPath.substring(0, effectiveSubPath.length - 1);
      // }
      print("Siamo su Windows.  Usiamo la basePath fornita: $effectiveBasePath");
    }

    // 2. ASSEMBLA I PEZZI DEL PERCORSO
    List<String> pathSegments = [effectiveBasePath];
    if (effectiveSubPath != null && effectiveSubPath.isNotEmpty) {
      pathSegments.addAll(p.split(effectiveSubPath));
    }
    pathSegments.add(fileNameWithExtension);

    String fullPath = p.normalize(p.joinAll(pathSegments));
    print("Percorso costruito dal validatore: $fullPath");

    // 3. VERIFICA L'ESISTENZA DEL FILE
    try {
      final file = File(fullPath);
      final bool fileExists = await file.exists();

      return FilePathResult(
        exists: fileExists,
        fullPath: fullPath,
        message: fileExists
            ? 'SUCCESSO: Il file\n$fullPath\nESISTE.'
            : 'ERRORE: Il file\n$fullPath\nNON ESISTE o i permessi sono mancanti.',
        isSuccess: fileExists,
      );
    } catch (e) {
      return FilePathResult(
        exists: false,
        fullPath: fullPath,
        message: 'ERRORE SISTEMA durante la verifica:\n$fullPath\nDettagli: $e',
        isSuccess: false,
      );
    }
  }
}
