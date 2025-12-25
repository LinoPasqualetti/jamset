import 'package:flutter/material.dart';
import 'package:livescore/main.dart';
import 'package:livescore/utils/file_opener.dart';

class ListaSpartitiCatalogoScreen extends StatefulWidget {
  final int catalogoId;
  final String nomeCatalogo;
  final String dbName;
  final String? filtroVolume; 
  final String? idVolumeFiltro;

  const ListaSpartitiCatalogoScreen({
    super.key,
    required this.catalogoId,
    required this.nomeCatalogo,
    required this.dbName,
    this.filtroVolume,
    this.idVolumeFiltro,
  });

  @override
  State<ListaSpartitiCatalogoScreen> createState() => _ListaSpartitiCatalogoScreenState();
}

class _ListaSpartitiCatalogoScreenState extends State<ListaSpartitiCatalogoScreen> {
  bool _isLoading = true;
  bool _isFetchingMore = false;
  bool _hasMoreData = true;
  String? _error;
  List<Map<String, dynamic>> _spartiti = [];
  
  final int _limit = 100; 
  int _offset = 0;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _scrollController.addListener(_onScroll);
    databaseService.addListener(_handleDatabaseChange);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    databaseService.removeListener(_handleDatabaseChange);
    super.dispose();
  }

  void _handleDatabaseChange() => _loadInitialData();

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      if (!_isFetchingMore && _hasMoreData) _loadMoreSpartiti();
    }
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _spartiti = [];
      _offset = 0;
      _hasMoreData = true;
    });
    await _loadMoreSpartiti();
  }

  Future<void> _loadMoreSpartiti() async {
    if (_isFetchingMore) return;
    setState(() => _isFetchingMore = true);
    
    try {
      if (databaseService.dbCatalogoAttivo == null) return;

      String sql = "SELECT * FROM spartiti WHERE tipodocu != 'V'";
      List<dynamic> args = [];
      
      if (widget.filtroVolume != null) {
        sql += " AND idvolume IN (SELECT b.idbra FROM spartiti AS b WHERE b.volume LIKE ?)";
        args.add(widget.filtroVolume);
      } else if (widget.idVolumeFiltro != null) {
        sql += " AND idvolume = ?";
        args.add(widget.idVolumeFiltro);
      }

      sql += " ORDER BY CAST(NumPag AS INTEGER) ASC, titolo ASC LIMIT ? OFFSET ?";
      args.addAll([_limit, _offset]);

      final data = await databaseService.dbCatalogoAttivo!.rawQuery(sql, args);

      if (mounted) {
        setState(() {
          _spartiti.addAll(data);
          _isLoading = false;
          _isFetchingMore = false;
          _offset += _limit;
          if (data.length < _limit) _hasMoreData = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('${widget.nomeCatalogo} (${_spartiti.length})', style: const TextStyle(fontSize: 14)),
        backgroundColor: Colors.teal[800],
        foregroundColor: Colors.white,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _spartiti.isEmpty) return const Center(child: CircularProgressIndicator());
    if (_spartiti.isEmpty) return const Center(child: Text('Nessun brano.', style: TextStyle(fontSize: 12)));

    return ListView.builder(
      controller: _scrollController,
      itemCount: _spartiti.length + (_hasMoreData ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _spartiti.length) return const Center(child: LinearProgressIndicator());

        final item = _spartiti[index];
        final String pag = item['NumPag']?.toString() ?? '-';
        final String orig = item['NumOrig']?.toString() ?? '';
        
        return InkWell(
          onTap: () => _openPdf(item),
          child: Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 0.5)),
              color: index.isEven ? Colors.white : Colors.grey.shade50,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), 
            child: Row(
              children: [
                SizedBox(
                  width: 45,
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      children: [
                        TextSpan(text: pag, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 13)),
                        if (orig.isNotEmpty && orig != pag)
                          TextSpan(text: "\n$orig", style: TextStyle(fontSize: 9, color: Colors.teal.shade300)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                      children: [
                        TextSpan(text: "${item['titolo'] ?? '---'}  ", style: const TextStyle(fontWeight: FontWeight.bold)),
                        if (item['autore'] != null && item['autore'].toString().isNotEmpty)
                          TextSpan(text: "??${item['autore']}  ", style: const TextStyle(color: Colors.blue, fontSize: 11)),
                        if (item['strumento'] != null && item['strumento'].toString().isNotEmpty)
                          TextSpan(text: "??${item['strumento']}  ", style: const TextStyle(color: Colors.deepOrange, fontSize: 11)),
                        if (item['ArchivioProvenienza'] != null)
                          TextSpan(text: "??${item['ArchivioProvenienza']}", style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
                      ],
                    ),
                  ),
                ),
                const Icon(Icons.picture_as_pdf, size: 16, color: Colors.teal),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openPdf(Map<String, dynamic> brano) async {
    await FileOpener.openFile(
      context: context,
      percResto: brano['PercResto']?.toString() ?? '',
      volume: brano['volume']?.toString() ?? '',
      tipoMulti: FileOpener.getTipoMultiFromRow(brano),
      page: int.tryParse(brano['NumPag']?.toString() ?? '1') ?? 1,
    );
  }
}
