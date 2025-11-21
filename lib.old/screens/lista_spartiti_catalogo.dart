import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:path/path.dart' as p;

import 'package:jamset/main.dart'; // Import corretto

class ListaSpartitiCatalogoScreen extends StatefulWidget {
  final int catalogoId;
  final String nomeCatalogo;
  final String dbName;

  const ListaSpartitiCatalogoScreen({
    super.key,
    required this.catalogoId,
    required this.nomeCatalogo,
    required this.dbName,
  });

  @override
  State<ListaSpartitiCatalogoScreen> createState() => _ListaSpartitiCatalogoScreenState();
}

class _ListaSpartitiCatalogoScreenState extends State<ListaSpartitiCatalogoScreen> {
  // --- STATO PER PAGINAZIONE ---
  final List<Map<String, dynamic>> _spartiti = [];
  final ScrollController _scrollController = ScrollController();
  final int _pageSize = 200;
  int _currentPage = 0;
  bool _isLoading = true;
  bool _hasMoreData = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadSpartiti(isInitialLoad: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 && !_isLoading && _hasMoreData) {
      _loadSpartiti();
    }
  }

  Future<void> _loadSpartiti({bool isInitialLoad = false}) async {
    if (_isLoading && !isInitialLoad) return; 

    if (isInitialLoad) {
      _currentPage = 0;
      _hasMoreData = true;
      _spartiti.clear();
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (dbCatalogoAttivo == null) {
        throw Exception('Il database del catalogo attivo non è disponibile.');
      }

      final offset = _currentPage * _pageSize;
      final data = await dbCatalogoAttivo!.query(
        'spartiti',
        limit: _pageSize,
        offset: offset,
        orderBy: 'titolo, strumento',
      );

      if (mounted) {
        setState(() {
          if (data.length < _pageSize) {
            _hasMoreData = false;
          }
          _spartiti.addAll(data);
          _currentPage++;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Spartiti in: ${widget.nomeCatalogo}'),
            SelectableText(
              p.join(gDatabasePath, widget.dbName),
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_spartiti.isEmpty && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Padding(padding: const EdgeInsets.all(16.0), child: SelectableText('Errore: $_error')));
    }
    if (_spartiti.isEmpty && !_isLoading) {
      return const Center(child: Text('Nessuno spartito trovato in questo catalogo.'));
    }

    final columns = _spartiti.first.keys.map((key) {
      return DataColumn2(label: Text(key, style: const TextStyle(fontWeight: FontWeight.bold)));
    }).toList();

    return Stack(
      children: [
        Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          child: DataTable2(
            columnSpacing: 12,
            horizontalMargin: 12,
            minWidth: 1500,
            columns: columns,
            rows: _spartiti.map((row) {
              return DataRow(cells: row.values.map((cell) {
                return DataCell(SelectableText(cell?.toString() ?? 'NULL'));
              }).toList());
            }).toList(),
          ),
        ),
        if (_isLoading && _spartiti.isNotEmpty)
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Center(child: CircularProgressIndicator()),
          )
      ],
    );
  }
}
