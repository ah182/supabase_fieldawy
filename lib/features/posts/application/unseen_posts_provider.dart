import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider to check for unseen posts
final unseenPostsProvider = FutureProvider<int>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final lastSeenTimestamp = prefs.getString('last_seen_post_timestamp');
  final supabase = Supabase.instance.client;

  try {
    // Get count of posts newer than last seen
    if (lastSeenTimestamp != null) {
      final response = await supabase
          .from('posts')
          .select()
          .gt('created_at', lastSeenTimestamp)
          .count(CountOption.exact);

      return response.count;
    } else {
      // First time - check if any posts exist
      final response =
          await supabase.from('posts').select().count(CountOption.exact);

      return response.count;
    }
  } catch (e) {
    print('❌ Error checking unseen posts: $e');
    return 0;
  }
});

/// Mark posts as seen (call when user opens PostsScreen)
Future<void> markPostsAsSeen() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
      'last_seen_post_timestamp', DateTime.now().toIso8601String());
}
