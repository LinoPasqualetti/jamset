// File: lib/platform/file_opener_stub.dart
// Questo file serve come segnaposto vuoto.
import 'package:flutter/widgets.dart';

Future<void> openPdfPlatformSpecific({
  required BuildContext context,
  required String filePath,
  required String pageNumber,
}) async {
  // Lancia un errore se viene chiamato per sbaglio.
  throw UnimplementedError('Funzione non implementata sulla piattaforma corrente');
}
