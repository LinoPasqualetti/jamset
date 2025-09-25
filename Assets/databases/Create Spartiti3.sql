CREATE TABLE spartiti3 (
    id_univoco_globale   INTEGER UNIQUE,
    titolo               TEXT    NOT NULL,
    autore               TEXT,
    strumento            TEXT,
    volume               TEXT,
    PercRadice           TEXT,
    PercResto            TEST,
    PrimoLink            TEXT,
    TipoMulti            TEXT,
    TipoDocu             TEXT,
    NumPag               INTEGER,
    NumOrig              INTEGER,
    ArchivioProvenienza  TEXT,
    tonalita             TEXT,
    genere               TEXT,
    difficolta           TEXT,
    data_aggiunta        TEXT    DEFAULT (STRFTIME('%Y-%m-%d %H:%M:%S', 'NOW', 'localtime') ),
    data_ultima_modifica TEXT,
    note_personali       TEXT,
    idBra                TEXT,
    IdVolume             TEXT,
    IdAutore             TEXT,
    PRIMARY KEY (
        id_univoco_globale AUTOINCREMENT
    )
);
