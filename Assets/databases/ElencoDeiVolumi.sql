SELECT count(*) , volume,strumento --,ArchivioProvenienza      --,count(volume,strumento,ArchivioProvenienza)        -- ArchivioProvenienza,
                --strumento,
                --primolink,
                --percradice,
                --percresto,
--          count(*)
  FROM spartiti
 WHERE tipoMulti LIKE 'PD%' 
 --     and   ArchivioProvenienza LIKE 'Real%'
 group BY volume,
          strumento;
