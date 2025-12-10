-- ============================================
-- MIGRAZIONE SEMPLICE - Senza content/content_rowid
-- Compatibile con SQLite senza FTS5 avanzato
-- ============================================

SELECT '🚀 INIZIO MIGRAZIONE SEMPLICE' as status;

-- 1. ELIMINA FTS ESISTENTI
DROP TABLE IF EXISTS spartiti_fts;
DROP TABLE IF EXISTS spartiti_andr_fts;

-- 2. CREA NUOVO FTS SEMPLICE (senza content/content_rowid)
CREATE VIRTUAL TABLE IF NOT EXISTS spartiti_fts USING fts5(
    titolo,
    autore,
    volume,
    ArchivioProvenienza
    -- ⭐️ SENZA content e content_rowid (problemi di compatibilità)
);

-- 3. ELIMINA TRIGGERS VECCHI
DROP TRIGGER IF EXISTS spartiti_ai_fts;
DROP TRIGGER IF EXISTS spartiti_au_fts;
DROP TRIGGER IF EXISTS spartiti_ad_fts;

-- 4. CREA NUOVI TRIGGERS SEMPLICI
CREATE TRIGGER IF NOT EXISTS spartiti_ai_fts AFTER INSERT ON spartiti
BEGIN
    INSERT INTO spartiti_fts(rowid, titolo, autore, volume, ArchivioProvenienza)
    VALUES (
        new.id_univoco_globale,
        COALESCE(new.titolo, ''),
        COALESCE(new.autore, ''),
        COALESCE(new.volume, ''),
        COALESCE(new.ArchivioProvenienza, '')
    );
END;

CREATE TRIGGER IF NOT EXISTS spartiti_au_fts AFTER UPDATE ON spartiti
BEGIN
    UPDATE spartiti_fts SET
        titolo = COALESCE(new.titolo, ''),
        autore = COALESCE(new.autore, ''),
        volume = COALESCE(new.volume, ''),
        ArchivioProvenienza = COALESCE(new.ArchivioProvenienza, '')
    WHERE rowid = old.id_univoco_globale;
END;

CREATE TRIGGER IF NOT EXISTS spartiti_ad_fts AFTER DELETE ON spartiti
BEGIN
    DELETE FROM spartiti_fts WHERE rowid = old.id_univoco_globale;
END;

-- 5. POPOLA FTS CON DATI ESISTENTI
INSERT INTO spartiti_fts(rowid, titolo, autore, volume, ArchivioProvenienza)
SELECT 
    id_univoco_globale,
    COALESCE(titolo, ''),
    COALESCE(autore, ''),
    COALESCE(volume, ''),
    COALESCE(ArchivioProvenienza, '')
FROM spartiti;

-- 6. VERIFICA
SELECT '✅ VERIFICA MIGRAZIONE:' as info;
SELECT 
    (SELECT COUNT(*) FROM spartiti_andr) as spartiti_andr,
    (SELECT COUNT(*) FROM spartiti) as spartiti,
    (SELECT COUNT(*) FROM spartiti_fts) as fts,
    (SELECT COUNT(*) FROM spartiti_fts WHERE spartiti_fts MATCH '*') as test_fts;

SELECT '🎉 MIGRAZIONE SEMPLICE COMPLETATA!' as status;