-- ============================================
-- MIGRAZIONE DATABASE ASSET - VERSIONE SICURA
-- Mantiene spartiti_andr, corregge FTS, aggiunge triggers
-- ============================================

-- 0. ATTIVA DEBUG
SELECT '🚀 INIZIO MIGRAZIONE' as status;

-- 1. VERIFICA STRUTTURA ATTUALE
SELECT '📋 TABELLE ESISTENTI:' as info;
SELECT type, name, sql FROM sqlite_master 
WHERE name NOT LIKE 'sqlite_%' 
ORDER BY type, name;

-- 2. CONTA RECORD CORRENTI
SELECT '📊 CONTEGGI PRE-MIGRAZIONE:' as info;
SELECT 
  (SELECT COUNT(*) FROM spartiti_andr) as spartiti_andr,
  (SELECT COUNT(*) FROM spartiti) as spartiti,
  (SELECT COUNT(*) FROM sqlite_master WHERE name LIKE '%fts%') as tabelle_fts;

-- 3. INIZIA TRANSAZIONE (per sicurezza)
BEGIN TRANSACTION;

-- 4. CREA NUOVA TABELLA spartiti (se serve)
CREATE TABLE IF NOT EXISTS spartiti_temp (
    IdBra INTEGER PRIMARY KEY AUTOINCREMENT,
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
    NumPag INTEGER,
    NumOrig INTEGER,
    IdVolume TEXT,
    IdAutore TEXT
);

-- 5. COPIA DATI (solo se spartiti è vuota)
INSERT OR IGNORE INTO spartiti_temp 
SELECT * FROM spartiti_andr 
WHERE NOT EXISTS (SELECT 1 FROM spartiti LIMIT 1);

-- Se spartiti ha già dati, copia quelli
INSERT OR IGNORE INTO spartiti_temp 
SELECT * FROM spartiti 
WHERE EXISTS (SELECT 1 FROM spartiti LIMIT 1);

-- 6. RIMPIAZZA TABELLA spartiti
DROP TABLE IF EXISTS spartiti;
ALTER TABLE spartiti_temp RENAME TO spartiti;

-- 7. ELIMINA FTS VECCHI (se esistono)
DROP TABLE IF EXISTS spartiti_fts;
DROP TABLE IF EXISTS spartiti_andr_fts;

-- 8. CREA NUOVO FTS CORRETTO
CREATE VIRTUAL TABLE spartiti_fts USING fts5(
    titolo,
    autore,
    volume,
    ArchivioProvenienza,
    content='spartiti',
    content_rowid='IdBra'
);

-- 9. ELIMINA TRIGGERS VECCHI
DROP TRIGGER IF EXISTS spartiti_ai_fts;
DROP TRIGGER IF EXISTS spartiti_au_fts;
DROP TRIGGER IF EXISTS spartiti_ad_fts;

-- 10. CREA NUOVI TRIGGERS
CREATE TRIGGER spartiti_ai_fts AFTER INSERT ON spartiti
BEGIN
    INSERT INTO spartiti_fts(rowid, titolo, autore, volume, ArchivioProvenienza)
    VALUES (
        new.IdBra,
        COALESCE(new.titolo, ''),
        COALESCE(new.autore, ''),
        COALESCE(new.volume, ''),
        COALESCE(new.ArchivioProvenienza, '')
    );
END;

CREATE TRIGGER spartiti_au_fts AFTER UPDATE ON spartiti
BEGIN
    UPDATE spartiti_fts SET
        titolo = COALESCE(new.titolo, ''),
        autore = COALESCE(new.autore, ''),
        volume = COALESCE(new.volume, ''),
        ArchivioProvenienza = COALESCE(new.ArchivioProvenienza, '')
    WHERE rowid = old.IdBra;
END;

CREATE TRIGGER spartiti_ad_fts AFTER DELETE ON spartiti
BEGIN
    DELETE FROM spartiti_fts WHERE rowid = old.IdBra;
END;

-- 11. POPOLA FTS CON DATI ESISTENTI
INSERT INTO spartiti_fts(rowid, titolo, autore, volume, ArchivioProvenienza)
SELECT 
    IdBra,
    COALESCE(titolo, ''),
    COALESCE(autore, ''),
    COALESCE(volume, ''),
    COALESCE(ArchivioProvenienza, '')
FROM spartiti;

-- 12. VERIFICA MIGRAZIONE
SELECT '✅ VERIFICA POST-MIGRAZIONE:' as info;
SELECT 
    (SELECT COUNT(*) FROM spartiti_andr) as spartiti_andr,
    (SELECT COUNT(*) FROM spartiti) as spartiti,
    (SELECT COUNT(*) FROM spartiti_fts) as fts,
    (SELECT COUNT(*) FROM spartiti_fts WHERE spartiti_fts MATCH '*') as test_fts;

-- 13. COMMIT TRANSAZIONE
COMMIT;

SELECT '🎉 MIGRAZIONE COMPLETATA CON SUCCESSO!' as status;