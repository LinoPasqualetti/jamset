import 'package:flutter/material.dart';
import 'package:jamsetgemini/main.dart'; // Importa databaseService
import 'VariaCatalogo.dart';

class GestisciElencoCataloghi extends StatefulWidget {
  const GestisciElencoCataloghi({super.key});

  @override
  State<GestisciElencoCataloghi> createState() => _GestisciElencoCataloghiState();
}

class _GestisciElencoCataloghiState extends State<GestisciElencoCataloghi> {
  List<Map<String, dynamic>> _cataloghi = [];
  List<Map<String, dynamic>> _filteredCataloghi = [];
  bool _isLoading = true;
  String? _error;
  int? _activeCatalogId;

  @override
  void initState() {
    super.initState();
    _loadCataloghi();
  }

  Future<void> _loadCataloghi() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _activeCatalogId = null;
    });

    try {
      if (databaseService.dbGlobale == null) {
        throw Exception('Il database globale non è stato inizializzato.');
      }

      await _loadActiveCatalogId();

      final data = await databaseService.dbGlobale!.query(
          'elenco_cataloghi',
          orderBy: 'nome_catalogo'
      );

      _syncInBackground();

      if (mounted) {
        setState(() {
          _cataloghi = data;
          _filteredCataloghi = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadActiveCatalogId() async {
    try {
      final activeData = await databaseService.dbGlobale!.query(
          'DatiSistremaApp', // CORRETTO: DatiSistremaApp
          columns: ['id_catalogo_attivo'],
          limit: 1
      );

      if (activeData.isNotEmpty) {
        _activeCatalogId = activeData.first['id_catalogo_attivo'] as int?;
      }
    } catch (e) {
      debugPrint('Errore nel caricamento catalogo attivo: $e');
    }
  }

  Future<void> _syncInBackground() async {
    try {
      await databaseService.synchronizeCatalogs();

      if (mounted && !_isLoading) {
        final freshData = await databaseService.dbGlobale!.query(
            'elenco_cataloghi',
            orderBy: 'nome_catalogo'
        );

        await _loadActiveCatalogId();

        setState(() {
          _cataloghi = freshData;
          _filteredCataloghi = freshData;
        });
      }
    } catch (e) {
      debugPrint('Errore sincronizzazione in background: $e');
    }
  }

  Future<void> _activateCatalog(int catalogId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Attiva Catalogo'),
        content: const Text('Vuoi attivare questo catalogo?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annulla')
          ),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Attiva', style: TextStyle(color: Colors.green))
          ),
        ],
      ),
    ) ?? false;

    if (!confirmed) return;

    try {
      await databaseService.dbGlobale!.update(
          'DatiSistremaApp', // CORRETTO: DatiSistremaApp
          {'id_catalogo_attivo': catalogId},
          where: 'id = ?',
          whereArgs: [1]
      );

      setState(() {
        _activeCatalogId = catalogId;
      });

      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Catalogo attivato con successo!'),
            backgroundColor: Colors.green,
          )
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore durante l\'attivazione: $e'),
            backgroundColor: Colors.red,
          )
      );
    }
  }

  Future<void> _navigateToVariaScreen([Map<String, dynamic>? catalogo]) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => VariaCatalogoScreen(
          initialData: catalogo,
          totalCataloghi: _cataloghi.length,
        ),
      ),
    );

    if (result == true) {
      await _loadCataloghi();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestione Elenco Cataloghi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCataloghi,
            tooltip: 'Ricarica Lista',
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToVariaScreen(),
        tooltip: 'Aggiungi un nuovo catalogo',
        icon: const Icon(Icons.add),
        label: const Text('Nuovo Catalogo'),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SelectableText('Errore: $_error')
          )
      );
    }

    if (_cataloghi.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.storage_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Nessun catalogo trovato.', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              'Usa il pulsante "Nuovo Catalogo" per iniziare.',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    final activeCatalog = _cataloghi.firstWhere(
          (c) => c['id'] == _activeCatalogId,
      orElse: () => {},
    );

    return Column(
      children: [
        if (_activeCatalogId != null && activeCatalog.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12.0),
            margin: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: Colors.blue.shade200, width: 2),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.blue.shade700),
                const SizedBox(width: 12.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CATALOGO ATTIVO',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        activeCatalog['nome_catalogo']?.toString() ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'File: ${activeCatalog['nome_file_db']?.toString() ?? 'N/A'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: _filteredCataloghi.length,
            itemBuilder: (context, index) {
              final catalogo = _filteredCataloghi[index];
              final bool isActive = catalogo['id'] == _activeCatalogId;

              return _buildCatalogCard(catalogo, isActive);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCatalogCard(Map<String, dynamic> catalogo, bool isActive) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      elevation: isActive ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isActive ? Colors.blue.shade700 : Colors.grey.shade300,
          width: isActive ? 2 : 1,
        ),
      ),
      child: ListTile(
        isThreeLine: true,
        leading: CircleAvatar(
          backgroundColor: isActive ? Colors.blue.shade100 : Colors.grey.shade200,
          child: Icon(
            isActive ? Icons.folder_open : Icons.folder_copy_outlined,
            color: isActive ? Colors.blue.shade800 : Colors.grey.shade700,
          ),
        ),
        title: Row(
          children: [
            Text(
              catalogo['nome_catalogo']?.toString() ?? 'Senza nome',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isActive ? Colors.blue.shade800 : null,
              ),
            ),
            if (isActive)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'ATTIVO',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'File: ${catalogo['nome_file_db']?.toString() ?? 'N/A'}',
              style: TextStyle(
                color: isActive ? Colors.blue.shade600 : null,
              ),
            ),
            const SizedBox(height: 2),
            Text('Brani: ${catalogo['conteggio_brani']?.toString() ?? '0'}'),
            const SizedBox(height: 2),
            if (catalogo['descrizione'] != null && catalogo['descrizione'].toString().isNotEmpty)
              Text(
                catalogo['descrizione'].toString(),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            if (value == 'edit') {
              _navigateToVariaScreen(catalogo);
            } else if (value == 'activate' && !isActive) {
              _activateCatalog(catalogo['id']);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit, size: 20),
                title: Text('Modifica'),
              ),
            ),
            if (!isActive)
              const PopupMenuItem(
                value: 'activate',
                child: ListTile(
                  leading: Icon(Icons.check_circle, size: 20, color: Colors.green),
                  title: Text('Attiva'),
                ),
              ),
          ],
        ),
        onTap: () {
          _showCatalogDetails(catalogo, isActive);
        },
      ),
    );
  }

  void _showCatalogDetails(Map<String, dynamic> catalogo, bool isActive) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(catalogo['nome_catalogo']?.toString() ?? 'Catalogo'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isActive)
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Catalogo attivo',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ),

              _buildDetailRow('ID', catalogo['id']?.toString()),
              _buildDetailRow('Nome file', catalogo['nome_file_db']?.toString()),
              _buildDetailRow('Brani', catalogo['conteggio_brani']?.toString()),
              _buildDetailRow('Data creazione', catalogo['data_creazione']?.toString()),
              _buildDetailRow('Ultimo aggiornamento', catalogo['data_ultimo_aggiornamento']?.toString()),

              if (catalogo['descrizione'] != null && catalogo['descrizione'].toString().isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    const Text('Descrizione:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(catalogo['descrizione'].toString()),
                  ],
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CHIUDI'),
          ),
          if (!isActive)
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _activateCatalog(catalogo['id']);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('ATTIVA'),
            ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _navigateToVariaScreen(catalogo);
            },
            child: const Text('MODIFICA'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value ?? 'N/A'),
          ),
        ],
      ),
    );
  }
}