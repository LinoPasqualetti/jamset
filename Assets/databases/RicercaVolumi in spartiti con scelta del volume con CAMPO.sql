select id_univoco_globale,idbra,idvolume,volume,* from 
spartiti
where tipodocu = 'V'
--and (idbra = idvolume
--or id_univoco_globale=idvolume)

and volume like   @Volume
   --   AND (a.tipoMulti LIKE 'PDF%' OR a.tipoMulti LIKE 'PD%' OR a.tipoMulti IS NULL) ORDER BY a.titolo, a.strumento
