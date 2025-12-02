import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';

class PdfViewerAndroidScreen extends StatelessWidget {
  final String filePath;
  
  const PdfViewerAndroidScreen({super.key, required this.filePath});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Visualizza PDF'),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new),
            onPressed: () => _openWithExternalApp(filePath, context),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.picture_as_pdf, size: 100, color: Colors.red),
            const SizedBox(height: 20),
            Text(
              'File PDF:',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SelectableText(
                filePath,
                style: const TextStyle(fontFamily: 'monospace'),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              icon: const Icon(Icons.open_in_browser),
              label: const Text('Apri con app esterna'),
              onPressed: () => _openWithExternalApp(filePath, context),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _openWithExternalApp(String path, BuildContext context) async {
    final result = await OpenFile.open(path);
    
    if (result.type != ResultType.done) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore: ${result.message}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
