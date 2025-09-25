INSERT INTO Spartiti (
--id_utente, nome_utente, cognome_utente, data_iscrizion
IdBra,
    titolo,
    autore,
    strumento,
    volume,
    PercRadice,
    PercResto,
    PrimoLInk,
    TipoMulti,
    TipoDocu,
    ArchivioProvenienza,
    NumPag,
    NumOrig,
    IdVolume,
    IdAutore

)
SELECT 
IdBra,
    titolo,
    autore,
    strumento,
    volume,
    PercRadice,
    PercResto,
    PrimoLInk,
    TipoMulti,
    TipoDocu,
    ArchivioProvenienza,
    NumPag,
    NumOrig,
    IdVolume,
    IdAutore
FROM spartiti2;