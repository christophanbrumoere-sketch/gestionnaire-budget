import '../models/operation_budget.dart';

class OperationRules {
  const OperationRules._();

  static bool virementEpargneEntierementAffecte(
    int montant,
    Iterable<AffectationEpargne> affectations,
  ) {
    final liste = affectations.toList();
    return liste.isNotEmpty &&
        liste.every((a) => a.montant > 0) &&
        liste.fold<int>(0, (somme, a) => somme + a.montant) == montant;
  }

  static bool retraitEpargneEntierementImpute(
    int montant,
    Iterable<AffectationEpargne> affectations,
  ) {
    final liste = affectations.toList();
    return liste.isNotEmpty &&
        liste.every((a) => a.montant < 0) &&
        liste.fold<int>(0, (somme, a) => somme + a.montant) == -montant;
  }
}
