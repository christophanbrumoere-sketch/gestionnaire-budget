enum TypeCompte { courant, epargne }

class Compte {
  final int? id;
  final String nom;
  final TypeCompte type;
  final int soldeInitial;
  final bool actif;

  const Compte({
    this.id,
    required this.nom,
    required this.type,
    required this.soldeInitial,
    this.actif = true,
  });

  // Compatibilite avec les premiers ecrans de l'application.
  int get solde => soldeInitial;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'nom': nom,
      'type': type.name,
      'solde_initial': soldeInitial,
      'actif': actif ? 1 : 0,
    };
  }

  factory Compte.fromMap(Map<String, Object?> map) {
    return Compte(
      id: map['id'] as int,
      nom: map['nom'] as String,
      type: TypeCompte.values.byName(map['type'] as String),
      soldeInitial: (map['solde_initial'] ?? map['solde'] ?? 0) as int,
      actif: ((map['actif'] ?? 1) as int) == 1,
    );
  }
}
