import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

part 'caching_service.g.dart'; // Hive generator will create this file

@HiveType(typeId: 2) // Using a new unique typeId
class CacheEntry {
  @HiveField(0)
  final dynamic data;

  @HiveField(1)
  final DateTime expiryTime;

  CacheEntry(this.data, this.expiryTime);

  bool get isExpired => DateTime.now().isAfter(expiryTime);
}

class CachingService {
  // The box will be opened in main.dart and passed to the provider.
  final Box _box;
  CachingService(this._box);

  T? get<T>(String key) {
    final entry = _box.get(key) as CacheEntry?;

    if (entry != null && !entry.isExpired) {
      if (kDebugMode) {
        print('Cache HIT for key: $key');
      }
      return entry.data as T;
    }

    if (kDebugMode) {
      print('Cache MISS for key: $key');
    }
    return null;
  }

  void set<T>(String key, T data, {Duration duration = const Duration(minutes: 10)}) {
    final expiryTime = DateTime.now().add(duration);
    _box.put(key, CacheEntry(data, expiryTime));
    if (kDebugMode) {
      print('Cache SET for key: $key');
    }
  }

  void invalidate(String key) {
    _box.delete(key);
    if (kDebugMode) {
      print('Cache INVALIDATED for key: $key');
    }
  }

  void invalidateWithPrefix(String prefix) {
    final keysToDelete = _box.keys.where((k) => k is String && k.startsWith(prefix));
    _box.deleteAll(keysToDelete);
    if (kDebugMode) {
      print('Cache INVALIDATED for prefix: $prefix');
    }
  }

  Future<void> clear() async {
    await _box.clear();
    if (kDebugMode) {
      print('Cache CLEARED');
    }
  }
}

// The provider will now depend on the box being ready.
final cachingServiceProvider = Provider<CachingService>((ref) {
  final box = Hive.box('api_cache');
  return CachingService(box);
});