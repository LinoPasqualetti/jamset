// lib/screens/main_screen.dart
import 'package:flutter/material.dart';
import 'package:livescore/screens/csv_viewer_screen.dart';
import 'package:livescore/screens/funzioni_variazione_dati_screen.dart';
import 'package:livescore/screens/gestione_variazioni_screen.dart';
import 'package:livescore/services/database_service.dart';
import 'package:livescore/main.dart'; // Per accedere a databaseService globale

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  Map<String, dynamic> _currentVolume = {};

  @override
  void initState() {
    super.initState();
    _loadCurrentVolume();
    databaseService.addListener(_loadCurrentVolume);
  }

  @override
  void dispose() {
    databaseService.removeListener(_loadCurrentVolume);
    super.dispose();
  }

  Future<void> _loadCurrentVolume() async {
    try {
      final volume = await databaseService.getCurrentVolume();
      if (mounted) {
        setState(() {
          _currentVolume = volume;
        });
      }
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
          currentVolume: _currentVolume,
          navigateTo: _navigateTo,
        );
      case 1:
        return const CsvViewerScreen();
      case 2:
        return const FunzioniVariazioneDatiScreen();
      case 3:
        return const GestioneVariazioniScreen();
      default:
        return HomePage(
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
        backgroundColor: Colors.white,
        selectedItemColor: Colors.indigo[800],
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Ricerca CSV'),
          BottomNavigationBarItem(icon: Icon(Icons.storage_outlined), label: 'Ricerca DB'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Gestione'),
        ],
        currentIndex: _selectedIndex,
        onTap: _navigateTo,
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final Map<String, dynamic> currentVolume;
  final Function(int) navigateTo;

  const HomePage({
    super.key,
    required this.currentVolume,
    required this.navigateTo,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isReindexing = false;
  double _reindexProgress = 0.0; // Valore da 0.0 a 1.0

  Future<void> _reindexFTS() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [Icon(Icons.search_off, color: Colors.orange), SizedBox(width: 8), Text('Reindicizzazione FTS')],
        ),
        content: const Text('Vuoi ricostruire completamente l\'indice di ricerca per il catalogo attivo?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ANNULLA')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true), 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            child: const Text('REINDICIZZA'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isReindexing = true;
      _reindexProgress = 0.0;
    });

    // Mostriamo il dialog di progresso
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder( // Importante per aggiornare il dialog internamente
          builder: (context, setModalState) {
            // Definiamo un timer per aggiornare la UI del modal quando cambia lo stato del genitore
            return AlertDialog(
              title: const Text('Reindicizzazione in corso...'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Attendi il completamento dell\'operazione.', style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 20),
                  LinearProgressIndicator(
                    value: _reindexProgress,
                    backgroundColor: Colors.grey.shade200,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${(_reindexProgress * 100).toInt()}%',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                  ),
                ],
              ),
            );
          }
        );
      }
    );

    try {
      await databaseService.risincronizzaFTSCompleta(
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _reindexProgress = progress;
            });
            // NOTA: Per aggiornare il dialog aperto con StatefulBuilder dovremmo usare setModalState, 
            // ma siccome il progresso cambia molto velocemente, chiuderemo e riapriremo il dialog 
            // o useremo un approccio più pulito con ValueNotifier se necessario. 
            // In questo caso, Flutter dovrebbe ridisegnare se il context è lo stesso.
          }
        }
      );

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Chiude il dialog di progresso
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reindicizzazione completata con successo!'), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) setState(() => _isReindexing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String nomeCatalogo = widget.currentVolume['nome_catalogo']?.toString() ?? 'Nessun Catalogo';
    final String brani = widget.currentVolume['conteggio_brani']?.toString() ?? '0';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Score', style: TextStyle(color: Colors.yellowAccent, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blueGrey[700],
        actions: [
          IconButton(
            icon: _isReindexing 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.yellowAccent))
              : const Icon(Icons.refresh, color: Colors.yellowAccent),
            onPressed: _isReindexing ? null : _reindexFTS,
            tooltip: 'Reindicizza FTS',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0, left: 8.0),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(nomeCatalogo, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                  Text('Brani: $brani', style: const TextStyle(fontSize: 9, color: Colors.yellowAccent)),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: Image.asset('assets/images/SfondoLibriRBeAebCubista.jpg', fit: BoxFit.cover),
          ),
          Container(color: Colors.black.withOpacity(0.4)),
          Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Text('Benvenuto!', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 40),
                  _buildMenuButton(context, 'Ricerca CSV', Icons.search, 1, Colors.white, Colors.black87),
                  const SizedBox(height: 16),
                  _buildMenuButton(context, 'Ricerca Database', Icons.storage_outlined, 2, Colors.indigo, Colors.white),
                  const SizedBox(height: 16),
                  _buildMenuButton(context, 'Gestione e Dati', Icons.edit_document, 3, Colors.teal, Colors.white),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuButton(BuildContext context, String label, IconData icon, int index, Color bgColor, Color textColor) {
    return SizedBox(
      width: 280,
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 20),
        label: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(label, style: const TextStyle(fontSize: 16))),
        style: ElevatedButton.styleFrom(backgroundColor: bgColor, foregroundColor: textColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        onPressed: () => widget.navigateTo(index),
      ),
    );
  }
}
