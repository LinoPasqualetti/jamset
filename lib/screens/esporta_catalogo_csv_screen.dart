// lib/screens/esporta_catalogo_csv_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../services/database_service.dart';

class EsportaCatalogoCsvScreen extends StatefulWidget {
  const EsportaCatalogoCsvScreen({super.key});

  @override
  State<EsportaCatalogoCsvScreen> createState() => _EsportaCatalogoCsvScreenState();
}

class _EsportaCatalogoCsvScreenState extends State<EsportaCatalogoCsvScreen> {
  final DatabaseService databaseService = DatabaseService();

  String _exportType = 'completo';
  String _status = 'Pronto';
  double _progress = 0.0;
  bool _isProcessing = false;
  String? _generatedFilePath;
  int _exportedRecords = 0;

  final TextEditingController _fileNameController = TextEditingController();
  final TextEditingController _volumeTextController = TextEditingController();
  final TextEditingController _archivioTextController = TextEditingController();
  final TextEditingController _autoreTextController = TextEditingController();
  final TextEditingController _strumentoTextController = TextEditingController();
  final TextEditingController _idVolumeController = TextEditingController();

  String? _selectedVolume;
  String? _selectedArchivio;
  String? _selectedAutore;
  String? _selectedStrumento;

  List<String> _consoleOutput = [];
  final ScrollController _consoleScrollController = ScrollController();

  final List<Map<String, dynamic>> _exportOptions = [
    {'value': 'completo', 'label': 'Catalogo completo'},
    {'value': 'volume', 'label': 'Per volume'},
    {'value': 'archivio', 'label': 'Per archivio'},
    {'value': 'autore', 'label': 'Per autore'},
    {'value': 'strumento', 'label': 'Per strumento'},
    {'value': 'id_volume', 'label': 'Per ID volume'},
    {'value': 'solo_volumi', 'label': 'Solo record volume'},
    {'value': 'solo_brani', 'label': 'Solo record brani'},
    {'value': 'statistiche', 'label': 'Statistiche catalogo'},
  ];

  List<String> _volumes = [];
  List<String> _archivi = [];
  List<String> _autori = [];
  List<String> _strumenti = [];

  @override
  void initState() {
    super.initState();
    _generateDefaultFileName();
    _loadCatalogData();
  }

  // Genera il nome file di default in base al tipo di esportazione
  void _generateDefaultFileName() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    String fileName = '';

    switch (_exportType) {
      case 'completo':
        fileName = 'catalogo_completo_$timestamp.csv';
        break;
      case 'volume':
        final volumeName = _selectedVolume ?? _volumeTextController.text;
        if (volumeName.isNotEmpty) {
          fileName = '${_sanitizeFileName(volumeName)}_$timestamp.csv';
        } else {
          fileName = 'volume_$timestamp.csv';
        }
        break;
      case 'archivio':
        final archivioName = _selectedArchivio ?? _archivioTextController.text;
        if (archivioName.isNotEmpty) {
          fileName = '${_sanitizeFileName(archivioName)}_$timestamp.csv';
        } else {
          fileName = 'archivio_$timestamp.csv';
        }
        break;
      case 'autore':
        final autoreName = _selectedAutore ?? _autoreTextController.text;
        if (autoreName.isNotEmpty) {
          fileName = '${_sanitizeFileName(autoreName)}_$timestamp.csv';
        } else {
          fileName = 'autore_$timestamp.csv';
        }
        break;
      case 'strumento':
        final strumentoName = _selectedStrumento ?? _strumentoTextController.text;
        if (strumentoName.isNotEmpty) {
          fileName = '${_sanitizeFileName(strumentoName)}_$timestamp.csv';
        } else {
          fileName = 'strumento_$timestamp.csv';
        }
        break;
      case 'id_volume':
        final idVolume = _idVolumeController.text;
        if (idVolume.isNotEmpty) {
          fileName = 'id_volume_${_sanitizeFileName(idVolume)}_$timestamp.csv';
        } else {
          fileName = 'id_volume_$timestamp.csv';
        }
        break;
      case 'solo_volumi':
        fileName = 'solo_record_volume_$timestamp.csv';
        break;
      case 'solo_brani':
        fileName = 'solo_record_brani_$timestamp.csv';
        break;
      case 'statistiche':
        fileName = 'statistiche_catalogo_$timestamp.csv';
        break;
      default:
        fileName = 'esportazione_$timestamp.csv';
    }

    _fileNameController.text = fileName;
  }

  // Aggiorna il nome file quando cambia il tipo di esportazione o i filtri
  void _updateFileName() {
    _generateDefaultFileName();
  }

  Future<void> _loadCatalogData() async {
    try {
      await databaseService.initialize();

      _volumes = await databaseService.getDistinctVolumes();
      _archivi = await databaseService.getDistinctArchivi();
      _autori = await databaseService.getDistinctAutori();
      _strumenti = await databaseService.getDistinctStrumenti();

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      _addConsoleOutput('❌ Errore caricamento dati: $e');
    }
  }

  void _addConsoleOutput(String message) {
    final timestamp = DateTime.now().toString().split(' ')[1].substring(0, 12);
    _consoleOutput.add('[$timestamp] $message');

    if (_consoleOutput.length > 100) {
      _consoleOutput.removeAt(0);
    }

    if (mounted) {
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _consoleScrollController.animateTo(
          _consoleScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  String _sanitizeFileName(String fileName) {
    // Rimuovi caratteri non validi per i nomi file
    final invalidChars = RegExp(r'[<>:"/\\|?*]');
    // Sostituisci spazi multipli con un singolo underscore
    fileName = fileName.replaceAll(invalidChars, '_').replaceAll(RegExp(r'\s+'), '_').trim();
    // Rimuovi underscore multipli consecutivi
    fileName = fileName.replaceAll(RegExp(r'_+'), '_');
    // Rimuovi underscore a inizio/fine
    fileName = fileName.replaceAll(RegExp(r'^_+|_+$'), '');
    // Limita la lunghezza del nome file
    if (fileName.length > 100) {
      fileName = '${fileName.substring(0, 97)}...';
    }
    return fileName;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
    _addConsoleOutput('❌ $message');
  }

  Future<void> _saveExportLog(String filePath, int recordCount, Duration duration) async {
    try {
      final appDocDir = await getApplicationSupportDirectory();
      final logFile = File(p.join(appDocDir.path, 'csv_exports_log.csv'));

      final logEntry = '${DateTime.now().toIso8601String()};'
          '${p.basename(filePath)};'
          '$_exportType;'
          '$recordCount;'
          '${duration.inSeconds} secondi;'
          '${databaseService.activeCatalogDbName}\n';

      String logContent = '';
      if (await logFile.exists()) {
        logContent = await logFile.readAsString();
      } else {
        logContent = 'Data;NomeFile;Tipo;Record;Durata;Catalogo\n';
      }

      logContent += logEntry;
      await logFile.writeAsString(logContent);

      _addConsoleOutput('📋 Log salvato in: ${logFile.path}');
    } catch (e) {
      _addConsoleOutput('⚠️ Errore salvataggio log: $e');
    }
  }

  Future<void> _exportToCsv() async {
    if (_isProcessing) return;

    // Validazioni
    String? filterValue;

    if (_exportType == 'volume') {
      filterValue = _selectedVolume ?? _volumeTextController.text;
      if (filterValue.isEmpty) {
        _showError('Inserire un volume');
        return;
      }
    } else if (_exportType == 'archivio') {
      filterValue = _selectedArchivio ?? _archivioTextController.text;
      if (filterValue.isEmpty) {
        _showError('Inserire un archivio');
        return;
      }
    } else if (_exportType == 'autore') {
      filterValue = _selectedAutore ?? _autoreTextController.text;
      if (filterValue.isEmpty) {
        _showError('Inserire un autore');
        return;
      }
    } else if (_exportType == 'strumento') {
      filterValue = _selectedStrumento ?? _strumentoTextController.text;
      if (filterValue.isEmpty) {
        _showError('Inserire uno strumento');
        return;
      }
    } else if (_exportType == 'id_volume' && _idVolumeController.text.isEmpty) {
      _showError('Inserire un ID volume');
      return;
    }

    // Validazione nome file
    String fileName = _fileNameController.text.trim();
    if (fileName.isEmpty) {
      _showError('Inserire un nome per il file CSV');
      return;
    }

    // Pulisci il nome file
    fileName = _sanitizeFileName(fileName);
    if (fileName.isEmpty) {
      _showError('Nome file non valido');
      return;
    }

    // Assicurati che abbia estensione .csv
    if (!fileName.toLowerCase().endsWith('.csv')) {
      fileName = '$fileName.csv';
    }

    setState(() {
      _isProcessing = true;
      _status = 'Preparazione esportazione...';
      _progress = 0.0;
      _generatedFilePath = null;
      _exportedRecords = 0;
    });

    _addConsoleOutput('\n══════════════════════════════════════════════════');
    _addConsoleOutput('🚀 INIZIO ESPORTAZIONE CSV');
    _addConsoleOutput('📊 Tipo: ${_exportOptions.firstWhere((opt) => opt['value'] == _exportType)['label']}');
    _addConsoleOutput('📁 Catalogo: ${databaseService.activeCatalogDbName}');
    _addConsoleOutput('📄 Nome file: $fileName');
    _addConsoleOutput('🕐 Orario inizio: ${DateTime.now().toString().split(' ')[1]}');

    try {
      String? csvPath;
      final startTime = DateTime.now();
      final stopwatch = Stopwatch()..start();

      // DEBUG: Stampa informazioni prima della chiamata
      _addConsoleOutput('🔍 DEBUG: Chiamata al DatabaseService in corso...');
      _addConsoleOutput('🔍 DEBUG: Tipo esportazione: $_exportType');
      _addConsoleOutput('🔍 DEBUG: Filtro: ${filterValue ?? _idVolumeController.text}');

      switch (_exportType) {
        case 'completo':
          _addConsoleOutput('📦 Avvio esportazione catalogo completo');
          csvPath = await databaseService.exportFullCatalogToCsv();
          break;

        case 'volume':
          _addConsoleOutput('📚 Avvio esportazione per volume: "$filterValue"');
          csvPath = await databaseService.exportVolumeToCsv(filterValue!);
          break;

        case 'archivio':
          _addConsoleOutput('🏛️ Avvio esportazione per archivio: "$filterValue"');
          csvPath = await databaseService.exportArchiveToCsv(filterValue!);
          break;

        case 'autore':
          _addConsoleOutput('👤 Avvio esportazione per autore: "$filterValue"');
          csvPath = await databaseService.exportAuthorToCsv(filterValue!);
          break;

        case 'strumento':
          _addConsoleOutput('🎵 Avvio esportazione per strumento: "$filterValue"');
          csvPath = await databaseService.exportInstrumentToCsv(filterValue!);
          break;

        case 'id_volume':
          _addConsoleOutput('🔢 Avvio esportazione per ID volume: "${_idVolumeController.text}"');
          csvPath = await databaseService.exportByVolumeId(_idVolumeController.text);
          break;

        case 'solo_volumi':
          _addConsoleOutput('📗 Avvio esportazione solo record volume');
          csvPath = await databaseService.exportVolumeRecordsToCsv();
          break;

        case 'solo_brani':
          _addConsoleOutput('📘 Avvio esportazione solo record brani');
          csvPath = await databaseService.exportPieceRecordsToCsv();
          break;

        case 'statistiche':
          _addConsoleOutput('📊 Avvio esportazione statistiche catalogo');

          try {
            // Usa il timeout per le statistiche
            csvPath = await databaseService.exportCatalogStatsToCsv()
                .timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                _addConsoleOutput('⏰ Timeout: Creazione versione semplificata...');
                // Crea un file di fallback
                return _createFallbackStatsFile();
              },
            );
          } on TimeoutException catch (e) {
            _addConsoleOutput('⚠️ Timeout durante l\'esportazione statistiche');
            csvPath = await _createFallbackStatsFile();
          } catch (e) {
            _addConsoleOutput('❌ Errore esportazione statistiche: $e');
            csvPath = await _createFallbackStatsFile(e.toString());
          }
          break;
      }

      stopwatch.stop();
      _addConsoleOutput('⏱️ DEBUG: Chiamata DatabaseService completata in ${stopwatch.elapsedMilliseconds}ms');

      if (csvPath == null) {
        throw Exception('Il DatabaseService ha restituito null');
      }

      _addConsoleOutput('✅ File generato dal DatabaseService');
      _addConsoleOutput('📁 Percorso temporaneo: $csvPath');

      if (!await File(csvPath).exists()) {
        throw Exception('File CSV non trovato nel percorso: $csvPath');
      }

      final file = File(csvPath);
      final stats = file.statSync();
      final lines = await file.readAsLines();
      final recordCount = _exportType == 'statistiche'
          ? lines.length - 1 // esclude l'header
          : lines.length - 1;

      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);

      // DEBUG: Informazioni dettagliate sul file
      _addConsoleOutput('🔍 DEBUG: File esistente: SI');
      _addConsoleOutput('🔍 DEBUG: Dimensione file: ${stats.size} bytes');
      _addConsoleOutput('🔍 DEBUG: Righe totali nel file: ${lines.length}');
      _addConsoleOutput('🔍 DEBUG: Record esportati: $recordCount');

      // DEBUG: Mostra prime e ultime righe per controllo
      if (lines.isNotEmpty) {
        _addConsoleOutput('🔍 DEBUG: Prima riga (header): ${lines[0].length > 100 ? "${lines[0].substring(0, 100)}..." : lines[0]}');
        if (lines.length > 1) {
          _addConsoleOutput('🔍 DEBUG: Seconda riga (primo record): ${lines[1].length > 100 ? "${lines[1].substring(0, 100)}..." : lines[1]}');
        }
        if (lines.length > 10) {
          _addConsoleOutput('🔍 DEBUG: Ultima riga: ${lines.last.length > 100 ? "${lines.last.substring(0, 100)}..." : lines.last}');
        }
      }

      // Rinomina il file con il nome scelto dall'utente
      final tempDir = await getTemporaryDirectory();

      // Gestione nome file duplicato
      final newFile = File('${tempDir.path}/$fileName');
      String finalFileName = fileName;

      if (await newFile.exists()) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final nameWithoutExt = fileName.replaceAll(RegExp(r'\.csv$', caseSensitive: false), '');
        finalFileName = '${nameWithoutExt}_$timestamp.csv';
        _addConsoleOutput('⚠️ Attenzione: File esiste già, rinomino in: $finalFileName');
      }

      final finalFilePath = '${tempDir.path}/$finalFileName';
      await file.copy(finalFilePath);

      // Cancella il file temporaneo originale
      await file.delete();

      csvPath = finalFilePath;

      // Aggiorna stato
      _updateProgress('✅ Esportazione completata!', 1.0);

      // Aggiornamento dello stato con mounted check
      if (mounted) {
        setState(() {
          _generatedFilePath = csvPath;
          _exportedRecords = recordCount;
          _isProcessing = false; // IMPORTANTE: Reset del flag di processing
        });
      }

      // Log dettagliato
      _addConsoleOutput('══════════════════════════════════════════════════');
      _addConsoleOutput('✅ ESPORTAZIONE COMPLETATA');
      _addConsoleOutput('📄 File finale: ${p.basename(csvPath)}');
      _addConsoleOutput('📁 Percorso: ${p.dirname(csvPath)}');
      _addConsoleOutput('💾 Dimensione: ${stats.size} bytes');
      _addConsoleOutput('📊 Record esportati: $recordCount');
      _addConsoleOutput('⏱️ Durata totale: ${duration.inSeconds} secondi');
      _addConsoleOutput('🕐 Orario completamento: ${endTime.toString().split(' ')[1]}');

      if (_exportType != 'statistiche') {
        _addConsoleOutput('📋 Campi per record: ${lines.isNotEmpty ? lines[0].split(';').length : 0}');
      }

      // Salva info in un file di log
      await _saveExportLog(csvPath, recordCount, duration);

      _addConsoleOutput('📝 Log esportazione salvato');
      _addConsoleOutput('══════════════════════════════════════════════════');

    } catch (e, stackTrace) {
      _addConsoleOutput('══════════════════════════════════════════════════');
      _addConsoleOutput('❌ ERRORE ESPORTAZIONE');
      _addConsoleOutput('💥 Errore: $e');
      if (stackTrace != null) {
        _addConsoleOutput('🔍 Stack trace: $stackTrace');
      }
      _addConsoleOutput('══════════════════════════════════════════════════');

      _updateProgress('❌ Errore: $e', 0.0);

      // Reset del flag anche in caso di errore
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  // Metodo per aggiornare lo stato e il progresso
  void _updateProgress(String status, double progress) {
    if (mounted) {
      setState(() {
        _status = status;
        _progress = progress;
      });
    }
  }

  // Metodi helper per creare file di fallback
  Future<String> _createFallbackStatsFile([String? errorMessage]) async {
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = errorMessage != null
        ? 'statistiche_errore_$timestamp.csv'
        : 'statistiche_semplici_$timestamp.csv';

    final csvPath = p.join(tempDir.path, fileName);

    final csvBuffer = StringBuffer();
    csvBuffer.write('Statistiche Catalogo - Informazioni limitate\n');
    csvBuffer.write('===========================================\n\n');
    csvBuffer.write('Data generazione;${DateTime.now().toLocal().toString()}\n');
    csvBuffer.write('Catalogo attivo;${databaseService.activeCatalogDbName}\n');

    if (errorMessage != null) {
      csvBuffer.write('Errore;$errorMessage\n');
      csvBuffer.write('Nota;Non è stato possibile generare statistiche complete\n');
    } else {
      csvBuffer.write('Nota;Statistiche semplificate generate automaticamente\n');
      csvBuffer.write('Informazioni;Prova ad esportare il catalogo completo per statistiche dettagliate\n');
    }

    await File(csvPath).writeAsString(csvBuffer.toString());

    _addConsoleOutput('📄 Creato file fallback: ${p.basename(csvPath)}');
    return csvPath;
  }

  void _copyToClipboard() {
    if (_generatedFilePath == null) {
      _showError('Nessun percorso da copiare');
      return;
    }

    Clipboard.setData(ClipboardData(text: _generatedFilePath!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Percorso copiato negli appunti'),
        duration: Duration(seconds: 2),
      ),
    );
    _addConsoleOutput('📋 Percorso copiato negli appunti');
  }

  void _openFileExplorer() async {
    if (_generatedFilePath == null || !await File(_generatedFilePath!).exists()) {
      _showError('Nessun file disponibile');
      return;
    }

    try {
      // Su Windows, usa 'explorer' per aprire la cartella
      if (Platform.isWindows) {
        final file = File(_generatedFilePath!);
        final directory = file.parent.path;

        // Escapizza il percorso per Windows
        final escapedPath = directory.replaceAll('/', '\\');

        await Process.run('explorer', [escapedPath]);
        _addConsoleOutput('📂 Apertura Esplora File: $escapedPath');
      } else if (Platform.isAndroid) {
        // Per Android, mostra un dialog con il percorso
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('File CSV'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('File generato con successo:'),
                const SizedBox(height: 8),
                Text(_generatedFilePath!, style: const TextStyle(fontFamily: 'monospace')),
                const SizedBox(height: 16),
                const Text('Il file si trova nella cartella temporanea dell\'app.'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      _showError('Impossibile aprire Esplora File: $e');
    }
  }

  void _clearConsole() {
    setState(() {
      _consoleOutput.clear();
    });
    _addConsoleOutput('🧹 Console pulita');
  }

  Widget _buildExportTypeInputs() {
    switch (_exportType) {
      case 'volume':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Volume:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_volumes.isNotEmpty)
              DropdownButtonFormField<String>(
                value: _selectedVolume,
                items: _volumes.map((volume) {
                  return DropdownMenuItem<String>(
                    value: volume,
                    child: Text(volume.length > 50 ? '${volume.substring(0, 50)}...' : volume),
                  );
                }).toList(),
                onChanged: _isProcessing ? null : (value) {
                  setState(() {
                    _selectedVolume = value;
                    // Aggiorna il nome file quando si seleziona un volume
                    _updateFileName();
                  });
                },
                decoration: const InputDecoration(
                  hintText: 'Seleziona un volume',
                  border: OutlineInputBorder(),
                ),
              ),
            const SizedBox(height: 8),
            const Text('Oppure inserisci manualmente:'),
            TextField(
              controller: _volumeTextController,
              onChanged: (value) {
                // Aggiorna il nome file quando si digita manualmente
                _updateFileName();
              },
              decoration: const InputDecoration(
                hintText: 'Nome del volume',
                border: OutlineInputBorder(),
              ),
              enabled: !_isProcessing,
            ),
          ],
        );

      case 'archivio':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Archivio:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_archivi.isNotEmpty)
              DropdownButtonFormField<String>(
                value: _selectedArchivio,
                items: _archivi.map((archivio) {
                  return DropdownMenuItem<String>(
                    value: archivio,
                    child: Text(archivio),
                  );
                }).toList(),
                onChanged: _isProcessing ? null : (value) {
                  setState(() {
                    _selectedArchivio = value;
                    _updateFileName();
                  });
                },
                decoration: const InputDecoration(
                  hintText: 'Seleziona un archivio',
                  border: OutlineInputBorder(),
                ),
              ),
            const SizedBox(height: 8),
            const Text('Oppure inserisci manualmente:'),
            TextField(
              controller: _archivioTextController,
              onChanged: (value) => _updateFileName(),
              decoration: const InputDecoration(
                hintText: 'Nome dell\'archivio',
                border: OutlineInputBorder(),
              ),
              enabled: !_isProcessing,
            ),
          ],
        );

      case 'autore':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Autore:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_autori.isNotEmpty)
              DropdownButtonFormField<String>(
                value: _selectedAutore,
                items: _autori.map((autore) {
                  return DropdownMenuItem<String>(
                    value: autore,
                    child: Text(autore.length > 50 ? '${autore.substring(0, 50)}...' : autore),
                  );
                }).toList(),
                onChanged: _isProcessing ? null : (value) {
                  setState(() {
                    _selectedAutore = value;
                    _updateFileName();
                  });
                },
                decoration: const InputDecoration(
                  hintText: 'Seleziona un autore',
                  border: OutlineInputBorder(),
                ),
              ),
            const SizedBox(height: 8),
            const Text('Oppure inserisci manualmente:'),
            TextField(
              controller: _autoreTextController,
              onChanged: (value) => _updateFileName(),
              decoration: const InputDecoration(
                hintText: 'Nome dell\'autore',
                border: OutlineInputBorder(),
              ),
              enabled: !_isProcessing,
            ),
          ],
        );

      case 'strumento':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Strumento:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_strumenti.isNotEmpty)
              DropdownButtonFormField<String>(
                value: _selectedStrumento,
                items: _strumenti.map((strumento) {
                  return DropdownMenuItem<String>(
                    value: strumento,
                    child: Text(strumento),
                  );
                }).toList(),
                onChanged: _isProcessing ? null : (value) {
                  setState(() {
                    _selectedStrumento = value;
                    _updateFileName();
                  });
                },
                decoration: const InputDecoration(
                  hintText: 'Seleziona uno strumento',
                  border: OutlineInputBorder(),
                ),
              ),
            const SizedBox(height: 8),
            const Text('Oppure inserisci manualmente:'),
            TextField(
              controller: _strumentoTextController,
              onChanged: (value) => _updateFileName(),
              decoration: const InputDecoration(
                hintText: 'Nome dello strumento',
                border: OutlineInputBorder(),
              ),
              enabled: !_isProcessing,
            ),
          ],
        );

      case 'id_volume':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ID Volume:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _idVolumeController,
              onChanged: (value) => _updateFileName(),
              decoration: const InputDecoration(
                hintText: 'Inserisci ID volume',
                border: OutlineInputBorder(),
              ),
              enabled: !_isProcessing,
            ),
          ],
        );

      default:
        return Container();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Esporta Porzioni di Catalogo in CSV'),
        actions: [
          if (_consoleOutput.isNotEmpty)
            IconButton(
              onPressed: _clearConsole,
              icon: const Icon(Icons.clear_all),
              tooltip: 'Pulisci console',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Selezione tipo esportazione
            const Text('Tipo di esportazione:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _exportType,
              items: _exportOptions.map((option) {
                return DropdownMenuItem<String>(
                  value: option['value'] as String,
                  child: Text(option['label'] as String),
                );
              }).toList(),
              onChanged: _isProcessing ? null : (value) {
                if (value != null) {
                  setState(() {
                    _exportType = value;
                    // Aggiorna il nome file quando si cambia il tipo di esportazione
                    _updateFileName();
                  });
                }
              },
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            // Input specifico per il tipo selezionato
            _buildExportTypeInputs(),

            const SizedBox(height: 16),

            // Nome file
            const Text('Nome file CSV:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _fileNameController,
              decoration: InputDecoration(
                hintText: 'Il nome sarà generato automaticamente',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _isProcessing ? null : () {
                    _updateFileName();
                    _addConsoleOutput('🔄 Nome file rigenerato');
                  },
                  tooltip: 'Rigenera nome file',
                ),
              ),
              enabled: !_isProcessing,
            ),
            const SizedBox(height: 4),
            const Text(
              'Puoi modificare il nome generato automaticamente',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),

            const SizedBox(height: 24),

            // Pulsante esporta
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _exportToCsv,
                icon: _isProcessing
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.file_download),
                label: Text(_isProcessing ? 'Esportazione in corso...' : 'Esporta CSV'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),

            // Barra di progresso
            if (_isProcessing)
              Column(
                children: [
                  const SizedBox(height: 16),
                  LinearProgressIndicator(value: _progress),
                  const SizedBox(height: 8),
                  Text(_status, textAlign: TextAlign.center),
                ],
              ),

            // Risultato esportazione
            if (_generatedFilePath != null && !_isProcessing)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  Card(
                    color: Colors.green.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green),
                              SizedBox(width: 8),
                              Text(
                                'Esportazione completata!',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text('File: ${p.basename(_generatedFilePath!)}'),
                          Text('Percorso: ${p.dirname(_generatedFilePath!)}'),
                          Text('Record esportati: $_exportedRecords'),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed: _openFileExplorer,
                                icon: const Icon(Icons.folder_open),
                                label: const Text('Apri cartella'),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: _copyToClipboard,
                                icon: const Icon(Icons.content_copy),
                                label: const Text('Copia percorso'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 24),

            // Console output
            const Text('Log esportazione:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(4),
              ),
              height: 300,
              child: _consoleOutput.isEmpty
                  ? const Center(
                child: Text(
                  'La console mostrerà i dettagli dell\'esportazione',
                  style: TextStyle(color: Colors.grey),
                ),
              )
                  : ListView.builder(
                controller: _consoleScrollController,
                padding: const EdgeInsets.all(8.0),
                itemCount: _consoleOutput.length,
                itemBuilder: (context, index) {
                  final line = _consoleOutput[index];
                  return Text(
                    line,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}