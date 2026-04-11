import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/produto.dart';

class DBHelper {
  // Nome e versão do seu banco de dados local
  static const _dbName = 'estoque_cic.db';
  static const _dbVersion = 1;
  static const _tableName = 'produtos';

  // Padrão Singleton: Garante que só exista 1 conexão aberta com o banco
  DBHelper._();
  static final DBHelper instance = DBHelper._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    // Acha a pasta segura de bancos de dados dentro do Android/iOS
    String dbPath = await getDatabasesPath();
    String path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
    );
  }

  // Cria a Tabela usando SQL puro
  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        codigo TEXT PRIMARY KEY,
        nome TEXT NOT NULL,
        lote TEXT,
        quantidade INTEGER NOT NULL,
        valorCompra REAL NOT NULL
      )
    ''');
  }

  // Função INSERT
  Future<int> insertProduto(Produto produto) async {
    Database db = await instance.database;
    return await db.insert(
      _tableName,
      produto.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace, // Se já existir o código, ele substitui
    );
  }

  // Função SELECT (Busca tudo)
  Future<List<Produto>> getEstoque() async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(_tableName);
    
    return List.generate(maps.length, (i) {
      return Produto.fromJson(maps[i]);
    });
  }

  // Função DELETE
  Future<int> deleteProduto(String codigo) async {
    Database db = await instance.database;
    return await db.delete(
      _tableName,
      where: 'codigo = ?',
      whereArgs: [codigo],
    );
  }
}