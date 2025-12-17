// lib/services/database_service_ibrido.dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Servizio IBRIDO che integra vecchio e nuovo sistema
class DatabaseServiceIbrido {
  static DatabaseServiceIbrido? _instance;
  Database? _dbGlobale;

  // Nomi database (coerenti con vecchio sistema)
  static const String _dbGlobaleName = 'DBGlobale.db';
  static const String _vecchioDbName = 'VecchioDb.db';

  // Riferimenti alle variabili GLOBALI (condivise con vecchio sistema)
  // IMPORTANTE: Queste variabili sono definite in main.dart
  // Le aggiorniamo qui per sincronizzazione
  late String gPercorsoPdf;
  late String gActiveCatalogDbName;
  late String gDatabasePath;

  // Collegamento al database del catalogo attivo
  Database? _dbCatalogoAttivo;

  DatabaseServiceIbrido._private();

  factory DatabaseServiceIbrido() {
    return _instance ??= DatabaseServiceIbrido._private();
  }

  /// ============================================================
  /// 1. INIZIALIZZAZIONE (DOPO che il vecchio sistema ha fatto il suo)
  /// ============================================================

  /// Deve essere chiamato DOPO inizializza_i_db_della_app()
  Future<void> inizializzaDopoVecchioSistema({
    required String percorsoPdf,
    required String catalogoAttivo,
    required String databasePath
  }) async {
    // Sincronizza con variabili globali del vecchio sistema
    gPercorsoPdf = percorsoPdf;
    gActiveCatalogDbName = catalogoAttivo;
    gDatabasePath = databasePath;

    print('🔄 DatabaseServiceIbrido sincronizzato con vecchio sistema:');
    print('   📂 Percorso PDF: $gPercorsoPdf');
    print('   📁 Catalogo attivo: $gActiveCatalogDbName');
    print('   🗂️  Path database: $gDatabasePath');

    // Inizializza DBGlobale
    await _inizializzaDbGlobale();
  }

  /// ============================================================
  /// 2. GESTIONE DB GLOBALE (DatiSistremaApp + elenco_cataloghi)
  /// ============================================================

  Future<Database> get dbGlobale async {
    if (_dbGlobale != null) return _dbGlobale!;
    return await _inizializzaDbGlobale();
  }

  Future<Database> _inizializzaDbGlobale() async {
    final path = p.join(gDatabasePath, _dbGlobaleName);

    // Apri semplicemente (il vecchio sistema l'ha già creato/configurato)
    _dbGlobale = await openDatabase(path);

    // Verifica che le tabelle esistano
    await _verificaStrutturaDbGlobale(_dbGlobale!);

    return _dbGlobale!;
  }

  Future<void> _verificaStrutturaDbGlobale(Database db) async {
    final tabelle = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'"
    );

    final nomiTabelle = tabelle.map((t) => t['name'] as String).toList();

    if (!nomiTabelle.contains('DatiSistremaApp')) {
      throw Exception('❌ Tabella DatiSistremaApp mancante!');
    }

    if (!nomiTabelle.contains('elenco_cataloghi')) {
      throw Exception('❌ Tabella elenco_cataloghi mancante!');
    }

    print('✅ Struttura DBGlobale verificata');
  }

  /// ============================================================
  /// 3. METODI PUBBLICI PER GESTIONE VOLUMI/CATALOGHI
  /// ============================================================

  /// Ottieni tutti i cataloghi disponibili
  Future<List<Map<String, dynamic>>> getAvailableVolumes() async {
    final db = await dbGlobale;

    // USA I NOMI CORRETTI del vecchio sistema: 'nome', 'descrizione'
    return await db.query(
        'elenco_cataloghi',
        columns: ['id', 'nome', 'nome_file_db', 'descrizione'],
        orderBy: 'nome ASC'
    );
  }

  /// Cambia catalogo attivo
  Future<bool> switchVolume(String dbFileName) async {
    try {
      final db = await dbGlobale;

      // 1. Trova catalogo per nome file
      final catalogo = await db.query(
          'elenco_cataloghi',
          where: 'nome_file_db = ?',
          whereArgs: [dbFileName],
          limit: 1
      );

      if (catalogo.isEmpty) {
        print('❌ Catalogo non trovato: $dbFileName');
        return false;
      }

      final catalogoId = catalogo.first['id'] as int;

      // 2. Aggiorna DatiSistremaApp
      await db.update(
        'DatiSistremaApp',
        {'id_catalogo_attivo': catalogoId},
        where: 'id = 1',
      );

      // 3. Aggiorna variabile GLOBALE (sincronizza con vecchio sistema)
      gActiveCatalogDbName = dbFileName;

      print('✅ Catalogo cambiato: $dbFileName (ID: $catalogoId)');

      // 4. RICARICA il database del catalogo (se necessario)
      await _ricaricaCatalogoAttivo();

      return true;
    } catch (e) {
      print('❌ Errore cambio catalogo: $e');
      return false;
    }
  }

  /// Ottieni catalogo corrente
  Future<Map<String, dynamic>> getCurrentVolume() async {
    final db = await dbGlobale;

    // Legge dal DBGlobale (come fa il vecchio sistema)
    final datiSistema = await db.query('DatiSistremaApp', limit: 1);

    if (datiSistema.isEmpty) {
      return {
        'nome': 'Catalogo Principale',
        'nome_file_db': _vecchioDbName,
        'descrizione': 'Catalogo predefinito'
      };
    }

    final idCatalogoAttivo = datiSistema.first['id_catalogo_attivo'] as int? ?? 1;

    final catalogoInfo = await db.query(
        'elenco_cataloghi',
        where: 'id = ?',
        whereArgs: [idCatalogoAttivo],
        limit: 1
    );

    if (catalogoInfo.isNotEmpty) {
      return {
        'id': catalogoInfo.first['id'],
        'nome': catalogoInfo.first['nome'],           // NOME CORRETTO
        'nome_file_db': catalogoInfo.first['nome_file_db'],
        'descrizione': catalogoInfo.first['descrizione']
      };
    }

    // Fallback al catalogo predefinito
    return {
      'nome': 'Catalogo Principale',
      'nome_file_db': _vecchioDbName,
      'descrizione': 'Catalogo predefinito'
    };
  }

  /// Aggiungi nuovo catalogo
  Future<int> aggiungiCatalogo({
    required String nome,
    required String nomeFileDb,
    String descrizione = '',
  }) async {
    final db = await dbGlobale;

    return await db.insert('elenco_cataloghi', {
      'nome': nome,
      'nome_file_db': nomeFileDb,
      'descrizione': descrizione,
    });
  }

  /// Aggiorna percorso PDF
  Future<void> aggiornaPercorsoPdf(String nuovoPercorso) async {
    final db = await dbGlobale;

    await db.update(
      'DatiSistremaApp',
      {'PercorsoPdf': nuovoPercorso},
      where: 'id = 1',
    );

    // Aggiorna variabile GLOBALE
    gPercorsoPdf = nuovoPercorso;

    print('✅ Percorso PDF aggiornato: $nuovoPercorso');
  }

  /// ============================================================
  /// 4. GESTIONE DATABASE CATALOGO ATTIVO
  /// ============================================================

  /// Ottieni database del catalogo attivo
  Future<Database?> get dbCatalogoAttivo async {
    if (_dbCatalogoAttivo != null) return _dbCatalogoAttivo;
    return await _caricaCatalogoAttivo();
  }

  Future<Database?> _caricaCatalogoAttivo() async {
    if (gActiveCatalogDbName.isEmpty) {
      print('⚠️ Nessun catalogo attivo configurato');
      return null;
    }

    final catalogoPath = p.join(gDatabasePath, gActiveCatalogDbName);
    final catalogoFile = File(catalogoPath);

    if (!await catalogoFile.exists()) {
      print('❌ File catalogo non trovato: $catalogoPath');
      return null;
    }

    try {
      _dbCatalogoAttivo = await openDatabase(catalogoPath);
      print('✅ Catalogo caricato: $gActiveCatalogDbName');
      return _dbCatalogoAttivo;
    } catch (e) {
      print('❌ Errore caricamento catalogo: $e');
      return null;
    }
  }

  Future<void> _ricaricaCatalogoAttivo() async {
    if (_dbCatalogoAttivo != null && _dbCatalogoAttivo!.isOpen) {
      await _dbCatalogoAttivo!.close();
      _dbCatalogoAttivo = null;
    }

    await _caricaCatalogoAttivo();
  }

  /// ============================================================
  /// 5. UTILITY E DIAGNOSTICA
  /// ============================================================

  Future<void> diagnosticaCompleta() async {
    print('\n' + '='*60);
    print('🔍 DIAGNOSTICA SISTEMA IBRIDO');
    print('='*60);

    print('📊 STATO ATTUALE:');
    print('   Percorso PDF: $gPercorsoPdf');
    print('   Catalogo attivo: $gActiveCatalogDbName');
    print('   Path database: $gDatabasePath');

    final db = await dbGlobale;

    // 1. DatiSistremaApp
    print('\n📝 DATI SISTREMA APP:');
    final datiSistema = await db.query('DatiSistremaApp', limit: 1);
    if (datiSistema.isNotEmpty) {
      print('   PercorsoPdf: ${datiSistema.first['PercorsoPdf']}');
      print('   id_catalogo_attivo: ${datiSistema.first['id_catalogo_attivo']}');
    }

    // 2. Elenco cataloghi
    print('\n📁 ELENCO CATALOGHI:');
    final cataloghi = await getAvailableVolumes();
    for (var catalogo in cataloghi) {
      final isAttivo = catalogo['nome_file_db'] == gActiveCatalogDbName;
      print('   ${isAttivo ? '→ ' : '  '}${catalogo['nome']} (${catalogo['nome_file_db']})');
    }

    print('='*60);
  }

  /// Forza sincronizzazione con variabili globali del main.dart
  void sincronizzaConMain({
    required String percorsoPdf,
    required String catalogoAttivo,
    required String databasePath
  }) {
    gPercorsoPdf = percorsoPdf;
    gActiveCatalogDbName = catalogoAttivo;
    gDatabasePath = databasePath;

    print('🔄 Sincronizzato con main.dart');
  }
}