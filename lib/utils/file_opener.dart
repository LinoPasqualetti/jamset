import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:livescore/main.dart'; // Per accedere a databaseService
import 'package:livescore/platform/opener_platform_interface.dart';

class FileOpener {
  /// Apre un file (PDF o qualsiasi altro tipo)
  static Future<void> openFile({
    required BuildContext context,
    required String percResto,
    required String volume,
    required String tipoMulti,
    int page = 1,
  })
  async {
    debugPrint('?? FILE OPENER - Accesso Diretto al Service');

    // 1. Leggi il percorso base DIRETTAMENTE dal DatabaseService
    String cleanBase = databaseService.percorsoPdf.trim();
    String cleanResto = percResto.trim();

    // Fallback di sicurezza estrema
    if (cleanBase.isEmpty) {
      debugPrint('?? ERRORE: percorsoPdf nel service è VUOTO. Tento recupero da gPercorsoPdf.');
      cleanBase = gPercorsoPdf.trim();
    }

    if (cleanBase.isEmpty) {
      debugPrint('? ERRORE FATALE: Nessun percorso PDF configurato nel sistema.');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Errore: Percorso PDF non configurato. Vai in Impostazioni.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // 2. Normalizzazione separatori
    if (Platform.isWindows) {
      cleanBase = cleanBase.replaceAll('/', r'\');
      cleanResto = cleanResto.replaceAll('/', r'\');
      cleanBase = cleanBase.replaceAll(RegExp(r'\\+$'), '');
      cleanResto = cleanResto.replaceAll(RegExp(r'^\\+|\\+$'), '');
    } else {
      cleanBase = cleanBase.replaceAll(r'\', '/');
      cleanResto = cleanResto.replaceAll(r'\', '/');
      cleanBase = cleanBase.replaceAll(RegExp(r'/+$'), '');
      cleanResto = cleanResto.replaceAll(RegExp(r'^/+|/+$'), '');
    }

    debugPrint('Base: "$cleanBase"');
    debugPrint('Resto: "$cleanResto"');
    debugPrint('Volume: "$volume"');

    // 3. Composizione percorso
    final fullPath = p.join(cleanBase, cleanResto, volume);
    debugPrint('Percorso finale: "$fullPath"');

    // 4. Verifica esistenza e apertura
    try {
      final fileType = await FileSystemEntity.type(fullPath);
      
      if (fileType != FileSystemEntityType.notFound) {
        debugPrint('? Elemento trovato ($fileType). Apertura in corso...');
        
        if (fileType == FileSystemEntityType.directory) {
          // Se è una directory, apriamo con il file manager (su Windows)
          await _openDirectory(fullPath);
        } else {
          // Se è un file, apriamo con il visualizzatore
          // Se page è 0 o null, lo passiamo come 1 o evitiamo il parametro se il visualizzatore lo permette
          int effectivePage = (page <= 0) ? 1 : page;
          
          await OpenerPlatformInterface.instance.openPdf(
            context: context,
            filePath: fullPath,
            page: effectivePage,
          );
        }
      } else {
        debugPrint('? File NON trovato in: $fullPath');
        if (context.mounted) {
          _showErrorSnackBar(context, volume, fullPath);
        }
      }
    } catch (e) {
      debugPrint('? Errore apertura: $e');
    }
  }

  static Future<void> _openDirectory(String path) async {
    if (Platform.isWindows) {
      await Process.run('explorer.exe', [path]);
    } else {
      debugPrint('Apertura directory non supportata su questa piattaforma');
    }
  }

  static void _showErrorSnackBar(BuildContext context, String volume, String fullPath) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Impossibile trovare il file:\n$volume'),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'DETTAGLI',
          onPressed: () {
            showDialog(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('Dettaglio Percorso'),
                content: SelectableText('Percorso cercato:\n$fullPath'),
                actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('CHIUDI'))],
              ),
            );
          },
        ),
      ),
    );
  }

  static String getTipoMultiFromRow(Map<String, dynamic> rowData, {String defaultValue = 'PDF'}) {
    final lowerCaseRowData = {for (var k in rowData.keys) k.toLowerCase(): rowData[k]};
    final tipoMulti = lowerCaseRowData['tipomulti'] as String?;
    if (tipoMulti != null && tipoMulti.isNotEmpty) return tipoMulti;
    final tipoDocu = lowerCaseRowData['tipodocu'] as String?;
    if (tipoDocu != null && tipoDocu.isNotEmpty) return tipoDocu;
    return defaultValue;
  }
}
