// File: lib/platform/opener_platform_interface.dart
import 'package:flutter/widgets.dart';

// 1. Definiamo un "contratto" astratto.
abstract class OpenerPlatformInterface {
  // 2. Un'istanza statica che punterà all'implementazione corretta.
  static late OpenerPlatformInterface instance;

  // 3. Il metodo che tutte le piattaforme dovranno implementare.
  Future<void> openPdf({
    // Il BuildContext non è più parte del contratto generale.
    // Verrà gestito internamente dalle singole implementazioni se necessario.
    required String filePath,
    required int page,
    BuildContext? context, // Lo rendiamo opzionale
  });
}
