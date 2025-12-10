// lib/utils/file_opener.dart - VERSIONE COMPLETA E CORRETTA
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:jamsetgemini/main.dart';
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
    debugPrint('📂 FILE OPENER - Versione ULTRA-SICURA');

// 1. Pulisci TUTTI i separatori
    String cleanBase = gPercorsoPdf.trim();
    String cleanResto = percResto.trim();

// Per Android/Unix
    if (Platform.isAndroid || Platform.isIOS || Platform.isLinux || Platform.isMacOS) {
// Sostituisci tutti i backslash con forward slash
      cleanBase = cleanBase.replaceAll(r'\', '/');
      cleanResto = cleanResto.replaceAll(r'\', '/');

// Rimuovi TUTTI i slash finali
      cleanBase = cleanBase.replaceAll(RegExp(r'/+$'), '');
      cleanResto = cleanResto.replaceAll(RegExp(r'^/+|/+$'), '');
    }
// Per Windows
    else if (Platform.isWindows) {
// Sostituisci tutti i forward slash con backslash
      cleanBase = cleanBase.replaceAll('/', r'\');
      cleanResto = cleanResto.replaceAll('/', r'\');

// Rimuovi TUTTI i backslash finali
      cleanBase = cleanBase.replaceAll(RegExp(r'\\+$'), '');
      cleanResto = cleanResto.replaceAll(RegExp(r'^\\+|\\+$'), '');
    }

    debugPrint('Base: "$cleanBase"');
    debugPrint('Resto: "$cleanResto"');
    debugPrint('Volume: "$volume"');

// 2. Usa SEMPRE path.join (gestisce automaticamente i separatori)
    final fullPath = p.join(cleanBase, cleanResto, volume);
    debugPrint('Percorso finale (path.join): "$fullPath"');

// 3. Verifica e apri
    try {
      final file = File(fullPath);
      final exists = await file.exists();

      if (exists) {
        debugPrint('✅ File trovato');
        await OpenerPlatformInterface.instance.openPdf(
          context: context,
          filePath: fullPath,
          page: page,
        );
      } else {
        debugPrint('❌ File non trovato');

// Mostra percorso alternativo debug
        debugPrint('DEBUG Percorsi alternativi:');
        debugPrint('  1. $cleanBase/$cleanResto/$volume');
        if (Platform.isWindows) {
          debugPrint('  2. $cleanBase\\$cleanResto\\$volume');
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File non trovato: $volume'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Errore: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ========== METODI PRIVATI (DEVONO ESSERE STATIC!) ==========

  static String _buildFilePath(String basePath, String percResto, String volume) {
    String cleanBase = basePath.trim();
    String cleanResto = percResto.trim();
    String cleanVolume = volume.trim();

    if (Platform.isWindows) {
      cleanBase = cleanBase.replaceAll('/', r'\');
      cleanResto = cleanResto.replaceAll('/', r'\');
      if (cleanBase.endsWith(r'\')) cleanBase = cleanBase.substring(0, cleanBase.length - 1);
      if (cleanResto.startsWith(r'\')) cleanResto = cleanResto.substring(1);
      return '$cleanBase\\$cleanResto\\$cleanVolume';
    } else {
      cleanBase = cleanBase.replaceAll(r'\', '/');
      cleanResto = cleanResto.replaceAll(r'\', '/');
      if (cleanBase.endsWith('/')) cleanBase = cleanBase.substring(0, cleanBase.length - 1);
      if (cleanResto.startsWith('/')) cleanResto = cleanResto.substring(1);
      return '$cleanBase/$cleanResto/$cleanVolume';
    }
  }

  static bool _isPdfFile(String tipoMulti, String volume) {
    if (tipoMulti.toUpperCase().contains('PDF') || tipoMulti.toUpperCase().contains('PD')) return true;
    if (volume.toLowerCase().endsWith('.pdf')) return true;
    return false;
  }

  static Future<void> _openWithSystemDefault(String filePath) async {
    if (Platform.isWindows) {
      await Process.run('start', ['', filePath], runInShell: true);
    } else if (Platform.isMacOS) {
      await Process.run('open', [filePath]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [filePath]);
    } else {
      throw Exception('Apertura file generici non supportata');
    }
  }

  static void _showSnackBar(BuildContext context, String message, Color color) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  static String getTipoMultiFromRow(Map<String, dynamic> rowData, {String defaultValue = 'PDF'}) {
    final lowerCaseRowData = {for (var k in rowData.keys) k.toLowerCase(): rowData[k]};

    final tipoMulti = lowerCaseRowData['tipomulti'] as String?;
    if (tipoMulti != null && tipoMulti.isNotEmpty) return tipoMulti;

    final tipoDocu = lowerCaseRowData['tipodocu'] as String?;
    if (tipoDocu != null && tipoDocu.isNotEmpty) return tipoDocu;

    final volume = lowerCaseRowData['volume'] as String?;
    if (volume != null) {
      if (volume.toLowerCase().endsWith('.pdf')) return 'PDF';
      if (volume.toLowerCase().endsWith('.doc') || volume.toLowerCase().endsWith('.docx')) return 'DOC';
      if (volume.toLowerCase().endsWith('.jpg') || volume.toLowerCase().endsWith('.jpeg')) return 'JPG';
      if (volume.toLowerCase().endsWith('.png')) return 'PNG';
      if (volume.toLowerCase().endsWith('.txt')) return 'TXT';
    }

    return defaultValue;
  }
}