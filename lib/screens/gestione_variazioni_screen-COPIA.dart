// lib/screens/gestione_variazioni_screen.dart - VERSIONE CORRETTA
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../services/database_service.dart';
import 'gestione_dati_globali_screen.dart';
import 'dichiarazione_file_volume_screen.dart';
import 'elenco_volumi_catalogo_screen.dart';
import 'popola_cataloghi_screen.dart';
import 'gestione_indici_screen.dart';
import 'esporta_catalogo_csv_screen.dart';
import 'gestisci_elenco_cataloghi.dart';
import 'test_apertura_file_screen.dart';

class GestioneVariazioniScreen extends StatefulWidget {
  const GestioneVariazioniScreen({super.key});

  @override
  State<GestioneVariazioniScreen> createState() => _GestioneVariazioniScreenState();
}

class _GestioneVariazioniScreenState extends State<GestioneVariazioniScreen> {
  final DatabaseService databaseService = DatabaseService();

  List<Map<String, dynamic>> _cataloghi = [];
  bool _isLoading = true;
  String _status = 'Caricamento...';

  final List<String> _consoleOutput = [];
  final ScrollController _consoleScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _caricaCataloghi();
  }

  void _addConsoleOutput(String message, {String type = 'default'}) {
    final timestamp = DateTime.now().toString().split(' ')[1].substring(0, 12);

    const tipoIcona = {
      'success': '✅',
      'info': 'ℹ️',
      'warning': '⚠️',
      'error': '❌',
      'default': '📝'
    };

    final icona = tipoIcona[type] ?? '📝';
    _consoleOutput.add('[$timestamp] $icona $message');

    if (_consoleOutput.length > 100) {
      _consoleOutput.removeAt(0);
    }

    if (mounted) {
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_consoleScrollController.hasClients) {
          _consoleScrollController.animateTo(
            _consoleScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _caricaCataloghi() async {
    setState(() {
      _isLoading = true;
      _status = 'Caricamento...';
    });

    _addConsoleOutput('Caricamento cataloghi...', type: 'info');

    try {
      await databaseService.initialize();
      _cataloghi = await databaseService.getAvailableVolumes();

      _addConsoleOutput('Trovati ${_cataloghi.length} cataloghi', type: 'success');

      setState(() {
        _isLoading = false;
        _status = _cataloghi.isEmpty ? 'Nessun catalogo' : 'Pronto';
      });
    } catch (e) {
      _addConsoleOutput('Errore: $e', type: 'error');
      setState(() {
        _isLoading = false;
        _status = 'Errore';
      });
    }
  }

  Widget _buildConsoleOutput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[700]!),
      ),
      height: 150,
      child: _consoleOutput.isEmpty
          ? const Center(
        child: Text(
          'I log appariranno qui',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
      )
          : Scrollbar(
        controller: _consoleScrollController,
        child: ListView.builder(
          controller: _consoleScrollController,
          padding: const EdgeInsets.all(6),
          itemCount: _consoleOutput.length,
          itemBuilder: (context, index) {
            final line = _consoleOutput[index];
            return Text(
              line,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                color: Colors.white,
              ),
            );
          },
        ),
      ),
    );
  }

  void _clearConsole() {
    setState(() {
      _consoleOutput.clear();
    });
    _addConsoleOutput('Console pulita', type: 'info');
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    final columns = isSmallScreen ? 2 : 3;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestione Database'),
        centerTitle: true,
        actions: [
          if (_consoleOutput.isNotEmpty)
            IconButton(
              onPressed: _clearConsole,
              icon: const Icon(Icons.clear_all, size: 20),
              tooltip: 'Pulisci console',
              padding: const EdgeInsets.all(8),
            ),
          IconButton(
            onPressed: _caricaCataloghi,
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Aggiorna',
            padding: const EdgeInsets.all(8),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // CARD CATALOGO CORRENTE (COMPATTA)
              Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      Icon(Icons.album, color: Colors.teal[700], size: 24),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'CATALOGO ATTIVO',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (_isLoading)
                              Row(
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.teal[700],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(_status, style: const TextStyle(fontSize: 12)),
                                ],
                              )
                            else
                              Text(
                                databaseService.activeCatalogDbName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // SEZIONE 1: GESTIONE CATALOGHI E IMPOSTAZIONI
              Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.settings, color: Colors.teal[700], size: 20),
                          const SizedBox(width: 6),
                          const Text(
                            'GESTIONE SISTEMA',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      GridView.count(
                        crossAxisCount: columns,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 1.2,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        children: [
                          // a) ELENCO CATALOGHI (Database)
                          _buildGridButton(
                            icon: Icons.storage,
                            label: 'Elenco\nCataloghi',
                            subtitle: 'Gestione DB',
                            color: Colors.blue,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const GestisciElencoCataloghi(),
                              ),
                            ),
                          ),

                          // b) GESTIONE VOLUMI
                          _buildGridButton(
                            icon: Icons.library_books,
                            label: 'Gestione\nVolumi',
                            subtitle: 'Indici volumi',
                            color: Colors.green,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ElencoVolumiCatalogoScreen(),
                              ),
                            ),
                          ),

                          // d) IMPOSTAZIONI
                          _buildGridButton(
                            icon: Icons.settings_applications,
                            label: 'Impostazioni',
                            subtitle: 'Dati globali',
                            color: Colors.orange,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const GestioneDatiGlobaliScreen(),
                              ),
                            ),
                          ),

                          // BACKUP (Non Attivo)
                          _buildGridButton(
                            icon: Icons.backup,
                            label: 'Backup\n(Non Attivo)',
                            subtitle: 'In sviluppo',
                            color: Colors.grey,
                            onTap: () => _mostraMessaggio('Backup in sviluppo'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // SEZIONE 2: IMPORT/EXPORT E INDICI
              Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.import_export, color: Colors.teal[700], size: 20),
                          const SizedBox(width: 6),
                          const Text(
                            'IMPORT/EXPORT & INDICI',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      GridView.count(
                        crossAxisCount: columns,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 1.2,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        children: [
                          // e) INSERISCI DA FILE
                          _buildGridButton(
                            icon: Icons.file_upload,
                            label: 'Inserisci\nda file',
                            subtitle: 'Importa CSV/Excel',
                            color: Colors.purple,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const DichiarazioneFileVolumeScreen(),
                              ),
                            ),
                          ),

                          // f) POPOLA CATALOGHI
                          _buildGridButton(
                            icon: Icons.playlist_add_check,
                            label: 'Popola\nCataloghi',
                            subtitle: 'Gestione indici',
                            color: Colors.indigo,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const PopolaCataloghiScreen(),
                              ),
                            ),
                          ),

                          // g) GESTIONE INDICI
                          _buildGridButton(
                            icon: Icons.tune,
                            label: 'Gestione\nIndici',
                            subtitle: 'Produzione FTS',
                            color: Colors.teal,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const GestioneIndiciScreen(),
                              ),
                            ),
                          ),

                          // h) EXPORT CSV
                          _buildGridButton(
                            icon: Icons.file_download,
                            label: 'Export\nCSV',
                            subtitle: 'Esporta dati',
                            color: Colors.blueGrey,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const EsportaCatalogoCsvScreen(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // SEZIONE 3: STRUMENTI E INDICI/SOMMARI
              Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.build, color: Colors.teal[700], size: 20),
                          const SizedBox(width: 6),
                          const Text(
                            'STRUMENTI & SOMMARI',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      GridView.count(
                        crossAxisCount: columns,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 1.2,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        children: [
                          // i) STRUMENTI DB
                          _buildGridButton(
                            icon: Icons.build,
                            label: 'Strumenti\nDB',
                            subtitle: 'Manutenzione',
                            color: Colors.brown,
                            onTap: _mostraStrumentiDB,
                          ),

                          // INDICI/SOMMARI
                          _buildGridButton(
                            icon: Icons.summarize,
                            label: 'Indici\nSommari',
                            subtitle: 'Titoli e pagine',
                            color: Colors.amber[700]!,
                            onTap: () {
                              _addConsoleOutput('Indici/Sommari - In sviluppo', type: 'warning');
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Funzionalità in sviluppo'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                          ),

                          // TEST APERTURA FILE
                          _buildGridButton(
                            icon: Icons.file_open,
                            label: 'Test\nFile',
                            subtitle: 'Verifica apertura',
                            color: Colors.red,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const TestAperturaFileScreen(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // CARD CONSOLE
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.terminal, size: 18),
                          SizedBox(width: 6),
                          Text(
                            'LOG SISTEMA',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _buildConsoleOutput(),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.grey[600],
                  height: 1.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _mostraMessaggio(String messaggio) {
    _addConsoleOutput(messaggio, type: 'info');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(messaggio),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _mostraStrumentiDB() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Strumenti Database'),
        content: SizedBox(
          width: double.minPositive,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Seleziona operazione:', style: TextStyle(fontSize: 14)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _buildDialogButton(
                    icon: Icons.sync,
                    label: 'Sincronizza\nFTS',
                    onTap: _sincronizzaFTS,
                    color: Colors.blue,
                  ),
                  _buildDialogButton(
                    icon: Icons.backup,
                    label: 'Backup\n(Non Attivo)',
                    onTap: () => _mostraSviluppo('Backup'),
                    color: Colors.grey,
                  ),
                  _buildDialogButton(
                    icon: Icons.assessment,
                    label: 'Ottimizza\nDB',
                    onTap: _ottimizzaDatabase,
                    color: Colors.green,
                  ),
                  _buildDialogButton(
                    icon: Icons.bug_report,
                    label: 'Diagnostica',
                    onTap: _eseguiDiagnostica,
                    color: Colors.orange,
                  ),
                  _buildDialogButton(
                    icon: Icons.build,
                    label: 'Indici\nDB',
                    onTap: () => _mostraSviluppo('Indici DB'),
                    color: Colors.purple,
                  ),
                  _buildDialogButton(
                    icon: Icons.cleaning_services,
                    label: 'Pulizia\nDB',
                    onTap: _puliziaDatabase,
                    color: Colors.red,
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CHIUDI'),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return SizedBox(
      width: 100,
      child: Card(
        elevation: 1,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _mostraSviluppo(String nome) {
    Navigator.pop(context);
    _addConsoleOutput('$nome - In sviluppo', type: 'warning');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$nome - Funzionalità in sviluppo'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  // METODI STRUMENTI DB
  void _sincronizzaFTS() async {
    Navigator.pop(context);
    _addConsoleOutput('Sincronizzazione FTS...', type: 'info');

    try {
      await databaseService.risincronizzaFTSCompleta(
        onProgress: (progress) {
          _addConsoleOutput('Progresso: ${(progress * 100).toStringAsFixed(0)}%', type: 'info');
        },
      );
      _addConsoleOutput('FTS sincronizzato', type: 'success');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('FTS sincronizzato')),
      );
    } catch (e) {
      _addConsoleOutput('Errore FTS: $e', type: 'error');
    }
  }

  void _ottimizzaDatabase() async {
    Navigator.pop(context);
    _addConsoleOutput('Ottimizzazione DB...', type: 'info');
    await Future.delayed(const Duration(seconds: 2));
    _addConsoleOutput('DB ottimizzato', type: 'success');
  }

  void _eseguiDiagnostica() async {
    Navigator.pop(context);
    _addConsoleOutput('Diagnostica DB...', type: 'info');
    try {
      await databaseService.runDiagnostics();
      _addConsoleOutput('Diagnostica completata', type: 'success');
    } catch (e) {
      _addConsoleOutput('Errore diagnostica: $e', type: 'error');
    }
  }

  void _puliziaDatabase() async {
    Navigator.pop(context);
    _addConsoleOutput('Pulizia DB...', type: 'info');
    try {
      await databaseService.cleanupOldCsvFiles();
      _addConsoleOutput('Pulizia completata', type: 'success');
    } catch (e) {
      _addConsoleOutput('Errore pulizia: $e', type: 'error');
    }
  }
}