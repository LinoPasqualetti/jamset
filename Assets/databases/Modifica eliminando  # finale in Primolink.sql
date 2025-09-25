--SELECT PrimoLink,
--       substr(PrimoLink,1, LENGTH(Primolink)-1 ) AS SenzaTesta
--  FROM
  UPDATE Spartiti2
  SET PrimoLink = 
  substr(PrimoLink,1, LENGTH(Primolink)-1 )
 WHERE instr(Primolink, "#") > 0;
