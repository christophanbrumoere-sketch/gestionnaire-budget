import 'package:flutter/material.dart';

import 'database/app_database.dart';
import 'models/compte.dart';
import 'models/enveloppe_budget.dart';
import 'models/operation_resume.dart';
import 'models/resume_budget.dart';
import 'screens/comptes_page.dart';
import 'screens/budgets_page.dart';
import 'screens/epargne_page.dart';
import 'screens/operation_form_page.dart';
import 'services/budget_service.dart';

void main() {
  runApp(const GestionnaireBudgetApp());
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

class GestionnaireBudgetApp extends StatelessWidget {
  const GestionnaireBudgetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Gestionnaire Budget',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D5B)),
        scaffoldBackgroundColor: const Color(0xFFF5F7F5),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D5B),
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _pageIndex = 0;
  int _actualisation = 0;

  void actualiser() {
    setState(() {
      _actualisation++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      AccueilPage(key: ValueKey(_actualisation)),
      ComptesPage(onChanged: actualiser),
      BudgetsPage(onChanged: actualiser),
      const PageVide(titre: 'Profil', icone: Icons.person_outline),
    ];

    return Scaffold(
      body: pages[_pageIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _pageIndex,
        onDestinationSelected: (index) {
          setState(() {
            _pageIndex = index;

            if (index == 0) {
              _actualisation++;
            }
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            label: 'Comptes',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline),
            label: 'Budgets',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profil',
          ),
        ],
      ),
      floatingActionButton: _pageIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () async {
                final resultat = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const OperationFormPage(),
                  ),
                );
                if (resultat == true) actualiser();
              },
              icon: const Icon(Icons.add),
              label: const Text('Opération'),
            )
          : null,
    );
  }
}

class AccueilPage extends StatefulWidget {
  const AccueilPage({super.key});

  @override
  State<AccueilPage> createState() => _AccueilPageState();
}

class _AccueilPageState extends State<AccueilPage> {
  final BudgetService _budgetService = BudgetService(
    database: AppDatabase.instance,
  );

  List<Compte> comptesCourants = [];
  int? compteCourantId;
  ResumeBudget resume = ResumeBudget.vide;
  List<OperationResume> dernieresOperations = [];
  String libellePeriode = 'Période en cours';
  bool chargement = true;

  @override
  void initState() {
    super.initState();
    chargerResume();
  }

  Future<void> chargerResume() async {
    final comptes = await AppDatabase.instance.obtenirComptes(
      type: TypeCompte.courant,
    );
    var selection = compteCourantId;
    if (!comptes.any((c) => c.id == selection)) {
      selection = comptes.isEmpty ? null : comptes.first.id;
    }

    final nouveauResume = selection == null
        ? ResumeBudget.vide
        : await _budgetService.chargerResume(compteCourantIds: [selection]);
    final periode = await AppDatabase.instance.obtenirPeriodeActive();
    final operations = selection == null || periode?.id == null
        ? <OperationResume>[]
        : await AppDatabase.instance.obtenirDernieresOperations(
            periodeId: periode!.id!,
            compteCourantId: selection,
          );

    if (!mounted) return;

    setState(() {
      comptesCourants = comptes;
      compteCourantId = selection;
      resume = nouveauResume;
      dernieresOperations = operations;
      libellePeriode = periode == null
          ? 'Aucune période active'
          : 'Depuis le ${_formatDate(periode.dateDebut)}';
      chargement = false;
    });
  }

  String _formatDate(DateTime date) {
    final jour = date.day.toString().padLeft(2, '0');
    final mois = date.month.toString().padLeft(2, '0');
    return '$jour/$mois/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
        children: [
          Text(
            'Mon budget',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            libellePeriode,
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (comptesCourants.length > 1) ...[
            const SizedBox(height: 14),
            DropdownButtonFormField<int>(
              initialValue: compteCourantId,
              decoration: const InputDecoration(
                labelText: 'Compte courant affiché',
              ),
              items: comptesCourants
                  .map(
                    (compte) => DropdownMenuItem(
                      value: compte.id,
                      child: Text(compte.nom),
                    ),
                  )
                  .toList(),
              onChanged: (value) async {
                setState(() {
                  compteCourantId = value;
                  chargement = true;
                });
                await chargerResume();
              },
            ),
          ],
          const SizedBox(height: 24),

          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ARGENT LIBRE',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    chargement ? '...' : formatXpf(resume.argentLibre),
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: resume.argentLibre < 0
                          ? Theme.of(context).colorScheme.error
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Somme réellement disponible jusqu'au prochain salaire",
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: ResumeCarte(
                  titre: 'Solde courant',
                  valeur: chargement ? '...' : formatXpf(resume.soldeCourant),
                  icone: Icons.account_balance,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ResumeCarte(
                  titre: 'Épargne',
                  valeur: chargement ? '...' : formatXpf(resume.totalEpargne),
                  icone: Icons.savings_outlined,
                  onTap: () async {
                    await Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EpargnePage(),
                      ),
                    );
                    await chargerResume();
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),

          Text(
            'Argent réservé',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          LigneReservee(
            titre: 'Charges fixes restantes',
            montant: chargement
                ? '...'
                : formatXpf(resume.chargesFixesRestantes),
          ),
          LigneReservee(
            titre: 'Charges variables restantes',
            montant: chargement
                ? '...'
                : formatXpf(resume.chargesVariablesRestantes),
          ),
          LigneReservee(
            titre: 'Épargne programmée',
            montant: chargement
                ? '...'
                : formatXpf(resume.epargneProgrammeeRestante),
          ),

          const SizedBox(height: 28),

          Text(
            'Enveloppes',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          if (!chargement && resume.enveloppes.isEmpty)
            const Card(
              elevation: 0,
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text('Aucune enveloppe définie pour cette période.'),
              ),
            ),
          ...resume.enveloppes.map(
            (enveloppe) => Card(
              elevation: 0,
              color: enveloppe.montantRestant < 0
                  ? Theme.of(context).colorScheme.errorContainer
                  : null,
              child: ListTile(
                leading: Icon(
                  enveloppe.type == TypeEnveloppeBudget.epargne
                      ? Icons.savings_outlined
                      : Icons.pie_chart_outline,
                ),
                title: Text(enveloppe.nom),
                subtitle: Text(
                  'Utilisé : ${formatXpf(enveloppe.montantUtilise)} / ${formatXpf(enveloppe.montantPrevu)}',
                ),
                trailing: Text(
                  formatXpf(enveloppe.montantRestant),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: enveloppe.montantRestant < 0
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 28),
          Text(
            'Dernières opérations',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          if (!chargement && dernieresOperations.isEmpty)
            const Card(
              elevation: 0,
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text('Aucune opération sur cette période.'),
              ),
            ),
          ...dernieresOperations.map((operation) {
            final positive = operation.montantSigne >= 0;
            return Card(
              elevation: 0,
              child: ListTile(
                leading: Icon(
                  positive ? Icons.south_west : Icons.north_east,
                  color: positive ? Colors.green : Colors.red,
                ),
                title: Text(operation.libelle),
                subtitle: Text(_formatDate(operation.date)),
                trailing: Text(
                  formatXpf(operation.montantSigne),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: positive ? Colors.green : Colors.red,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class ResumeCarte extends StatelessWidget {
  final String titre;
  final String valeur;
  final IconData icone;
  final VoidCallback? onTap;

  const ResumeCarte({
    super.key,
    required this.titre,
    required this.valeur,
    required this.icone,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icone),
              const SizedBox(height: 14),
              Text(
                titre,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                valeur,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LigneReservee extends StatelessWidget {
  final String titre;
  final String montant;

  const LigneReservee({super.key, required this.titre, required this.montant});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: ListTile(
        title: Text(titre),
        trailing: Text(
          montant,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class PageVide extends StatelessWidget {
  final String titre;
  final IconData icone;

  const PageVide({super.key, required this.titre, required this.icone});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 55),
            const SizedBox(height: 15),
            Text(
              titre,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Module en cours de développement'),
          ],
        ),
      ),
    );
  }
}
