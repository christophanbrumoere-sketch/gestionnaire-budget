import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/charge_fixe.dart';
import '../models/compte.dart';
import '../models/enveloppe_budget.dart';
import '../models/enveloppe_epargne.dart';
import '../models/operation_budget.dart';
import '../models/operation_resume.dart';
import '../models/periode_budget.dart';
import '../services/operation_rules.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  static const int _version = 5;
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _ouvrirDatabase();
    return _database!;
  }

  Future<Database> _ouvrirDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'gestionnaire_budget.db');

    return openDatabase(
      path,
      version: _version,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _creerSchemaV5(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _migrerVersV5(db);
      },
    );
  }

  Future<void> _creerSchemaV5(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS comptes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL,
        type TEXT NOT NULL CHECK(type IN ('courant', 'epargne')),
        solde_initial INTEGER NOT NULL DEFAULT 0,
        actif INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS periodes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date_debut TEXT NOT NULL,
        date_fin TEXT,
        est_active INTEGER NOT NULL DEFAULT 1,
        creee_le TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS soldes_ouverture_periode (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        periode_id INTEGER NOT NULL,
        compte_id INTEGER NOT NULL,
        montant INTEGER NOT NULL,
        UNIQUE(periode_id, compte_id),
        FOREIGN KEY(periode_id) REFERENCES periodes(id) ON DELETE CASCADE,
        FOREIGN KEY(compte_id) REFERENCES comptes(id) ON DELETE RESTRICT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS charges_fixes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        compte_id INTEGER NOT NULL,
        nom TEXT NOT NULL,
        montant_reference INTEGER NOT NULL CHECK(montant_reference >= 0),
        jour_prevu INTEGER CHECK(jour_prevu IS NULL OR (jour_prevu BETWEEN 1 AND 31)),
        actif INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY(compte_id) REFERENCES comptes(id) ON DELETE RESTRICT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS charges_fixes_periode (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        periode_id INTEGER NOT NULL,
        charge_fixe_id INTEGER NOT NULL,
        montant_prevu INTEGER NOT NULL CHECK(montant_prevu >= 0),
        payee INTEGER NOT NULL DEFAULT 0,
        montant_reel INTEGER CHECK(montant_reel IS NULL OR montant_reel >= 0),
        date_paiement TEXT,
        UNIQUE(periode_id, charge_fixe_id),
        FOREIGN KEY(periode_id) REFERENCES periodes(id) ON DELETE CASCADE,
        FOREIGN KEY(charge_fixe_id) REFERENCES charges_fixes(id) ON DELETE RESTRICT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS enveloppes_budget (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        compte_id INTEGER NOT NULL,
        nom TEXT NOT NULL,
        type TEXT NOT NULL CHECK(type IN ('depense', 'epargne')),
        montant_reference INTEGER NOT NULL CHECK(montant_reference >= 0),
        icone TEXT,
        actif INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY(compte_id) REFERENCES comptes(id) ON DELETE RESTRICT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS enveloppes_budget_periode (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        periode_id INTEGER NOT NULL,
        enveloppe_budget_id INTEGER NOT NULL,
        montant_prevu INTEGER NOT NULL CHECK(montant_prevu >= 0),
        UNIQUE(periode_id, enveloppe_budget_id),
        FOREIGN KEY(periode_id) REFERENCES periodes(id) ON DELETE CASCADE,
        FOREIGN KEY(enveloppe_budget_id) REFERENCES enveloppes_budget(id) ON DELETE RESTRICT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS enveloppes_epargne (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        compte_epargne_id INTEGER NOT NULL,
        nom TEXT NOT NULL,
        solde_initial INTEGER NOT NULL DEFAULT 0 CHECK(solde_initial >= 0),
        montant_cible INTEGER CHECK(montant_cible IS NULL OR montant_cible >= 0),
        echeance TEXT,
        actif INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY(compte_epargne_id) REFERENCES comptes(id) ON DELETE RESTRICT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS operations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        periode_id INTEGER NOT NULL,
        date_operation TEXT NOT NULL,
        libelle TEXT NOT NULL,
        type TEXT NOT NULL,
        montant INTEGER NOT NULL CHECK(montant > 0),
        compte_source_id INTEGER,
        compte_destination_id INTEGER,
        enveloppe_budget_id INTEGER,
        note TEXT,
        creee_le TEXT NOT NULL,
        FOREIGN KEY(periode_id) REFERENCES periodes(id) ON DELETE RESTRICT,
        FOREIGN KEY(compte_source_id) REFERENCES comptes(id) ON DELETE RESTRICT,
        FOREIGN KEY(compte_destination_id) REFERENCES comptes(id) ON DELETE RESTRICT,
        FOREIGN KEY(enveloppe_budget_id) REFERENCES enveloppes_budget(id) ON DELETE RESTRICT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS affectations_epargne (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        operation_id INTEGER NOT NULL,
        enveloppe_epargne_id INTEGER NOT NULL,
        montant INTEGER NOT NULL CHECK(montant != 0),
        FOREIGN KEY(operation_id) REFERENCES operations(id) ON DELETE CASCADE,
        FOREIGN KEY(enveloppe_epargne_id) REFERENCES enveloppes_epargne(id) ON DELETE RESTRICT
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_operations_periode ON operations(periode_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_operations_enveloppe ON operations(enveloppe_budget_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_affectations_enveloppe ON affectations_epargne(enveloppe_epargne_id)',
    );
  }

  Future<void> _migrerVersV5(Database db) async {
    await _creerSchemaV5(db);
    await _assurerColonnesCompte(db);
    await _migrerAnciensBudgets(db);
    await _creerPeriodeMigrationSiNecessaire(db);
  }

  Future<bool> _tableExiste(DatabaseExecutor db, String table) async {
    final result = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      [table],
    );
    return result.isNotEmpty;
  }

  Future<Set<String>> _colonnesTable(
    DatabaseExecutor db,
    String table,
  ) async {
    if (!await _tableExiste(db, table)) return {};
    final rows = await db.rawQuery('PRAGMA table_info($table)');
    return rows.map((row) => row['name'] as String).toSet();
  }

  Future<void> _assurerColonnesCompte(Database db) async {
    final colonnes = await _colonnesTable(db, 'comptes');

    if (!colonnes.contains('solde_initial')) {
      await db.execute(
        'ALTER TABLE comptes ADD COLUMN solde_initial INTEGER NOT NULL DEFAULT 0',
      );
      if (colonnes.contains('solde')) {
        await db.execute('UPDATE comptes SET solde_initial = solde');
      }
    }

    if (!colonnes.contains('actif')) {
      await db.execute(
        'ALTER TABLE comptes ADD COLUMN actif INTEGER NOT NULL DEFAULT 1',
      );
    }
  }

  Future<void> _migrerAnciensBudgets(Database db) async {
    if (!await _tableExiste(db, 'budgets')) return;

    final ancienNombre = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM budgets'),
        ) ??
        0;
    final nouveauNombre = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM enveloppes_budget'),
        ) ??
        0;

    if (ancienNombre == 0 || nouveauNombre > 0) return;

    final comptesCourants = await db.query(
      'comptes',
      columns: ['id'],
      where: "type = 'courant'",
      orderBy: 'id ASC',
      limit: 1,
    );
    if (comptesCourants.isEmpty) return;

    final compteId = comptesCourants.first['id'] as int;
    final budgets = await db.query('budgets', orderBy: 'id ASC');

    for (final budget in budgets) {
      await db.insert('enveloppes_budget', {
        'compte_id': compteId,
        'nom': budget['nom'],
        'type': TypeEnveloppeBudget.depense.name,
        'montant_reference': budget['montant_mensuel'],
        'actif': 1,
      });
    }
  }

  Future<void> _creerPeriodeMigrationSiNecessaire(Database db) async {
    final active = await db.query(
      'periodes',
      columns: ['id'],
      where: 'est_active = 1',
      limit: 1,
    );

    final int periodeId;
    if (active.isEmpty) {
      final maintenant = DateTime.now();
      periodeId = await db.insert('periodes', {
        'date_debut': maintenant.toIso8601String(),
        'date_fin': null,
        'est_active': 1,
        'creee_le': maintenant.toIso8601String(),
      });
    } else {
      periodeId = active.first['id'] as int;
    }

    final comptes = await db.query(
      'comptes',
      columns: ['id', 'solde_initial'],
      where: 'actif = 1',
    );
    for (final compte in comptes) {
      await db.insert('soldes_ouverture_periode', {
        'periode_id': periodeId,
        'compte_id': compte['id'],
        'montant': compte['solde_initial'] ?? 0,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    await _creerSnapshotsPeriode(db, periodeId);
  }

  Future<void> _creerSnapshotsPeriode(
    DatabaseExecutor db,
    int periodeId,
  ) async {
    final charges = await db.query(
      'charges_fixes',
      where: 'actif = 1',
    );
    for (final charge in charges) {
      await db.insert('charges_fixes_periode', {
        'periode_id': periodeId,
        'charge_fixe_id': charge['id'],
        'montant_prevu': charge['montant_reference'],
        'payee': 0,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    final enveloppes = await db.query(
      'enveloppes_budget',
      where: 'actif = 1',
    );
    for (final enveloppe in enveloppes) {
      await db.insert('enveloppes_budget_periode', {
        'periode_id': periodeId,
        'enveloppe_budget_id': enveloppe['id'],
        'montant_prevu': enveloppe['montant_reference'],
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<PeriodeBudget?> obtenirPeriodeActive() async {
    final db = await database;
    final rows = await db.query(
      'periodes',
      where: 'est_active = 1',
      orderBy: 'id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return PeriodeBudget.fromMap(rows.first);
  }

  Future<int> ouvrirNouvellePeriode({required DateTime dateDebut}) async {
    final db = await database;
    return db.transaction(
      (txn) => _ouvrirNouvellePeriodeDansTransaction(txn, dateDebut),
    );
  }

  Future<int> enregistrerSalaireEtOuvrirPeriode({
    required int compteDestinationId,
    required int montant,
    required DateTime date,
    String libelle = 'Salaire',
  }) async {
    if (montant <= 0) throw ArgumentError('Le salaire doit etre positif.');
    if (libelle.trim().isEmpty) {
      throw ArgumentError('Le libelle est obligatoire.');
    }

    final db = await database;
    return db.transaction((txn) async {
      await _verifierCompteType(txn, compteDestinationId, TypeCompte.courant);
      final periodeId = await _ouvrirNouvellePeriodeDansTransaction(txn, date);
      return txn.insert('operations', {
        'periode_id': periodeId,
        'date_operation': date.toIso8601String(),
        'libelle': libelle.trim(),
        'type': TypeOperationBudget.salaire.name,
        'montant': montant,
        'compte_source_id': null,
        'compte_destination_id': compteDestinationId,
        'enveloppe_budget_id': null,
        'note': null,
        'creee_le': DateTime.now().toIso8601String(),
      });
    });
  }

  Future<int> _ouvrirNouvellePeriodeDansTransaction(
    DatabaseExecutor db,
    DateTime dateDebut,
  ) async {
    final active = await db.query(
      'periodes',
      where: 'est_active = 1',
      orderBy: 'id DESC',
      limit: 1,
    );
    final anciennePeriodeId = active.isEmpty ? null : active.first['id'] as int;

    final comptes = await db.query(
      'comptes',
      columns: ['id', 'type', 'solde_initial'],
      where: 'actif = 1',
      orderBy: 'id ASC',
    );

    final soldesReportes = <int, int>{};
    for (final compte in comptes) {
      final id = compte['id'] as int;
      if (anciennePeriodeId == null) {
        soldesReportes[id] = (compte['solde_initial'] as int?) ?? 0;
      } else {
        soldesReportes[id] = await _calculerSoldeComptePeriode(
          db,
          periodeId: anciennePeriodeId,
          compteId: id,
          typeCompte: TypeCompte.values.byName(compte['type'] as String),
        );
      }
    }

    if (anciennePeriodeId != null) {
      await db.update(
        'periodes',
        {
          'date_fin': dateDebut
              .subtract(const Duration(milliseconds: 1))
              .toIso8601String(),
          'est_active': 0,
        },
        where: 'id = ?',
        whereArgs: [anciennePeriodeId],
      );
    }

    final periodeId = await db.insert('periodes', {
      'date_debut': dateDebut.toIso8601String(),
      'date_fin': null,
      'est_active': 1,
      'creee_le': DateTime.now().toIso8601String(),
    });

    for (final entry in soldesReportes.entries) {
      await db.insert('soldes_ouverture_periode', {
        'periode_id': periodeId,
        'compte_id': entry.key,
        'montant': entry.value,
      });
    }
    await _creerSnapshotsPeriode(db, periodeId);
    return periodeId;
  }

  Future<int> _calculerSoldeComptePeriode(
    DatabaseExecutor db, {
    required int periodeId,
    required int compteId,
    required TypeCompte typeCompte,
  }) async {
    final ouvertureRows = await db.query(
      'soldes_ouverture_periode',
      columns: ['montant'],
      where: 'periode_id = ? AND compte_id = ?',
      whereArgs: [periodeId, compteId],
      limit: 1,
    );
    final ouverture = ouvertureRows.isEmpty
        ? 0
        : ouvertureRows.first['montant'] as int;

    final mouvements = await db.rawQuery('''
      SELECT
        COALESCE(SUM(CASE WHEN compte_destination_id = ? THEN montant ELSE 0 END), 0)
        - COALESCE(SUM(CASE WHEN compte_source_id = ? THEN montant ELSE 0 END), 0)
        AS net
      FROM operations
      WHERE periode_id = ?
    ''', [compteId, compteId, periodeId]);
    final net = (mouvements.first['net'] as num?)?.toInt() ?? 0;

    var chargesPayees = 0;
    if (typeCompte == TypeCompte.courant) {
      final chargesRows = await db.rawQuery('''
        SELECT COALESCE(SUM(
          CASE WHEN cfp.payee = 1
            THEN COALESCE(cfp.montant_reel, cfp.montant_prevu)
            ELSE 0
          END
        ), 0) AS total
        FROM charges_fixes_periode cfp
        JOIN charges_fixes cf ON cf.id = cfp.charge_fixe_id
        WHERE cfp.periode_id = ? AND cf.compte_id = ?
      ''', [periodeId, compteId]);
      chargesPayees = (chargesRows.first['total'] as num?)?.toInt() ?? 0;
    }

    return ouverture + net - chargesPayees;
  }

  // ==========================
  // COMPTES
  // ==========================

  Future<int> ajouterCompte(
    Compte compte, {
    String? enveloppeEpargneInitiale,
  }) async {
    final db = await database;

    return db.transaction((txn) async {
      final nomEnveloppeInitiale = enveloppeEpargneInitiale?.trim() ?? '';
      if (compte.type == TypeCompte.epargne &&
          compte.soldeInitial != 0 &&
          nomEnveloppeInitiale.isEmpty) {
        throw ArgumentError(
          "Le solde initial d'un compte epargne doit etre entierement affecte.",
        );
      }
      final data = compte.toMap()..remove('id');
      final id = await txn.insert('comptes', data);

      if (compte.type == TypeCompte.epargne &&
          nomEnveloppeInitiale.isNotEmpty) {
        await txn.insert('enveloppes_epargne', {
          'compte_epargne_id': id,
          'nom': nomEnveloppeInitiale,
          'solde_initial': compte.soldeInitial,
          'montant_cible': null,
          'echeance': null,
          'actif': 1,
        });
      }

      final periode = await txn.query(
        'periodes',
        columns: ['id'],
        where: 'est_active = 1',
        orderBy: 'id DESC',
        limit: 1,
      );
      if (periode.isNotEmpty) {
        await txn.insert('soldes_ouverture_periode', {
          'periode_id': periode.first['id'],
          'compte_id': id,
          'montant': compte.soldeInitial,
        });
      }

      return id;
    });
  }

  Future<List<Compte>> obtenirComptes({TypeCompte? type}) async {
    final db = await database;
    final result = await db.query(
      'comptes',
      where: type == null ? 'actif = 1' : 'actif = 1 AND type = ?',
      whereArgs: type == null ? null : [type.name],
      orderBy: 'id ASC',
    );
    return result.map(Compte.fromMap).toList();
  }

  Future<int> obtenirSoldeCompteActuel(int compteId) async {
    final db = await database;
    final compteRows = await db.query(
      'comptes',
      columns: ['type', 'solde_initial'],
      where: 'id = ?',
      whereArgs: [compteId],
      limit: 1,
    );
    if (compteRows.isEmpty) return 0;

    final periodeId = await _periodeActiveId(db);
    if (periodeId == null) {
      return (compteRows.first['solde_initial'] as int?) ?? 0;
    }

    return _calculerSoldeComptePeriode(
      db,
      periodeId: periodeId,
      compteId: compteId,
      typeCompte: TypeCompte.values.byName(
        compteRows.first['type'] as String,
      ),
    );
  }

  Future<int> modifierCompte(Compte compte) async {
    final db = await database;
    return db.transaction((txn) async {
      final data = compte.toMap()..remove('id');
      final resultat = await txn.update(
        'comptes',
        data,
        where: 'id = ?',
        whereArgs: [compte.id],
      );
      final periodeId = await _periodeActiveId(txn);
      if (periodeId != null) {
        await txn.update(
          'soldes_ouverture_periode',
          {'montant': compte.soldeInitial},
          where: 'periode_id = ? AND compte_id = ?',
          whereArgs: [periodeId, compte.id],
        );
      }
      return resultat;
    });
  }

  Future<int> supprimerCompte(int id) async {
    final db = await database;
    return db.update(
      'comptes',
      {'actif': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==========================
  // CHARGES FIXES
  // ==========================

  Future<List<ChargeFixe>> obtenirChargesFixes({int? compteId}) async {
    final db = await database;
    final rows = await db.query(
      'charges_fixes',
      where: compteId == null ? 'actif = 1' : 'actif = 1 AND compte_id = ?',
      whereArgs: compteId == null ? null : [compteId],
      orderBy: 'jour_prevu ASC, id ASC',
    );
    return rows.map(ChargeFixe.fromMap).toList();
  }

  Future<int> ajouterChargeFixe(ChargeFixe charge) async {
    final db = await database;
    return db.transaction((txn) async {
      await _verifierCompteType(txn, charge.compteId, TypeCompte.courant);
      final data = charge.toMap()..remove('id');
      final id = await txn.insert('charges_fixes', data);
      final periodeId = await _periodeActiveId(txn);
      if (periodeId != null) {
        await txn.insert('charges_fixes_periode', {
          'periode_id': periodeId,
          'charge_fixe_id': id,
          'montant_prevu': charge.montantReference,
          'payee': 0,
        });
      }
      return id;
    });
  }

  Future<int> modifierChargeFixe(ChargeFixe charge) async {
    final db = await database;
    return db.transaction((txn) async {
      await _verifierCompteType(txn, charge.compteId, TypeCompte.courant);
      final data = charge.toMap()..remove('id');
      final resultat = await txn.update(
        'charges_fixes',
        data,
        where: 'id = ?',
        whereArgs: [charge.id],
      );
      final periodeId = await _periodeActiveId(txn);
      if (periodeId != null) {
        await txn.update(
          'charges_fixes_periode',
          {'montant_prevu': charge.montantReference},
          where: 'periode_id = ? AND charge_fixe_id = ? AND payee = 0',
          whereArgs: [periodeId, charge.id],
        );
      }
      return resultat;
    });
  }

  Future<int> supprimerChargeFixe(int id) async {
    final db = await database;
    return db.update(
      'charges_fixes',
      {'actif': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> marquerChargeFixePayee({
    required int chargeFixePeriodeId,
    required bool payee,
    int? montantReel,
    DateTime? datePaiement,
  }) async {
    final db = await database;
    await db.update(
      'charges_fixes_periode',
      {
        'payee': payee ? 1 : 0,
        'montant_reel': payee ? montantReel : null,
        'date_paiement': payee ? datePaiement?.toIso8601String() : null,
      },
      where: 'id = ?',
      whereArgs: [chargeFixePeriodeId],
    );
  }

  Future<List<ChargeFixePeriode>> obtenirChargesFixesPeriode({
    required int periodeId,
    required Iterable<int> compteIds,
  }) async {
    final ids = compteIds.toList();
    if (ids.isEmpty) return [];
    final db = await database;
    final marqueurs = _marqueurs(ids.length);
    final rows = await db.rawQuery('''
      SELECT cfp.id, cfp.charge_fixe_id, cf.nom, cfp.montant_prevu,
             cfp.payee, cfp.montant_reel, cfp.date_paiement
      FROM charges_fixes_periode cfp
      JOIN charges_fixes cf ON cf.id = cfp.charge_fixe_id
      WHERE cfp.periode_id = ? AND cf.compte_id IN ($marqueurs)
      ORDER BY cf.jour_prevu ASC, cf.id ASC
    ''', [periodeId, ...ids]);
    return rows.map(ChargeFixePeriode.fromMap).toList();
  }

  // ==========================
  // ENVELOPPES DU COMPTE COURANT
  // ==========================

  Future<List<EnveloppeBudget>> obtenirEnveloppesBudget({
    int? compteId,
  }) async {
    final db = await database;
    final rows = await db.query(
      'enveloppes_budget',
      where: compteId == null ? 'actif = 1' : 'actif = 1 AND compte_id = ?',
      whereArgs: compteId == null ? null : [compteId],
      orderBy: 'type ASC, id ASC',
    );
    return rows.map(EnveloppeBudget.fromMap).toList();
  }

  Future<int> ajouterEnveloppeBudget(EnveloppeBudget enveloppe) async {
    final db = await database;
    return db.transaction((txn) async {
      await _verifierCompteType(txn, enveloppe.compteId, TypeCompte.courant);
      final data = enveloppe.toMap()..remove('id');
      final id = await txn.insert('enveloppes_budget', data);
      final periodeId = await _periodeActiveId(txn);
      if (periodeId != null) {
        await txn.insert('enveloppes_budget_periode', {
          'periode_id': periodeId,
          'enveloppe_budget_id': id,
          'montant_prevu': enveloppe.montantReference,
        });
      }
      return id;
    });
  }

  Future<int> modifierEnveloppeBudget(EnveloppeBudget enveloppe) async {
    final db = await database;
    return db.transaction((txn) async {
      await _verifierCompteType(txn, enveloppe.compteId, TypeCompte.courant);
      final data = enveloppe.toMap()..remove('id');
      final resultat = await txn.update(
        'enveloppes_budget',
        data,
        where: 'id = ?',
        whereArgs: [enveloppe.id],
      );
      final periodeId = await _periodeActiveId(txn);
      if (periodeId != null) {
        await txn.update(
          'enveloppes_budget_periode',
          {'montant_prevu': enveloppe.montantReference},
          where: 'periode_id = ? AND enveloppe_budget_id = ?',
          whereArgs: [periodeId, enveloppe.id],
        );
      }
      return resultat;
    });
  }

  Future<int> supprimerEnveloppeBudget(int id) async {
    final db = await database;
    return db.update(
      'enveloppes_budget',
      {'actif': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<EnveloppeBudgetPeriode>> obtenirEnveloppesBudgetPeriode({
    required int periodeId,
    required Iterable<int> compteIds,
  }) async {
    final ids = compteIds.toList();
    if (ids.isEmpty) return [];
    final db = await database;
    final marqueurs = _marqueurs(ids.length);
    final rows = await db.rawQuery('''
      SELECT eb.id, eb.nom, eb.type, ebp.montant_prevu,
             COALESCE(SUM(o.montant), 0) AS montant_utilise
      FROM enveloppes_budget_periode ebp
      JOIN enveloppes_budget eb ON eb.id = ebp.enveloppe_budget_id
      LEFT JOIN operations o
        ON o.enveloppe_budget_id = eb.id AND o.periode_id = ebp.periode_id
      WHERE ebp.periode_id = ? AND eb.compte_id IN ($marqueurs)
      GROUP BY eb.id, eb.nom, eb.type, ebp.montant_prevu
      ORDER BY eb.type ASC, eb.id ASC
    ''', [periodeId, ...ids]);

    return rows
        .map(
          (row) => EnveloppeBudgetPeriode(
            enveloppeId: row['id'] as int,
            nom: row['nom'] as String,
            type: TypeEnveloppeBudget.values.byName(row['type'] as String),
            montantPrevu: row['montant_prevu'] as int,
            montantUtilise: row['montant_utilise'] as int,
          ),
        )
        .toList();
  }

  // ==========================
  // EPARGNE AFFECTEE
  // ==========================

  Future<int> ajouterEnveloppeEpargne(EnveloppeEpargne enveloppe) async {
    final db = await database;
    return db.transaction((txn) async {
      await _verifierCompteType(
        txn,
        enveloppe.compteEpargneId,
        TypeCompte.epargne,
      );
      final data = enveloppe.toMap()..remove('id');
      return txn.insert('enveloppes_epargne', data);
    });
  }

  Future<List<EnveloppeEpargne>> obtenirEnveloppesEpargne({
    int? compteEpargneId,
  }) async {
    final db = await database;
    final rows = await db.query(
      'enveloppes_epargne',
      where: compteEpargneId == null
          ? 'actif = 1'
          : 'actif = 1 AND compte_epargne_id = ?',
      whereArgs: compteEpargneId == null ? null : [compteEpargneId],
      orderBy: 'id ASC',
    );
    return rows.map(EnveloppeEpargne.fromMap).toList();
  }

  Future<int> obtenirSoldeEnveloppeEpargne(int enveloppeId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT ee.solde_initial + COALESCE(SUM(ae.montant), 0) AS solde
      FROM enveloppes_epargne ee
      LEFT JOIN affectations_epargne ae ON ae.enveloppe_epargne_id = ee.id
      WHERE ee.id = ?
      GROUP BY ee.id, ee.solde_initial
    ''', [enveloppeId]);
    if (rows.isEmpty) return 0;
    return (rows.first['solde'] as num?)?.toInt() ?? 0;
  }

  Future<int> modifierEnveloppeEpargne(EnveloppeEpargne enveloppe) async {
    final db = await database;
    return db.transaction((txn) async {
      await _verifierCompteType(
        txn,
        enveloppe.compteEpargneId,
        TypeCompte.epargne,
      );
      final data = enveloppe.toMap()..remove('id');
      return txn.update(
        'enveloppes_epargne',
        data,
        where: 'id = ?',
        whereArgs: [enveloppe.id],
      );
    });
  }

  Future<int> supprimerEnveloppeEpargne(int id) async {
    final db = await database;
    final solde = await obtenirSoldeEnveloppeEpargne(id);
    if (solde != 0) {
      throw StateError(
        "Une enveloppe d'epargne doit etre vide avant suppression.",
      );
    }
    return db.update(
      'enveloppes_epargne',
      {'actif': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> obtenirTotalEpargneAffectee() async {
    final db = await database;
    final initial = Sqflite.firstIntValue(
          await db.rawQuery('''
            SELECT COALESCE(SUM(solde_initial), 0)
            FROM enveloppes_epargne
            WHERE actif = 1
          '''),
        ) ??
        0;
    final mouvements = Sqflite.firstIntValue(
          await db.rawQuery('''
            SELECT COALESCE(SUM(ae.montant), 0)
            FROM affectations_epargne ae
            JOIN enveloppes_epargne ee ON ee.id = ae.enveloppe_epargne_id
            WHERE ee.actif = 1
          '''),
        ) ??
        0;
    return initial + mouvements;
  }

  // ==========================
  // OPERATIONS
  // ==========================

  Future<int> ajouterOperation(OperationBudget operation) async {
    final db = await database;
    return db.transaction((txn) async {
      await _validerOperation(txn, operation);

      final operationId = await txn.insert('operations', {
        'periode_id': operation.periodeId,
        'date_operation': operation.date.toIso8601String(),
        'libelle': operation.libelle.trim(),
        'type': operation.type.name,
        'montant': operation.montant,
        'compte_source_id': operation.compteSourceId,
        'compte_destination_id': operation.compteDestinationId,
        'enveloppe_budget_id': operation.enveloppeBudgetId,
        'note': operation.note,
        'creee_le': DateTime.now().toIso8601String(),
      });

      for (final affectation in operation.affectationsEpargne) {
        await txn.insert('affectations_epargne', {
          'operation_id': operationId,
          'enveloppe_epargne_id': affectation.enveloppeEpargneId,
          'montant': affectation.montant,
        });
      }

      return operationId;
    });
  }

  Future<void> _validerOperation(
    DatabaseExecutor db,
    OperationBudget operation,
  ) async {
    if (operation.montant <= 0) {
      throw ArgumentError('Le montant doit etre strictement positif.');
    }
    if (operation.libelle.trim().isEmpty) {
      throw ArgumentError('Le libelle est obligatoire.');
    }

    switch (operation.type) {
      case TypeOperationBudget.salaire:
      case TypeOperationBudget.autreRevenu:
        if (operation.compteSourceId != null ||
            operation.compteDestinationId == null ||
            operation.enveloppeBudgetId != null ||
            operation.affectationsEpargne.isNotEmpty) {
          throw ArgumentError('Operation de revenu incoherente.');
        }
        await _verifierCompteType(
          db,
          operation.compteDestinationId!,
          TypeCompte.courant,
        );

      case TypeOperationBudget.depense:
        if (operation.compteSourceId == null ||
            operation.compteDestinationId != null ||
            operation.enveloppeBudgetId == null ||
            operation.affectationsEpargne.isNotEmpty) {
          throw ArgumentError(
            'Une depense doit etre affectee a une enveloppe de depense.',
          );
        }
        await _verifierCompteType(
          db,
          operation.compteSourceId!,
          TypeCompte.courant,
        );
        await _verifierEnveloppeBudget(
          db,
          operation.enveloppeBudgetId!,
          TypeEnveloppeBudget.depense,
          operation.compteSourceId!,
        );

      case TypeOperationBudget.virementEpargne:
        if (operation.compteSourceId == null ||
            operation.compteDestinationId == null ||
            operation.enveloppeBudgetId == null ||
            operation.affectationsEpargne.isEmpty) {
          throw ArgumentError(
            'Un virement epargne doit avoir une source, une destination et une affectation.',
          );
        }
        await _verifierCompteType(
          db,
          operation.compteSourceId!,
          TypeCompte.courant,
        );
        await _verifierCompteType(
          db,
          operation.compteDestinationId!,
          TypeCompte.epargne,
        );
        await _verifierEnveloppeBudget(
          db,
          operation.enveloppeBudgetId!,
          TypeEnveloppeBudget.epargne,
          operation.compteSourceId!,
        );
        if (!OperationRules.virementEpargneEntierementAffecte(
          operation.montant,
          operation.affectationsEpargne,
        )) {
          throw ArgumentError(
            "La totalite du virement doit etre affectee a l'epargne.",
          );
        }
        await _verifierAffectationsSurCompte(
          db,
          operation.affectationsEpargne,
          operation.compteDestinationId!,
        );

      case TypeOperationBudget.retraitEpargne:
        if (operation.compteSourceId == null ||
            operation.compteDestinationId == null ||
            operation.enveloppeBudgetId != null ||
            operation.affectationsEpargne.isEmpty) {
          throw ArgumentError('Retrait epargne incomplet.');
        }
        await _verifierCompteType(
          db,
          operation.compteSourceId!,
          TypeCompte.epargne,
        );
        await _verifierCompteType(
          db,
          operation.compteDestinationId!,
          TypeCompte.courant,
        );
        if (!OperationRules.retraitEpargneEntierementImpute(
          operation.montant,
          operation.affectationsEpargne,
        )) {
          throw ArgumentError(
            "Le retrait doit etre impute integralement a l'epargne.",
          );
        }
        await _verifierAffectationsSurCompte(
          db,
          operation.affectationsEpargne,
          operation.compteSourceId!,
        );

      case TypeOperationBudget.transfertEpargneInterne:
        if (operation.compteSourceId != null ||
            operation.compteDestinationId != null ||
            operation.enveloppeBudgetId != null ||
            operation.affectationsEpargne.length < 2) {
          throw ArgumentError('Transfert entre enveloppes incomplet.');
        }
        final somme = operation.affectationsEpargne.fold<int>(
          0,
          (total, a) => total + a.montant,
        );
        final positifs = operation.affectationsEpargne
            .where((a) => a.montant > 0)
            .fold<int>(0, (total, a) => total + a.montant);
        final negatifs = operation.affectationsEpargne
            .where((a) => a.montant < 0)
            .fold<int>(0, (total, a) => total - a.montant);
        if (somme != 0 ||
            positifs != operation.montant ||
            negatifs != operation.montant) {
          throw ArgumentError('Le transfert entre enveloppes doit etre equilibre.');
        }
        await _verifierAffectationsMemeCompte(
          db,
          operation.affectationsEpargne,
        );
    }
  }

  Future<int> obtenirMouvementNetComptes({
    required int periodeId,
    required Iterable<int> compteIds,
  }) async {
    final ids = compteIds.toList();
    if (ids.isEmpty) return 0;
    final db = await database;
    final marqueurs = _marqueurs(ids.length);
    final rows = await db.rawQuery('''
      SELECT
        COALESCE(SUM(CASE WHEN compte_destination_id IN ($marqueurs) THEN montant ELSE 0 END), 0)
        - COALESCE(SUM(CASE WHEN compte_source_id IN ($marqueurs) THEN montant ELSE 0 END), 0)
        AS net
      FROM operations
      WHERE periode_id = ?
    ''', [...ids, ...ids, periodeId]);
    return (rows.first['net'] as num?)?.toInt() ?? 0;
  }

  Future<List<OperationResume>> obtenirDernieresOperations({
    required int periodeId,
    required int compteCourantId,
    int limite = 10,
  }) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT id, date_operation, libelle, type,
             CASE
               WHEN compte_destination_id = ? THEN montant
               WHEN compte_source_id = ? THEN -montant
               ELSE 0
             END AS montant_signe
      FROM operations
      WHERE periode_id = ?
        AND (compte_source_id = ? OR compte_destination_id = ?)
      ORDER BY date_operation DESC, id DESC
      LIMIT ?
    ''', [
      compteCourantId,
      compteCourantId,
      periodeId,
      compteCourantId,
      compteCourantId,
      limite,
    ]);
    return rows.map(OperationResume.fromMap).toList();
  }

  Future<int> obtenirEntreesComptes({
    required int periodeId,
    required Iterable<int> compteIds,
  }) async {
    final ids = compteIds.toList();
    if (ids.isEmpty) return 0;
    final db = await database;
    final marqueurs = _marqueurs(ids.length);
    final rows = await db.rawQuery('''
      SELECT COALESCE(SUM(montant), 0) AS total
      FROM operations
      WHERE periode_id = ? AND compte_destination_id IN ($marqueurs)
    ''', [periodeId, ...ids]);
    return (rows.first['total'] as num?)?.toInt() ?? 0;
  }

  Future<int> obtenirSoldeOuvertureComptes({
    required int periodeId,
    required Iterable<int> compteIds,
  }) async {
    final ids = compteIds.toList();
    if (ids.isEmpty) return 0;
    final db = await database;
    final marqueurs = _marqueurs(ids.length);
    final rows = await db.rawQuery('''
      SELECT COALESCE(SUM(montant), 0) AS total
      FROM soldes_ouverture_periode
      WHERE periode_id = ? AND compte_id IN ($marqueurs)
    ''', [periodeId, ...ids]);
    return (rows.first['total'] as num?)?.toInt() ?? 0;
  }

  // ==========================
  // VALIDATIONS INTERNES
  // ==========================

  Future<int?> _periodeActiveId(DatabaseExecutor db) async {
    final rows = await db.query(
      'periodes',
      columns: ['id'],
      where: 'est_active = 1',
      orderBy: 'id DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['id'] as int;
  }

  Future<void> _verifierCompteType(
    DatabaseExecutor db,
    int compteId,
    TypeCompte attendu,
  ) async {
    final rows = await db.query(
      'comptes',
      columns: ['type', 'actif'],
      where: 'id = ?',
      whereArgs: [compteId],
      limit: 1,
    );
    if (rows.isEmpty ||
        rows.first['type'] != attendu.name ||
        rows.first['actif'] != 1) {
      throw ArgumentError('Le compte selectionne est incompatible.');
    }
  }

  Future<void> _verifierEnveloppeBudget(
    DatabaseExecutor db,
    int enveloppeId,
    TypeEnveloppeBudget type,
    int compteId,
  ) async {
    final rows = await db.query(
      'enveloppes_budget',
      columns: ['type', 'compte_id', 'actif'],
      where: 'id = ?',
      whereArgs: [enveloppeId],
      limit: 1,
    );
    if (rows.isEmpty ||
        rows.first['type'] != type.name ||
        rows.first['compte_id'] != compteId ||
        rows.first['actif'] != 1) {
      throw ArgumentError("L'enveloppe selectionnee est incompatible.");
    }
  }

  Future<void> _verifierAffectationsSurCompte(
    DatabaseExecutor db,
    List<AffectationEpargne> affectations,
    int compteEpargneId,
  ) async {
    for (final affectation in affectations) {
      final rows = await db.query(
        'enveloppes_epargne',
        columns: ['compte_epargne_id', 'actif'],
        where: 'id = ?',
        whereArgs: [affectation.enveloppeEpargneId],
        limit: 1,
      );
      if (rows.isEmpty ||
          rows.first['compte_epargne_id'] != compteEpargneId ||
          rows.first['actif'] != 1) {
        throw ArgumentError("Affectation d'epargne incompatible.");
      }
    }
  }

  Future<void> _verifierAffectationsMemeCompte(
    DatabaseExecutor db,
    List<AffectationEpargne> affectations,
  ) async {
    int? compteId;
    for (final affectation in affectations) {
      final rows = await db.query(
        'enveloppes_epargne',
        columns: ['compte_epargne_id', 'actif'],
        where: 'id = ?',
        whereArgs: [affectation.enveloppeEpargneId],
        limit: 1,
      );
      if (rows.isEmpty || rows.first['actif'] != 1) {
        throw ArgumentError("Enveloppe d'epargne introuvable.");
      }
      final courant = rows.first['compte_epargne_id'] as int;
      compteId ??= courant;
      if (courant != compteId) {
        throw ArgumentError(
          "Un transfert interne ne peut pas melanger plusieurs comptes d'epargne.",
        );
      }
    }
  }

  String _marqueurs(int nombre) => List.filled(nombre, '?').join(',');
}
