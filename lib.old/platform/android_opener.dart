import 'package:flutter/material.dart';
import 'package:jamset/main.dart'; // Importa main.dart per accedere alla navigatorKey globale
import 'package:jamset/platform/opener_platform_interface.dart';
import 'package:jamset/screens/pdf_viewer_android_screen.dart';

class AndroidOpener implements OpenerPlatformInterface {
  @override
  Future<void> openPdf({
    required String filePath,
    required int page,
    BuildContext? context,
  }) async {
    final navigatorState = navigatorKey.currentState;
    if (navigatorState != null) {
      navigatorState.push(
        MaterialPageRoute(
          builder: (context) => PdfViewerAndroidScreen(
            filePath: filePath,
            initialPage: page,
          ),
        ),
      );
    }
  }
}
