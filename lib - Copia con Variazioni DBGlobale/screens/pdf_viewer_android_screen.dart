import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path/path.dart' as p; 

/// Una schermata per visualizzare un file PDF locale usando flutter_pdfview.
class PdfViewerAndroidScreen extends StatefulWidget {
  final String filePath;
  final int initialPage;

  const PdfViewerAndroidScreen({
    super.key,
    required this.filePath,
    required this.initialPage,
  });

  @override
  State<PdfViewerAndroidScreen> createState() => _PdfViewerAndroidScreenState();
}

class _PdfViewerAndroidScreenState extends State<PdfViewerAndroidScreen> {
  late PDFViewController _pdfViewController;
  bool _isReady = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(p.basename(widget.filePath)),
      ),
      body: PDFView(
        filePath: widget.filePath,
        enableSwipe: true,
        swipeHorizontal: false,
        autoSpacing: false,
        pageFling: true,
        defaultPage: widget.initialPage - 1, // flutter_pdfview usa pagine 0-based
        onRender: (pages) {
          setState(() {
            _isReady = true;
          });
          print("PDF Renderizzato: $pages pagine totali.");
        },
        onError: (error) {
          print("Errore durante la visualizzazione del PDF: $error");
          // Opzionale: mostra un dialog di errore
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Errore PDF'),
              content: Text('Impossibile caricare il file PDF.\n\nDettagli: $error'),
              actions: [
                TextButton(
                  child: const Text('OK'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          );
        },
        onViewCreated: (PDFViewController pdfViewController) {
          _pdfViewController = pdfViewController;
        },
      ),
    );
  }
}
