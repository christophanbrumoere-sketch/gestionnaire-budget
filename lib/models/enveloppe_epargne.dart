class EnveloppeEpargne {
  final int? id;
  final int compteEpargneId;
  final String nom;
  final int soldeInitial;
  final int? montantCible;
  final DateTime? echeance;
  final bool actif;

  const EnveloppeEpargne({
    this.id,
    required this.compteEpargneId,
    required this.nom,
    this.soldeInitial = 0,
    this.montantCible,
    this.echeance,
    this.actif = true,
  });

  Map<String, Object?> toMap() => {
    'id': id,
    'compte_epargne_id': compteEpargneId,
    'nom': nom,
    'solde_initial': soldeInitial,
    'montant_cible': montantCible,
    'echeance': echeance?.toIso8601String(),
    'actif': actif ? 1 : 0,
  };

  factory EnveloppeEpargne.fromMap(Map<String, Object?> map) =>
      EnveloppeEpargne(
        id: map['id'] as int,
        compteEpargneId: map['compte_epargne_id'] as int,
        nom: map['nom'] as String,
        soldeInitial: (map['solde_initial'] ?? 0) as int,
        montantCible: map['montant_cible'] as int?,
        echeance: map['echeance'] == null
            ? null
            : DateTime.parse(map['echeance'] as String),
        actif: (map['actif'] as int) == 1,
      );
}
