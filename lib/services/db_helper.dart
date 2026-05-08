import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/produto.dart';
import '../models/custo_operacional.dart';

class DBHelper {
  static const _dbName = 'estoque_cic.db';
  // Versão 3 inclui tabela de custos operacionais
  static const _dbVersion = 3;
  static const _tableName = 'produtos';
  static const _tableCustos = 'custos_operacionais';

  DBHelper._();
  static final DBHelper instance = DBHelper._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String dbPath = await getDatabasesPath();
    String path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade, // Gatilho para atualizar o banco antigo
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        codigo TEXT PRIMARY KEY,
        nome TEXT NOT NULL,
        lote TEXT,
        quantidade INTEGER NOT NULL,
        valorCompra REAL NOT NULL,
        markup REAL NOT NULL,
        valorVenda REAL NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $_tableCustos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        valor REAL NOT NULL
      )
    ''');
  }

  // Atualiza o banco se for uma versão mais antiga
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute("ALTER TABLE $_tableName ADD COLUMN markup REAL NOT NULL DEFAULT 2.0");
      await db.execute("ALTER TABLE $_tableName ADD COLUMN valorVenda REAL NOT NULL DEFAULT 0.0");
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE $_tableCustos (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nome TEXT NOT NULL,
          valor REAL NOT NULL
        )
      ''');
    }
  }

  Future<int> insertProduto(Produto produto) async {
    Database db = await instance.database;
    return await db.insert(
      _tableName,
      produto.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Produto>> getEstoque() async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(_tableName);
    return List.generate(maps.length, (i) {
      return Produto.fromJson(maps[i]);
    });
  }

  Future<int> deleteProduto(String codigo) async {
    Database db = await instance.database;
    return await db.delete(
      _tableName,
      where: 'codigo = ?',
      whereArgs: [codigo],
    );
  }

  Future<List<CustoOperacional>> getCustosOperacionais() async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(_tableCustos);
    return List.generate(maps.length, (i) {
      return CustoOperacional.fromJson(maps[i]);
    });
  }

  Future<int> replaceCustosOperacionais(List<CustoOperacional> custos) async {
    Database db = await instance.database;
    await db.delete(_tableCustos);
    int inserted = 0;
    for (var custo in custos) {
      await db.insert(
        _tableCustos,
        custo.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      inserted++;
    }
    return inserted;
  }
}