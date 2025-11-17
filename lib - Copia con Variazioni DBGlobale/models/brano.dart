// lib/models/brano.dart

class Brano {
  final int? idBra;
  final String? tipoMulti;
  final String? tipoDocu;
  final String titolo;
  final String? autore;
  final String? strum;
  final String? archivioProvenienza;
  final String? volume;
  final int? numPag;
  final int? numOrig;
  final String? primoLink;

  Brano({
    this.idBra,
    this.tipoMulti,
    this.tipoDocu,
    required this.titolo,
    this.autore,
    this.strum,
    this.archivioProvenienza,
    this.volume,
    this.numPag,
    this.numOrig,
    this.primoLink,
  });

  // Converte un oggetto Brano in una mappa per l'inserimento nel database.
  Map<String, dynamic> toMap() {
    return {
      'idBra': idBra,
      'tipoMulti': tipoMulti,
      'tipoDocu': tipoDocu,
      'titolo': titolo,
      'autore': autore,
      'strum': strum,
      'archivioProvenienza': archivioProvenienza,
      'volume': volume,
      'numPag': numPag,
      'numOrig': numOrig,
      'primoLink': primoLink,
    };
  }

  // Crea un oggetto Brano da una mappa letta dal database.
  factory Brano.fromMap(Map<String, dynamic> map) {
    return Brano(
      idBra: map['idBra'] as int?,
      tipoMulti: map['tipoMulti'] as String?,
      tipoDocu: map['tipoDocu'] as String?,
      titolo: map['titolo'] as String,
      autore: map['autore'] as String?,
      strum: map['strum'] as String?,
      archivioProvenienza: map['archivioProvenienza'] as String?,
      volume: map['volume'] as String?,
      numPag: map['numPag'] as int?,
      numOrig: map['numOrig'] as int?,
      primoLink: map['primoLink'] as String?,
    );
  }

  @override
  String toString() {
    return 'Brano{idBra: $idBra, titolo: $titolo, autore: $autore, ...}';
  }
}