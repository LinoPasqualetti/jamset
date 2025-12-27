--select instr(PercRadice,'Jamset'),substr(PercRadice,1,20), substr(PercRadice,20)||substr(percresto,2),percradice,percresto,* from 
update
spartiti_andr
set PercRadice =  substr(PercRadice,1,20),
PercResto=substr(PercRadice,20)||substr(PercResto,2)
