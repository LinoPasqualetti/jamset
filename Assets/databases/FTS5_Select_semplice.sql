--SELECT * from 
---spartiti_fts
--where


--SELECT * FROM spartiti_fts WHERE spartiti_fts MATCH 'when darkness'
--order by titolo,volume;

select distinct Numpag,a.titolo,a.volume,percradice||percresto||a.Volume as PerApertura,a.ArchivioProvenienza, strumento,primolink, percradice,percresto 
from spartiti a
JOIN spartiti_fts fts on a.idBra=fts.rowid
 where a.tipoMulti like 'PD%' and spartiti_fts match 'girl ipanema'
order by a.titolo,a.strumento
