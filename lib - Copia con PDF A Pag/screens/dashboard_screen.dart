import 'package:flutter/material.dart';
import 'package:jamset/screens/csv_viewer_screen.dart';
import 'package:jamset/screens/gestione_variazioni_screen.dart';

// Questa è la nuova schermata "contenitore" che mantiene lo stato
// delle pagine di ricerca e gestione.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final PageController _pageController;
  int _currentIndex = 0;

  // Crea le istanze delle pagine UNA SOLA VOLTA per mantenerle in memoria.
  final List<Widget> _pages = [
    const CsvViewerScreen(),
    const GestioneVariazioniScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Funzione chiamata quando si tocca un'icona nella barra di navigazione.
  void _onTabTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // L'AppBar cambia titolo in base alla pagina visualizzata.
      appBar: AppBar(
        title: Text(_currentIndex == 0 ? 'Ricerca Brani (CSV)' : 'Gestione e Impostazioni'),
        backgroundColor: _currentIndex == 0 ? Colors.blueGrey[700] : Colors.teal[700],
        elevation: 2,
        // Il tasto "indietro" appare automaticamente per tornare alla MainScreen.
      ),
      // Il PageView è il widget che scorre le pagine e le mantiene "vive".
      body: PageView(
        controller: _pageController,
        children: _pages,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
      // La BottomNavigationBar permette di passare da una schermata all'altra.
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.search_outlined),
            label: 'Ricerca',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Gestione',
          ),
        ],
      ),
    );
  }
}
