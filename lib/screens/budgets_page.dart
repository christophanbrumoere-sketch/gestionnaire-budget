import 'package:flutter/material.dart';

import '../database/app_database.dart';
import '../models/budget.dart';

class BudgetsPage extends StatefulWidget {
  final VoidCallback? onChanged;

  const BudgetsPage({super.key, this.onChanged});

  @override
  State<BudgetsPage> createState() => _BudgetsPageState();
}

class _BudgetsPageState extends State<BudgetsPage> {
  List<Budget> budgets = [];
  bool chargement = true;

  @override
  void initState() {
    super.initState();
    chargerBudgets();
  }

  String formatXpf(int montant) {
    final texte = montant.toString();
    final buffer = StringBuffer();

    for (int i = 0; i < texte.length; i++) {
      if (i > 0 && (texte.length - i) % 3 == 0) {
        buffer.write(' ');
      }
      buffer.write(texte[i]);
    }

    return '${buffer.toString()} XPF';
  }

  Future<void> chargerBudgets() async {
    final resultat = await AppDatabase.instance.obtenirBudgets();

    if (!mounted) return;

    setState(() {
      budgets = resultat;
      chargement = false;
    });
  }

  Future<void> ouvrirFormulaire({Budget? budget}) async {
    final nomController = TextEditingController(text: budget?.nom ?? '');

    final montantController = TextEditingController(
      text: budget?.montantMensuel.toString() ?? '',
    );

    final resultat = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            budget == null ? 'Ajouter un budget' : 'Modifier le budget',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nomController,
                  decoration: const InputDecoration(
                    labelText: 'Nom du budget',
                    hintText: 'Ex. Courses',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: montantController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Budget mensuel',
                    suffixText: 'XPF',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () async {
                final nom = nomController.text.trim();

                final montant = int.tryParse(
                  montantController.text
                      .replaceAll(' ', '')
                      .replaceAll(',', ''),
                );

                if (nom.isEmpty || montant == null || montant < 0) {
                  return;
                }

                final nouveauBudget = Budget(
                  id: budget?.id,
                  nom: nom,
                  montantMensuel: montant,
                );

                if (budget == null) {
                  await AppDatabase.instance.ajouterBudget(nouveauBudget);
                } else {
                  await AppDatabase.instance.modifierBudget(nouveauBudget);
                }

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('Enregistrer'),
            ),
          ],
        );
      },
    );

    if (resultat == true) {
      await chargerBudgets();
      widget.onChanged?.call();
    }
  }

  Future<void> supprimer(Budget budget) async {
    final confirmation = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Supprimer le budget ?'),
          content: Text('Le budget "${budget.nom}" sera supprimé.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );

    if (confirmation == true && budget.id != null) {
      await AppDatabase.instance.supprimerBudget(budget.id!);
      await chargerBudgets();
      widget.onChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = budgets.fold<int>(
      0,
      (somme, budget) => somme + budget.montantMensuel,
    );

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(title: const Text('Budgets')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => ouvrirFormulaire(),
          icon: const Icon(Icons.add),
          label: const Text('Ajouter'),
        ),
        body: chargement
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('BUDGET MENSUEL TOTAL'),
                          const SizedBox(height: 8),
                          Text(
                            formatXpf(total),
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  if (budgets.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Aucun budget enregistré.\n\n'
                          'Ajoute par exemple Courses, Carburant ou Loisirs.',
                        ),
                      ),
                    ),

                  ...budgets.map(
                    (budget) => Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.pie_chart_outline),
                        ),
                        title: Text(
                          budget.nom,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: const Text('Budget mensuel'),
                        trailing: Text(
                          formatXpf(budget.montantMensuel),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onTap: () => ouvrirFormulaire(budget: budget),
                        onLongPress: () => supprimer(budget),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
