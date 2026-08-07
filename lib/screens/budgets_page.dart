import 'package:flutter/material.dart';

import '../database/app_database.dart';
import '../models/charge_fixe.dart';
import '../models/compte.dart';
import '../models/enveloppe_budget.dart';

class BudgetsPage extends StatefulWidget {
  final VoidCallback? onChanged;

  const BudgetsPage({super.key, this.onChanged});

  @override
  State<BudgetsPage> createState() => _BudgetsPageState();
}

class _BudgetsPageState extends State<BudgetsPage> {
  List<Compte> comptesCourants = [];
  int? compteId;
  List<ChargeFixe> chargesFixes = [];
  List<ChargeFixePeriode> chargesPeriode = [];
  List<EnveloppeBudget> enveloppes = [];
  List<EnveloppeBudgetPeriode> enveloppesPeriode = [];
  bool chargement = true;

  @override
  void initState() {
    super.initState();
    charger();
  }

  Future<void> charger() async {
    final comptes = await AppDatabase.instance.obtenirComptes(
      type: TypeCompte.courant,
    );
    var selection = compteId;
    if (!comptes.any((c) => c.id == selection)) {
      selection = comptes.isEmpty ? null : comptes.first.id;
    }

    List<ChargeFixe> nouvellesCharges = [];
    List<ChargeFixePeriode> nouvellesChargesPeriode = [];
    List<EnveloppeBudget> nouvellesEnveloppes = [];
    List<EnveloppeBudgetPeriode> nouvellesEnveloppesPeriode = [];

    if (selection != null) {
      nouvellesCharges = await AppDatabase.instance.obtenirChargesFixes(
        compteId: selection,
      );
      nouvellesEnveloppes = await AppDatabase.instance.obtenirEnveloppesBudget(
        compteId: selection,
      );
      final periode = await AppDatabase.instance.obtenirPeriodeActive();
      if (periode?.id != null) {
        nouvellesChargesPeriode = await AppDatabase.instance
            .obtenirChargesFixesPeriode(
              periodeId: periode!.id!,
              compteIds: [selection],
            );
        nouvellesEnveloppesPeriode = await AppDatabase.instance
            .obtenirEnveloppesBudgetPeriode(
              periodeId: periode.id!,
              compteIds: [selection],
            );
      }
    }

    if (!mounted) return;
    setState(() {
      comptesCourants = comptes;
      compteId = selection;
      chargesFixes = nouvellesCharges;
      chargesPeriode = nouvellesChargesPeriode;
      enveloppes = nouvellesEnveloppes;
      enveloppesPeriode = nouvellesEnveloppesPeriode;
      chargement = false;
    });
  }

  String formatXpf(int montant) {
    final texte = montant.abs().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < texte.length; i++) {
      if (i > 0 && (texte.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(texte[i]);
    }
    return '${montant < 0 ? '-' : ''}${buffer.toString()} XPF';
  }

  ChargeFixePeriode? _etatCharge(int chargeId) {
    for (final charge in chargesPeriode) {
      if (charge.chargeFixeId == chargeId) return charge;
    }
    return null;
  }

  EnveloppeBudgetPeriode? _etatEnveloppe(int enveloppeId) {
    for (final enveloppe in enveloppesPeriode) {
      if (enveloppe.enveloppeId == enveloppeId) return enveloppe;
    }
    return null;
  }

  Future<void> ouvrirChargeFixe({ChargeFixe? charge}) async {
    final selection = compteId;
    if (selection == null) return;

    final nomController = TextEditingController(text: charge?.nom ?? '');
    final montantController = TextEditingController(
      text: charge?.montantReference.toString() ?? '',
    );
    final jourController = TextEditingController(
      text: charge?.jourPrevu?.toString() ?? '',
    );

    final resultat = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(charge == null ? 'Ajouter une charge fixe' : 'Modifier'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomController,
                decoration: const InputDecoration(labelText: 'Nom'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: montantController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Montant prévu',
                  suffixText: 'XPF',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: jourController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Jour prévu (optionnel)',
                  hintText: '1 à 31',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              final nom = nomController.text.trim();
              final montant = int.tryParse(
                montantController.text.replaceAll(' ', ''),
              );
              final jourTexte = jourController.text.trim();
              final jour = jourTexte.isEmpty ? null : int.tryParse(jourTexte);
              if (nom.isEmpty ||
                  montant == null ||
                  montant < 0 ||
                  (jourTexte.isNotEmpty &&
                      (jour == null || jour < 1 || jour > 31))) {
                return;
              }

              final valeur = ChargeFixe(
                id: charge?.id,
                compteId: selection,
                nom: nom,
                montantReference: montant,
                jourPrevu: jour,
              );
              if (charge == null) {
                await AppDatabase.instance.ajouterChargeFixe(valeur);
              } else {
                await AppDatabase.instance.modifierChargeFixe(valeur);
              }
              if (dialogContext.mounted) Navigator.pop(dialogContext, true);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (resultat == true) {
      await charger();
      widget.onChanged?.call();
    }
  }

  Future<void> changerEtatCharge(
    ChargeFixe charge,
    ChargeFixePeriode etat,
    bool payee,
  ) async {
    int? montantReel;
    if (payee) {
      final controller = TextEditingController(
        text: etat.montantPrevu.toString(),
      );
      final resultat = await showDialog<int>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('${charge.nom} payée'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Montant réellement payé',
              suffixText: 'XPF',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                final montant = int.tryParse(
                  controller.text.replaceAll(' ', ''),
                );
                if (montant != null && montant >= 0) {
                  Navigator.pop(dialogContext, montant);
                }
              },
              child: const Text('Valider'),
            ),
          ],
        ),
      );
      if (resultat == null) return;
      montantReel = resultat;
    }

    await AppDatabase.instance.marquerChargeFixePayee(
      chargeFixePeriodeId: etat.id,
      payee: payee,
      montantReel: montantReel,
      datePaiement: payee ? DateTime.now() : null,
    );
    await charger();
    widget.onChanged?.call();
  }

  Future<void> ouvrirEnveloppe({EnveloppeBudget? enveloppe}) async {
    final selection = compteId;
    if (selection == null) return;

    final nomController = TextEditingController(text: enveloppe?.nom ?? '');
    final montantController = TextEditingController(
      text: enveloppe?.montantReference.toString() ?? '',
    );
    var type = enveloppe?.type ?? TypeEnveloppeBudget.depense;

    final resultat = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(enveloppe == null ? 'Ajouter une enveloppe' : 'Modifier'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nomController,
                  decoration: const InputDecoration(labelText: 'Nom'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: montantController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Montant prévu',
                    suffixText: 'XPF',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<TypeEnveloppeBudget>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(
                      value: TypeEnveloppeBudget.depense,
                      child: Text('Charge variable'),
                    ),
                    DropdownMenuItem(
                      value: TypeEnveloppeBudget.epargne,
                      child: Text('Épargne prévue'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => type = value);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () async {
                final nom = nomController.text.trim();
                final montant = int.tryParse(
                  montantController.text.replaceAll(' ', ''),
                );
                if (nom.isEmpty || montant == null || montant < 0) return;

                final valeur = EnveloppeBudget(
                  id: enveloppe?.id,
                  compteId: selection,
                  nom: nom,
                  type: type,
                  montantReference: montant,
                  icone: enveloppe?.icone,
                );
                if (enveloppe == null) {
                  await AppDatabase.instance.ajouterEnveloppeBudget(valeur);
                } else {
                  await AppDatabase.instance.modifierEnveloppeBudget(valeur);
                }
                if (dialogContext.mounted) Navigator.pop(dialogContext, true);
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );

    if (resultat == true) {
      await charger();
      widget.onChanged?.call();
    }
  }

  Future<bool> confirmerSuppression(String libelle) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Supprimer ?'),
            content: Text(libelle),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Supprimer'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final enveloppesDepenses = enveloppes
        .where((e) => e.type == TypeEnveloppeBudget.depense)
        .toList();
    final enveloppesEpargne = enveloppes
        .where((e) => e.type == TypeEnveloppeBudget.epargne)
        .toList();

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(title: const Text('Budgets')),
        floatingActionButton: compteId == null
            ? null
            : FloatingActionButton.extended(
                onPressed: () => ouvrirEnveloppe(),
                icon: const Icon(Icons.add),
                label: const Text('Enveloppe'),
              ),
        body: chargement
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                children: [
                  if (comptesCourants.length > 1)
                    DropdownButtonFormField<int>(
                      initialValue: compteId,
                      decoration: const InputDecoration(
                        labelText: 'Compte courant affiché',
                      ),
                      items: comptesCourants
                          .map(
                            (c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.nom),
                            ),
                          )
                          .toList(),
                      onChanged: (value) async {
                        setState(() => compteId = value);
                        await charger();
                      },
                    ),
                  if (comptesCourants.length > 1) const SizedBox(height: 18),
                  if (compteId == null)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Crée d’abord un compte courant pour définir ton budget.',
                        ),
                      ),
                    )
                  else ...[
                    _TitreSection(
                      titre: 'Charges fixes',
                      onAjouter: () => ouvrirChargeFixe(),
                    ),
                    if (chargesFixes.isEmpty)
                      const _CarteVide(texte: 'Aucune charge fixe.'),
                    ...chargesFixes.map((charge) {
                      final etat = charge.id == null
                          ? null
                          : _etatCharge(charge.id!);
                      return Card(
                        child: ListTile(
                          leading: etat == null
                              ? const Icon(Icons.event_repeat)
                              : Checkbox(
                                  value: etat.payee,
                                  onChanged: (value) {
                                    if (value != null) {
                                      changerEtatCharge(charge, etat, value);
                                    }
                                  },
                                ),
                          title: Text(charge.nom),
                          subtitle: Text(
                            charge.jourPrevu == null
                                ? 'Mensuelle'
                                : 'Prévue le ${charge.jourPrevu}',
                          ),
                          trailing: Text(
                            formatXpf(etat?.montantPrevu ?? charge.montantReference),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onTap: () => ouvrirChargeFixe(charge: charge),
                          onLongPress: () async {
                            if (charge.id != null &&
                                await confirmerSuppression(
                                  'La charge « ${charge.nom} » sera retirée des prochaines périodes.',
                                )) {
                              await AppDatabase.instance.supprimerChargeFixe(
                                charge.id!,
                              );
                              await charger();
                              widget.onChanged?.call();
                            }
                          },
                        ),
                      );
                    }),
                    const SizedBox(height: 24),
                    const _TitreSection(titre: 'Charges variables'),
                    if (enveloppesDepenses.isEmpty)
                      const _CarteVide(texte: 'Aucune enveloppe de dépense.'),
                    ...enveloppesDepenses.map(_carteEnveloppe),
                    const SizedBox(height: 24),
                    const _TitreSection(titre: 'Épargne prévue'),
                    if (enveloppesEpargne.isEmpty)
                      const _CarteVide(
                        texte:
                            'Aucune enveloppe d’épargne prévue sur le compte courant.',
                      ),
                    ...enveloppesEpargne.map(_carteEnveloppe),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _carteEnveloppe(EnveloppeBudget enveloppe) {
    final etat = enveloppe.id == null ? null : _etatEnveloppe(enveloppe.id!);
    final restant = etat?.montantRestant ?? enveloppe.montantReference;
    final depasse = restant < 0;

    return Card(
      color: depasse ? Theme.of(context).colorScheme.errorContainer : null,
      child: ListTile(
        leading: Icon(
          enveloppe.type == TypeEnveloppeBudget.epargne
              ? Icons.savings_outlined
              : Icons.pie_chart_outline,
        ),
        title: Text(enveloppe.nom),
        subtitle: Text(
          etat == null
              ? 'Prévu : ${formatXpf(enveloppe.montantReference)}'
              : 'Utilisé : ${formatXpf(etat.montantUtilise)} / ${formatXpf(etat.montantPrevu)}',
        ),
        trailing: Text(
          formatXpf(restant),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: depasse ? Theme.of(context).colorScheme.error : null,
          ),
        ),
        onTap: () => ouvrirEnveloppe(enveloppe: enveloppe),
        onLongPress: () async {
          if (enveloppe.id != null &&
              await confirmerSuppression(
                'L’enveloppe « ${enveloppe.nom} » sera retirée des prochaines périodes.',
              )) {
            await AppDatabase.instance.supprimerEnveloppeBudget(enveloppe.id!);
            await charger();
            widget.onChanged?.call();
          }
        },
      ),
    );
  }
}

class _TitreSection extends StatelessWidget {
  final String titre;
  final VoidCallback? onAjouter;

  const _TitreSection({required this.titre, this.onAjouter});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            titre,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        if (onAjouter != null)
          IconButton(onPressed: onAjouter, icon: const Icon(Icons.add)),
      ],
    );
  }
}

class _CarteVide extends StatelessWidget {
  final String texte;

  const _CarteVide({required this.texte});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(18), child: Text(texte)),
    );
  }
}
