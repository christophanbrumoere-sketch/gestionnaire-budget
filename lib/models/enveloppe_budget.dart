enum TypeEnveloppeBudget { depense, epargne }

class EnveloppeBudget {
  final int? id;
  final int compteId;
  final String nom;
  final TypeEnveloppeBudget type;
  final int montantReference;
  final String? icone;
  final bool actif;

  const EnveloppeBudget({
    this.id,
    required this.compteId,
    required this.nom,
    required this.type,
    required this.montantReference,
    this.icone,
    this.actif = true,
  });

  Map<String, Object?> toMap() => {
    'id': id,
    'compte_id': compteId,
    'nom': nom,
    'type': type.name,
    'montant_reference': montantReference,
    'icone': icone,
    'actif': actif ? 1 : 0,
  };

  factory EnveloppeBudget.fromMap(Map<String, Object?> map) => EnveloppeBudget(
    id: map['id'] as int,
    compteId: map['compte_id'] as int,
    nom: map['nom'] as String,
    type: TypeEnveloppeBudget.values.byName(map['type'] as String),
    montantReference: map['montant_reference'] as int,
    icone: map['icone'] as String?,
    actif: (map['actif'] as int) == 1,
  );
}

class EnveloppeBudgetPeriode {
  final int enveloppeId;
  final String nom;
  final TypeEnveloppeBudget type;
  final int montantPrevu;
  final int montantUtilise;

  const EnveloppeBudgetPeriode({
    required this.enveloppeId,
    required this.nom,
    required this.type,
    required this.montantPrevu,
    required this.montantUtilise,
  });

  int get montantRestant => montantPrevu - montantUtilise;
  int get depassement => montantRestant < 0 ? -montantRestant : 0;
}
