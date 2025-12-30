import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Provider للوصول لـ SharedPreferences
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences not initialized');
});

// StateNotifier لإدارة سجلات البحث المتعددة
// الحالة الآن هي Map<String, List<String>> حيث المفتاح هو tabId
class SearchHistoryNotifier extends StateNotifier<Map<String, List<String>>> {
  final SharedPreferences _prefs;
  static const _key = 'search_history_map';
  static const _maxHistoryLength = 3; // أحدث 3 عمليات بحث لكل تاب

  SearchHistoryNotifier(this._prefs) : super({}) {
    _loadHistory();
  }

  void _loadHistory() {
    final jsonString = _prefs.getString(_key);
    if (jsonString != null) {
      try {
        final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
        // تحويل القيم إلى List<String>
        final historyMap = decoded.map((key, value) {
          return MapEntry(key, List<String>.from(value));
        });
        state = historyMap;
      } catch (e) {
        state = {};
      }
    } else {
      state = {};
    }
  }

  Future<void> addSearchTerm(String term, String tabId) async {
    if (term.trim().isEmpty) return;
    
    final cleanTerm = term.trim();
    // نسخ الحالة الحالية
    final currentMap = Map<String, List<String>>.from(state);
    
    // الحصول على قائمة التاب الحالي أو إنشاء جديدة
    var tabHistory = List<String>.from(currentMap[tabId] ?? []);

    // إزالة الكلمة لو موجودة
    tabHistory.removeWhere((item) => item.toLowerCase() == cleanTerm.toLowerCase());
    
    // إضافة في الأول
    tabHistory.insert(0, cleanTerm);

    // الحفاظ على الحد الأقصى
    if (tabHistory.length > _maxHistoryLength) {
      tabHistory = tabHistory.sublist(0, _maxHistoryLength);
    }

    // تحديث الماب
    currentMap[tabId] = tabHistory;
    state = currentMap;
    
    // الحفظ
    await _saveToPrefs(currentMap);
  }

  Future<void> removeSearchTerm(String term, String tabId) async {
    final currentMap = Map<String, List<String>>.from(state);
    var tabHistory = List<String>.from(currentMap[tabId] ?? []);
    
    tabHistory.remove(term);
    currentMap[tabId] = tabHistory;
    
    state = currentMap;
    await _saveToPrefs(currentMap);
  }

  Future<void> clearHistory(String tabId) async {
    final currentMap = Map<String, List<String>>.from(state);
    currentMap[tabId] = []; // مسح سجل هذا التاب فقط
    
    state = currentMap;
    await _saveToPrefs(currentMap);
  }

  Future<void> _saveToPrefs(Map<String, List<String>> map) async {
    await _prefs.setString(_key, jsonEncode(map));
  }
  
  // دالة مساعدة للحصول على سجل تاب معين
  List<String> getHistoryForTab(String tabId) {
    return state[tabId] ?? [];
  }
}

final searchHistoryProvider = StateNotifierProvider<SearchHistoryNotifier, Map<String, List<String>>>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SearchHistoryNotifier(prefs);
});