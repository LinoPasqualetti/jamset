import 'package:flutter/material.dart';
import 'package:livescore/main.dart'; 
import 'package:livescore/screens/lista_spartiti_catalogo.dart';

class ElencoVolumiCatalogoScreen extends StatefulWidget {
  const ElencoVolumiCatalogoScreen({super.key});

  @override
  State<ElencoVolumiCatalogoScreen> createState() => _ElencoVolumiCatalogoScreenState();
}

class _ElencoVolumiCatalogoScreenState extends State<ElencoVolumiCatalogoScreen> {
  Map<String, List<Map<String, dynamic>>> _gruppiVolumi = {};
  List<String> _nomiArchivi = [];
  bool _isLoading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadVolumi();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadVolumi([String? filter]) async {
    setState(() => _isLoading = true);
    try {
      if (databaseService.dbCatalogoAttivo == null) return;

      // MODIFICATO: aggiunto filtro IdBra = IdVolume per isolare i record che rappresentano i volumi "padre"
      String query = "SELECT * FROM spartiti WHERE tipodocu = 'V' AND IdBra = IdVolume";
      List<dynamic> args = [];
      if (filter != null && filter.isNotEmpty) {
        query += " AND (volume LIKE ? OR titolo LIKE ? OR ArchivioProvenienza LIKE ?)";
        args.addAll(['%$filter%', '%$filter%', '%$filter%']);
      }
      query += " ORDER BY ArchivioProvenienza COLLATE NOCASE ASC, volume COLLATE NOCASE ASC";

      final List<Map<String, dynamic>> data = await databaseService.dbCatalogoAttivo!.rawQuery(query, args);

      final Map<String, List<Map<String, dynamic>>> temporaryGroups = {};
      for (var row in data) {
        final String archivio = (row['ArchivioProvenienza']?.toString() ?? 'Senza Archivio').trim();
        final String chiave = archivio.isEmpty ? 'Senza Archivio' : archivio;
        if (!temporaryGroups.containsKey(chiave)) temporaryGroups[chiave] = [];
        temporaryGroups[chiave]!.add(row);
      }

      if (mounted) {
        setState(() {
          _gruppiVolumi = temporaryGroups;
          _nomiArchivi = temporaryGroups.keys.toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _deleteVolumeIfEmpty(Map<String, dynamic> volume) async {
    final String idVolume = (volume['IdVolume'] ?? volume['IdBra'] ?? '').toString();
    final String nomeVolume = (volume['volume'] ?? volume['titolo'] ?? 'Senza Nome').toString();
    try {
      final res = await databaseService.dbCatalogoAttivo!.rawQuery("SELECT COUNT(*) as c FROM spartiti WHERE IdVolume = ? AND tipodocu != 'V'", [idVolume]);
      final int figli = res.first['c'] as int? ?? 0;
      if (figli > 0) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Volume non vuoto ($figli brani).'), backgroundColor: Colors.orange));
        return;
      }
      final confirmed = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('Elimina?'), content: Text('Vuoi eliminare "$nomeVolume"?'), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('NO')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('SI'))])) ?? false;
      if (confirmed) {
        await databaseService.dbCatalogoAttivo!.delete('spartiti', where: 'IdBra = ?', whereArgs: [volume['IdBra']]);
        _loadVolumi(_searchController.text);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final String nomeCat = databaseService.activeCatalogDbName.isEmpty ? "..." : databaseService.activeCatalogDbName;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Gestione Volumi', style: TextStyle(fontSize: 15)),
            Text('DB: $nomeCat', style: const TextStyle(fontSize: 10, color: Colors.yellowAccent)),
          ],
        ),
        backgroundColor: Colors.teal[800],
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(45),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: SizedBox(
              height: 35,
              child: TextField(
                controller: _searchController,
                onSubmitted: (value) => _loadVolumi(value),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Filtra...',
                  hintStyle: const TextStyle(color: Colors.white60, fontSize: 13),
                  prefixIcon: const Icon(Icons.search, color: Colors.white60, size: 18),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Errore: $_error', style: const TextStyle(fontSize: 12)));
    if (_nomiArchivi.isEmpty) return const Center(child: Text('Nessun volume.', style: TextStyle(fontSize: 12)));

    return ListView.builder(
      itemCount: _nomiArchivi.length,
      itemBuilder: (context, index) {
        final String nomeArchivio = _nomiArchivi[index];
        final List<Map<String, dynamic>> volumiNelGruppo = _gruppiVolumi[nomeArchivio]!;

        if (volumiNelGruppo.length > 1) {
          return Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              visualDensity: VisualDensity.compact,
              tilePadding: const EdgeInsets.symmetric(horizontal: 12),
              leading: const Icon(Icons.folder_open, color: Colors.teal, size: 18),
              title: Text(nomeArchivio, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: Text('${volumiNelGruppo.length} volumi', style: const TextStyle(fontSize: 10)),
              children: volumiNelGruppo.map((v) => _buildVolumeRow(v, isNested: true)).toList(),
            ),
          );
        }
        return _buildVolumeRow(volumiNelGruppo.first);
      },
    );
  }

  Widget _buildVolumeRow(Map<String, dynamic> item, {bool isNested = false}) {
    String nome = (item['volume'] ?? '').toString().trim();
    if (nome.isEmpty) nome = (item['titolo'] ?? '').toString().trim();
    final String autore = item['autore']?.toString() ?? '-';

    return InkWell(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => ListaSpartitiCatalogoScreen(
          catalogoId: 0,
          nomeCatalogo: nome,
          dbName: databaseService.activeCatalogDbName,
          idVolumeFiltro: (item['IdVolume'] ?? item['IdBra'] ?? '').toString(),
        )));
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 0.5)),
          color: isNested ? Colors.teal.withOpacity(0.02) : Colors.white,
        ),
        padding: EdgeInsets.fromLTRB(isNested ? 32 : 12, 4, 8, 4),
        child: Row(
          children: [
            const Icon(Icons.book, size: 16, color: Colors.teal),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nome, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(autore, style: TextStyle(fontSize: 10, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => _deleteVolumeIfEmpty(item),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
