Future<void> _setupDatabase(Database db, String dbName) async {
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
        CREATE VIRTUAL TABLE spartiti_fts USING FTS5 (
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
}