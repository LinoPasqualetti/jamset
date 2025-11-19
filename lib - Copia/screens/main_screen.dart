import 'package:flutter/material.dart';
import 'package:jamset/screens/csv_viewer_screen.dart';
import 'package:jamset/screens/gestione_variazioni_screen.dart';
import 'package:jamset/screens/funzioni_variazione_dati_screen.dart'; // <-- 1. IMPORT

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // 2. AGGIUNTA SCHERMATA ALLA LISTA
  static const List<Widget> _widgetOptions = <Widget>[
    _HomePage(),
    CsvViewerScreen(),
    FunzioniVariazioneDatiScreen(), // <-- Nuova schermata
    GestioneVariazioniScreen(),
  ];

  void _navigateTo(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      // 3. AGGIUNTA VOCE ALLA BARRA DI NAVIGAZIONE
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // Per mostrare più di 3 elementi
        items: const <BottomNavigationBarItem>[
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
            label: 'Ricerca DB', // <-- Nuova voce
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

class _HomePage extends StatelessWidget {
  const _HomePage();

  @override
  Widget build(BuildContext context) {
    final parentState = context.findAncestorStateOfType<_MainScreenState>()!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('JamSet - Ricerca Home Page'),
        backgroundColor: Colors.blueGrey[700],
        foregroundColor: Colors.yellowAccent,
        elevation: 0,
      ),
      drawer: Drawer(
        // ... il tuo drawer rimane invariato ...
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
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  const Text(
                    'Benvenuto in JamSet!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.search_outlined),
                    label: const Text('Ricerca e Prospettazione Brani (CSV)'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                    onPressed: () {
                      parentState._navigateTo(1);
                    },
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.storage_outlined),
                    label: const Text('Ricerca Brani da Database'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                      textStyle: const TextStyle(fontSize: 16),
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                       // 4. COLLEGAMENTO ALLA NUOVA SCHERMATA (INDICE 2)
                      parentState._navigateTo(2);
                    },
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.edit_document),
                    label: const Text('Gestione Variazioni e Dati'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                      textStyle: const TextStyle(fontSize: 16),
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                       // 5. AGGIORNAMENTO INDICE VECCHIA SCHERMATA (ORA 3)
                      parentState._navigateTo(3);
                    },
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
