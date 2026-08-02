class Budget {
  final int? id;
  final String nom;
  final int montantMensuel;

  const Budget({this.id, required this.nom, required this.montantMensuel});

  Map<String, Object?> toMap() {
    return {'id': id, 'nom': nom, 'montant_mensuel': montantMensuel};
  }

  factory Budget.fromMap(Map<String, Object?> map) {
    return Budget(
      id: map['id'] as int,
      nom: map['nom'] as String,
      montantMensuel: map['montant_mensuel'] as int,
    );
  }
}
