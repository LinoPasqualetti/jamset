// lib/screens/main_screen.dart
import 'package:flutter/material.dart';
import 'package:jamset/screens/csv_viewer_screen.dart';
import 'package:jamset/screens/gestione_variazioni_screen.dart';
import 'dart:io' show Platform; // Importa solo 'Platform' da dart:io
import 'package:flutter/foundation.dart' show kIsWeb; // Per kIsWeb

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      // Rimuoviamo il backgroundColor dallo Scaffold se l'immagine deve coprire tutto
      // backgroundColor: Colors.blueGrey[100], (Rimosso o commentato)
      appBar: AppBar(
        title: const Text('JamSet App di gestione e ricerca di spartiti musicali - Home Page '),
        backgroundColor: Colors.blueGrey[700],
        foregroundColor: Colors.yellowAccent ,
        //centerTitle: ,
        elevation: 0, // Opzionale: rimuove l'ombra dell'AppBar se preferisci un look più piatto con lo sfondo
      ),
      body: Stack( // Usiamo Stack per sovrapporre l'immagine e il contenuto
        children: <Widget>[
          // 1. Immagine di Sfondo
          Positioned.fill( // Fa sì che l'immagine riempia tutto lo spazio disponibile dello Stack
            child: Image.asset(
              'assets/images/SfondoLibriRBeAeb2.jpg', // <<< SOSTITUISCI CON IL TUO PERCORSO IMMAGINE
              fit: BoxFit.cover, // Copre l'intero spazio, tagliando se necessario
              // Altre opzioni per 'fit':  // BoxFit.contain: Mostra tutta l'immagine, potrebbe lasciare spazi vuoti
              // BoxFit.fill: Stira l'immagine per riempire, potrebbe distorcerla   // BoxFit.fitWidth: Riempie la larghezza, potrebbe tagliare verticalmente
              // BoxFit.fitHeight: Riempie l'altezza, potrebbe tagliare orizzontalmente  // BoxFit.scaleDown: Mostra l'immagine alla sua dimensione originale se più piccola, altrimenti come BoxFit.contain
            ),
          ),

          // 2. Contenuto Originale della Schermata (Centrato)
          // Potrebbe essere necessario avvolgere il contenuto in un Container
          // per applicare un colore di sfondo semi-trasparente sopra l'immagine,
          // se il testo non è leggibile.
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Text(
                    'Benvenuto in JamSet!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28, // Leggermente più grande per leggibilità
                      fontWeight: FontWeight.bold,
                      color: Colors.white, // Cambia colore per contrasto con l'immagine

                    ),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.search_outlined),
                    label: const Text('Ricerca e Prospettazione Brani (CSV)'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      textStyle: const TextStyle(fontSize: 16),
                      // Potresti voler rendere i bottoni leggermente trasparenti
                      // o cambiare il loro colore per adattarsi meglio allo sfondo.
                      // Esempio: backgroundColor: Colors.black.withOpacity(0.5),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const CsvViewerScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.edit_document),
                    label: const Text('Gestione Variazioni e Dati'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      textStyle: const TextStyle(fontSize: 16),
                      backgroundColor: Colors.teal, // Mantieni o adatta questo colore
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const GestioneVariazioniScreen()),
                      );
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