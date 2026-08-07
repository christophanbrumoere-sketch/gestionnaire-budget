import 'operation_budget.dart';

class OperationResume {
  final int id;
  final DateTime date;
  final String libelle;
  final TypeOperationBudget type;
  final int montantSigne;

  const OperationResume({
    required this.id,
    required this.date,
    required this.libelle,
    required this.type,
    required this.montantSigne,
  });

  factory OperationResume.fromMap(Map<String, Object?> map) => OperationResume(
    id: map['id'] as int,
    date: DateTime.parse(map['date_operation'] as String),
    libelle: map['libelle'] as String,
    type: TypeOperationBudget.values.byName(map['type'] as String),
    montantSigne: (map['montant_signe'] as num).toInt(),
  );
}
