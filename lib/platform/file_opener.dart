// File: lib/platform/file_opener.dart (VERSIONE CORRETTA E SEMPLIFICATA)

// Esporta il file corretto in base alla piattaforma (Web o Nativa).
// Questa è l'unica cosa che questo file deve fare.
export 'file_opener_stub.dart' // Fallback di default
if (kIsWeb) 'file_opener_web.dart' // Se è web, usa la versione web
if (dart.library.io) 'file_opener_native.dart'; // Se è nativo (non web), usa la versione nativa

// Importa le librerie necessarie per le condizioni qui sopra.
import 'package:flutter/foundation.dart' show kIsWeb;
