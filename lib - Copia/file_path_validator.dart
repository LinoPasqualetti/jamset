// file_path_validator.dart
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;

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

/// Classe tecnica per validare percorsi di file su piattaforme NATIVE (non web).
/// Si aspetta percorsi già preparati per la piattaforma corrente.
class ValidaPercorso {
  static Future<FilePathResult> checkGenericFilePath({
    required String basePath,
    String? subPath,
    required String fileNameWithExtension,
  }) async {
    // 1. Questa classe non opera su web.
    if (kIsWeb) {
      return FilePathResult(exists: false, message: "La verifica dei file nativi non è supportata su web.", isSuccess: false);
    }

    // 2. Controlli preliminari sugli input
    if (fileNameWithExtension.isEmpty) {
      return FilePathResult(exists: false, message: "Il nome del file non può essere vuoto.", isSuccess: false);
    }

    // 3. Pulisci il subPath per una gestione uniforme
    String? cleanSubPath = subPath;
    if (cleanSubPath != null) {
      cleanSubPath = cleanSubPath.replaceAll(r'\', '/'); // Uniforma i separatori
      if (cleanSubPath.startsWith('/')) cleanSubPath = cleanSubPath.substring(1);
      if (cleanSubPath.endsWith('/')) cleanSubPath = cleanSubPath.substring(0, cleanSubPath.length - 1);
    }

    // 4. Assembla i pezzi del percorso usando il pacchetto 'path'
    // Questo pacchetto usa automaticamente i separatori corretti ('\' o '/')
    // in base alla piattaforma su cui l'app sta girando.
    List<String> pathSegments = [basePath];
    if (cleanSubPath != null && cleanSubPath.isNotEmpty) {
      pathSegments.addAll(p.split(cleanSubPath));
    }
    pathSegments.add(fileNameWithExtension);

    String fullPath = p.normalize(p.joinAll(pathSegments));
    print("Percorso nativo costruito dal validatore: $fullPath");

    // 5. Verifica l'esistenza del file sul file system locale
    try {
      final file = File(fullPath);
      final bool fileExists = await file.exists();
      return FilePathResult(
        exists: fileExists,
        fullPath: fullPath,
        message: fileExists ? 'SUCCESSO: Il file\n$fullPath\nESISTE.' : 'ERRORE: Il file\n$fullPath\nNON ESISTE o i permessi sono mancanti.',
        isSuccess: fileExists,
      );
    } catch (e) {
      return FilePathResult(exists: false, fullPath: fullPath, message: 'ERRORE SISTEMA durante la verifica:\n$fullPath\nDettagli: $e', isSuccess: false);
    }
  }
}

