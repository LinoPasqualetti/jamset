import 'package:flutter/material.dart';
import 'package:jamset/screens/csv_viewer_screen.dart';
import 'package:jamset/screens/gestione_variazioni_screen.dart';

// 1. Trasformiamo MainScreen in uno StatefulWidget per poter gestire lo stato
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // 2. Teniamo traccia di quale "pagina" mostrare
  int _selectedIndex = 0; // 0 per la Home, 1 per la Ricerca, 2 per la Gestione

  // 3. Creiamo le istanze delle nostre pagine UNA SOLA VOLTA.
  //    Questo è il segreto per mantenere lo stato.
  static const List<Widget> _widgetOptions = <Widget>[
    // Indice 0: La tua Home Page, la mettiamo in un widget separato per pulizia
    _HomePage(),
    // Indice 1: La schermata di ricerca, che manterrà il suo stato
    CsvViewerScreen(),
    // Indice 2: La schermata di gestione, che manterrà il suo stato
    GestioneVariazioniScreen(),
  ];

  void _navigateTo(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // La nostra MainScreen ora è un "contenitore" che usa IndexedStack
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      // 4. Aggiungiamo una BottomNavigationBar per navigare tra le sezioni
      bottomNavigationBar: BottomNavigationBar(
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

// 5. Creiamo un widget privato per contenere la UI della tua Home Page originale.
//    Questo widget non ha più bisogno di usare Navigator.push.
class _HomePage extends StatelessWidget {
  const _HomePage();

  @override
  Widget build(BuildContext context) {
    // Per chiamare la funzione _navigateTo del genitore, usiamo questo trucco
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
                      // ORA: dice al genitore di mostrare la pagina con indice 1
                      parentState._navigateTo(1);
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
                      // ORA: dice al genitore di mostrare la pagina con indice 2
                      parentState._navigateTo(2);
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
