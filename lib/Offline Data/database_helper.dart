import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  static Database? _database;

  /// Database Name
  static const String databaseName = "erp_offline.db";

  /// Database Version
  static const int databaseVersion = 1;

  /// Table Name
  static const String tableQueue = "offline_queue";

  /// Get Database
  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDatabase();

    return _database!;
  }

  /// Create Database
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();

    final path = join(dbPath, databaseName);

    return await openDatabase(
      path,
      version: databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// First Time Create Table
  /// First Time Create Table
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableQueue(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        api_url TEXT NOT NULL,
        method TEXT NOT NULL,
        body TEXT NOT NULL,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  /// Future Upgrade
  Future<void> _onUpgrade(
      Database db,
      int oldVersion,
      int newVersion,
      ) async {
    /// 🔥 v1 -> v2: retry_count column add karo (500 error tracking
    /// mate). Existing installed app upgrade thay tyare aa chalse,
    /// jethi juna pending queue records na loss thay.
    if (oldVersion < 2) {
      await db.execute(
        "ALTER TABLE $tableQueue ADD COLUMN retry_count INTEGER NOT NULL DEFAULT 0",
      );
    }
  }

  /// Close Database
  Future<void> close() async {
    final db = await database;
    db.close();
  }

  /// Delete Database (Testing Only)
  Future<void> deleteDatabaseFile() async {
    final dbPath = await getDatabasesPath();

    final path = join(dbPath, databaseName);

    await deleteDatabase(path);

    _database = null;
  }
}