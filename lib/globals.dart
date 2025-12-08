import 'package:sqflite/sqflite.dart';

// ===================================================================
// VARIABILI GLOBALI DELL'APPLICAZIONE
// Unica fonte di verità per lo stato condiviso.
// Tutte le variabili globali iniziano con 'g'.
// ===================================================================

// --- CONFIGURAZIONE PERCORSI ---

// Percorso completo della cartella dei database.
// Inizializzato in `inizializza_i_db_della_app.dart`.
String gDatabasePath = '';

// Percorso completo della cartella radice dei PDF (es. C:\JamsetPDF o /storage/emulated/0/JamsetPDF).
// Inizializzato e corretto per la piattaforma in `inizializza_i_db_della_app.dart`.
String gPercorsoPdf = '';


// --- ISTANZE DATABASE ---

// Database globale che contiene le impostazioni dell'app e l'elenco dei cataloghi.
Database? gDbGlobale;

// Database "storico" o di fallback.
Database? dbVecchio;

// Database del catalogo di spartiti attualmente attivo.
Database? dbCatalogoAttivo;


// --- CONFIGURAZIONE CATALOGO ATTIVO ---

// Nome del file di database del catalogo attualmente in uso (es. 'catalogo_principale.db').
String gActiveCatalogDbName = '';
