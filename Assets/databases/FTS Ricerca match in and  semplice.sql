SELECT DISTINCT Numpag,a.titolo, a.volume,  a.ArchivioProvenienza,a.strumento, primolink, '${gPercorsoPdf}' percradice, percresto, '${gPercorsoPdf}' || percresto || '/' || a.Volume as PerApertura
      FROM spartiti a   WHERE a.id_univoco_globale IN ( SELECT rowid FROM spartiti_fts  
      
WHERE spartiti_fts MATCH 
      'girl ipanema' )  
      
AND (a.tipoMulti LIKE 'PDF%' OR a.tipoMulti LIKE 'PD%' OR a.tipoMulti IS NULL) ORDER BY a.titolo, a.strumento   