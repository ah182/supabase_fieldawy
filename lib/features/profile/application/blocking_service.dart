import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final blockingServiceProvider = Provider<BlockingService>((ref) {
  return BlockingService();
});

class BlockingService {
  static const String _blockedUsersKey = 'blocked_users';

  Future<List<String>> getBlockedUsers() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_blockedUsersKey) ?? [];
  }

  Future<void> blockUser(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final blocked = prefs.getStringList(_blockedUsersKey) ?? [];
    if (!blocked.contains(userId)) {
      blocked.add(userId);
      await prefs.setStringList(_blockedUsersKey, blocked);
    }
  }

  Future<void> unblockUser(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final blocked = prefs.getStringList(_blockedUsersKey) ?? [];
    if (blocked.contains(userId)) {
      blocked.remove(userId);
      await prefs.setStringList(_blockedUsersKey, blocked);
    }
  }

  Future<bool> isUserBlocked(String userId) async {
    final blocked = await getBlockedUsers();
    return blocked.contains(userId);
  }
}
