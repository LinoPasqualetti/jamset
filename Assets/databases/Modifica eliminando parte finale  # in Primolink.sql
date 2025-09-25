UPDATE Spartiti2
   SET PrimoLink = substr(PrimoLink, 1, instr(Primolink, "#") -1) 
 WHERE instr(Primolink, "#") > 1;
