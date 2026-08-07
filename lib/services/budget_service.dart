import '../database/app_database.dart';
import '../models/resume_budget.dart';
import 'budget_calculator.dart';

class BudgetService {
  final AppDatabase database;

  const BudgetService({required this.database});

  Future<ResumeBudget> chargerResume({
    required Iterable<int> compteCourantIds,
  }) async {
    final ids = compteCourantIds.toList();
    final periode = await database.obtenirPeriodeActive();
    if (periode?.id == null || ids.isEmpty) return ResumeBudget.vide;

    final periodeId = periode!.id!;
    final enveloppes = await database.obtenirEnveloppesBudgetPeriode(
      periodeId: periodeId,
      compteIds: ids,
    );
    final charges = await database.obtenirChargesFixesPeriode(
      periodeId: periodeId,
      compteIds: ids,
    );

    final soldeOuverture = await database.obtenirSoldeOuvertureComptes(
      periodeId: periodeId,
      compteIds: ids,
    );
    final entrees = await database.obtenirEntreesComptes(
      periodeId: periodeId,
      compteIds: ids,
    );
    final mouvementNet = await database.obtenirMouvementNetComptes(
      periodeId: periodeId,
      compteIds: ids,
    );
    final totalEpargne = await database.obtenirTotalEpargneAffectee();

    final chargesFixesPrevues = charges.fold<int>(
      0,
      (somme, charge) => somme + charge.montantPrevu,
    );
    final chargesFixesPayees = charges.fold<int>(
      0,
      (somme, charge) => somme + charge.montantPaye,
    );
    final chargesFixesRestantes = charges
        .where((charge) => !charge.payee)
        .fold<int>(0, (somme, charge) => somme + charge.montantPrevu);

    return BudgetCalculator.calculer(
      soldeOuvertureCourant: soldeOuverture,
      entreesCourantes: entrees,
      mouvementNetCourant: mouvementNet,
      chargesFixesPrevues: chargesFixesPrevues,
      chargesFixesPayees: chargesFixesPayees,
      chargesFixesRestantes: chargesFixesRestantes,
      totalEpargne: totalEpargne,
      enveloppes: enveloppes,
    );
  }
}
