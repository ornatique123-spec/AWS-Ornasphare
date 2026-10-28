import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
class Offlinevaluesave {


  /// ✅ SAVE local draft (dareek change par call thashe)
  Future<void> saveCastingDraft(int voucherId, List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    final String key = "casting_draft_$voucherId";
    final String jsonData = jsonEncode(items);
    await prefs.setString(key, jsonData);
  }

  /// ✅ LOAD local draft (dialog open thata pehla call thashe)
  Future<List<Map<String, dynamic>>?> loadCastingDraft(int voucherId) async {
    final prefs = await SharedPreferences.getInstance();
    final String key = "casting_draft_$voucherId";
    final String? jsonData = prefs.getString(key);

    if (jsonData == null || jsonData.isEmpty) return null;

    try {
      final List decoded = jsonDecode(jsonData);
      return decoded.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      return null;
    }
  }

  /// ✅ CLEAR local draft (Apply success pachi call thashe)
  Future<void> clearCastingDraft(int voucherId) async {
    final prefs = await SharedPreferences.getInstance();
    final String key = "casting_draft_$voucherId";
    await prefs.remove(key);
  }
}