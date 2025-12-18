import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

class PdfViewerScreen extends StatefulWidget {
  final String filePath;
  final int initialPage;

  const PdfViewerScreen({
    super.key,
    required this.filePath,
    this.initialPage = 0,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  final Completer<PDFViewController> _controller = Completer<PDFViewController>();
  int? totalPages = 0;
  int? currentPage = 0;
  bool isReady = false;
  String errorMessage = '';
  bool _showUI = true;
  bool _isNightMode = false; // Stato per Modalità Notte
  
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    currentPage = widget.initialPage;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _toggleUI() {
    setState(() {
      _showUI = !_showUI;
    });
  }

  void _handleKeyEvent(KeyEvent event) async {
    if (event is KeyDownEvent) {
      final controller = await _controller.future;
      if (event.logicalKey == LogicalKeyboardKey.arrowDown || 
          event.logicalKey == LogicalKeyboardKey.pageDown ||
          event.logicalKey == LogicalKeyboardKey.space ||
          event.logicalKey == LogicalKeyboardKey.arrowRight) {
        if (currentPage! < totalPages! - 1) {
          controller.setPage(currentPage! + 1);
        }
      } 
      else if (event.logicalKey == LogicalKeyboardKey.arrowUp || 
               event.logicalKey == LogicalKeyboardKey.pageUp ||
               event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        if (currentPage! > 0) {
          controller.setPage(currentPage! - 1);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isNightMode ? Colors.black : Colors.grey[200],
      appBar: _showUI 
        ? AppBar(
            backgroundColor: Colors.black.withOpacity(0.8),
            foregroundColor: Colors.white,
            elevation: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.filePath.split('/').last,
                  style: const TextStyle(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
                if (isReady)
                  Text(
                    'Pagina ${currentPage! + 1} di $totalPages',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
              ],
            ),
            actions: [
              // Tasto Modalità Notte
              IconButton(
                icon: Icon(_isNightMode ? Icons.light_mode : Icons.dark_mode),
                onPressed: () => setState(() => _isNightMode = !_isNightMode),
                tooltip: 'Modalità Notte',
              ),
              IconButton(
                icon: const Icon(Icons.arrow_upward),
                onPressed: isReady && currentPage! > 0
                    ? () async {
                        final controller = await _controller.future;
                        controller.setPage(currentPage! - 1);
                      }
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.arrow_downward),
                onPressed: isReady && currentPage! < totalPages! - 1
                    ? () async {
                        final controller = await _controller.future;
                        controller.setPage(currentPage! + 1);
                      }
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          )
        : null,
      extendBodyBehindAppBar: true,
      body: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: GestureDetector(
          onTap: _toggleUI, 
          child: Stack(
            children: <Widget>[
              PDFView(
                filePath: widget.filePath,
                enableSwipe: true,
                swipeHorizontal: false, 
                autoSpacing: true,      
                pageFling: false,       
                pageSnap: false,
                nightMode: _isNightMode, // Applicazione Modalità Notte
                defaultPage: widget.initialPage,
                fitPolicy: FitPolicy.WIDTH, 
                onRender: (pages) {
                  setState(() {
                    totalPages = pages;
                    isReady = true;
                  });
                },
                onError: (error) {
                  setState(() => errorMessage = error.toString());
                },
                onPageError: (page, error) {
                  setState(() => errorMessage = '$page: $error');
                },
                onViewCreated: (PDFViewController pdfViewController) {
                  _controller.complete(pdfViewController);
                },
                onPageChanged: (int? page, int? total) {
                  setState(() => currentPage = page);
                },
              ),
              
              // UI SOVRAPPOSTA: Slider per navigazione rapida
              if (_showUI && isReady && totalPages! > 1)
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 80,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.description, color: Colors.white, size: 18),
                        Expanded(
                          child: Slider(
                            value: currentPage!.toDouble(),
                            min: 0,
                            max: totalPages!.toDouble() - 1,
                            divisions: totalPages! - 1,
                            activeColor: Colors.tealAccent,
                            inactiveColor: Colors.white24,
                            label: 'Pagina ${currentPage! + 1}',
                            onChanged: (double value) async {
                              final controller = await _controller.future;
                              controller.setPage(value.toInt());
                            },
                          ),
                        ),
                        Text(
                          '${currentPage! + 1}/${totalPages}',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),

              if (_showUI && isReady)
                Positioned(
                  bottom: 20,
                  right: 20,
                  child: FloatingActionButton.small(
                    backgroundColor: Colors.teal.withOpacity(0.8),
                    onPressed: () async {
                      final controller = await _controller.future;
                      _showJumpToPageDialog(context, controller);
                    },
                    child: const Icon(Icons.search, color: Colors.white),
                  ),
                ),

              if (errorMessage.isNotEmpty)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.white.withOpacity(0.9),
                    child: Text('Errore: $errorMessage', style: const TextStyle(color: Colors.red)),
                  ),
                ),
              
              if (!isReady && errorMessage.isEmpty)
                const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      ),
    );
  }

  void _showJumpToPageDialog(BuildContext context, PDFViewController controller) {
    final TextEditingController _pageController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vai alla pagina'),
        content: TextField(
          controller: _pageController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: '1-$totalPages'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
          TextButton(
            onPressed: () {
              final page = int.tryParse(_pageController.text);
              if (page != null && page > 0 && page <= totalPages!) {
                controller.setPage(page - 1);
                Navigator.pop(context);
              }
            },
            child: const Text('VAI'),
          ),
        ],
      ),
    );
  }
}
