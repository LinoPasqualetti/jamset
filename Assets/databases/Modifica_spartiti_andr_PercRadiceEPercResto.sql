--select primolink, instr(primolink,volume), substr(primolink,3,instr(primolink,volume) -3)
-- as futuroPercResto 
 --from spartiti_andr
 update spartiti_andr set 
--PercResto = substr(primolink,3,instr(primolink,volume) -3)
PercRadice = "/storage/emulated/0/JamsetPDF/"
--substr(primolink,1,instr(primolink,volume)-1)
-- from spartiti2