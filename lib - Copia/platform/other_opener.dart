// File: lib/platform/other_opener.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'opener_platform_interface.dart';

// Implementazione CONCRETA per Windows e altre piattaforme non-Android.
class OtherOpener implements OpenerPlatformInterface {
  @override
  Future<void> openPdf({
    required BuildContext context,
    required String filePath,
    required int page,
  }) async {
    const acrobatPath = 'C:\\Program Files\\Adobe\\Acrobat DC\\Acrobat\\Acrobat.exe';
    if (Platform.isWindows && await File(acrobatPath).exists()) {
      await Process.run(acrobatPath, ['/A', 'page=$page', filePath]);
    } else {
      await OpenFile.open(filePath);
      if (Platform.isWindows && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Adobe non trovato. PDF aperto alla prima pagina.')));
      }
    }
  }
}
