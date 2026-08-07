import 'package:flutter/material.dart';

import '../database/app_database.dart';
import '../models/compte.dart';
import '../models/enveloppe_epargne.dart';

class EpargnePage extends StatefulWidget {
  const EpargnePage({super.key});

  @override
  State<EpargnePage> createState() => _EpargnePageState();
}

class _EpargnePageState extends State<EpargnePage> {
  List<Compte> comptes = [];
  int? compteId;
  List<EnveloppeEpargne> enveloppes = [];
  Map<int, int> soldes = {};
  bool chargement = true;

  @override
  void initState() {
    super.initState();
    charger();
  }

  Future<void> charger() async {
    final nouveauxComptes = await AppDatabase.instance.obtenirComptes(
      type: TypeCompte.epargne,
    );
    var selection = compteId;
    if (!nouveauxComptes.any((c) => c.id == selection)) {
      selection = nouveauxComptes.isEmpty ? null : nouveauxComptes.first.id;
    }

    final nouvellesEnveloppes = selection == null
        ? <EnveloppeEpargne>[]
        : await AppDatabase.instance.obtenirEnveloppesEpargne(
            compteEpargneId: selection,
          );
    final nouveauxSoldes = <int, int>{};
    for (final enveloppe in nouvellesEnveloppes) {
      if (enveloppe.id != null) {
        nouveauxSoldes[enveloppe.id!] = await AppDatabase.instance
            .obtenirSoldeEnveloppeEpargne(enveloppe.id!);
      }
    }

    if (!mounted) return;
    setState(() {
      comptes = nouveauxComptes;
      compteId = selection;
      enveloppes = nouvellesEnveloppes;
      soldes = nouveauxSoldes;
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

  Future<void> ouvrirFormulaire({EnveloppeEpargne? enveloppe}) async {
    final selection = compteId;
    if (selection == null) return;

    final nomController = TextEditingController(text: enveloppe?.nom ?? '');
    final cibleController = TextEditingController(
      text: enveloppe?.montantCible?.toString() ?? '',
    );

    final resultat = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          enveloppe == null
              ? 'Nouvelle enveloppe d’épargne'
              : 'Modifier l’enveloppe',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomController,
                decoration: const InputDecoration(
                  labelText: 'Nom',
                  hintText: 'Voyage, Précaution, Famille…',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cibleController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Objectif (optionnel)',
                  suffixText: 'XPF',
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
              final cibleTexte = cibleController.text.replaceAll(' ', '').trim();
              final cible = cibleTexte.isEmpty ? null : int.tryParse(cibleTexte);
              if (nom.isEmpty ||
                  (cibleTexte.isNotEmpty && (cible == null || cible < 0))) {
                return;
              }

              final valeur = EnveloppeEpargne(
                id: enveloppe?.id,
                compteEpargneId: selection,
                nom: nom,
                soldeInitial: enveloppe?.soldeInitial ?? 0,
                montantCible: cible,
                echeance: enveloppe?.echeance,
              );
              if (enveloppe == null) {
                await AppDatabase.instance.ajouterEnveloppeEpargne(valeur);
              } else {
                await AppDatabase.instance.modifierEnveloppeEpargne(valeur);
              }
              if (dialogContext.mounted) Navigator.pop(dialogContext, true);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (resultat == true) await charger();
  }

  Future<void> supprimer(EnveloppeEpargne enveloppe) async {
    if (enveloppe.id == null) return;
    final confirmation = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer l’enveloppe ?'),
        content: Text('« ${enveloppe.nom} » sera supprimée si son solde est nul.'),
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
    );
    if (confirmation != true) return;

    try {
      await AppDatabase.instance.supprimerEnveloppeEpargne(enveloppe.id!);
      await charger();
    } on StateError catch (erreur) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(erreur.message.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = soldes.values.fold<int>(0, (somme, solde) => somme + solde);

    return Scaffold(
      appBar: AppBar(title: const Text('Épargne')),
      floatingActionButton: compteId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => ouvrirFormulaire(),
              icon: const Icon(Icons.add),
              label: const Text('Enveloppe'),
            ),
      body: chargement
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                if (comptes.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Crée d’abord un compte épargne dans l’onglet Comptes.',
                      ),
                    ),
                  )
                else ...[
                  if (comptes.length > 1)
                    DropdownButtonFormField<int>(
                      initialValue: compteId,
                      decoration: const InputDecoration(
                        labelText: 'Compte épargne affiché',
                      ),
                      items: comptes
                          .map(
                            (compte) => DropdownMenuItem(
                              value: compte.id,
                              child: Text(compte.nom),
                            ),
                          )
                          .toList(),
                      onChanged: (value) async {
                        setState(() => compteId = value);
                        await charger();
                      },
                    ),
                  const SizedBox(height: 16),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.savings_outlined),
                      title: const Text('Épargne affectée'),
                      trailing: Text(
                        formatXpf(total),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Enveloppes d’épargne',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (enveloppes.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('Aucune enveloppe d’épargne.'),
                      ),
                    ),
                  ...enveloppes.map((enveloppe) {
                    final solde = soldes[enveloppe.id] ?? 0;
                    final cible = enveloppe.montantCible;
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.savings_outlined),
                        ),
                        title: Text(enveloppe.nom),
                        subtitle: cible == null
                            ? null
                            : Text('Objectif : ${formatXpf(cible)}'),
                        trailing: Text(
                          formatXpf(solde),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onTap: () => ouvrirFormulaire(enveloppe: enveloppe),
                        onLongPress: () => supprimer(enveloppe),
                      ),
                    );
                  }),
                ],
              ],
            ),
    );
  }
}
