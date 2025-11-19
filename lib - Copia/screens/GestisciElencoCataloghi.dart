import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import 'package:jamset/main.dart'; // <-- IMPORT CORRETTO
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

  @override
  void initState() {
    super.initState();
    _loadCataloghi();
  }

  // LOGICA ADATTATA PER USARE IL DB GLOBALE
  Future<void> _loadCataloghi() async {
    try {
      if (dbGlobale == null) {
        throw Exception('Il database globale non è stato inizializzato.');
      }
      final data = await dbGlobale!.query('elenco_cataloghi', orderBy: 'nome_catalogo');

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
      _loadCataloghi();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestione Elenco Cataloghi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _navigateToVariaScreen(),
            tooltip: 'Nuovo Catalogo',
          ),
        ],
      ),
      body: _buildBody(),
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
      return const Center(child: Text('Nessun catalogo trovato. Premi + per aggiungerne uno.'));
    }

    return ListView.builder(
      itemCount: _cataloghi.length,
      itemBuilder: (context, index) {
        final catalogo = _cataloghi[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: ListTile(
            isThreeLine: true,
            leading: CircleAvatar(child: Text(catalogo['id'].toString())),
            title: Text(catalogo['nome_catalogo']?.toString() ?? 'Senza nome', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('File: ${catalogo['nome_file_db']?.toString() ?? 'N/A'}'),
                Text('Brani: ${catalogo['conteggio_brani']?.toString() ?? '0'} - Ult. agg: ${catalogo['data_ultimo_aggiornamento']?.toString() ?? 'Mai'}'),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () => _navigateToVariaScreen(catalogo),
            ),
          ),
        );
      },
    );
  }
}
