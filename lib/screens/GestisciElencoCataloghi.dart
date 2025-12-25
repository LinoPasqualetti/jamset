import 'package:flutter/material.dart';
import 'package:livescore/main.dart'; // Importa databaseService
import 'VariaCatalogo.dart';

class GestisciElencoCataloghi extends StatefulWidget {
  const GestisciElencoCataloghi({super.key});

  @override
  State<GestisciElencoCataloghi> createState() => _GestisciElencoCataloghiState();
}

class _GestisciElencoCataloghiState extends State<GestisciElencoCataloghi> {
  List<Map<String, dynamic>> _cataloghi = [];
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
    });

    try {
      if (databaseService.dbGlobale == null) {
        throw Exception('Il database globale non è stato inizializzato.');
      }

      // Sincronizza i file prima di caricare la lista
      await databaseService.synchronizeCatalogs();

      // Carica l'ID del catalogo attivo dal DB globale
      final activeData = await databaseService.dbGlobale!.query(
          'DatiSistremaApp',
          columns: ['id_catalogo_attivo'],
          limit: 1
      );

      if (activeData.isNotEmpty) {
        _activeCatalogId = activeData.first['id_catalogo_attivo'] as int?;
      }

      // Carica tutti i cataloghi
      final data = await databaseService.dbGlobale!.query(
          'elenco_cataloghi',
          orderBy: 'nome_catalogo'
      );

      if (mounted) {
        setState(() {
          _cataloghi = data;
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

  Future<void> _handleActivateCatalog(Map<String, dynamic> catalogo) async {
    final String dbName = catalogo['nome_file_db'] ?? '';
    if (dbName.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Attiva Catalogo'),
        content: Text('Vuoi impostare "${catalogo['nome_catalogo']}" come catalogo attivo?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annulla')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Attiva', style: TextStyle(color: Colors.green))),
        ],
      ),
    ) ?? false;

    if (!confirmed) return;

    setState(() => _isLoading = true);
    
    try {
      // Usa il metodo del servizio che gestisce sia il DB globale che il caricamento in memoria
      final success = await databaseService.switchVolume(dbName);
      
      if (success) {
        await _loadCataloghi();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Catalogo "${catalogo['nome_catalogo']}" attivato!'), backgroundColor: Colors.teal),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore durante l\'attivazione: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
      return Center(child: Padding(padding: const EdgeInsets.all(16.0), child: SelectableText('Errore: $_error')));
    }

    if (_cataloghi.isEmpty) {
      return const Center(child: Text('Nessun catalogo trovato. Usa il tasto + per aggiungerne uno.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: _cataloghi.length,
      itemBuilder: (context, index) {
        final catalogo = _cataloghi[index];
        final bool isActive = catalogo['id'] == _activeCatalogId;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          elevation: isActive ? 4 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: isActive ? Colors.blue.shade700 : Colors.transparent, width: 2),
          ),
          child: ListTile(
            isThreeLine: true,
            leading: CircleAvatar(
              backgroundColor: isActive ? Colors.blue.shade100 : Colors.grey.shade200,
              child: Icon(isActive ? Icons.check_circle : Icons.folder_copy_outlined, 
                          color: isActive ? Colors.blue.shade800 : Colors.grey.shade700),
            ),
            title: Row(
              children: [
                Expanded(child: Text(catalogo['nome_catalogo']?.toString() ?? 'Senza nome', 
                         style: const TextStyle(fontWeight: FontWeight.bold))),
                if (isActive) 
                  const Chip(label: Text('ATTIVO', style: TextStyle(fontSize: 10, color: Colors.white)), 
                             backgroundColor: Colors.blue, padding: EdgeInsets.zero),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('File: ${catalogo['nome_file_db']?.toString() ?? 'N/A'}'),
                Text('Brani: ${catalogo['conteggio_brani']?.toString() ?? '0'}'),
              ],
            ),
            onTap: isActive ? null : () => _handleActivateCatalog(catalogo),
            trailing: IconButton(
              icon: const Icon(Icons.edit, color: Colors.grey),
              onPressed: () => _navigateToVariaScreen(catalogo),
              tooltip: 'Modifica metadati',
            ),
          ),
        );
      },
    );
  }
}
