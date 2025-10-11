import 'package:flutter/material.dart';
import 'package:jamset/platform/opener_platform_interface.dart';

class TestPdfScreen extends StatefulWidget {
  const TestPdfScreen({super.key});

  @override
  State<TestPdfScreen> createState() => _TestPdfScreenState();
}

class _TestPdfScreenState extends State<TestPdfScreen> {
  final _pathController = TextEditingController();
  final _pageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pre-compiliamo con un percorso di esempio per comodità
    _pathController.text = "/storage/emulated/0/JamsetPDF/PDF REAL BOOK/BookC/Hal Leonard Real Jazz Book.pdf";
    _pageController.text = "78";
  }

  @override
  void dispose() {
    _pathController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _openPdf() {
    final filePath = _pathController.text;
    final page = int.tryParse(_pageController.text) ?? 1;

    if (filePath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Il percorso del file non può essere vuoto.')),
      );
      return;
    }

    print("--- TEST DI APERTURA PDF ---");
    print("File: $filePath");
    print("Pagina: $page");
    
    // Chiamata diretta alla nostra interfaccia nativa
    OpenerPlatformInterface.instance.openPdf(
      filePath: filePath,
      page: page,
      context: context, // Lo passiamo per coerenza, anche se su Android non verrà usato
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Apertura PDF Nativo'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _pathController,
              decoration: const InputDecoration(
                labelText: 'Percorso Completo del File PDF',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pageController,
              decoration: const InputDecoration(
                labelText: 'Numero di Pagina',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Apri PDF'),
              onPressed: _openPdf,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


