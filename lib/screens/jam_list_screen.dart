// lib/screens/jam_list_screen.dart
import 'package:flutter/material.dart';
import '../database/database_service.dart';
import '../models/brano.dart';
import 'add_brano_screen.dart';
import 'dart:async';

class JamListScreen extends StatefulWidget {
  const JamListScreen({super.key});

  @override
  State<JamListScreen> createState() => _JamListScreenState();
}

class _JamListScreenState extends State<JamListScreen> {
  final DatabaseService _databaseService = DatabaseService();
  late Future<List<Brano>> _braniFuture;

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _refreshBrani();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _refreshBrani([String? query]) {
    setState(() {
      if (query != null && query.isNotEmpty) {
        _braniFuture = _databaseService.searchBrani(query);
      } else {
        _braniFuture = _databaseService.getBrani();
      }
    });
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _refreshBrani(_searchController.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('JamSet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const AddBranoScreen()),
              );
              _refreshBrani();
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight + 10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cerca per titolo, autore o provenienza...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                contentPadding: const EdgeInsets.all(0),
              ),
            ),
          ),
        ),
      ),
      body: FutureBuilder<List<Brano>>(
        future: _braniFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Errore: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Nessun brano trovato.'));
          } else {
            return ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final brano = snapshot.data![index];
                return ListTile(
                  title: Text(brano.titolo),
                  subtitle: Text('Autore: ${brano.autore} - Provenienza: ${brano.provenienza}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Naviga alla schermata del visualizzatore PDF
                  },
                );
              },
            );
          }
        },
      ),
    );
  }
}