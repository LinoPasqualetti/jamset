# 1. (Opzionale ma consigliato) Pulisci i file di backup che non vuoi più
#    rm "lib/screens/CSVViewer versione funzionateDaSurface.dart"
#    rm "lib/screens/csv_viewer_screen - CopiaDeiSugerimentiPerListaConPercoRadiceEResto.dart"
#    rm "lib/CSV_VIEWER OLD.dart"
#    rm "Assets/images/SfondoLibriRBeAeb2 - Copia.jpg"

# 2. Modifica o crea .gitignore per ignorare i file temporanei di Word
#    Aggiungi "~$*.docx" a .gitignore

# 3. Aggiungi i file che vuoi committare
git add lib/screens/csv_viewer_screen.dart     # Il file principale
git add Assets/images/SherlockCerca2.png      # La nuova immagine che usi
git add lib/screens/AppJamsetStruttura.md     # Per le ultime modifiche
git add .gitignore                            # Se hai modificato .gitignore

# Valuta se vuoi aggiungere gli altri file modificati come:
# git add Assets/SpartitiERicerca.pptx
# git add Assets/images/SfondoLibriRBeAeb2.jpg
# ...e così via per gli altri file in "Changes not staged" e "Untracked" che sono rilevanti

# 4. Controlla lo stato
git status

# 5. Se tutto è come vuoi, fai il commit
git commit -m "UI: Aggiornato empty state con SherlockCerca2 e sfondo; aggiunti file rilevanti"

# 6. Pusha le modifiche
git push origin main
