/// funzioni_variazione_dati_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:data_table_2/data_table_2.dart';
import 'dart:io' show Platform;

import 'package:jamset/main.dart';
import 'package:jamset/platform/opener_platform_interface.dart';
import 'package:path/path.dart' as p;

class FunzioniVariazioneDatiScreen extends StatefulWidget {
  const FunzioniVariazioneDatiScreen({super.key});

  @override
  State<FunzioniVariazioneDatiScreen> createState() =>
      _FunzioniVariazioneDatiScreenState();
}

class _FunzioniVariazioneDatiScreenState extends State<FunzioniVariazioneDatiScreen> with AutomaticKeepAliveClientMixin {
  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _queryResults = [];

  // --- STATO PER LA PAGINAZIONE ---
  final int _pageSize = 200;
  int _currentPage = 0;
  bool _hasMoreData = true;
  bool _isFirstLoad = true;
  String _lastQuery = '';

  final ScrollController _scrollController = ScrollController();
  late final TextEditingController _searchController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: 'love*');
    _scrollController.addListener(_onScroll);
    _executeQuery();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 && !_isLoading && _hasMoreData) {
      _loadMoreData();
    }
  }

  String _buildQuery(String searchTerm, {int? offset}) {
    String whereClause;

    if (Platform.isWindows) {
      // Usa FTS5 su Windows
      final ftsQuery = searchTerm.replaceAll('\'', '\'\'');
      whereClause = "s.IdBra IN (SELECT rowid FROM spartiti_fts WHERE spartiti_fts MATCH '$ftsQuery')";
    } else {
      // Usa LIKE su altre piattaforme (Android)
      final likeQuery = '%$searchTerm%';
      whereClause = "s.titolo LIKE '$likeQuery' OR s.autore LIKE '$likeQuery'";
    }

    String query = '''
      SELECT s.* 
      FROM spartiti s 
      WHERE $whereClause
      ORDER BY s.titolo, s.strumento
      LIMIT $_pageSize
    ''';
    if (offset != null) {
      query += ' OFFSET $offset';
    }
    return query;
  }

  Future<void> _executeQuery({bool loadMore = false}) async {
    if (_isLoading) return;

    final searchTerm = _searchController.text.trim();
    if (searchTerm.isEmpty) {
      setState(() {
        _queryResults = [];
        _isFirstLoad = true;
      });
      return;
    }

    if (!loadMore) {
      _currentPage = 0;
      _hasMoreData = true;
      _queryResults.clear();
      _isFirstLoad = true;
      _lastQuery = searchTerm;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final offset = _currentPage * _pageSize;
      final query = _buildQuery(_lastQuery, offset: offset);

      final results = await dbCatalogoAttivo!.rawQuery(query);

      if (mounted) {
        setState(() {
          if (results.length < _pageSize) {
            _hasMoreData = false;
          }
          _queryResults.addAll(results);
          _currentPage++;
          _isLoading = false;
          _isFirstLoad = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Errore esecuzione query: \n${e.toString()}";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreData() async {
    _executeQuery(loadMore: true);
  }

  Future<void> _openPdfFromRow(Map<String, dynamic> rowData) async {
    final lowerCaseRowData = {for (var k in rowData.keys) k.toLowerCase(): rowData[k]};

    final percRadice = lowerCaseRowData['percradice']?.toString() ?? '';
    final percResto = lowerCaseRowData['percresto']?.toString() ?? '';
    final volume = lowerCaseRowData['volume']?.toString() ?? '';
    final pageNum = lowerCaseRowData['numpag'];

    if (gPercorsoPdf.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('ERRORE: Percorso PDF non configurato nelle impostazioni di sistema.'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    final String filePath = p.join(gPercorsoPdf, percRadice, percResto, volume);
    final page = int.tryParse(pageNum?.toString() ?? '1') ?? 1;

    await OpenerPlatformInterface.instance.openPdf(
      context: context,
      filePath: filePath,
      page: page,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _searchController,
            autofocus: true,
            decoration: InputDecoration(
                labelText: 'Cerca in ${gActiveCatalogDbName.replaceAll('.db', '')}',
                hintText: 'Usa * per ricerche parziali (es. love*)',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => _executeQuery(),
                )
            ),
            onSubmitted: (_) => _executeQuery(),
          ),
          const SizedBox(height: 10),
          if (_isLoading && _isFirstLoad)
            const Center(child: CircularProgressIndicator())
          else
            Expanded(
              child: _buildResultsSection(),
            ),
        ],
      ),
    );
  }

  Widget _buildResultsSection() {
    if (_error != null) return Center(child: SelectableText(_error!, style: const TextStyle(color: Colors.red)));
    if (_queryResults.isEmpty) return const Center(child: Text('Nessun risultato. Prova una nuova ricerca.'));

    return Stack(
      children: [
        Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          child: DataTable2(
            columnSpacing: 10,
            horizontalMargin: 10,
            minWidth: 2000,
            columns: _queryResults.first.keys.map((key) {
              ColumnSize size;
              switch (key.toLowerCase()) {
                case 'numpag': size = ColumnSize.S; break;
                case 'titolo': size = ColumnSize.L; break;
                default: size = ColumnSize.M;
              }
              return DataColumn2(label: Text(key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), size: size);
            }).toList(),
            rows: _queryResults.map((row) {
              return DataRow2(
                onTap: () => _openPdfFromRow(row),
                cells: row.values.map((cell) => DataCell(SelectableText(cell?.toString() ?? 'NULL', style: const TextStyle(fontSize: 11)))).toList(),
              );
            }).toList(),
          ),
        ),
        if (_isLoading && !_isFirstLoad)
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
