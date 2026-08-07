import '../models/enveloppe_budget.dart';
import '../models/resume_budget.dart';

class BudgetCalculator {
  const BudgetCalculator._();

  static ResumeBudget calculer({
    required int soldeOuvertureCourant,
    required int entreesCourantes,
    required int mouvementNetCourant,
    required int chargesFixesPrevues,
    required int chargesFixesPayees,
    required int chargesFixesRestantes,
    required int totalEpargne,
    required List<EnveloppeBudgetPeriode> enveloppes,
  }) {
    final totalEnveloppesPrevues = enveloppes.fold<int>(
      0,
      (somme, enveloppe) => somme + enveloppe.montantPrevu,
    );

    final depassements = enveloppes.fold<int>(
      0,
      (somme, enveloppe) => somme + enveloppe.depassement,
    );

    final chargesVariablesRestantes = enveloppes
        .where((e) => e.type == TypeEnveloppeBudget.depense)
        .fold<int>(0, (somme, enveloppe) => somme + enveloppe.montantRestant);

    final epargneProgrammeeRestante = enveloppes
        .where((e) => e.type == TypeEnveloppeBudget.epargne)
        .fold<int>(0, (somme, enveloppe) => somme + enveloppe.montantRestant);

    return ResumeBudget(
      soldeCourant:
          soldeOuvertureCourant + mouvementNetCourant - chargesFixesPayees,
      argentLibre:
          soldeOuvertureCourant +
          entreesCourantes -
          chargesFixesPrevues -
          totalEnveloppesPrevues -
          depassements,
      chargesFixesPrevues: chargesFixesPrevues,
      chargesFixesRestantes: chargesFixesRestantes,
      chargesVariablesRestantes: chargesVariablesRestantes,
      epargneProgrammeeRestante: epargneProgrammeeRestante,
      totalEpargne: totalEpargne,
      enveloppes: enveloppes,
    );
  }
}
