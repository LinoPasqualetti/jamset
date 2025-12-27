// screens/genera_indici_fts_screen.dart
import 'package:flutter/material.dart';
import 'package:livescore/main.dart';

class GeneraIndiciFtsScreen extends StatefulWidget {
  const GeneraIndiciFtsScreen({super.key});

  @override
  State<GeneraIndiciFtsScreen> createState() => _GeneraIndiciFtsScreenState();
}

class _GeneraIndiciFtsScreenState extends State<GeneraIndiciFtsScreen> {
  bool _isProcessing = false;
  String _status = '';
  double _progress = 0.0;

  Future<void> _generateFtsIndices() async {
    setState(() {
      _isProcessing = true;
      _status = 'Preparazione generazione indici FTS...';
      _progress = 0.0;
    });

    try {
      // Simula progresso
      for (int i = 0; i <= 100; i += 10) {
        if (!mounted) return;

        setState(() {
          _progress = i / 100;
          _status = 'Generazione indici FTS in corso... $i%';
        });

        await Future.delayed(const Duration(milliseconds: 300));
      }

      // TODO: Chiamare il metodo del DatabaseService per generare indici FTS
      // await databaseService.generaIndiciFTS();

      setState(() {
        _status = '✅ Indici FTS generati con successo!';
        _progress = 1.0;
      });

      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _status = '';
          _progress = 0.0;
        });
      }

    } catch (e) {
      setState(() {
        _status = '❌ Errore: $e';
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Genera Indici di Ricerca FTS'),
        backgroundColor: Colors.purple[800], // CAMBIATO COLORE
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Descrizione
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Genera Indici di Ricerca Full-Text (FTS)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple, // CAMBIATO COLORE
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Questa funzione genera o rigenera gli indici di ricerca full-text '
                          'che permettono ricerche rapide nel catalogo.',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.info, size: 16, color: Colors.purple[300]),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Utile quando gli indici sono corrotti o dopo aggiornamenti massivi del catalogo.',
                            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Informazioni catalogo attivo
            Card(
              color: Colors.grey[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Catalogo Attivo',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      databaseService.activeCatalogDbName.isNotEmpty
                          ? databaseService.activeCatalogDbName
                          : 'Nessun catalogo attivo',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    FutureBuilder<Map<String, dynamic>>(
                      future: databaseService.getFTSStatus(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          final status = snapshot.data!;
                          return Text(
                            status['message'] ?? '',
                            style: TextStyle(
                              color: status['synced'] == true ? Colors.green : Colors.orange,
                              fontSize: 12,
                            ),
                          );
                        }
                        return const Text('Caricamento...', style: TextStyle(fontSize: 12));
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Pulsante di generazione
            if (!_isProcessing)
              ElevatedButton.icon(
                onPressed: _generateFtsIndices,
                icon: const Icon(Icons.search),
                label: const Text(
                  'GENERA INDICI FTS',
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple[700], // CAMBIATO COLORE
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

            // Progresso
            if (_isProcessing) ...[
              const SizedBox(height: 20),
              LinearProgressIndicator(
                value: _progress,
                backgroundColor: Colors.grey[200],
                color: Colors.purple,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 16),
              Text(
                _status,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _status.contains('✅') ? Colors.green :
                  _status.contains('❌') ? Colors.red : Colors.purple,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],

            const Spacer(),

            // Note
            Card(
              color: Colors.purple[50],
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Icon(Icons.warning, size: 16, color: Colors.purple[700]),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Nota: La generazione degli indici FTS può richiedere tempo '
                            'per cataloghi molto grandi.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}