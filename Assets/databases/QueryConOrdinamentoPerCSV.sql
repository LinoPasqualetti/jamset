SELECT 
       tipodocu,idvolume,idbra,titolo,tipomulti,
       volume,
       numpag,
       
       *
  FROM spartiti

spartiti
where 
ArchivioProvenienza like @campo
and not tipomulti = 'DIR'
order by idvolume,  tipodocu desc, numpag