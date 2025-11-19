import 'dart:io';
import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Inizializza un singolo database, copiandolo dalla cartella assets
/// se non esiste già nella directory dei database dell'applicazione.
Future<Database> initDatabase(String dbName) async {
  final dbDir = await getDatabasesPath();
  final dbPath = join(dbDir, dbName);

  // Copia dagli asset solo se il file non esiste
  if (!(await File(dbPath).exists())) {
    print("Copia del database '$dbName' dagli assets...");
    try {
      ByteData data = await rootBundle.load(join("assets", "databases", dbName));
      List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await File(dbPath).writeAsBytes(bytes, flush: true);
      print("Copia completata: $dbPath");
    } catch (e) {
      throw Exception("Errore durante la copia del database '$dbName': $e");
    }
  }
  // Apri il database
  return await openDatabase(dbPath);
}
