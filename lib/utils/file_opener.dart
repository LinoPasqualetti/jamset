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
    String? customBasePath,
  }) async {
    try {
      print('\n📂 FILE OPENER');
      print('Piattaforma: ${Platform.operatingSystem}');
      print('TipoMulti: $tipoMulti');
      print('Volume: $volume');
      print('PercResto: $percResto');

      final basePath = customBasePath ?? gPercorsoPdf;

      if (basePath.isEmpty) {
        _showSnackBar(context, '❌ Percorso base non configurato', Colors.red);
        return;
      }

      if (volume.isEmpty || percResto.isEmpty) {
        _showSnackBar(context, '❌ Volume o PercResto vuoti', Colors.red);
        return;
      }

      final fullPath = _buildFilePath(basePath, percResto, volume);
      print('Percorso: $fullPath');

      final file = File(fullPath);
      final exists = await file.exists();

      if (!exists) {
        _showSnackBar(context, '❌ File non trovato: ${p.basename(volume)}', Colors.red);
        return;
      }

      print('✅ File trovato (${file.lengthSync()} bytes)');

      // Loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        if (_isPdfFile(tipoMulti, volume)) {
          print('📄 Apertura PDF...');
          await OpenerPlatformInterface.instance.openPdf(
            context: context,
            filePath: fullPath,
            page: page,
          );
        } else {
          print('🔧 Apertura con app predefinita...');
          await _openWithSystemDefault(fullPath);
        }

        Navigator.of(context, rootNavigator: true).pop();

      } catch (e) {
        Navigator.of(context, rootNavigator: true).pop();
        _showSnackBar(context, '❌ Errore apertura: ${e.toString()}', Colors.red);
      }

    } catch (e) {
      _showSnackBar(context, '💥 Errore: ${e.toString()}', Colors.red);
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