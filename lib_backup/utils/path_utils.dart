// lib/utils/path_utils.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:jamsetgemini/main.dart'; // per gPercorsoPdf

class PathUtils {
  static Future<String> getPlatformAppDocumentsPath() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final dir = await getApplicationDocumentsDirectory();
      return dir.path;
    } else {
      // Per desktop, usa una directory predefinita o lascia che sia configurata
      return gPercorsoPdf.isNotEmpty
          ? gPercorsoPdf
          : Platform.isWindows
          ? r"C:\JamsetPDF"
          : Platform.isMacOS
          ? "/Users/Shared/JamsetPDF"
          : "/var/JamsetPDF";
    }
  }

  static Future<String> buildPdfPath(String percResto, String volume) async {
    final basePath = gPercorsoPdf.isNotEmpty
        ? gPercorsoPdf
        : await getPlatformAppDocumentsPath();

    return p.join(basePath, percResto, volume);
  }

  static bool isWindowsPath(String path) {
    return path.contains(r'\') ||
        path.startsWith('C:') ||
        path.startsWith('D:') ||
        path.startsWith(RegExp(r'[A-Z]:\\'));
  }

  static String convertToPlatformPath(String path) {
    if (Platform.isWindows) {
      return path.replaceAll('/', r'\');
    } else {
      return path.replaceAll(r'\', '/');
    }
  }
}