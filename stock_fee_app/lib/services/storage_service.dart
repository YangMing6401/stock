import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/broker_setting.dart';
import '../models/history_record.dart';

class StorageService {
  static const String _brokerKey = 'broker_setting';
  static const String _historyKey = 'calculation_history';

  static Future<BrokerSetting> loadBrokerSetting() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString(_brokerKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final map = jsonDecode(jsonStr);
        return BrokerSetting.fromJson(map);
      }
    } catch (e) {
      // Fallback
    }
    return const BrokerSetting();
  }

  static Future<void> saveBrokerSetting(BrokerSetting setting) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_brokerKey, jsonEncode(setting.toJson()));
  }

  static Future<List<HistoryRecord>> loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? list = prefs.getStringList(_historyKey);
      if (list != null) {
        return list.map((item) => HistoryRecord.fromJson(item)).toList();
      }
    } catch (e) {
      // Fallback
    }
    return [];
  }

  static Future<void> saveRecord(HistoryRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(_historyKey) ?? [];
    list.insert(0, record.toJson());
    // Keep top 50 records
    if (list.length > 50) {
      list.removeRange(50, list.length);
    }
    await prefs.setStringList(_historyKey, list);
  }

  static Future<void> deleteRecord(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? list = prefs.getStringList(_historyKey);
    if (list != null) {
      list.removeWhere((item) {
        final record = HistoryRecord.fromJson(item);
        return record.id == id;
      });
      await prefs.setStringList(_historyKey, list);
    }
  }

  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }
}
