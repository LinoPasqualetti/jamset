// File: lib/platform/file_opener_native.dart (ORA È L'INIETTORE)
import 'dart:io';
import 'android_opener.dart';
import 'other_opener.dart';
import 'opener_platform_interface.dart';

// Questa funzione viene chiamata una sola volta per configurare tutto.
void setupNativeOpeners() {
  if (Platform.isAndroid) {
    OpenerPlatformInterface.instance = AndroidOpener();
  } else {
    OpenerPlatformInterface.instance = OtherOpener();
  }
}
