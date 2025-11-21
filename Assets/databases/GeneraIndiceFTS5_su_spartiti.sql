INSERT INTO spartiti_fts
(rowid,
    titolo,
    autore,
    volume,
    ArchivioProvenienza)
SELECT IdBra, 
    titolo,
    autore,
    volume,
    ArchivioProvenienza
    FROM spartiti;