CREATE VIRTUAL TABLE spartiti_fts USING fts5 (
    titolo,
    autore,
    volume,
    ArchivioProvenienza,
    content = 'spartiti',
    content_rowid = 'IdBra'
);
