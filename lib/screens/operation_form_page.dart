import 'package:flutter/material.dart';

import '../database/app_database.dart';
import '../models/compte.dart';
import '../models/enveloppe_budget.dart';
import '../models/enveloppe_epargne.dart';
import '../models/operation_budget.dart';
import '../models/periode_budget.dart';

class OperationFormPage extends StatefulWidget {
  const OperationFormPage({super.key});

  @override
  State<OperationFormPage> createState() => _OperationFormPageState();
}

class _OperationFormPageState extends State<OperationFormPage> {
  final libelleController = TextEditingController();
  final montantController = TextEditingController();

  TypeOperationBudget type = TypeOperationBudget.depense;
  DateTime date = DateTime.now();
  PeriodeBudget? periode;
  List<Compte> comptesCourants = [];
  List<Compte> comptesEpargne = [];
  List<EnveloppeBudget> enveloppesBudget = [];
  List<EnveloppeEpargne> enveloppesEpargne = [];
  int? compteCourantId;
  int? compteEpargneId;
  int? enveloppeBudgetId;
  int? enveloppeEpargneId;
  bool chargement = true;
  bool enregistrement = false;

  @override
  void initState() {
    super.initState();
    charger();
  }

  @override
  void dispose() {
    libelleController.dispose();
    montantController.dispose();
    super.dispose();
  }

  Future<void> charger() async {
    final courants = await AppDatabase.instance.obtenirComptes(
      type: TypeCompte.courant,
    );
    final epargnes = await AppDatabase.instance.obtenirComptes(
      type: TypeCompte.epargne,
    );
    final periodeActive = await AppDatabase.instance.obtenirPeriodeActive();

    final courant = courants.isEmpty ? null : courants.first.id;
    final epargne = epargnes.isEmpty ? null : epargnes.first.id;

    if (!mounted) return;
    setState(() {
      comptesCourants = courants;
      comptesEpargne = epargnes;
      compteCourantId = courant;
      compteEpargneId = epargne;
      periode = periodeActive;
      chargement = false;
    });
    await chargerEnveloppes();
  }

  Future<void> chargerEnveloppes() async {
    final courant = compteCourantId;
    final epargne = compteEpargneId;
    final budgets = courant == null
        ? <EnveloppeBudget>[]
        : await AppDatabase.instance.obtenirEnveloppesBudget(compteId: courant);
    final objectifs = epargne == null
        ? <EnveloppeEpargne>[]
        : await AppDatabase.instance.obtenirEnveloppesEpargne(
            compteEpargneId: epargne,
          );

    final budgetCompatible = budgets.where((enveloppe) {
      if (type == TypeOperationBudget.virementEpargne) {
        return enveloppe.type == TypeEnveloppeBudget.epargne;
      }
      return enveloppe.type == TypeEnveloppeBudget.depense;
    }).toList();

    if (!mounted) return;
    setState(() {
      enveloppesBudget = budgets;
      enveloppesEpargne = objectifs;
      if (!budgetCompatible.any((e) => e.id == enveloppeBudgetId)) {
        enveloppeBudgetId = budgetCompatible.isEmpty
            ? null
            : budgetCompatible.first.id;
      }
      if (!objectifs.any((e) => e.id == enveloppeEpargneId)) {
        enveloppeEpargneId = objectifs.isEmpty ? null : objectifs.first.id;
      }
    });
  }

  List<EnveloppeBudget> get enveloppesCompatibles {
    if (type == TypeOperationBudget.virementEpargne) {
      return enveloppesBudget
          .where((e) => e.type == TypeEnveloppeBudget.epargne)
          .toList();
    }
    return enveloppesBudget
        .where((e) => e.type == TypeEnveloppeBudget.depense)
        .toList();
  }

  String libelleType(TypeOperationBudget valeur) {
    return switch (valeur) {
      TypeOperationBudget.salaire => 'Salaire / nouvelle période',
      TypeOperationBudget.autreRevenu => 'Autre revenu',
      TypeOperationBudget.depense => 'Dépense',
      TypeOperationBudget.virementEpargne => 'Virement vers épargne',
      TypeOperationBudget.retraitEpargne => 'Retrait d’épargne',
      TypeOperationBudget.transfertEpargneInterne =>
        'Transfert entre enveloppes',
    };
  }

  Future<void> choisirDate() async {
    final nouvelleDate = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (nouvelleDate != null && mounted) setState(() => date = nouvelleDate);
  }

  void afficherErreur(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> enregistrer() async {
    if (enregistrement) return;
    final montant = int.tryParse(
      montantController.text.replaceAll(' ', '').replaceAll(',', ''),
    );
    final libelle = libelleController.text.trim();
    if (montant == null || montant <= 0 || libelle.isEmpty) {
      afficherErreur('Renseigne un libellé et un montant positif.');
      return;
    }
    if (compteCourantId == null) {
      afficherErreur('Aucun compte courant disponible.');
      return;
    }

    setState(() => enregistrement = true);
    try {
      if (type == TypeOperationBudget.salaire) {
        await AppDatabase.instance.enregistrerSalaireEtOuvrirPeriode(
          compteDestinationId: compteCourantId!,
          montant: montant,
          date: date,
          libelle: libelle,
        );
      } else {
        final periodeId = periode?.id;
        if (periodeId == null) {
          afficherErreur(
            'Commence par saisir le salaire qui ouvre la première période.',
          );
          return;
        }

        final operation = switch (type) {
          TypeOperationBudget.autreRevenu => OperationBudget(
            periodeId: periodeId,
            date: date,
            libelle: libelle,
            type: type,
            montant: montant,
            compteDestinationId: compteCourantId,
          ),
          TypeOperationBudget.depense => OperationBudget(
            periodeId: periodeId,
            date: date,
            libelle: libelle,
            type: type,
            montant: montant,
            compteSourceId: compteCourantId,
            enveloppeBudgetId: enveloppeBudgetId,
          ),
          TypeOperationBudget.virementEpargne => OperationBudget(
            periodeId: periodeId,
            date: date,
            libelle: libelle,
            type: type,
            montant: montant,
            compteSourceId: compteCourantId,
            compteDestinationId: compteEpargneId,
            enveloppeBudgetId: enveloppeBudgetId,
            affectationsEpargne: [
              AffectationEpargne(
                enveloppeEpargneId: enveloppeEpargneId ?? -1,
                montant: montant,
              ),
            ],
          ),
          TypeOperationBudget.retraitEpargne => OperationBudget(
            periodeId: periodeId,
            date: date,
            libelle: libelle,
            type: type,
            montant: montant,
            compteSourceId: compteEpargneId,
            compteDestinationId: compteCourantId,
            affectationsEpargne: [
              AffectationEpargne(
                enveloppeEpargneId: enveloppeEpargneId ?? -1,
                montant: -montant,
              ),
            ],
          ),
          TypeOperationBudget.salaire => throw StateError('Déjà traité'),
          TypeOperationBudget.transfertEpargneInterne =>
            throw StateError('Fonction en cours de raccordement'),
        };

        if ((type == TypeOperationBudget.depense ||
                type == TypeOperationBudget.virementEpargne) &&
            enveloppeBudgetId == null) {
          afficherErreur('Sélectionne une enveloppe compatible.');
          return;
        }
        if ((type == TypeOperationBudget.virementEpargne ||
                type == TypeOperationBudget.retraitEpargne) &&
            (compteEpargneId == null || enveloppeEpargneId == null)) {
          afficherErreur('Sélectionne le compte et l’enveloppe d’épargne.');
          return;
        }

        await AppDatabase.instance.ajouterOperation(operation);
      }

      if (mounted) Navigator.pop(context, true);
    } on ArgumentError catch (erreur) {
      afficherErreur(erreur.message?.toString() ?? 'Opération invalide.');
    } on StateError catch (erreur) {
      afficherErreur(erreur.message.toString());
    } finally {
      if (mounted) setState(() => enregistrement = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final utiliseEnveloppeBudget =
        type == TypeOperationBudget.depense ||
        type == TypeOperationBudget.virementEpargne;
    final utiliseEpargne =
        type == TypeOperationBudget.virementEpargne ||
        type == TypeOperationBudget.retraitEpargne;

    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle opération')),
      body: chargement
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                DropdownButtonFormField<TypeOperationBudget>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    TypeOperationBudget.salaire,
                    TypeOperationBudget.autreRevenu,
                    TypeOperationBudget.depense,
                    TypeOperationBudget.virementEpargne,
                    TypeOperationBudget.retraitEpargne,
                  ]
                      .map(
                        (valeur) => DropdownMenuItem(
                          value: valeur,
                          child: Text(libelleType(valeur)),
                        ),
                      )
                      .toList(),
                  onChanged: (valeur) async {
                    if (valeur == null) return;
                    setState(() {
                      type = valeur;
                      enveloppeBudgetId = null;
                    });
                    await chargerEnveloppes();
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: libelleController,
                  decoration: const InputDecoration(
                    labelText: 'Libellé',
                    hintText: 'Ex. Courses, salaire, voyage…',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: montantController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Montant',
                    suffixText: 'XPF',
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: const Text('Date'),
                  subtitle: Text(
                    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
                  ),
                  onTap: choisirDate,
                ),
                const SizedBox(height: 8),
                if (comptesCourants.length > 1)
                  DropdownButtonFormField<int>(
                    initialValue: compteCourantId,
                    decoration: InputDecoration(
                      labelText: type == TypeOperationBudget.retraitEpargne
                          ? 'Compte courant destinataire'
                          : 'Compte courant',
                    ),
                    items: comptesCourants
                        .map(
                          (compte) => DropdownMenuItem(
                            value: compte.id,
                            child: Text(compte.nom),
                          ),
                        )
                        .toList(),
                    onChanged: (valeur) async {
                      setState(() {
                        compteCourantId = valeur;
                        enveloppeBudgetId = null;
                      });
                      await chargerEnveloppes();
                    },
                  ),
                if (utiliseEnveloppeBudget) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    initialValue: enveloppeBudgetId,
                    decoration: InputDecoration(
                      labelText: type == TypeOperationBudget.virementEpargne
                          ? 'Enveloppe « Épargne prévue »'
                          : 'Enveloppe de dépense',
                    ),
                    items: enveloppesCompatibles
                        .map(
                          (enveloppe) => DropdownMenuItem(
                            value: enveloppe.id,
                            child: Text(enveloppe.nom),
                          ),
                        )
                        .toList(),
                    onChanged: (valeur) =>
                        setState(() => enveloppeBudgetId = valeur),
                  ),
                ],
                if (utiliseEpargne) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    initialValue: compteEpargneId,
                    decoration: const InputDecoration(
                      labelText: 'Compte épargne',
                    ),
                    items: comptesEpargne
                        .map(
                          (compte) => DropdownMenuItem(
                            value: compte.id,
                            child: Text(compte.nom),
                          ),
                        )
                        .toList(),
                    onChanged: (valeur) async {
                      setState(() {
                        compteEpargneId = valeur;
                        enveloppeEpargneId = null;
                      });
                      await chargerEnveloppes();
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    initialValue: enveloppeEpargneId,
                    decoration: const InputDecoration(
                      labelText: 'Enveloppe d’épargne',
                    ),
                    items: enveloppesEpargne
                        .map(
                          (enveloppe) => DropdownMenuItem(
                            value: enveloppe.id,
                            child: Text(enveloppe.nom),
                          ),
                        )
                        .toList(),
                    onChanged: (valeur) =>
                        setState(() => enveloppeEpargneId = valeur),
                  ),
                ],
                if (type == TypeOperationBudget.virementEpargne) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Le montant sera intégralement affecté à l’enveloppe d’épargne sélectionnée.',
                  ),
                ],
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: enregistrement ? null : enregistrer,
                  icon: const Icon(Icons.check),
                  label: Text(
                    enregistrement ? 'Enregistrement…' : 'Enregistrer',
                  ),
                ),
              ],
            ),
    );
  }
}
