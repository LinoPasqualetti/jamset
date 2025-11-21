CREATE TRIGGER spartiti_ad AFTER DELETE ON spartiti BEGIN
  INSERT INTO spartiti_fts(spartiti_fts, rowid, titolo, autore, volume, ArchivioProvenienza) 
  VALUES('delete', old.IdBra, old.titolo, old.autore, old.volume, old.ArchivioProvenienza);
  END;