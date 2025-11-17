select distinct volume,ArchivioProvenienza, strumento,primolink, percradice,percresto
from
spartiti
where 
tipoMulti like 'PD%'
and ArchivioProvenienza like 'Real%'
order by volume,strumento