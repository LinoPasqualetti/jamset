import 'dart:io';
import 'package:flutter/material.dart';
import 'package:jamset/main.dart'; // Importa main.dart per accedere alla configurazione
import 'package:jamset/platform/opener_platform_interface.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart'; // Importa il pacchetto url_launcher

class WindowsOpener implements OpenerPlatformInterface {
  @override
  Future<void> openPdf({
    required String filePath,
    required int page,
    BuildContext? context,
  }) async {
    // Ottieni l'estensione del file in minuscolo.
    final fileExtension = p.extension(filePath).toLowerCase();

    // --- DEBUG ---
    print("--- DEBUG APERTURA FILE ---");
    print("File: $filePath");
    print("Estensione: $fileExtension");
    print("---------------------------");

    try {
      if (fileExtension == '.pdf') {
        // CASO 1: È un file PDF. Usa il lettore configurato.
        final pdfViewerPath = appSystemConfig['pdfViewerPath'] ?? '';
        if (pdfViewerPath.isEmpty) {
          if(context != null) _showErrorDialog(context, 'Errore di Configurazione', 'Il percorso del lettore PDF non è stato impostato.');
          return;
        }

        final args = ['/A', 'page=$page', filePath];
        await Process.start(pdfViewerPath, args, runInShell: false);

      } else {
        // CASO 2: NON è un file PDF. Usa url_launcher per l'apertura di default.
        final Uri fileUri = Uri.file(filePath);
        
        if (await canLaunchUrl(fileUri)) {
          await launchUrl(fileUri);
        } else {
          throw Exception('Impossibile lanciare l\'URL per il file: $filePath');
        }
      }
    } catch (e) {
      if (context != null) {
        _showErrorDialog(
          context,
          'Eccezione Apertura File',
          '''Si è verificato un errore imprevisto durante l'apertura del file.\n\nDettagli: $e''',
        );
      }
    }
  }

  Future<void> _showErrorDialog(BuildContext context, String title, String content) {
    return showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(child: Text(content)),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        );
      },
    );
  }
}
