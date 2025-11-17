                     
                     SELECT IdBra,
                            titolo,
                            autore,
                            strumento,
                            volume,
                            PercRadice,
                         PercResto,
                         PrimoLInk,
                            TipoMulti,
                            TipoDocu,
                            ArchivioProvenienza,
                            NumPag,
                            NumOrig,
                            IdVolume,
                            IdAutore
                       FROM spartiti
                       where
                            titolo like  ?
                       and ArchivioProvenienza like ?
                       and volume like ?
                       and strumento like ?
                       and TipoMulti like ?
                       and autore like ?
                       order by titolo,strumento,volume