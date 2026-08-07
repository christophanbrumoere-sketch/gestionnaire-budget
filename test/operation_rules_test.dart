import 'package:flutter_test/flutter_test.dart';
import 'package:gestionnaire_budget/models/operation_budget.dart';
import 'package:gestionnaire_budget/services/operation_rules.dart';

void main() {
  test("un virement d'epargne doit etre affecte a 100 %", () {
    const affectationsCompletes = [
      AffectationEpargne(enveloppeEpargneId: 1, montant: 15000),
      AffectationEpargne(enveloppeEpargneId: 2, montant: 10000),
    ];
    const affectationsIncompletes = [
      AffectationEpargne(enveloppeEpargneId: 1, montant: 15000),
    ];

    expect(
      OperationRules.virementEpargneEntierementAffecte(
        25000,
        affectationsCompletes,
      ),
      isTrue,
    );
    expect(
      OperationRules.virementEpargneEntierementAffecte(
        25000,
        affectationsIncompletes,
      ),
      isFalse,
    );
  });
}
