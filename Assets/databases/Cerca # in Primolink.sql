SELECT PrimoLink,
       substr(PrimoLink, 1, instr(Primolink, "#") ) AS SenzaTesta
  FROM
  /* UPDATE */ 
  Spartiti2
  -- SET PrimoLink = substr(PrimoLink,1,instr( Primolink,"#"))
 WHERE instr(Primolink, "#") > 1;
