// lib/main.dart - VERSIONE CON DEBUG POSIZIONE DB
import 'package:flutter/material.dart';
import 'package:jamsetgemini/screens/main_screen.dart';
import 'dart:io' show Directory, File, Platform;
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:path_provider/path_provider.dart';

// --- IMPORT PER DATABASE ---
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';
// ---------------------------

// NUOVO IMPORT per l'inizializzazione corretta
import 'package:jamsetgemini/database/inizializza_i_db_della_app.dart';

import 'package:jamsetgemini/platform/opener_platform_interface.dart';
import 'package:jamsetgemini/platform/android_opener.dart';
import 'package:jamsetgemini/platform/windows_opener.dart';

// Chiave globale per accedere al Navigator
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Map<String, String> appSystemConfig = {};

// === VARIABILI GLOBALI ===
Database? dbVecchio;
Database? dbGlobale;
Database? dbCatalogoAttivo;
String gActiveCatalogDbName = '';
String gPercorsoPdf = '';
String gDatabasePath = '';
// =======================

// ================================================
// FUNZIONE PER TROVARE LA POSIZIONE REALE DEI DB
// ================================================
Future<void> findActualDatabaseLocation() async {
  print('🔍 ================================================');
  print('🔍 RICERCA POSIZIONE REALE DATABASE');
  print('🔍 ================================================');

  try {
    // 1. User profile (Windows specific)
    final userProfile = Platform.environment['USERPROFILE'] ?? 'C:\\Users\\LINOP';
    print('👤 User profile: $userProfile');

    // 2. Directory usando path_provider
    print('\n📁 PATH PROVIDER DIRECTORY:');

    final supportDir = await getApplicationSupportDirectory();
    print('• ApplicationSupportDirectory: ${supportDir.path}');

    final docsDir = await getApplicationDocumentsDirectory();
    print('• ApplicationDocumentsDirectory: ${docsDir.path}');

    final tempDir = await getTemporaryDirectory();
    print('• TemporaryDirectory: ${tempDir.path}');

    // 3. Directory corrente
    print('\n📍 DIRECTORY CORRENTE:');
    print('• Directory.current: ${Directory.current.path}');

    // 4. Posizioni Windows specifiche da controllare
    print('\n🏠 POSIZIONI WINDOWS SPECIFICHE:');
    final windowsLocations = [
      '$userProfile\\AppData\\Local',
      '$userProfile\\AppData\\Roaming',
      '$userProfile\\AppData\\LocalLow',
      '$userProfile\\.jamsetgemini',
      '$userProfile\\Documents\\jamsetgemini',
      '${Directory.current.path}\\data',
      '${Directory.current.path}\\build\\windows\\runner\\Debug\\data',
    ];

    for (var location in windowsLocations) {
      final dir = Directory(location);
      if (await dir.exists()) {
        print('• ✅ $location (ESISTE)');
      } else {
        print('• ❌ $location (NON ESISTE)');
      }
    }

    // 5. Cerca file .db in tutte le directory
    print('\n🔎 CERCA FILE .db:');
    final searchDirs = [
      supportDir,
      docsDir,
      tempDir,
      Directory(Directory.current.path),
      Directory('${Directory.current.path}\\data'),
    ];

    for (var dir in searchDirs) {
      if (await dir.exists()) {
        try {
          final files = await dir.list().toList();
          final dbFiles = files.where((f) =>
          f is File && f.path.toLowerCase().endsWith('.db')).toList();

          if (dbFiles.isNotEmpty) {
            print('\n📂 In ${dir.path}:');
            for (var dbFile in dbFiles) {
              final file = File(dbFile.path);
              final size = await file.length();
              final modified = await file.lastModified();
              print('   📄 ${dbFile.path}');
              print('     Size: ${size} bytes, Modified: $modified');
            }
          }
        } catch (e) {
          print('   ⚠️  Errore accesso a ${dir.path}: $e');
        }
      }
    }

    // 6. Crea file di test per vedere dove viene salvato
    print('\n🧪 CREAZIONE FILE DI TEST:');
    final testFile1 = File('${supportDir.path}/test_location.txt');
    await testFile1.writeAsString('Test in support: ${DateTime.now()}');
    print('• File test in support: ${testFile1.path}');

    final testFile2 = File('${docsDir.path}/test_location.txt');
    await testFile2.writeAsString('Test in documents: ${DateTime.now()}');
    print('• File test in documents: ${testFile2.path}');

    // 7. Usando getDatabasesPath() di sqflite
    print('\n🗃️  SQLITE DATABASES PATH:');
    try {
      final databasesPath = await getDatabasesPath();
      print('• getDatabasesPath(): $databasesPath');

      final dbDir = Directory(databasesPath);
      if (await dbDir.exists()) {
        print('• Directory databases: ESISTE');
        final files = await dbDir.list().toList();
        for (var file in files) {
          print('   📄 ${file.path}');
        }
      } else {
        print('• Directory databases: NON ESISTE');
      }
    } catch (e) {
      print('• Errore getDatabasesPath(): $e');
    }

  } catch (e) {
    print('❌ ERRORE NELLA RICERCA: $e');
  }

  print('🔍 ================================================\n');
}

// ================================================
// FUNZIONE PER CANCELLARE TUTTI I DB ESISTENTI
// ================================================
Future<void> deleteAllExistingDatabases() async {
  print('🗑️  ================================================');
  print('🗑️  CANCELLAZIONE DATABASE ESISTENTI');
  print('🗑️  ================================================');

  try {
    final userProfile = Platform.environment['USERPROFILE'] ?? 'C:\\Users\\LINOP';

    // Tutte le possibili posizioni
    final allLocations = [
      // Path provider
      (await getApplicationSupportDirectory()).path,
      (await getApplicationDocumentsDirectory()).path,
      (await getTemporaryDirectory()).path,

      // Windows specific
      '$userProfile\\AppData\\Local\\com.example.jamsetgemini',
      '$userProfile\\AppData\\Local\\jamsetgemini',
      '$userProfile\\AppData\\Roaming\\com.example.jamsetgemini',
      '$userProfile\\AppData\\Roaming\\jamsetgemini',
      '$userProfile\\.jamsetgemini',

      // Directory progetto
      '${Directory.current.path}\\data',
      '${Directory.current.path}\\build\\windows\\runner\\Debug\\data',
      '${Directory.current.path}\\build\\windows\\x64\\runner\\Debug\\data',
    ];

    int deletedCount = 0;

    for (var location in allLocations) {
      final dir = Directory(location);
      if (await dir.exists()) {
        print('📁 Controllo: $location');

        try {
          final files = await dir.list().toList();
          for (var file in files) {
            if (file is File && file.path.toLowerCase().endsWith('.db')) {
              await file.delete();
              print('   🗑️  Cancellato: ${file.path}');
              deletedCount++;
            }
          }

          // Prova a cancellare directory vuote
          final remaining = await dir.list().toList();
          if (remaining.isEmpty) {
            await dir.delete();
            print('   📁 Directory vuota cancellata');
          }
        } catch (e) {
          print('   ⚠️  Errore accesso: $e');
        }
      }
    }

    print('\n✅ CANCELLATI $deletedCount file .db');

  } catch (e) {
    print('❌ ERRORE CANCELLAZIONE: $e');
  }

  print('🗑️  ================================================\n');
}

// ================================================
// MAIN
// ================================================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- FIX PER `Read-only file system` ---
  // Imposta la directory corrente su una cartella scrivibile prima di usare FFI.
  if (!kIsWeb) {
    Directory.current = (await getApplicationDocumentsDirectory()).path;
  }

  // ================================================
  // DEBUG: TROVA DOVE SONO I DATABASE
  // ================================================
  print('\n' + '='*60);
  print('🔄 AVVIO APP - DEBUG MODE');
  print('='*60);

  await findActualDatabaseLocation();

  // ================================================
  // OPZIONALE: CANCELLA DB ESISTENTI PER RIPARTIRE PULITO
  // ================================================
  // PER TESTARE, SCOMMENTA QUESTA RIGA:
  // await deleteAllExistingDatabases();
  // ================================================

  // --- Inizializzazione Piattaforma-Specifica di SQLite ---
  if (Platform.isAndroid) {
    await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
  }
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS || Platform.isAndroid) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  try {
    // --- INIZIALIZZAZIONE PLATFORM SPECIFIC ---
    if (Platform.isWindows) {
      const userSpecificViewerPath = r"C:\Program Files (x86)\Adobe\Acrobat 9.0\Acrobat\Acrobat.exe";
      const defaultViewerPath = r"C:\Program Files\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe";
      if (File(userSpecificViewerPath).existsSync()) {
        appSystemConfig['pdfViewerPath'] = userSpecificViewerPath;
      } else {
        appSystemConfig['pdfViewerPath'] = defaultViewerPath;
      }
    }

    if (!kIsWeb) {
      try {
        if (Platform.isAndroid) {
          OpenerPlatformInterface.instance = AndroidOpener();
        } else if (Platform.isWindows) {
          OpenerPlatformInterface.instance = WindowsOpener();
        }
      } catch (e) {
        if (kDebugMode) print("Errore inizializzazione piattaforma: $e");
      }
    }

    // --- MODIFICA PRINCIPALE: USO LA NUOVA FUNZIONE DI INIZIALIZZAZIONE ---
    if (kDebugMode) print("=== AVVIO INIZIALIZZAZIONE DB CON SISTEMA CORRETTO ===");
    if (kDebugMode) print("Piattaforma: ${Platform.operatingSystem}");

    // SOSTITUISCI TUTTA LA LOGICA VECCHIA CON QUESTA CHIAMATA
    await inizializzaIDbDellaApp();

    if (kDebugMode) {
      print("=== INIZIALIZZAZIONE COMPLETATA ===");
      print("Percorso PDF corretto: $gPercorsoPdf");
      print("Database globale: ${dbGlobale != null ? 'OK' : 'NON DISPONIBILE'}");
      print("Catalogo attivo: $gActiveCatalogDbName");
      print("Percorso DB: $gDatabasePath");

      // Debug extra: verifica se il percorso esiste
      if (gPercorsoPdf.isNotEmpty) {
        final dir = Directory(gPercorsoPdf);
        final exists = await dir.exists();
        print("Directory PDF esiste? $exists");
      }
    }

    runApp(const MyApp());

  } catch (e, stackTrace) {
    if (kDebugMode) {
      print("### ERRORE CRITICO DURANTE L'INIZIALIZZAZIONE: $e ###");
      print("Stack trace: $stackTrace");
    }

    // FALLBACK: Inizializzazione minima per permettere all'app di partire
    try {
      // Imposta un percorso di fallback
      final defaultDir = await getApplicationDocumentsDirectory();
      gPercorsoPdf = p.join(defaultDir.path, 'JamsetPDF');

      // Crea la directory se non esiste
      await Directory(gPercorsoPdf).create(recursive: true);

      if (kDebugMode) {
        print("=== FALLBACK INIZIALIZZATO ===");
        print("Percorso fallback: $gPercorsoPdf");
      }
    } catch (fallbackError) {
      if (kDebugMode) print("Errore anche nel fallback: $fallbackError");
    }

    runApp(ErrorApp(error: "Errore inizializzazione: ${e.toString()}"));
  }
}

// --- MANTIENI QUESTA FUNZIONE PER COMPATIBILITÀ ---
Future<void> _setupDatabase(Database db, String dbName) async {
  try {
    await db.transaction((txn) async {
      // 1. Normalizzazione dei percorsi (solo su piattaforme non-Windows)
      if (!Platform.isWindows) {
        if (kDebugMode) print("[$dbName] Normalizzazione percorsi per piattaforma non-Windows...");
        await txn.rawUpdate("UPDATE spartiti SET percResto = REPLACE(percResto, '\\', '/')");
      }

      // 2. Verifica e creazione indice FTS5
      final ftsTable = await txn.query('sqlite_master', where: 'type = ? AND name = ?', whereArgs: ['table', 'spartiti_fts']);
      if (ftsTable.isEmpty) {
        if (kDebugMode) print("[$dbName] Indice FTS non trovato. Creazione in corso...");

        // Crea la tabella virtuale
        await txn.execute('''
          CREATE VIRTUAL TABLE spartiti_fts USING fts5 (
            titolo, autore, volume, ArchivioProvenienza,
            content = \'spartiti\', content_rowid = \'IdBra\'
          );
        ''');

        // Popola l'indice
        await txn.execute('''
          INSERT INTO spartiti_fts(rowid, titolo, autore, volume, ArchivioProvenienza)
          SELECT IdBra, titolo, autore, volume, ArchivioProvenienza FROM spartiti;
        ''');

        // Crea i trigger
        await txn.execute('''
          CREATE TRIGGER spartiti_ai AFTER INSERT ON spartiti BEGIN
            INSERT INTO spartiti_fts(rowid, titolo, autore, volume, ArchivioProvenienza)
            VALUES (new.IdBra, new.titolo, new.autore, new.volume, new.ArchivioProvenienza);
          END;
        ''');
        await txn.execute('''
          CREATE TRIGGER spartiti_ad AFTER DELETE ON spartiti BEGIN
            INSERT INTO spartiti_fts(spartiti_fts, rowid, titolo, autore, volume, ArchivioProvenienza) 
            VALUES(\'delete\', old.IdBra, old.titolo, old.autore, old.volume, old.ArchivioProvenienza);
          END;
        ''');
        await txn.execute('''
          CREATE TRIGGER spartiti_au AFTER UPDATE ON spartiti BEGIN
            INSERT INTO spartiti_fts(spartiti_fts, rowid, titolo, autore, volume, ArchivioProvenienza) 
            VALUES(\'delete\', old.IdBra, old.titolo, old.autore, old.volume, old.ArchivioProvenienza);
            INSERT INTO spartiti_fts(rowid, titolo, autore, volume, ArchivioProvenienza)
            VALUES (new.IdBra, new.titolo, new.autore, new.volume, new.ArchivioProvenienza);
          END;
        ''');

        if (kDebugMode) print("[$dbName] Creazione indice FTS e triggers completata.");
      }
    });
  } catch (e) {
    if (kDebugMode) print("Errore in _setupDatabase per $dbName: $e");
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'JamsetGemini App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blueGrey,
            primary: Colors.blueAccent,
            secondary: Colors.amber
        ),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

class ErrorApp extends StatelessWidget {
  final String error;
  const ErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFFFFF0F0),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 60),
                const SizedBox(height: 20),
                const Text(
                    'Errore Critico all\'Avvio',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)
                ),
                const SizedBox(height: 10),
                SelectableText(
                  error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Riprova'),
                  onPressed: () {
                    // Potresti aggiungere un meccanismo di riprova qui
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}