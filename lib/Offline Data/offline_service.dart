import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'database_helper.dart';

class OfflineService {
  OfflineService._();

  static final OfflineService instance = OfflineService._();

  /// Save Offline Data
  Future<int> saveOffline({
    required String apiUrl,
    required String method,
    required Map<String, dynamic> body,
  }) async {
    final db = await DatabaseHelper.instance.database;

    return await db.insert(
      DatabaseHelper.tableQueue,
      {
        "api_url": apiUrl,
        "method": method,
        "body": jsonEncode(body),
        "status": "pending",
        "created_at": DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get All Pending Data
  Future<List<Map<String, dynamic>>> getPendingData() async {
    final db = await DatabaseHelper.instance.database;

    return await db.query(
      DatabaseHelper.tableQueue,
      where: "status=?",
      whereArgs: ["pending"],
      orderBy: "id ASC",
    );
  }

  /// Get All Data
  Future<List<Map<String, dynamic>>> getAllData() async {
    final db = await DatabaseHelper.instance.database;

    return await db.query(
      DatabaseHelper.tableQueue,
      orderBy: "id DESC",
    );
  }

  /// Delete Synced Record
  Future<int> deleteRecord(int id) async {
    final db = await DatabaseHelper.instance.database;

    return await db.delete(
      DatabaseHelper.tableQueue,
      where: "id=?",
      whereArgs: [id],
    );
  }

  /// Delete All Records
  Future<void> clearAll() async {
    final db = await DatabaseHelper.instance.database;

    await db.delete(DatabaseHelper.tableQueue);
  }

  /// Update Status
  /// Update Status
  Future<void> updateStatus(
      int id,
      String status,
      ) async {
    final db = await DatabaseHelper.instance.database;

    await db.update(
      DatabaseHelper.tableQueue,
      {
        "status": status,
      },
      where: "id=?",
      whereArgs: [id],
    );
  }

  /// ======================================================
  /// 🔥 RETRY COUNT — 500 error par kai vaar fail thayu
  /// tracking karva mate (retry_count column joie che)
  /// ======================================================

  /// Retry count 1 vadhare
  Future<void> incrementRetryCount(int id) async {
    final db = await DatabaseHelper.instance.database;

    await db.rawUpdate(
      "UPDATE ${DatabaseHelper.tableQueue} SET retry_count = COALESCE(retry_count, 0) + 1 WHERE id = ?",
      [id],
    );
  }

  /// Ek record no current retry count get karo
  Future<int> getRetryCount(int id) async {
    final db = await DatabaseHelper.instance.database;

    final result = await db.query(
      DatabaseHelper.tableQueue,
      columns: ["retry_count"],
      where: "id=?",
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) return 0;

    return int.tryParse(result.first["retry_count"]?.toString() ?? "0") ?? 0;
  }

  /// Pending Count
  Future<int> pendingCount() async {
    final db = await DatabaseHelper.instance.database;

    final result = await db.rawQuery(
      "SELECT COUNT(*) as total FROM ${DatabaseHelper.tableQueue} WHERE status='pending'",
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Save API Response
  Future<void> saveCache({
    required String apiUrl,
    required String response,
  }) async {
    final db = await DatabaseHelper.instance.database;

    await db.insert(
      "offline_cache",
      {
        "api_url": apiUrl,
        "response": response,
        "updated_at": DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get Cache
  Future<String?> getCache(String apiUrl) async {
    final db = await DatabaseHelper.instance.database;

    final result = await db.query(
      "offline_cache",
      where: "api_url=?",
      whereArgs: [apiUrl],
      limit: 1,
    );

    if (result.isEmpty) return null;

    return result.first["response"] as String;
  }
}