/////// lib/utils/database_diagnostica.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseDiagnostica {

  /// Esegue diagnostica completa sul database
  static Future<void> eseguiDiagnosticaCompleta(Database? db) async {
    debugPrint("\n" + "="*80);
    debugPrint("🔬 DIAGNOSTICA DATABASE livescore");
    debugPrint("="*80);

    debugPrint("Data: ${DateTime.now()}");
    debugPrint("Piattaforma: ${Platform.operatingSystem}");
    debugPrint("Versione: ${Platform.version}");

    if (db == null) {
      debugPrint("❌ Database non inizializzato - impossibile eseguire diagnostica");
      return;
    }

    try {
      // 1. Verifica database
      await _diagnosticaDatabase(db);

      // 2. Test FTS
      await _testFTS(db);

      // 3. Test ricerca specifica
      await _testRicercaSpecifica(db);

    } catch (e, s) {
      debugPrint("❌ Errore durante diagnostica: $e");
      debugPrint("Stack: $s");
    }

    debugPrint("\n" + "="*80);
    debugPrint("✅ DIAGNOSTICA COMPLETATA");
    debugPrint("="*80);
  }

  /// Analizza il database
  static Future<void> _diagnosticaDatabase(Database db) async {
    debugPrint("\n📁 ANALISI DATABASE:");
    debugPrint("   Path: ${db.path}");
    debugPrint("   Aperto: ${db.isOpen}");

    try {
      // Verifica tabelle
      final tables = await db.rawQuery(
          "SELECT name, type FROM sqlite_master ORDER BY type, name"
      );

      debugPrint("   Oggetti database: ${tables.length}");

      // Separa per tipo
      final tabelle = tables.where((t) => t['type'] == 'table').toList();
      final indici = tables.where((t) => t['type'] == 'index').toList();
      final trigger = tables.where((t) => t['type'] == 'trigger').toList();
      final viste = tables.where((t) => t['type'] == 'view').toList();

      debugPrint("   Tabelle: ${tabelle.length}");
      debugPrint("   Indici: ${indici.length}");
      debugPrint("   Trigger: ${trigger.length}");
      debugPrint("   Viste: ${viste.length}");

      // Cerca tabelle specifiche
      final hasSpartiti = tabelle.any((t) => t['name'] == 'spartiti');
      final hasFTS = tabelle.any((t) => t['name'] == 'spartiti_fts');

      if (hasSpartiti) {
        final count = await db.rawQuery("SELECT COUNT(*) as c FROM spartiti");
        final total = count.first['c'] as int? ?? 0;
        debugPrint("   📊 Record 'spartiti': $total");

        // Verifica colonne
        final colonne = await db.rawQuery("PRAGMA table_info(spartiti)");
        debugPrint("   Colonne 'spartiti': ${colonne.length}");

        // Colonne critiche da verificare
        final colonneCritiche = ['IdBra', 'titolo', 'autore', 'strumento', 'volume', 'ArchivioProvenienza'];
        for (final col in colonneCritiche) {
          final exists = colonne.any((c) => c['name'] == col);
          debugPrint("     ${exists ? '✅' : '❌'} $col");
        }
      } else {
        debugPrint("   ❌ Tabella 'spartiti' NON trovata!");
      }

      if (hasFTS) {
        final countFTS = await db.rawQuery("SELECT COUNT(*) as c FROM spartiti_fts");
        final totalFTS = countFTS.first['c'] as int? ?? 0;
        debugPrint("   📊 Record 'spartiti_fts': $totalFTS");

        // Verifica struttura FTS
        try {
          final ftsInfo = await db.rawQuery("PRAGMA table_info(spartiti_fts)");
          debugPrint("   Colonne FTS: ${ftsInfo.length}");
          for (final col in ftsInfo) {
            debugPrint("     - ${col['name']}");
          }
        } catch (e) {
          debugPrint("   ⚠️ Errore lettura info FTS: $e");
        }
      } else {
        debugPrint("   ⚠️ Tabella 'spartiti_fts' NON trovata!");
      }

      // Verifica trigger FTS
      final ftsTriggers = trigger.where((t) => t['name'].toString().contains('fts')).toList();
      debugPrint("   Trigger FTS: ${ftsTriggers.length}");
      for (final trig in ftsTriggers) {
        debugPrint("     - ${trig['name']}");
      }

      if (hasSpartiti && hasFTS) {
        // Verifica sincronizzazione
        final joinTest = await db.rawQuery("""
          SELECT COUNT(*) as c 
          FROM spartiti s 
          LEFT JOIN spartiti_fts f ON s.IdBra = f.rowid 
          WHERE f.rowid IS NULL
        """);
        final missing = joinTest.first['c'] as int? ?? 0;

        if (missing > 0) {
          debugPrint("   ⚠️ $missing record in spartiti senza corrispondenza FTS!");
        } else {
          debugPrint("   ✅ Tutti i record spartiti hanno corrispondenza FTS");
        }
      }

    } catch (e) {
      debugPrint("   ❌ Errore analisi database: $e");
    }
  }

  /// Test funzionalità FTS
  static Future<void> _testFTS(Database db) async {
    debugPrint("\n🧪 TEST FUNZIONALITÀ FTS:");

    try {
      // Verifica se la tabella FTS esiste
      final ftsExists = await db.rawQuery(
          "SELECT 1 FROM sqlite_master WHERE type='table' AND name='spartiti_fts'"
      );

      if (ftsExists.isEmpty) {
        debugPrint("   ❌ Tabella FTS non esiste!");
        return;
      }

      // Test query semplici
      final testCases = [
        {'query': 'girl', 'desc': 'Termine singolo'},
        {'query': 'ipanema', 'desc': 'Termine singolo 2'},
        {'query': 'girl ipanema', 'desc': 'Frase completa'},
        {'query': 'test', 'desc': 'Termine generico'},
      ];

      for (final test in testCases) {
        try {
          final start = DateTime.now();
          final result = await db.rawQuery(
              "SELECT COUNT(*) as c FROM spartiti_fts WHERE spartiti_fts MATCH ?",
              [test['query']]
          );
          final duration = DateTime.now().difference(start);
          final count = result.first['c'] as int? ?? 0;

          debugPrint("   '${test['query']}': $count risultati in ${duration.inMilliseconds}ms");

          if (count > 0 && test['query'] == 'girl ipanema') {
            // Mostra esempio dei risultati
            final esempi = await db.rawQuery(
                "SELECT titolo, autore, strumento FROM spartiti_fts WHERE spartiti_fts MATCH ? LIMIT 2",
                [test['query']]
            );
            for (final es in esempi) {
              debugPrint("     Esempio: ${es['titolo']} - ${es['autore']} (${es['strumento']})");
            }
          }

        } catch (e) {
          debugPrint("   ❌ Errore query '${test['query']}': $e");
        }
      }

    } catch (e) {
      debugPrint("   ❌ Errore test FTS: $e");
    }
  }

  /// Test ricerca specifica (simile a quella dell'app)
  static Future<void> _testRicercaSpecifica(Database db) async {
    debugPrint("\n🎯 TEST RICERCA SPECIFICA (come nell'app):");

    try {
      // Query completa come nell'app
      const query = '''
        SELECT DISTINCT 
          Numpag, 
          a.titolo, 
          a.volume, 
          a.ArchivioProvenienza, 
          a.strumento,  
          primolink,
          '/storage/emulated/0/JamsetPDF/' as percradice, 
          percresto,
          '/storage/emulated/0/JamsetPDF/' || percresto || a.Volume as PerApertura
        FROM spartiti a 
        JOIN spartiti_fts fts ON a.IdBra = fts.rowid 
        WHERE a.tipoMulti LIKE 'PD%'
          AND spartiti_fts MATCH ?
        ORDER BY a.titolo, a.strumento
      ''';

      debugPrint("   Query da testare:");
      debugPrint("   ${query.substring(0, 100)}...");

      final start = DateTime.now();
      final results = await db.rawQuery(query, ['girl ipanema']);
      final duration = DateTime.now().difference(start);

      debugPrint("   Tempo esecuzione: ${duration.inMilliseconds}ms");
      debugPrint("   Risultati trovati: ${results.length}");

      if (results.isNotEmpty) {
        debugPrint("   Primi 3 risultati:");
        for (int i = 0; i < results.length && i < 3; i++) {
          final row = results[i];
          debugPrint("""
      --- Risultato ${i + 1} ---
      Titolo: ${row['titolo']}
      Strumento: ${row['strumento']}
      Volume: ${row['volume']}
      PerApertura: ${row['PerApertura']}
      PercResto: ${row['percresto']}
          """);
        }
      } else {
        debugPrint("   ⚠️ Nessun risultato trovato!");

        // Diagnostica extra
        debugPrint("   🔍 Diagnostica extra:");

        // 1. Verifica filtro tipoMulti
        final tipoMultiCheck = await db.rawQuery(
            "SELECT DISTINCT tipoMulti FROM spartiti WHERE tipoMulti IS NOT NULL LIMIT 5"
        );
        debugPrint("   Valori tipoMulti presenti:");
        for (final row in tipoMultiCheck) {
          debugPrint("     - '${row['tipoMulti']}'");
        }

        // 2. Test senza filtro tipoMulti
        final testNoFilter = await db.rawQuery(
            "SELECT COUNT(*) as c FROM spartiti a JOIN spartiti_fts fts ON a.IdBra = fts.rowid WHERE spartiti_fts MATCH ?",
            ['girl ipanema']
        );
        final countNoFilter = testNoFilter.first['c'] as int? ?? 0;
        debugPrint("   Risultati senza filtro tipoMulti: $countNoFilter");

        // 3. Verifica join
        final testJoin = await db.rawQuery(
            "SELECT COUNT(*) as c FROM spartiti WHERE IdBra IN (SELECT rowid FROM spartiti_fts WHERE spartiti_fts MATCH ?)",
            ['girl ipanema']
        );
        final countJoin = testJoin.first['c'] as int? ?? 0;
        debugPrint("   Record corrispondenti (join alternativo): $countJoin");
      }

    } catch (e, s) {
      debugPrint("   ❌ Errore test ricerca specifica: $e");
      debugPrint("   Stack: $s");
    }
  }

  /// Ripara FTS se necessario
  static Future<void> riparaFTS(Database db) async {
    debugPrint("\n🔧 RIPARAZIONE FTS:");

    try {
      // 1. Elimina strutture esistenti
      await db.execute("DROP TABLE IF EXISTS spartiti_fts");
      await db.execute("DROP TRIGGER IF EXISTS spartiti_ai_fts");
      await db.execute("DROP TRIGGER IF EXISTS spartiti_ad_fts");
      await db.execute("DROP TRIGGER IF EXISTS spartiti_au_fts");

      debugPrint("   Strutture FTS eliminate");

      // 2. Crea nuova tabella FTS (compatibile Android)
      if (Platform.isAndroid) {
        // Versione semplice per Android
        await db.execute('''
          CREATE VIRTUAL TABLE spartiti_fts 
          USING fts5(
            titolo,
            autore,
            strumento,
            volume,
            ArchivioProvenienza,
            content='spartiti',
            content_rowid='IdBra'
          )
        ''');
        debugPrint("   Tabella FTS creata (versione Android)");
      } else {
        // Versione avanzata per altri OS
        await db.execute('''
          CREATE VIRTUAL TABLE spartiti_fts 
          USING fts5(
            titolo,
            autore,
            strumento,
            volume,
            ArchivioProvenienza,
            tokenize='unicode61',
            content='spartiti',
            content_rowid='IdBra'
          )
        ''');
        debugPrint("   Tabella FTS creata (versione avanzata)");
      }

      // 3. Popola FTS
      final count = await db.rawQuery("SELECT COUNT(*) as c FROM spartiti");
      final total = count.first['c'] as int? ?? 0;

      if (total > 0) {
        debugPrint("   Popolamento FTS con $total record...");

        if (total > 10000) {
          // Popolamento in blocchi per grandi dataset
          await _popolaFTSInBlocchi(db, total);
        } else {
          // Popolamento singolo
          await db.execute('''
            INSERT INTO spartiti_fts(rowid, titolo, autore, strumento, volume, ArchivioProvenienza)
            SELECT 
              IdBra,
              COALESCE(titolo, ''),
              COALESCE(autore, ''),
              COALESCE(strumento, ''),
              COALESCE(volume, ''),
              COALESCE(ArchivioProvenienza, '')
            FROM spartiti
          ''');
        }

        debugPrint("   FTS popolato con successo");
      } else {
        debugPrint("   ⚠️ Nessun record da indicizzare");
      }

      // 4. Verifica
      final countFTS = await db.rawQuery("SELECT COUNT(*) as c FROM spartiti_fts");
      final totalFTS = countFTS.first['c'] as int? ?? 0;
      debugPrint("   Record FTS dopo riparazione: $totalFTS");

      if (total > 0 && totalFTS == 0) {
        debugPrint("   ❌ ERRORE: FTS ancora vuoto dopo riparazione!");
      } else if (totalFTS == total) {
        debugPrint("   ✅ Riparazione completata con successo!");
      } else {
        debugPrint("   ⚠️ Discrepanza: spartiti=$total, FTS=$totalFTS");
      }

    } catch (e, s) {
      debugPrint("   ❌ Errore durante riparazione FTS: $e");
      debugPrint("   Stack: $s");
    }
  }

  /// Popola FTS in blocchi per grandi dataset
  static Future<void> _popolaFTSInBlocchi(Database db, int totalRecords, {int chunkSize = 5000}) async {
    final chunks = (totalRecords / chunkSize).ceil();
    debugPrint("   Popolamento in $chunks blocchi da $chunkSize...");

    for (int i = 0; i < chunks; i++) {
      final offset = i * chunkSize;

      await db.execute('''
        INSERT INTO spartiti_fts(rowid, titolo, autore, strumento, volume, ArchivioProvenienza)
        SELECT 
          IdBra,
          COALESCE(titolo, ''),
          COALESCE(autore, ''),
          COALESCE(strumento, ''),
          COALESCE(volume, ''),
          COALESCE(ArchivioProvenienza, '')
        FROM spartiti
        LIMIT $chunkSize OFFSET $offset
      ''');

      final progress = ((i + 1) / chunks * 100).toStringAsFixed(1);
      debugPrint("   Blocco ${i + 1}/$chunks completato ($progress%)");

      // Yield per non bloccare l'UI
      if (i % 5 == 0) await Future.delayed(Duration(milliseconds: 10));
    }
  }
}
