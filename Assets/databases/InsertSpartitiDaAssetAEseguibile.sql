--insert into spartiti
insert into spartiti
(IdBra               ,
    titolo              ,
    autore              ,
    strumento          ,
    volume             ,
    PercRadice          ,
    PercResto           ,
    PrimoLInk           ,
    TipoMulti           ,
    TipoDocu            ,
    ArchivioProvenienza ,
    NumPag              ,
    NumOrig             ,
    IdVolume            ,
    IdAutore  )   
select 
idBra               ,
    titolo              ,
    autore              ,
    strumento          ,
    volume             ,
    PercRadice          ,
    PercResto           ,
    PrimoLInk           ,
    TipoMulti           ,
    TipoDocu            ,
    ArchivioProvenienza ,
    NumPag              ,
    NumOrig             ,
    IdVolume            ,
    IdAutore     
 from 
VecchioDb0.spartiti_andr
