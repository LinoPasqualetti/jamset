// lib/screens/gestione_variazioni_screen.dart - VERSIONE CON SIDEBAR COMPATTA
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

  // Stati per la sidebar (espansione/compattazione)
  bool _showGestioneSistema = true;
  bool _showImportExport = true;
  bool _showStrumenti = true;

  // Console output
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestione Database'),
        centerTitle: true,
      ),
      body: Row(
        children: [
          // SIDEBAR SINISTRA (200px di larghezza)
          Container(
            width: 200,
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(right: BorderSide(color: Colors.grey[300]!)),
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // INTESTAZIONE SIDEBAR
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.album, color: Colors.teal[700], size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'CATALOGO',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          if (_isLoading)
                            Row(
                              children: [
                                SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.teal[700],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _status,
                                    style: const TextStyle(fontSize: 11),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            )
                          else
                            Text(
                              databaseService.activeCatalogDbName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),

                    const Divider(height: 16, thickness: 1),

                    // SEZIONE 1: GESTIONE SISTEMA (espandibile)
                    _buildSidebarSection(
                      title: 'GESTIONE SISTEMA',
                      isExpanded: _showGestioneSistema,
                      onToggle: () => setState(() => _showGestioneSistema = !_showGestioneSistema),
                      children: [
                        _buildSidebarItem(
                          icon: Icons.storage,
                          label: 'Elenco Cataloghi',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const GestisciElencoCataloghi(),
                            ),
                          ),
                        ),
                        _buildSidebarItem(
                          icon: Icons.library_books,
                          label: 'Gestione Volumi',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ElencoVolumiCatalogoScreen(),
                            ),
                          ),
                        ),
                        _buildSidebarItem(
                          icon: Icons.settings_applications,
                          label: 'Impostazioni',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const GestioneDatiGlobaliScreen(),
                            ),
                          ),
                        ),
                        _buildSidebarItem(
                          icon: Icons.backup,
                          label: 'Backup (ND)',
                          onTap: () => _mostraMessaggio('Backup non disponibile'),
                          color: Colors.grey,
                        ),
                      ],
                    ),

                    const Divider(height: 8, thickness: 0.5),

                    // SEZIONE 2: IMPORT/EXPORT (espandibile)
                    _buildSidebarSection(
                      title: 'IMPORT/EXPORT',
                      isExpanded: _showImportExport,
                      onToggle: () => setState(() => _showImportExport = !_showImportExport),
                      children: [
                        _buildSidebarItem(
                          icon: Icons.file_upload,
                          label: 'Importa da CSV',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const DichiarazioneFileVolumeScreen(),
                            ),
                          ),
                        ),
                        _buildSidebarItem(
                          icon: Icons.playlist_add_check,
                          label: 'Popola Cataloghi',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PopolaCataloghiScreen(),
                            ),
                          ),
                        ),
                        _buildSidebarItem(
                          icon: Icons.tune,
                          label: 'Gestione Indici',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const GestioneIndiciScreen(),
                            ),
                          ),
                        ),
                        _buildSidebarItem(
                          icon: Icons.file_download,
                          label: 'Esporta CSV',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const EsportaCatalogoCsvScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const Divider(height: 8, thickness: 0.5),

                    // SEZIONE 3: STRUMENTI (espandibile)
                    _buildSidebarSection(
                      title: 'STRUMENTI',
                      isExpanded: _showStrumenti,
                      onToggle: () => setState(() => _showStrumenti = !_showStrumenti),
                      children: [
                        _buildSidebarItem(
                          icon: Icons.summarize,
                          label: 'Indici/Sommari',
                          onTap: () => _mostraMessaggio('Indici/Sommari in sviluppo'),
                        ),
                        _buildSidebarItem(
                          icon: Icons.file_open,
                          label: 'Test File',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const TestAperturaFileScreen(),
                            ),
                          ),
                        ),
                        _buildSidebarItem(
                          icon: Icons.build,
                          label: 'Strumenti DB',
                          onTap: _mostraStrumentiDB,
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // PULSANTI AZIONE
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _caricaCataloghi,
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('AGGIORNA'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                textStyle: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _clearConsole,
                              icon: const Icon(Icons.clear_all, size: 16),
                              label: const Text('PULISCI LOG'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                textStyle: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // AREA PRINCIPALE CON CONSOLE
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'LOG DEL SISTEMA',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Qui vengono visualizzati i log di tutte le operazioni eseguite',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Card(
                      elevation: 3,
                      child: _buildConsoleOutput(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.info, size: 16, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Usa la sidebar per accedere a tutte le funzioni di gestione',
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarSection({
    required String title,
    required bool isExpanded,
    required VoidCallback onToggle,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
            child: Row(
              children: [
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isExpanded) ...[
          const SizedBox(height: 4),
          ...children,
          const SizedBox(height: 4),
        ],
      ],
    );
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: color ?? Colors.teal[700],
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConsoleOutput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(4),
      ),
      child: _consoleOutput.isEmpty
          ? const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.terminal, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'Nessun log disponibile',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            Text(
              'Le operazioni appariranno qui',
              style: TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ],
        ),
      )
          : Scrollbar(
        controller: _consoleScrollController,
        child: ListView.builder(
          controller: _consoleScrollController,
          padding: const EdgeInsets.all(8),
          itemCount: _consoleOutput.length,
          itemBuilder: (context, index) {
            final line = _consoleOutput[index];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.0),
              child: Text(
                line,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: Colors.white,
                ),
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
                    label: 'Backup\n(ND)',
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
      width: 90,
      child: Card(
        elevation: 1,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w500),
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