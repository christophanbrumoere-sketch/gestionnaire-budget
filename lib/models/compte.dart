enum TypeCompte { courant, epargne }

class Compte {
  final int? id;
  final String nom;
  final TypeCompte type;
  final int solde;

  const Compte({
    this.id,
    required this.nom,
    required this.type,
    required this.solde,
  });

  Map<String, Object?> toMap() {
    return {'id': id, 'nom': nom, 'type': type.name, 'solde': solde};
  }

  factory Compte.fromMap(Map<String, Object?> map) {
    return Compte(
      id: map['id'] as int,
      nom: map['nom'] as String,
      type: TypeCompte.values.byName(map['type'] as String),
      solde: map['solde'] as int,
    );
  }
}
