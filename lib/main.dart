import 'package:flutter/material.dart';
import 'screens/comptes_page.dart';

void main() {
  runApp(const GestionnaireBudgetApp());
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

  final List<Widget> _pages = const [
    AccueilPage(),
    ComptesPage(),
    PageVide(titre: 'Budgets', icone: Icons.pie_chart_outline),
    PageVide(titre: 'Profil', icone: Icons.person_outline),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_pageIndex],

      bottomNavigationBar: NavigationBar(
        selectedIndex: _pageIndex,
        onDestinationSelected: (index) {
          setState(() {
            _pageIndex = index;
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

// ======================================================
// ACCUEIL
// ======================================================

class AccueilPage extends StatelessWidget {
  const AccueilPage({super.key});

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

          // ARGENT LIBRE
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
                    '0 XPF',
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

          // SOLDES
          const Row(
            children: [
              Expanded(
                child: ResumeCarte(
                  titre: 'Solde courant',
                  valeur: '0 XPF',
                  icone: Icons.account_balance,
                ),
              ),

              SizedBox(width: 12),

              Expanded(
                child: ResumeCarte(
                  titre: 'Épargnes',
                  valeur: '0 XPF',
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

// ======================================================
// PETITES CARTES SOLDES
// ======================================================

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

// ======================================================
// ARGENT RÉSERVÉ
// ======================================================

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

// ======================================================
// PAGES EN CONSTRUCTION
// ======================================================

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
