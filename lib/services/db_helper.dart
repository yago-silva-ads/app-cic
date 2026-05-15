import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/produto.dart';

class DBHelper {
  static const _dbName = 'estoque_cic.db';
  // Mudamos a versão para 2 para o app saber que a tabela cresceu
  static const _dbVersion = 4; 
  static const _tableName = 'produtos';

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
        valorVenda REAL NOT NULL,
        origem TEXT DEFAULT 'Revendido'
      )
    ''');
  }

  // Se o usuário já tinha o app instalado (Versão 1), adiciona as colunas novas sem deletar nada
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute("ALTER TABLE $_tableName ADD COLUMN markup REAL NOT NULL DEFAULT 2.0");
      await db.execute("ALTER TABLE $_tableName ADD COLUMN valorVenda REAL NOT NULL DEFAULT 0.0");
    }
    if (oldVersion < 3) {
      await db.execute("ALTER TABLE $_tableName ADD COLUMN origem TEXT DEFAULT 'Revendido'");
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE ficha_tecnica (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          id_produto_fabricado TEXT NOT NULL,
          id_insumo_revendido TEXT NOT NULL,
          quantidade_usada REAL NOT NULL,
          FOREIGN KEY (id_produto_fabricado) REFERENCES produtos (codigo),
          FOREIGN KEY (id_insumo_revendido) REFERENCES produtos (codigo)
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
}