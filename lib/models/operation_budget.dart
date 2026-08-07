enum TypeOperationBudget {
  salaire,
  autreRevenu,
  depense,
  virementEpargne,
  retraitEpargne,
  transfertEpargneInterne,
}

class AffectationEpargne {
  final int enveloppeEpargneId;
  final int montant;

  const AffectationEpargne({
    required this.enveloppeEpargneId,
    required this.montant,
  });
}

class OperationBudget {
  final int? id;
  final int periodeId;
  final DateTime date;
  final String libelle;
  final TypeOperationBudget type;
  final int montant;
  final int? compteSourceId;
  final int? compteDestinationId;
  final int? enveloppeBudgetId;
  final String? note;
  final List<AffectationEpargne> affectationsEpargne;

  const OperationBudget({
    this.id,
    required this.periodeId,
    required this.date,
    required this.libelle,
    required this.type,
    required this.montant,
    this.compteSourceId,
    this.compteDestinationId,
    this.enveloppeBudgetId,
    this.note,
    this.affectationsEpargne = const [],
  });
}
