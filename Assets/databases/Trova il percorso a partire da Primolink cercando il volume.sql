--select primolink, instr(primolink,volume), substr(primolink,3,instr(primolink,volume) -3)
--from spartiti2
update spartiti2 set 
--PercResto = substr(primolink,3,instr(primolink,volume) -3)
PercRadice = "C:\Users\LINOP\AppData\Roaming\com.example\area_di_test"
--substr(primolink,1,instr(primolink,volume)-1)
-- from spartiti2