import 'package:flutter_test/flutter_test.dart';
import 'package:gestionnaire_budget/models/enveloppe_budget.dart';
import 'package:gestionnaire_budget/services/budget_calculator.dart';

void main() {
  test('migration conserve le scenario existant 46 000 - 40 000', () {
    final resume = BudgetCalculator.calculer(
      soldeOuvertureCourant: 46000,
      entreesCourantes: 0,
      mouvementNetCourant: 0,
      chargesFixesPrevues: 0,
      chargesFixesPayees: 0,
      chargesFixesRestantes: 0,
      totalEpargne: 0,
      enveloppes: const [
        EnveloppeBudgetPeriode(
          enveloppeId: 1,
          nom: 'Budgets existants',
          type: TypeEnveloppeBudget.depense,
          montantPrevu: 40000,
          montantUtilise: 0,
        ),
      ],
    );

    expect(resume.argentLibre, 6000);
    expect(resume.soldeCourant, 46000);
  });

  test('scenario mensuel de reference du cahier des charges', () {
    final resume = BudgetCalculator.calculer(
      soldeOuvertureCourant: 20000,
      entreesCourantes: 300000,
      mouvementNetCourant: 300000 - 90000 - 30000,
      chargesFixesPrevues: 150000,
      chargesFixesPayees: 140000,
      chargesFixesRestantes: 0,
      totalEpargne: 30000,
      enveloppes: const [
        EnveloppeBudgetPeriode(
          enveloppeId: 1,
          nom: 'Charges variables',
          type: TypeEnveloppeBudget.depense,
          montantPrevu: 100000,
          montantUtilise: 90000,
        ),
        EnveloppeBudgetPeriode(
          enveloppeId: 2,
          nom: 'Épargne',
          type: TypeEnveloppeBudget.epargne,
          montantPrevu: 40000,
          montantUtilise: 30000,
        ),
      ],
    );

    expect(resume.argentLibre, 30000);
    expect(resume.soldeCourant, 60000);
    expect(resume.chargesVariablesRestantes, 10000);
    expect(resume.epargneProgrammeeRestante, 10000);
  });

  test("un depassement d'enveloppe reduit uniquement l'argent libre", () {
    final resume = BudgetCalculator.calculer(
      soldeOuvertureCourant: 80000,
      entreesCourantes: 0,
      mouvementNetCourant: -45000,
      chargesFixesPrevues: 0,
      chargesFixesPayees: 0,
      chargesFixesRestantes: 0,
      totalEpargne: 0,
      enveloppes: const [
        EnveloppeBudgetPeriode(
          enveloppeId: 1,
          nom: 'Courses',
          type: TypeEnveloppeBudget.depense,
          montantPrevu: 30000,
          montantUtilise: 45000,
        ),
      ],
    );

    expect(resume.argentLibre, 35000);
    expect(resume.enveloppes.single.montantRestant, -15000);
  });
}
