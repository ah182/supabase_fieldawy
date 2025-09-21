import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CacheEntry<T> {
  final T data;
  final DateTime expiryTime;

  CacheEntry(this.data, this.expiryTime);

  bool get isExpired => DateTime.now().isAfter(expiryTime);
}

class CachingService {
  final Map<String, CacheEntry> _cache = {};

  T? get<T>(String key) {
    final entry = _cache[key];

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
    _cache[key] = CacheEntry(data, expiryTime);
    if (kDebugMode) {
      print('Cache SET for key: $key');
    }
  }

  void invalidate(String key) {
    _cache.remove(key);
    if (kDebugMode) {
      print('Cache INVALIDATED for key: $key');
    }
  }

  void invalidateWithPrefix(String prefix) {
    _cache.removeWhere((key, value) => key.startsWith(prefix));
    if (kDebugMode) {
      print('Cache INVALIDATED for prefix: $prefix');
    }
  }

  void clear() {
    _cache.clear();
    if (kDebugMode) {
      print('Cache CLEARED');
    }
  }
}

final cachingServiceProvider = Provider<CachingService>((ref) => CachingService());