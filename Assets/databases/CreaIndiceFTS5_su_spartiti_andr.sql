CREATE VIRTUAL TABLE spartiti_andr_fts USING fts5 (
    titolo,
    autore,
    volume,
    ArchivioProvenienza,
    content = 'spartiti_andr',
    content_rowid = 'IdBra'
);
