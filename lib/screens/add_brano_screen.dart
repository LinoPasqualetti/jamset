// lib/screens/add_brano_screen.dart
import 'package:flutter/material.dart';
import '../models/brano.dart';
import '../database/database_service.dart';

class AddBranoScreen extends StatefulWidget {
  const AddBranoScreen({super.key});

  @override
  State<AddBranoScreen> createState() => _AddBranoScreenState();
}

class _AddBranoScreenState extends State<AddBranoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _databaseService = DatabaseService();

  final _titoloController = TextEditingController();
  final _tipoMultiController = TextEditingController();
  final _tipoDocuController = TextEditingController();
  final _autoreController = TextEditingController();
  final _strumController = TextEditingController();
  final _archivioProvenienzaController = TextEditingController();
  final _volumeController = TextEditingController();
  final _numPagController = TextEditingController();
  final _numOrigController = TextEditingController();
  final _primoLinkController = TextEditingController();

  // Metodo per salvare il brano nel database
  Future<void> _saveBrano() async {
    if (_formKey.currentState!.validate()) {
      final newBrano = Brano(
        titolo: _titoloController.text,
        tipoMulti: _tipoMultiController.text,
        tipoDocu: _tipoDocuController.text,
        autore: _autoreController.text,
        strum: _strumController.text,
        archivioProvenienza: _archivioProvenienzaController.text,
        volume: _volumeController.text,
        numPag: int.tryParse(_numPagController.text) ?? 0,
        numOrig: int.tryParse(_numOrigController.text) ?? 0,
        primoLink: _primoLinkController.text,
      );

      await _databaseService.insertBrano(newBrano);
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  void dispose() {
    _titoloController.dispose();
    _tipoMultiController.dispose();
    _tipoDocuController.dispose();
    _autoreController.dispose();
    _strumController.dispose();
    _archivioProvenienzaController.dispose();
    _volumeController.dispose();
    _numPagController.dispose();
    _numOrigController.dispose();
    _primoLinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aggiungi un nuovo brano'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titoloController,
                decoration: const InputDecoration(labelText: 'Titolo *'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Inserisci il titolo';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _tipoMultiController,
                decoration: const InputDecoration(labelText: 'Tipo Multi'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _tipoDocuController,
                decoration: const InputDecoration(labelText: 'Tipo Documento'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _autoreController,
                decoration: const InputDecoration(labelText: 'Autore'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _strumController,
                decoration: const InputDecoration(labelText: 'Strumento'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _archivioProvenienzaController,
                decoration: const InputDecoration(labelText: 'Archivio/Provenienza'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _volumeController,
                decoration: const InputDecoration(labelText: 'Volume'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _numPagController,
                decoration: const InputDecoration(labelText: 'Numero di Pagina'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _numOrigController,
                decoration: const InputDecoration(labelText: 'Numero Pagina Originale'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _primoLinkController,
                decoration: const InputDecoration(labelText: 'Primo Link'),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveBrano,
                child: const Text('Salva Brano'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}