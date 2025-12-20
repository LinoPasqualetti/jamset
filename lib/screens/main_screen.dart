// lib/screens/main_screen.dart
import 'package:flutter/material.dart';
import 'package:jamsetgemini/screens/csv_viewer_screen.dart';
import 'package:jamsetgemini/screens/funzioni_variazione_dati_screen.dart';
import 'package:jamsetgemini/screens/gestione_variazioni_screen.dart';
import 'package:jamsetgemini/services/database_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final DatabaseService _databaseService = DatabaseService();
  Map<String, dynamic> _currentVolume = {};

  @override
  void initState() {
    super.initState();
    _loadCurrentVolume();
  }

  Future<void> _loadCurrentVolume() async {
    try {
      final volume = await _databaseService.getCurrentVolume();
      setState(() {
        _currentVolume = volume;
      });
    } catch (e) {
      debugPrint('Errore caricamento volume corrente: $e');
    }
  }

  void _navigateTo(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildCurrentScreen() {
    switch (_selectedIndex) {
      case 0:
        return HomePage(
          databaseService: _databaseService,
          currentVolume: _currentVolume,
          navigateTo: _navigateTo,
        );
      case 1:
        return CsvViewerScreen();
      case 2:
        return FunzioniVariazioneDatiScreen();
      case 3:
        return GestioneVariazioniScreen();
      default:
        return HomePage(
          databaseService: _databaseService,
          currentVolume: _currentVolume,
          navigateTo: _navigateTo,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildCurrentScreen(),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Ricerca CSV',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.storage_outlined),
            label: 'Ricerca DB',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Gestione',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _navigateTo,
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final DatabaseService databaseService;
  final Map<String, dynamic> currentVolume;
  final Function(int) navigateTo;

  const HomePage({
    Key? key,
    required this.databaseService,
    required this.currentVolume,
    required this.navigateTo,
  }) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Map<String, dynamic> _currentVolume;
  bool _isReindexing = false;

  @override
  void initState() {
    super.initState();
    _currentVolume = widget.currentVolume;
    if (_currentVolume.isEmpty) {
      _loadCurrentVolume();
    }
  }

  Future<void> _loadCurrentVolume() async {
    try {
      final volume = await widget.databaseService.getCurrentVolume();
      setState(() {
        _currentVolume = volume;
      });
    } catch (e) {
      debugPrint('Errore caricamento volume corrente: $e');
    }
  }

  Future<void> _reindexFTS() async {
    setState(() {
      _isReindexing = true;
    });

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.search_off, color: Colors.orange),
            SizedBox(width: 8),
            Text('Reindicizzazione FTS'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Vuoi reindicizzare completamente la ricerca full-text?',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 8),
            if (_currentVolume.isNotEmpty)
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      Text(
                        'Catalogo attivo:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      Text(
                        _currentVolume['nome_catalogo'] as String? ?? 'Sconosciuto',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      Text(
                        'Brani: ${_currentVolume['conteggio_brani'] ?? 0}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            SizedBox(height: 8),
            Text(
              'Questa operazione potrebbe richiedere alcuni secondi.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('ANNULLA'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: Text('REINDICIZZA'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      setState(() {
        _isReindexing = false;
      });
      return;
    }

    try {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Reindicizzazione in corso...'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Attendi mentre il catalogo viene reindicizzato.'),
                SizedBox(height: 16),
                LinearProgressIndicator(
                  value: null,
                  backgroundColor: Colors.grey.shade200,
                ),
                SizedBox(height: 8),
                Text(
                  'Questa operazione potrebbe richiedere alcuni secondi.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          );
        },
      );

      await widget.databaseService.risincronizzaFTSCompleta();

      await _loadCurrentVolume();

      if (context.mounted) {
        Navigator.of(context).pop();
      }

      if (context.mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Successo'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'La ricerca full-text è stata reindicizzata con successo!',
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 12),
                if (_currentVolume.isNotEmpty)
                  Card(
                    color: Colors.green.shade50,
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          Text(
                            'Catalogo aggiornato:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade800,
                            ),
                          ),
                          Text(
                            _currentVolume['nome_catalogo'] as String? ?? 'Sconosciuto',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.green.shade800,
                            ),
                          ),
                          Text(
                            'Brani: ${_currentVolume['conteggio_brani'] ?? 0}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: Text('OK'),
              ),
            ],
          ),
        );
      }

    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.error, color: Colors.red),
                SizedBox(width: 8),
                Text('Errore'),
              ],
            ),
            content: Text(
              'Si è verificato un errore durante la reindicizzazione:\n\n$e',
              style: TextStyle(fontSize: 14),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: Text('CHIUDI'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isReindexing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'JamsetGemini',
              style: TextStyle(
                color: Colors.yellowAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_currentVolume.isNotEmpty)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blueGrey[800]?.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.yellowAccent.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.library_music, size: 16, color: Colors.yellowAccent),
                    SizedBox(width: 6),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentVolume['nome_catalogo'] as String? ?? 'Catalogo',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Brani: ${_currentVolume['conteggio_brani'] ?? 0}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.yellowAccent,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
        backgroundColor: Colors.blueGrey[700],
        foregroundColor: Colors.yellowAccent,
        elevation: 0,
        actions: [
          IconButton(
            icon: _isReindexing
                ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.yellowAccent,
              ),
            )
                : Icon(Icons.search_off, size: 20),
            onPressed: _isReindexing ? null : _reindexFTS,
            tooltip: 'Reindicizza FTS',
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blueGrey[700],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Jamset Gemini',
                    style: TextStyle(
                      color: Colors.yellowAccent,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Gestione Spartiti Musicali',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.home),
              title: Text('Home'),
              onTap: () {
                Navigator.pop(context);
                widget.navigateTo(0);
              },
            ),
            ListTile(
              leading: Icon(Icons.search),
              title: Text('Ricerca CSV'),
              onTap: () {
                Navigator.pop(context);
                widget.navigateTo(1);
              },
            ),
            ListTile(
              leading: Icon(Icons.storage_outlined),
              title: Text('Ricerca DB'),
              onTap: () {
                Navigator.pop(context);
                widget.navigateTo(2);
              },
            ),
            ListTile(
              leading: Icon(Icons.settings),
              title: Text('Gestione'),
              onTap: () {
                Navigator.pop(context);
                widget.navigateTo(3);
              },
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.search_off, color: Colors.orange, size: 20),
              title: Text('Reindicizza FTS'),
              subtitle: Text('Rigenera ricerca full-text'),
              onTap: _isReindexing ? null : _reindexFTS,
              enabled: !_isReindexing,
            ),
          ],
        ),
      ),
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: Image.asset(
              'assets/images/SfondoLibriRBeAebCubista.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Text(
                    'Benvenuto in JamsetGemini!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  SizedBox(height: 40),

                  // PRIMI 3 BOTTONI COMPATTI
                  SizedBox(
                    width: 280,
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.search_outlined, size: 20),
                      label: Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Ricerca CSV',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onPressed: () {
                        widget.navigateTo(1);
                      },
                    ),
                  ),

                  SizedBox(height: 16),

                  SizedBox(
                    width: 280,
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.storage_outlined, size: 20),
                      label: Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Ricerca Database',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        widget.navigateTo(2);
                      },
                    ),
                  ),

                  SizedBox(height: 16),

                  SizedBox(
                    width: 280,
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.edit_document, size: 20),
                      label: Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Gestione Variazioni',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        widget.navigateTo(3);
                      },
                    ),
                  ),

                  SizedBox(height: 30),

                  // BOTTONE REINDICIZZAZIONE FTS (SOTTO GLI ALTRI)
                  SizedBox(
                    width: 260, // Ancora più piccolo degli altri
                    child: ElevatedButton.icon(
                      onPressed: _isReindexing ? null : _reindexFTS,
                      icon: _isReindexing
                          ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : Icon(Icons.refresh, size: 18),
                      label: Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          _isReindexing ? 'Reindicizzazione...' : 'Reindicizza FTS',
                          style: TextStyle(fontSize: 15),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        minimumSize: Size(double.infinity, 44),
                      ),
                    ),
                  ),

                  SizedBox(height: 8),

                  Text(
                    'Manutenzione ricerca full-text',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}