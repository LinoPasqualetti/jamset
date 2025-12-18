import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:jamsetgemini/main.dart'; // Per accedere a databaseService
import 'package:jamsetgemini/platform/opener_platform_interface.dart';

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
    debugPrint('📂 FILE OPENER - Accesso Diretto al Service');

    // 1. Leggi il percorso base DIRETTAMENTE dal DatabaseService
    // Questo evita di dipendere da variabili globali che potrebbero non essere rinfrescate
    String cleanBase = databaseService.percorsoPdf.trim();
    String cleanResto = percResto.trim();

    // Fallback di sicurezza estrema
    if (cleanBase.isEmpty) {
      debugPrint('⚠️ ERRORE: percorsoPdf nel service è VUOTO. Tento recupero da gPercorsoPdf.');
      cleanBase = gPercorsoPdf.trim();
    }

    // Se è ancora vuoto, il sistema non è configurato
    if (cleanBase.isEmpty) {
      debugPrint('❌ ERRORE FATALE: Nessun percorso PDF configurato nel sistema.');
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
      final file = File(fullPath);
      if (await file.exists()) {
        debugPrint('✅ File trovato. Apertura in corso...');
        await OpenerPlatformInterface.instance.openPdf(
          context: context,
          filePath: fullPath,
          page: page,
        );
      } else {
        debugPrint('❌ File NON trovato in: $fullPath');
        if (context.mounted) {
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
      }
    } catch (e) {
      debugPrint('❌ Errore apertura: $e');
    }
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
