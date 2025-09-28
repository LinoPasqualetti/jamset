Widget _buildEmptyState() {
  return Container( // AVVOLGI CON CONTAINER
    color: Colors.grey[200], // IMPOSTA IL COLORE DI BACKGROUND DESIDERATO QUI
    // Puoi usare Colors.amber, Colors.tealAccent.withOpacity(0.5), ecc.
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch, // Per estendere il background se necessario
          children: <Widget>[
            Image.asset(
                'assets/images/SherlockCerca2.png',
                height: 200,
                errorBuilder: (context, error, stackTrace) {
                  return const Text('Errore caricamento immagine SherlockCerca2');
                }
            ),
            const SizedBox(height: 24),
            const Text(
              'Nessun file CSV caricato.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('Carica File CSV'),
              onPressed: _pickAndLoadCsv,
            ),
          ],
        ),
      ),
    ),;
}
