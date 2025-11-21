CREATE TRIGGER spartiti_au AFTER UPDATE ON spartiti BEGIN
  INSERT INTO spartiti_fts(spartiti_fts, rowid, titolo, autore, volume, ArchivioProvenienza) 
  VALUES('delete', old.IdBra
  , old.titolo, old.autore, old.volume, old.ArchivioProvenienza);
  INSERT INTO spartiti_fts(rowid, titolo, autore, volume, ArchivioProvenienza) 
  VALUES (new.IdBra, new.titolo, new.autore, new.volume, new.ArchivioProvenienza);
END;