import 'enveloppe_budget.dart';

class ResumeBudget {
  final int soldeCourant;
  final int argentLibre;
  final int chargesFixesPrevues;
  final int chargesFixesRestantes;
  final int chargesVariablesRestantes;
  final int epargneProgrammeeRestante;
  final int totalEpargne;
  final List<EnveloppeBudgetPeriode> enveloppes;

  const ResumeBudget({
    required this.soldeCourant,
    required this.argentLibre,
    required this.chargesFixesPrevues,
    required this.chargesFixesRestantes,
    required this.chargesVariablesRestantes,
    required this.epargneProgrammeeRestante,
    required this.totalEpargne,
    required this.enveloppes,
  });

  static const vide = ResumeBudget(
    soldeCourant: 0,
    argentLibre: 0,
    chargesFixesPrevues: 0,
    chargesFixesRestantes: 0,
    chargesVariablesRestantes: 0,
    epargneProgrammeeRestante: 0,
    totalEpargne: 0,
    enveloppes: [],
  );
}
