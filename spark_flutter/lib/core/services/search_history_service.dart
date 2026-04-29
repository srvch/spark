import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kPrefsKey = 'spark_recent_searches';
const _kMaxHistory = 8;

// ── Provider ──────────────────────────────────────────────────────────────────
final searchHistoryProvider =
    StateNotifierProvider<SearchHistoryNotifier, List<String>>((ref) {
  return SearchHistoryNotifier()..load();
});

class SearchHistoryNotifier extends StateNotifier<List<String>> {
  SearchHistoryNotifier() : super([]);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getStringList(_kPrefsKey) ?? [];
  }

  Future<void> add(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final updated = [q, ...state.where((s) => s != q)]
        .take(_kMaxHistory)
        .toList();
    await prefs.setStringList(_kPrefsKey, updated);
    state = updated;
  }

  Future<void> remove(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final updated = state.where((s) => s != query).toList();
    await prefs.setStringList(_kPrefsKey, updated);
    state = updated;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPrefsKey);
    state = [];
  }
}
