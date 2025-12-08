import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'dart:async';

class PdfViewerScreen extends StatefulWidget {
  final String filePath;
  final int initialPage;

  const PdfViewerScreen({
    super.key,
    required this.filePath,
    this.initialPage = 0, // Le pagine nel viewer sono 0-indexed
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  final Completer<PDFViewController> _controller = Completer<PDFViewController>();
  int? pages = 0;
  bool isReady = false;
  String errorMessage = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.filePath.split('/').last), // Mostra il nome del file
      ),
      body: Stack(
        children: <Widget>[
          PDFView(
            filePath: widget.filePath,
            enableSwipe: true,
            swipeHorizontal: false,
            autoSpacing: false,
            pageFling: true,
            pageSnap: true,
            defaultPage: widget.initialPage,
            fitPolicy: FitPolicy.BOTH,
            preventLinkNavigation: false, // Per futuri link interni
            onRender: (pages) {
              setState(() {
                this.pages = pages;
                isReady = true;
              });
            },
            onError: (error) {
              setState(() {
                errorMessage = error.toString();
              });
              print(error.toString());
            },
            onPageError: (page, error) {
              setState(() {
                errorMessage = '$page: ${error.toString()}';
              });
              print('$page: ${error.toString()}');
            },
            onViewCreated: (PDFViewController pdfViewController) {
              _controller.complete(pdfViewController);
            },
            onPageChanged: (int? page, int? total) {
              // print('page change: $page/$total');
            },
          ),
          errorMessage.isEmpty
              ? !isReady
              ? const Center(
            child: CircularProgressIndicator(),
          )
              : Container()
              : Center(
            child: Text(errorMessage),
          )
        ],
      ),
    );
  }
}
