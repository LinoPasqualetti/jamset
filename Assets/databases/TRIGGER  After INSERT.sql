CREATE TRIGGER spartiti_ai
 AFTER INSERT ON spartiti BEGIN
  INSERT INTO spartiti_fts(rowid, titolo, autore, volume, ArchivioProvenienza) 
  VALUES (new.IdBra, new.titolo, new.autore, new.volume, new.ArchivioProvenienza);
END;