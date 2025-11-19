import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // Useremo questo pacchetto per il web
import 'opener_platform_interface.dart';

class WebOpener implements OpenerPlatformInterface {
  @override
  Future<bool> openPdf({
    required BuildContext context,
    required String filePath, // Qui 'filePath' conterrà l'URL base del PDF
    int? page,             // Il numero di pagina che vogliamo raggiungere
  }) async {
    // 1. Iniziamo con l'URL base del PDF.
    String urlConPagina = filePath;

    // 2. LOGICA DI GESTIONE DELLA PAGINA
    //    Se viene fornito un numero di pagina valido (maggiore di 0),
    //    lo aggiungiamo all'URL come frammento.
    if (page != null && page > 0) {
      // Aggiungiamo il frammento #page=NUMERO all'URL
      urlConPagina = '$urlConPagina#page=$page';
    }

    // 3. Convertiamo la stringa dell'URL finale (con il frammento) in un oggetto Uri.
    //    Usiamo tryParse per evitare errori in caso di URL malformato.
    final Uri? url = Uri.tryParse(urlConPagina);

    // 4. Controlliamo se l'URL è valido e se il browser può aprirlo.
    if (url != null && await canLaunchUrl(url)) {
      try {
        // 5. Chiediamo al browser di aprire l'URL in una nuova scheda.
        //    Sarà il browser a interpretare il frammento '#page=' e a posizionarsi
        //    sulla pagina corretta, se il suo visualizzatore PDF lo supporta.
        await launchUrl(url, mode: LaunchMode.externalApplication);
        print("Tentativo di apertura URL: $url");
        return true; // Successo
      } catch (e) {
        print("Errore durante l'apertura dell'URL con url_launcher: $e");
        return false; // Fallimento
      }
    } else {
      print("URL non valido o non lanciabile: $urlConPagina");
      return false; // Fallimento
    }
  }
}
