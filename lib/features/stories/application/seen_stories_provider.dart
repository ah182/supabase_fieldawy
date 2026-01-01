import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fieldawy_store/features/home/application/search_history_provider.dart'; // To reuse sharedPreferencesProvider

/// Provider لإدارة حالة الستوريهات المشاهدة
class SeenStoriesNotifier extends StateNotifier<Set<String>> {
  final _prefs;
  static const _key = 'seen_stories_ids';

  SeenStoriesNotifier(this._prefs) : super(<String>{}) {
    _loadSeenIds();
  }

  void _loadSeenIds() {
    final List<String>? list = _prefs.getStringList(_key);
    if (list != null) {
      state = list.toSet();
    } else {
      state = <String>{};
    }
  }

  Future<void> markAsSeen(String storyId) async {
    if (state.contains(storyId)) return;
    
    final newState = {...state, storyId};
    state = newState;
    await _prefs.setStringList(_key, newState.toList());
  }

  bool isSeen(String storyId) => state.contains(storyId);

  /// مسح السجلات القديمة (اختياري، يمكن مسحها عند الحاجة)
  Future<void> clearAll() async {
    state = {};
    await _prefs.remove(_key);
  }
}

final seenStoriesProvider = StateNotifierProvider<SeenStoriesNotifier, Set<String>>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SeenStoriesNotifier(prefs);
});
