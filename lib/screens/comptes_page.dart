import 'package:flutter/material.dart';

import '../database/app_database.dart';
import '../models/compte.dart';

class ComptesPage extends StatefulWidget {
  final VoidCallback? onChanged;

  const ComptesPage({super.key, this.onChanged});

  @override
  State<ComptesPage> createState() => _ComptesPageState();
}

class _ComptesPageState extends State<ComptesPage> {
  List<Compte> comptes = [];
  bool chargement = true;

  @override
  void initState() {
    super.initState();
    chargerComptes();
  }

  Future<void> chargerComptes() async {
    final resultat = await AppDatabase.instance.obtenirComptes();

    if (!mounted) return;

    setState(() {
      comptes = resultat;
      chargement = false;
    });
  }

  String formatXpf(int montant) {
    final texte = montant.abs().toString();
    final buffer = StringBuffer();

    for (int i = 0; i < texte.length; i++) {
      if (i > 0 && (texte.length - i) % 3 == 0) {
        buffer.write(' ');
      }
      buffer.write(texte[i]);
    }

    return '${montant < 0 ? '-' : ''}${buffer.toString()} XPF';
  }

  Future<void> ouvrirFormulaire({Compte? compte}) async {
    final nomController = TextEditingController(text: compte?.nom ?? '');

    final soldeController = TextEditingController(
      text: compte?.solde.toString() ?? '',
    );

    TypeCompte type = compte?.type ?? TypeCompte.courant;

    final resultat = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                compte == null ? 'Ajouter un compte' : 'Modifier le compte',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nomController,
                      decoration: const InputDecoration(
                        labelText: 'Nom du compte',
                        hintText: 'Ex. SGCB',
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<TypeCompte>(
                      initialValue: type,
                      decoration: const InputDecoration(
                        labelText: 'Type de compte',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: TypeCompte.courant,
                          child: Text('Compte courant'),
                        ),
                        DropdownMenuItem(
                          value: TypeCompte.epargne,
                          child: Text('Épargne'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            type = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: soldeController,
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Solde actuel',
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
                    final solde = int.tryParse(
                      soldeController.text
                          .replaceAll(' ', '')
                          .replaceAll(',', ''),
                    );

                    if (nom.isEmpty || solde == null) {
                      return;
                    }

                    final nouveauCompte = Compte(
                      id: compte?.id,
                      nom: nom,
                      type: type,
                      solde: solde,
                    );

                    if (compte == null) {
                      await AppDatabase.instance.ajouterCompte(nouveauCompte);
                    } else {
                      await AppDatabase.instance.modifierCompte(nouveauCompte);
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
      },
    );

    if (resultat == true) {
      await chargerComptes();
      widget.onChanged?.call();
    }
  }

  Future<void> supprimer(Compte compte) async {
    final confirmation = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Supprimer le compte ?'),
          content: Text('Le compte "${compte.nom}" sera supprimé.'),
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

    if (confirmation == true && compte.id != null) {
      await AppDatabase.instance.supprimerCompte(compte.id!);
      await chargerComptes();
      widget.onChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalCourant = comptes
        .where((c) => c.type == TypeCompte.courant)
        .fold<int>(0, (total, c) => total + c.solde);

    final totalEpargne = comptes
        .where((c) => c.type == TypeCompte.epargne)
        .fold<int>(0, (total, c) => total + c.solde);

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(title: const Text('Comptes')),
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
                  Row(
                    children: [
                      Expanded(
                        child: _TotalCard(
                          titre: 'Courant',
                          montant: formatXpf(totalCourant),
                          icone: Icons.account_balance,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _TotalCard(
                          titre: 'Épargne',
                          montant: formatXpf(totalEpargne),
                          icone: Icons.savings_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (comptes.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Aucun compte enregistré.\n\n'
                          'Appuie sur « Ajouter » pour créer ton premier compte.',
                        ),
                      ),
                    ),
                  ...comptes.map(
                    (compte) => Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Icon(
                            compte.type == TypeCompte.courant
                                ? Icons.account_balance
                                : Icons.savings_outlined,
                          ),
                        ),
                        title: Text(
                          compte.nom,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          compte.type == TypeCompte.courant
                              ? 'Compte courant'
                              : 'Épargne',
                        ),
                        trailing: Text(
                          formatXpf(compte.solde),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onTap: () => ouvrirFormulaire(compte: compte),
                        onLongPress: () => supprimer(compte),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  final String titre;
  final String montant;
  final IconData icone;

  const _TotalCard({
    required this.titre,
    required this.montant,
    required this.icone,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icone),
            const SizedBox(height: 10),
            Text(titre),
            const SizedBox(height: 4),
            Text(
              montant,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
