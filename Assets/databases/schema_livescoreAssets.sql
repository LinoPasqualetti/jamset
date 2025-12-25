CREATE TABLE sqlite_sequence(name,seq);
CREATE TABLE spartiti (
    id_univoco_globale integer unique, 
    IdBra text,
    titolo text,
    autore text,
    strumento text,
    volume text,
    PercRadice          TEXT,
    PercResto           TEXT,
    PrimoLInk text,
    TipoMulti text,
    TipoDocu text,
    ArchivioProvenienza text,
    NumPag integer,
    NumOrig integer,
    IdVolume text,
    IdAutore text,
     PRIMARY KEY (
        id_univoco_globale AUTOINCREMENT
    )

);
CREATE TABLE spartiti_andr(
  id_univoco_globale INT,
  IdBra TEXT,
  titolo TEXT,
  autore TEXT,
  strumento TEXT,
  volume TEXT,
  PercRadice TEXT,
  PercResto TEXT,
  PrimoLInk TEXT,
  TipoMulti TEXT,
  TipoDocu TEXT,
  ArchivioProvenienza TEXT,
  NumPag INT,
  NumOrig INT,
  IdVolume TEXT,
  IdAutore TEXT
);
CREATE VIRTUAL TABLE spartiti_fts USING fts5 (
    titolo,
    autore,
    volume,
    ArchivioProvenienza,
    content = 'spartiti',
    content_rowid ='IdBra');
CREATE TABLE IF NOT EXISTS 'spartiti_fts_data'(id INTEGER PRIMARY KEY, block BLOB);
CREATE TABLE IF NOT EXISTS 'spartiti_fts_idx'(segid, term, pgno, PRIMARY KEY(segid, term)) WITHOUT ROWID;
CREATE TABLE IF NOT EXISTS 'spartiti_fts_docsize'(id INTEGER PRIMARY KEY, sz BLOB);
CREATE TABLE IF NOT EXISTS 'spartiti_fts_config'(k PRIMARY KEY, v) WITHOUT ROWID;
CREATE VIRTUAL TABLE spartiti_andr_fts USING fts5 (
    titolo,
    autore,
    volume,
    ArchivioProvenienza,
    content = 'spartiti_andr',
    content_rowid ='IdBra');
CREATE TABLE IF NOT EXISTS 'spartiti_andr_fts_data'(id INTEGER PRIMARY KEY, block BLOB);
CREATE TABLE IF NOT EXISTS 'spartiti_andr_fts_idx'(segid, term, pgno, PRIMARY KEY(segid, term)) WITHOUT ROWID;
CREATE TABLE IF NOT EXISTS 'spartiti_andr_fts_docsize'(id INTEGER PRIMARY KEY, sz BLOB);
CREATE TABLE IF NOT EXISTS 'spartiti_andr_fts_config'(k PRIMARY KEY, v) WITHOUT ROWID;
