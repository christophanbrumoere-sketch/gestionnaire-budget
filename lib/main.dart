import 'package:flutter/material.dart';

import 'database/app_database.dart';
import 'models/compte.dart';
import 'screens/comptes_page.dart';

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
      const PageVide(titre: 'Budgets', icone: Icons.pie_chart_outline),
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
              onPressed: () {},
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
  int soldeCourant = 0;
  int totalEpargne = 0;
  bool chargement = true;

  @override
  void initState() {
    super.initState();
    chargerSoldes();
  }

  Future<void> chargerSoldes() async {
    final comptes = await AppDatabase.instance.obtenirComptes();

    final courant = comptes
        .where((c) => c.type == TypeCompte.courant)
        .fold<int>(0, (total, compte) => total + compte.solde);

    final epargne = comptes
        .where((c) => c.type == TypeCompte.epargne)
        .fold<int>(0, (total, compte) => total + compte.solde);

    if (!mounted) return;

    setState(() {
      soldeCourant = courant;
      totalEpargne = epargne;
      chargement = false;
    });
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
          const Text(
            'Août 2026',
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
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
                    formatXpf(soldeCourant),
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
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
                  valeur: chargement ? '...' : formatXpf(soldeCourant),
                  icone: Icons.account_balance,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ResumeCarte(
                  titre: 'Épargnes',
                  valeur: chargement ? '...' : formatXpf(totalEpargne),
                  icone: Icons.savings_outlined,
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

          const LigneReservee(
            titre: 'Charges fixes restantes',
            montant: '0 XPF',
          ),
          const LigneReservee(
            titre: 'Budgets restant à consommer',
            montant: '0 XPF',
          ),
          const LigneReservee(titre: 'Épargne programmée', montant: '0 XPF'),

          const SizedBox(height: 28),

          Text(
            'Budgets',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          const Card(
            elevation: 0,
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('Aucun budget configuré pour le moment.'),
            ),
          ),
        ],
      ),
    );
  }
}

class ResumeCarte extends StatelessWidget {
  final String titre;
  final String valeur;
  final IconData icone;

  const ResumeCarte({
    super.key,
    required this.titre,
    required this.valeur,
    required this.icone,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icone),
            const SizedBox(height: 14),
            Text(titre, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 5),
            Text(
              valeur,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
          ],
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
