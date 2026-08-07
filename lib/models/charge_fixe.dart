class ChargeFixe {
  final int? id;
  final int compteId;
  final String nom;
  final int montantReference;
  final int? jourPrevu;
  final bool actif;

  const ChargeFixe({
    this.id,
    required this.compteId,
    required this.nom,
    required this.montantReference,
    this.jourPrevu,
    this.actif = true,
  });

  Map<String, Object?> toMap() => {
    'id': id,
    'compte_id': compteId,
    'nom': nom,
    'montant_reference': montantReference,
    'jour_prevu': jourPrevu,
    'actif': actif ? 1 : 0,
  };

  factory ChargeFixe.fromMap(Map<String, Object?> map) => ChargeFixe(
    id: map['id'] as int,
    compteId: map['compte_id'] as int,
    nom: map['nom'] as String,
    montantReference: map['montant_reference'] as int,
    jourPrevu: map['jour_prevu'] as int?,
    actif: (map['actif'] as int) == 1,
  );
}

class ChargeFixePeriode {
  final int id;
  final int chargeFixeId;
  final String nom;
  final int montantPrevu;
  final bool payee;
  final int? montantReel;
  final DateTime? datePaiement;

  const ChargeFixePeriode({
    required this.id,
    required this.chargeFixeId,
    required this.nom,
    required this.montantPrevu,
    required this.payee,
    this.montantReel,
    this.datePaiement,
  });

  int get montantPaye => payee ? (montantReel ?? montantPrevu) : 0;

  factory ChargeFixePeriode.fromMap(Map<String, Object?> map) =>
      ChargeFixePeriode(
        id: map['id'] as int,
        chargeFixeId: map['charge_fixe_id'] as int,
        nom: map['nom'] as String,
        montantPrevu: map['montant_prevu'] as int,
        payee: (map['payee'] as int) == 1,
        montantReel: map['montant_reel'] as int?,
        datePaiement: map['date_paiement'] == null
            ? null
            : DateTime.parse(map['date_paiement'] as String),
      );
}
