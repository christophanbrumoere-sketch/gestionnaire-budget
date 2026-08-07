class PeriodeBudget {
  final int? id;
  final DateTime dateDebut;
  final DateTime? dateFin;
  final bool estActive;

  const PeriodeBudget({
    this.id,
    required this.dateDebut,
    this.dateFin,
    this.estActive = true,
  });

  Map<String, Object?> toMap() => {
    'id': id,
    'date_debut': dateDebut.toIso8601String(),
    'date_fin': dateFin?.toIso8601String(),
    'est_active': estActive ? 1 : 0,
  };

  factory PeriodeBudget.fromMap(Map<String, Object?> map) => PeriodeBudget(
    id: map['id'] as int,
    dateDebut: DateTime.parse(map['date_debut'] as String),
    dateFin: map['date_fin'] == null
        ? null
        : DateTime.parse(map['date_fin'] as String),
    estActive: (map['est_active'] as int) == 1,
  );
}
