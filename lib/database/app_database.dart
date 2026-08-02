import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/compte.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _ouvrirDatabase();
    return _database!;
  }

  Future<Database> _ouvrirDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'gestionnaire_budget.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE comptes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nom TEXT NOT NULL,
            type TEXT NOT NULL,
            solde INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  Future<int> ajouterCompte(Compte compte) async {
    final db = await database;

    final data = compte.toMap();
    data.remove('id');

    return db.insert('comptes', data);
  }

  Future<List<Compte>> obtenirComptes() async {
    final db = await database;

    final result = await db.query('comptes', orderBy: 'id DESC');

    return result.map(Compte.fromMap).toList();
  }

  Future<int> modifierCompte(Compte compte) async {
    final db = await database;

    return db.update(
      'comptes',
      compte.toMap(),
      where: 'id = ?',
      whereArgs: [compte.id],
    );
  }

  Future<int> supprimerCompte(int id) async {
    final db = await database;

    return db.delete('comptes', where: 'id = ?', whereArgs: [id]);
  }
}
